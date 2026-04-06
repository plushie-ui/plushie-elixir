# Custom Types

Plushie's type system validates, coerces, and encodes widget field
values. Types generate guards for setter function heads, typespecs
for documentation, and cast functions for runtime validation. Every
widget field declaration references a type, either a primitive
shortcut or a module implementing `Plushie.Type`.

For the behaviour API and macro details, see `Plushie.Type`.

## Built-in types

### Primitive shortcuts

| Shortcut | Module | Guard | Accepts |
|----------|--------|-------|---------|
| `:integer` | `Plushie.Type.Integer` | `is_integer(v)` | Integers only |
| `:float` | `Plushie.Type.Float` | `is_number(v)` | Integers and floats (GUI-friendly) |
| `:string` | `Plushie.Type.String` | `is_binary(v) or is_atom(v)` | Strings and atoms (coerced to string) |
| `:boolean` | `Plushie.Type.Boolean` | `is_boolean(v)` | `true` or `false` |
| `:atom` | `Plushie.Type.Atom` | `is_atom(v)` | Any atom |
| `:any` | `Plushie.Type.Any` | (none) | Any term |
| `:map` | `Plushie.Type.Map` | `is_map(v)` | Any map |

`:float` accepts integers at the API boundary because GUI dimensions
like `size: 14` should work without requiring `14.0`. The guard is
`is_number` and the value is stored as-is.

`:string` accepts atoms and coerces them to strings via
`Atom.to_string/1`. This is common for enum-like string props
(cursor names, mode strings) where atoms are more ergonomic.

### Domain types

These are full modules referenced by name in field declarations:

| Module | Purpose |
|--------|---------|
| `Plushie.Type.Color` | CSS named colors, hex strings, RGB maps |
| `Plushie.Type.Length` | `:fill`, `:shrink`, `{:fill_portion, n}`, or numeric |
| `Plushie.Type.Font` | `:default`, `:monospace`, string, or Font struct |
| `Plushie.Type.Padding` | Uniform number, `{v, h}` tuple, or per-side map |
| `Plushie.Type.Style` | Preset atoms (`:primary`, etc.) or `StyleMap` struct |
| `Plushie.Type.Range` | `{min, max}` numeric tuple |
| `Plushie.Type.Border` | Border struct (color, width, radius) |
| `Plushie.Type.Shadow` | Shadow struct (color, offset, blur) |
| `Plushie.Type.A11y` | Accessibility annotations (role, label, etc.) |
| `Plushie.Type.Alignment` | `:left`, `:center`, `:right`, `:top`, `:bottom` |
| `Plushie.Type.Shaping` | `:basic`, `:advanced`, `:auto` |
| `Plushie.Type.Wrapping` | `:none`, `:word`, `:glyph`, `:word_or_glyph` |

## The Plushie.Type behaviour

### Required callbacks

| Callback | Signature | Purpose |
|----------|-----------|---------|
| `cast/1` | `term() -> {:ok, term()} \| :error` | Validate and coerce input to canonical form |
| `typespec/0` | `-> Macro.t()` | Quoted typespec for `@type` and `@spec` generation |

### Optional callbacks

| Callback | Signature | Purpose |
|----------|-----------|---------|
| `guard/1` | `Macro.t() -> Macro.t() \| nil` | Quoted guard clause for setter function heads |
| `encode/1` | `term() -> term()` | Wire encoding (Elixir value to JSON-safe value) |
| `fields/0` | `-> [{atom(), term()}] \| nil` | Sub-field definitions for DSL block support |
| `field_options/0` | `-> [atom()]` | Valid constraint names for this type |
| `constrain_guard/2` | `(Macro.t(), keyword()) -> [Macro.t()]` | Additional guard clauses from field constraints |

## How types are used

When you declare `field :size, :float, min: 0`, the widget macro
resolves `:float` to `Plushie.Type.Float` at compile time and:

1. **Typespec**: calls `Float.typespec()` to generate the field's
   `@type` entry and setter `@spec`
2. **Guard**: calls `Float.guard(var)` to generate the setter's
   `when is_number(value)` clause
3. **Constraints**: calls `Float.constrain_guard(var, [min: 0])` to
   add `and value >= 0` to the guard
4. **Cast**: calls `Float.cast(value)` in the setter body to
   validate and coerce the input
5. **Encode**: calls `Float.encode(value)` during tree normalization
   to produce the wire-safe representation
6. **Doc generation**: uses the typespec string in the auto-generated
   Props table in the widget's `@moduledoc`

If cast returns `:error`, the setter raises `ArgumentError` with the
field name and the invalid value.

## Declaring custom types

There are four ways to declare a type: enum, struct, union, and
manual implementation. The first three use the `use Plushie.Type`
macro which generates callbacks from declarations. Manual
implementation gives full control.

### Enum types

For types with a fixed set of atom values:

```elixir
defmodule MyApp.Type.Priority do
  use Plushie.Type

  enum [:low, :medium, :high, :critical]
end
```

The macro generates:
- `cast/1`: returns `{:ok, value}` if the atom is in the list,
  `:error` otherwise
- `guard/1`: `value in [:low, :medium, :high, :critical]`
- `typespec/0`: `:low | :medium | :high | :critical`
- `encode/1`: `Atom.to_string(value)`

Use it in a widget. The `:doc` option provides the description that
appears in the auto-generated Props table and the setter's `@doc`:

```elixir
widget :task_card do
  field :priority, MyApp.Type.Priority, doc: "Task priority level."
end
```

See [Custom Widgets: Field options](custom-widgets.md#field-options)
for all available field options (`:doc`, `:default`, `:wire_name`,
`:cast`, etc.) and
[reserved field names](custom-widgets.md#reserved-field-names).

The setter accepts only the declared atoms:

```elixir
TaskCard.priority(card, :high)      # OK
TaskCard.priority(card, :unknown)   # raises ArgumentError
```

### Struct types

For types with multiple named fields:

```elixir
defmodule MyApp.Type.Margin do
  use Plushie.Type

  field :top, :float
  field :right, :float
  field :bottom, :float
  field :left, :float
end
```

The macro generates a struct and:
- `cast/1`: accepts a map or keyword list, validates each field
  through its type, returns `{:ok, %Margin{...}}`
- `fields/0`: `[top: :float, right: :float, ...]` for DSL block
  resolution
- `typespec/0`: `%MyApp.Type.Margin{top: number(), ...}`
- `encode/1`: converts struct to plain map

Struct types support the DSL block form:

```elixir
container "panel" do
  margin do
    top 10
    bottom 20
  end
end
```

### Union types

For types that accept multiple forms. Order matters: cast tries
each variant top-to-bottom and returns the first success.

```elixir
defmodule MyApp.Type.Background do
  use Plushie.Type

  union do
    enum [:transparent, :inherit]
    type Plushie.Type.Color
    type Plushie.Type.Gradient
  end
end
```

Given `Background.cast(:transparent)`:
1. Tries enum cast: `:transparent` is in the list, returns
   `{:ok, :transparent}`

Given `Background.cast("#ff0000")`:
1. Tries enum cast: `"#ff0000"` is not an atom in the list, fails
2. Tries Color.cast: valid hex string, returns `{:ok, "#ff0000"}`

Given `Background.cast(42)`:
1. Tries enum: fails
2. Tries Color: fails
3. Tries Gradient: fails
4. Returns `:error`

The guard is the OR of each variant's guard. The typespec is the
union of each variant's typespec.

**Overlapping types**: if `:transparent` is both a valid enum atom
AND a valid Color name, the enum match wins because it's listed
first. Place more specific types before more general ones.

### Manual types

For types with complex validation logic, implement the callbacks
directly without the macro:

```elixir
defmodule MyApp.Type.HexColor do
  @behaviour Plushie.Type

  @impl true
  def cast("#" <> hex = value) when byte_size(hex) in [6, 8] do
    if String.match?(hex, ~r/^[0-9a-fA-F]+$/) do
      {:ok, String.downcase(value)}
    else
      :error
    end
  end
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: String.t())

  @impl true
  def guard(var), do: quote(do: is_binary(unquote(var)))
end
```

## Writing cast/1

`cast/1` is the heart of a type module. It defines what values are
accepted and how they're normalized.

### Contract

- Return `{:ok, canonical_value}` on valid input
- Return `:error` on invalid input
- Never raise (the framework converts `:error` to `ArgumentError`
  with context)
- Be idempotent: `cast(value) |> elem(1) |> cast()` must succeed

### Multiple input forms

Types often accept several input representations and normalize to a
canonical form. `Plushie.Type.Color` is a good example:

```elixir
defmodule Plushie.Type.Color do
  @behaviour Plushie.Type

  # Named atoms: :red, :blue, :cornflowerblue, ...
  def cast(name) when is_atom(name) do
    case Map.fetch(@named_colors, name) do
      {:ok, hex} -> {:ok, hex}
      :error -> :error
    end
  end

  # Hex strings: "#ff0000", "#ff000080"
  def cast("#" <> _ = hex), do: {:ok, String.downcase(hex)}

  # RGB maps: %{r: 255, g: 0, b: 0}
  def cast(%{r: r, g: g, b: b}) when is_integer(r) and is_integer(g) and is_integer(b) do
    {:ok, "#" <> hex(r) <> hex(g) <> hex(b)}
  end

  def cast(_), do: :error
end
```

All three forms normalize to a canonical hex string. The setter
accepts any of them:

```elixir
Button.background(btn, :red)           # OK, stored as "#ff0000"
Button.background(btn, "#FF0000")      # OK, stored as "#ff0000"
Button.background(btn, %{r: 255, g: 0, b: 0})  # OK, stored as "#ff0000"
Button.background(btn, 42)             # raises ArgumentError
```

### Delegating to other types

Types can compose internally by calling other types' `cast/1`:

```elixir
defmodule MyApp.Type.ColorPair do
  @behaviour Plushie.Type

  def cast(%{fg: fg, bg: bg}) do
    with {:ok, fg_hex} <- Plushie.Type.Color.cast(fg),
         {:ok, bg_hex} <- Plushie.Type.Color.cast(bg) do
      {:ok, %{fg: fg_hex, bg: bg_hex}}
    else
      _ -> :error
    end
  end
  def cast(_), do: :error
end
```

## Writing guard/1

Guards run in setter function heads before cast. They reject
obviously wrong types at pattern match time (faster than calling
cast). Guards must use only guard-safe expressions (BIF calls like
`is_binary`, `is_number`, comparisons, boolean operators).

```elixir
@impl true
def guard(var) do
  quote(do: is_binary(unquote(var)) or is_atom(unquote(var)))
end
```

The `var` argument is a quoted variable reference. Return `nil` to
skip guard generation entirely (the setter accepts all values and
relies on cast for validation). This is appropriate when the type
accepts too many input forms to express in a guard.

**Note**: the guard protects the setter's main clause. A separate
nil clause (for optional fields) is generated automatically. Don't
include nil checking in your guard.

## Writing typespec/0

Return a quoted Elixir typespec AST. This appears in the widget's
`@type t` definition and setter `@spec`:

```elixir
# Simple: a known Elixir type
def typespec, do: quote(do: String.t())

# Union: multiple forms
def typespec, do: quote(do: atom() | String.t() | map())

# Module struct reference
def typespec, do: quote(do: %MyApp.Type.Margin{})
```

The typespec should describe the INPUT forms the type accepts (what
users write in code), not the internal canonical form (what cast
produces). This gives accurate `@spec` annotations on setters.

## Writing encode/1

`encode/1` converts the canonical Elixir value to a JSON-safe wire
representation. Called during tree normalization for every non-nil
prop value.

```elixir
@impl true
def encode(%__MODULE__{top: t, right: r, bottom: b, left: l}) do
  %{top: t, right: r, bottom: b, left: l}
end
```

**When to implement encode/1**:
- Your type stores structs (need to convert to plain maps)
- Your type stores atoms (need to convert to strings)
- Your type stores tuples (need to convert to lists)

**When to skip encode/1** (the default handles it):
- Your type stores strings, numbers, or booleans (already JSON-safe)
- Your type stores plain maps (recursively encoded by the framework)

The framework's default encoding (`Plushie.Type.encode_value/1`)
handles common cases: atoms become strings, tuples become lists,
maps are recursively encoded, structs delegate to their module's
`encode/1` if available.

For types with nested sub-values, call `Plushie.Type.encode_value/1`
on them:

```elixir
def encode(%__MODULE__{items: items, label: label}) do
  %{
    items: Enum.map(items, &Plushie.Type.encode_value/1),
    label: label
  }
end
```

## Composite types

Types can be composed inline in field declarations without a
dedicated module:

```elixir
widget :chart do
  field :data_points, {:list, MyApp.Type.DataPoint}
  field :range, {:tuple, [:float, :float]}
  field :mode, {:enum, [:line, :bar, :scatter]}
  field :background, {:union, [Plushie.Type.Color, Plushie.Type.Gradient]}
end
```

### How composite validation works

| Constructor | Guard | Cast |
|-------------|-------|------|
| `{:list, inner}` | `is_list(v)` | Maps `inner.cast/1` over each element. All must succeed. |
| `{:tuple, [types]}` | `is_tuple(v) and tuple_size(v) == N` | Validates each position through its type. All must succeed. |
| `{:enum, [atoms]}` | `v in [atoms]` | Checks membership. |
| `{:union, [types]}` | OR of each type's guard | Tries each type's cast in order. First `{:ok, _}` wins. |

If any element fails to cast in a list or tuple, the entire setter
raises `ArgumentError`.

### Nested composites

Composites nest naturally:

```elixir
# List of coordinate tuples
field :path, {:list, {:tuple, [:float, :float]}}

# List of enum values
field :selected_tags, {:list, {:enum, [:bug, :feature, :docs]}}
```

The setter validates the outer list, then validates each element
through the inner composite.

### When to use a module vs inline composite

Use inline composites when the type is simple and used in one place:

```elixir
field :mode, {:enum, [:line, :bar, :scatter]}
```

Use a module when:
- The type has complex cast logic (multiple input forms)
- The type is reused across multiple widgets
- The type needs custom encoding
- The type has constraints (field_options/constrain_guard)

## Field constraints

Numeric and string types can declare constraint support. The widget
macro validates constraints at compile time and extends the setter
guard:

```elixir
field :opacity, :float, min: 0.0, max: 1.0
field :name, :string, min_length: 1
field :count, :integer, min: 0, max: 999
```

| Type | Constraints | Guard extension |
|------|-------------|----------------|
| `:integer` | `min`, `max` | `value >= min and value <= max` |
| `:float` | `min`, `max` | `value >= min and value <= max` |
| `:string` | `min_length`, `max_length` | `byte_size(value) >= n` |

### Custom constraints

Define your own constraints by implementing `field_options/0` and
`constrain_guard/2`:

```elixir
defmodule MyApp.Type.Port do
  @behaviour Plushie.Type

  @impl true
  def cast(v) when is_integer(v) and v > 0 and v <= 65535, do: {:ok, v}
  def cast(_), do: :error

  @impl true
  def typespec, do: quote(do: pos_integer())

  @impl true
  def guard(var), do: quote(do: is_integer(unquote(var)))

  @impl true
  def field_options, do: [:exclude_reserved]

  @impl true
  def constrain_guard(var, opts) do
    if opts[:exclude_reserved] do
      [quote(do: unquote(var) > 1024)]
    else
      []
    end
  end
end
```

Usage:

```elixir
field :port, MyApp.Type.Port, exclude_reserved: true
```

The macro checks at compile time that `exclude_reserved` is in the
type's `field_options()` list. Unknown constraints raise a compile
error.

## Types in event declarations

The same types work in event field declarations:

```elixir
event :color_changed do
  field :hue, :float
  field :saturation, :float
end

event :item_selected, value: MyApp.Type.Priority
```

Event fields are validated at the wire boundary when events arrive
from the renderer, using `Plushie.Type.cast_field/2`. Invalid values
are dropped with a protocol error. This catches type mismatches
between the renderer and SDK at the boundary rather than deep in
application code.

## Nil handling

Types never receive `nil`. The framework handles nil before calling
cast:

- `required: true` fields (default for positional args): nil at
  construction time raises `ArgumentError`
- Optional fields: nil in a setter stores nil (unsets the field)
- Nil fields are skipped during wire encoding (renderer uses its
  default)

Your `cast/1` does not need a `cast(nil)` clause.

## Module organization

Place type modules under a `Type` namespace in your application:

```
lib/
  my_app/
    type/
      priority.ex       # MyApp.Type.Priority
      color_pair.ex     # MyApp.Type.ColorPair
      margin.ex         # MyApp.Type.Margin
```

Type modules are discovered by the widget macro at compile time via
`Code.ensure_compiled/1`. They must be compilable before the widget
module that references them.

## Testing

### Cast validation

Test your type's `cast/1` with valid inputs, invalid inputs, and
edge cases:

```elixir
describe "Priority" do
  test "accepts valid values" do
    assert {:ok, :high} = MyApp.Type.Priority.cast(:high)
    assert {:ok, :low} = MyApp.Type.Priority.cast(:low)
  end

  test "rejects invalid values" do
    assert :error = MyApp.Type.Priority.cast(:invalid)
    assert :error = MyApp.Type.Priority.cast("high")
    assert :error = MyApp.Type.Priority.cast(nil)
  end

  test "is idempotent" do
    {:ok, value} = MyApp.Type.Priority.cast(:high)
    assert {:ok, ^value} = MyApp.Type.Priority.cast(value)
  end
end
```

### Multi-form cast

For types accepting multiple input forms, test each form and verify
they produce the same canonical output:

```elixir
test "all color forms normalize to hex" do
  {:ok, from_atom} = Color.cast(:red)
  {:ok, from_hex} = Color.cast("#ff0000")
  {:ok, from_map} = Color.cast(%{r: 255, g: 0, b: 0})

  assert from_atom == from_hex
  assert from_hex == from_map
  assert from_atom == "#ff0000"
end
```

### Encode round-trip

Verify encoded output is JSON-safe and preserves information:

```elixir
test "encode produces JSON-safe output" do
  {:ok, value} = MyApp.Type.Margin.cast(%{top: 10, bottom: 20})
  encoded = MyApp.Type.Margin.encode(value)

  assert is_map(encoded)
  assert {:ok, _} = Jason.encode(encoded)
  assert encoded.top == 10
  assert encoded.bottom == 20
end
```

### Widget integration

Test that widgets using your type validate correctly:

```elixir
test "setter accepts valid values" do
  card = TaskCard.new("t1") |> TaskCard.priority(:high)
  assert card.priority == :high
end

test "setter rejects invalid values" do
  assert_raise ArgumentError, fn ->
    TaskCard.new("t1") |> TaskCard.priority(:invalid)
  end
end
```

## See also

- `Plushie.Type` - behaviour definition and `use Plushie.Type` macro
- [Custom Widgets reference](custom-widgets.md) - using types in widget
  field declarations
- [Built-in Widgets reference](built-in-widgets.md) - type usage in
  built-in widget props
