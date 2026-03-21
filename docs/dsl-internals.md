# DSL internals

Maintainer and extension author guide to the Toddy UI DSL. This covers
the macro architecture, how blocks are compiled, and how to add new
widgets and type structs that participate in the DSL.

For user-facing DSL documentation, see the `Toddy.UI` moduledoc.


## How the DSL works

The DSL is three layers that compose bottom-up:

### Widget structs (data layer)

`Toddy.Widget.*` modules define typed structs for each widget.
`Toddy.Type.*` modules define shared property types (padding, border,
color, font, etc.). `Toddy.Canvas.Shape.*` modules define canvas shape
structs. Each struct carries its valid fields, default values, and type
metadata.

### Builder functions (construction layer)

Every widget struct module exposes `new/2` (or `new/N` for widgets with
positional args like `Button.new(id, label, opts)`), `with_options/2`,
and `build/1`. Type structs expose `from_opts/1`. Canvas shapes expose
builder functions like `Shape.rect/5`, `Shape.circle/4`. These are
plain functions -- no macros, no AST manipulation. They can be called
anywhere.

### Macros (DSL layer)

`Toddy.UI` macros provide ergonomic do-block syntax. They compile
down to calls to the builder functions at expansion time. The macros
handle:

- Auto-ID generation from call-site module and line number
- Block-form option parsing (bare `key value` declarations in do-blocks)
- Container child collection (flattening lists, filtering nils)
- Canvas context validation (layer/group/interactive nesting rules)
- Compile-time option key validation with helpful error messages

The key design constraint: macros produce the same `%{id, type, props,
children}` node maps as calling builder functions directly. The DSL is
sugar, not a separate representation.


## The Buildable behaviour

`Toddy.DSL.Buildable` is the behaviour for types that participate in
the block-form option pattern. When a container's do-block contains a
nested do-block for a struct-typed option (like `border do ... end`
inside a `container`), the DSL needs to know how to construct that
struct from the parsed key/value pairs.

### When to implement it

Implement `Buildable` on any struct that:

1. Appears as a value type in a widget's `__option_types__/0` map
2. Should support nested do-block construction in the DSL

All `Toddy.Type.*` structs that appear in widget option types implement
it. Canvas shape helper structs (`Stroke`, `Dash`, `Interactive`,
`HitRect`, `DragBounds`, `ShapeStyle`) implement it. Extension widgets
get it automatically from `prop` declarations.

### Callbacks

- `from_opts(opts)` -- constructs the struct from a keyword list.
  Should handle missing keys (use defaults) and validate unknown keys.

- `__field_keys__/0` -- returns the list of valid field name atoms.
  Used for compile-time key validation.

- `__field_types__/0` -- returns a map of field names to struct modules
  for fields that themselves support nested do-block construction. This
  enables recursive nesting (e.g. `shadow do ... end` inside
  `style do ... end`). Return `%{}` for flat structs.


## Adding a new widget

### 1. Create the struct module

Create `lib/toddy/widget/my_widget.ex`:

```elixir
defmodule Toddy.Widget.MyWidget do
  alias Toddy.Widget.Build

  @valid_option_keys ~w(width height some_prop a11y)a

  defstruct [:id, :some_prop, :width, :height, :a11y]

  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  def with_options(%__MODULE__{} = w, []), do: w

  def with_options(%__MODULE__{} = w, opts) do
    Enum.reduce(opts, w, fn
      {:some_prop, v}, acc -> %{acc | some_prop: v}
      {:width, v}, acc -> %{acc | width: v}
      {:height, v}, acc -> %{acc | height: v}
      {:a11y, v}, acc -> %{acc | a11y: v}
      {key, _}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  def build(%__MODULE__{} = w), do: Toddy.Widget.to_node(w)

  def __option_keys__, do: @valid_option_keys

  def __option_types__ do
    %{a11y: Toddy.Type.A11y}
  end
end
```

Key points:

- `__option_keys__/0` returns all valid option atoms. The DSL uses
  this for compile-time validation.
- `__option_types__/0` maps option names to struct modules for options
  that support nested do-block construction. Return `%{}` if none.
- `with_options/2` handles the keyword-to-struct conversion with
  explicit key matching. Unknown keys raise via `Build.unknown_option!/2`.

### 2. Implement the Widget protocol

```elixir
defimpl Toddy.Widget, for: Toddy.Widget.MyWidget do
  def to_node(w) do
    props =
      %{}
      |> Build.put_if(w.some_prop, :some_prop)
      |> Build.put_if(w.width, :width)
      |> Build.put_if(w.height, :height)

    %{id: w.id, type: "my_widget", props: props, children: []}
  end
end
```

### 3. Add a macro to Toddy.UI

For a **leaf widget** (no children):

```elixir
defmacro my_widget(id, opts_or_do \\ []) do
  case opts_or_do do
    [do: block] ->
      option_keys = Toddy.Widget.MyWidget.__option_keys__()
      option_types = Toddy.Widget.MyWidget.__option_types__()
      pairs = interpret_block(block, option_types)
      validate_option_keys!(pairs, option_keys, "my_widget", __CALLER__)
      opts_ast = pairs_to_keyword_ast(pairs)
      quote do: Toddy.UI.__build_my_widget__(unquote(id), unquote(opts_ast))

    opts ->
      quote do: Toddy.UI.__build_my_widget__(unquote(id), unquote(opts))
  end
end

@doc false
def __build_my_widget__(id, opts) do
  Toddy.Widget.MyWidget.new(id, clean_opts(opts))
  |> Toddy.Widget.MyWidget.build()
end
```

For a **container widget** (has children), follow the `column` pattern:
use `container_scope/4` to walk the block AST, then call
`__build_container__/5`.

### 4. Add to module lists

- Container widgets: add `{Toddy.Widget.MyWidget, "my_widget"}` to
  `@container_modules` in `Toddy.UI`.
- Leaf widgets: add `"my_widget"` to `@leaf_widget_names`.
- Display widgets (leaf, auto-ID): add to `@display_widget_names`.

These lists drive:
- Wrong-container error messages (which containers own which options)
- Canvas scope collision detection (widget names vs shape names)

### 5. Register in .formatter.exs

Add entries to the `toddy_ui_locals` list so the formatter keeps
do-block forms paren-free:

```elixir
my_widget: 1,
my_widget: 2,
my_widget: 3,
```


## Adding a new type struct

Type structs represent complex property values (padding, border, font,
shadow, etc.) that can be constructed via nested do-blocks.

### 1. Create the struct with Buildable

```elixir
defmodule Toddy.Type.MyType do
  @behaviour Toddy.DSL.Buildable

  defstruct [:field_a, :field_b]

  @impl true
  def from_opts(opts) do
    %__MODULE__{
      field_a: Keyword.get(opts, :field_a),
      field_b: Keyword.get(opts, :field_b)
    }
  end

  @impl true
  def __field_keys__, do: ~w(field_a field_b)a

  @impl true
  def __field_types__, do: %{}
end
```

### 2. Add the Encode protocol implementation

Implement `Toddy.Encode` so the struct serializes correctly over the
wire:

```elixir
defimpl Toddy.Encode, for: Toddy.Type.MyType do
  def encode(%{field_a: a, field_b: b}) do
    %{"field_a" => a, "field_b" => b}
  end
end
```

### 3. Wire it into widget option types

Add the mapping in the relevant widget module's `__option_types__/0`:

```elixir
def __option_types__ do
  %{my_type: Toddy.Type.MyType, padding: Toddy.Type.Padding}
end
```

This enables:

```elixir
container "box" do
  my_type do
    field_a "hello"
    field_b 42
  end
  text("content")
end
```


## How canvas_scope works

`canvas_scope/2` is a compile-time AST walker that validates and
rewrites expressions inside canvas do-blocks. It tracks three nesting
contexts: `:canvas`, `:layer`, and `:group`.

### Context rules

| Expression | Valid in | Invalid in |
|---|---|---|
| `layer` | `:canvas` | `:layer`, `:group` |
| `group` | `:layer`, `:group` | `:canvas` |
| `interactive` | `:group` | `:canvas`, `:layer` |
| Shape functions | `:layer`, `:group` | `:canvas` |

### Rewriting

`text`, `image`, and `svg` are ambiguous -- they exist as both widget
macros and canvas shape builders. Inside canvas scope, `canvas_scope`
rewrites calls to these names:

- `text(x, y, content, opts)` in canvas scope calls
  `Toddy.Canvas.Shape.text/4` (shape builder), not `Toddy.UI.text`
  (widget macro).
- Short-form `text("hello")` is detected and raises a compile error
  with a hint to use the positional canvas form.

The same rewriting applies to `image` and `svg`.

### Control flow

`canvas_scope` recurses into `if`, `for`, `case`, `cond`, `with`, and
`unless` bodies, preserving all branches. Anonymous functions (`fn`)
inside canvas blocks are also walked.

### Error messages

Invalid nesting produces compile-time errors with context:

```
** (CompileError) group is not valid here. Put groups inside a layer:

    layer "main" do
      group do
        ...
      end
    end
```


## How container_scope works

`container_scope/4` walks container do-block ASTs, rewriting bare
option calls into tagged tuples that `__build_container__/5` can
partition from children at runtime.

### What it does

1. **Option recognition.** A bare call like `spacing 8` where
   `spacing` is in the widget's `__option_keys__` list gets rewritten
   to `{:__widget_prop__, :spacing, 8}`.

2. **Do-block option handling.** A call like `padding do top 16 end`
   where `padding` maps to `Toddy.Type.Padding` in `__option_types__`
   gets rewritten to
   `{:__widget_prop__, :padding, Toddy.Type.Padding.from_opts(...)}`.

3. **Wrong-container validation.** A bare call like `spacing 8` inside
   a `container` block (where `spacing` is not valid) checks whether
   `spacing` belongs to any other container. If so, it raises a
   compile error naming the containers that support it.

4. **Pass-through.** Everything else (widget calls, function calls,
   variables, literals) passes through unchanged and becomes a child
   node.

### Control flow

Like `canvas_scope`, `container_scope` recurses into all control flow
forms (`if`, `for`, `case`, `cond`, `with`, `unless`, `fn`), applying
`wrap_block_in_list` to multi-expression bodies.


## The block interpreter pipeline

`interpret_block/2` handles do-blocks for leaf widgets and nested
struct options. It converts block AST into keyword pairs suitable for
`from_opts` or `with_options` calls.

### Pipeline

1. **Parse block AST.** A `{:__block__, _, exprs}` tuple is split into
   individual expressions. A single expression is wrapped in a list.

2. **Interpret each expression.** Each `{name, meta, [value]}`
   three-tuple becomes a `{name, value}` pair. Bare names
   (`{name, meta, nil}`) become `{name, true}` (boolean flag syntax).

3. **Struct-typed key handling.** If `type_mapping` maps a key to a
   struct module and the value is a `[do: inner_block]`, the
   interpreter recurses: it calls `interpret_block` on the inner block
   using the struct's `__field_types__` for its own type mapping, then
   generates a `StructModule.from_opts(nested_pairs)` call.

4. **Output.** A list of `{atom, ast}` pairs. For leaf widgets, these
   are converted to keyword AST via `pairs_to_keyword_ast/1` and
   passed to the build function. For container options, they are
   wrapped in `from_opts` calls.


## Multi-expression control flow

### The problem

Elixir block expressions evaluate to their last expression. An `if`
body with multiple widget calls would only contribute the last widget
to the parent's children list:

```elixir
column do
  if show_header? do
    text("Title")      # this would be silently dropped
    text("Subtitle")   # only this would appear
  end
end
```

### The solution

`wrap_block_in_list/1` detects multi-expression blocks
(`{:__block__, _, exprs}` where `length(exprs) > 1`) and replaces the
block with a bare list of its expressions. Single expressions pass
through unchanged.

The parent's generated code already calls `List.flatten/1`, so the
injected list is flattened into the children list. This preserves all
expressions from every branch of every control flow form.

This transformation is applied in `container_scope` to all control
flow body positions: `if` do/else, `for` do, `case` branches, `cond`
branches, `with` do/else, and `fn` clause bodies.


## Prop override semantics

When both the keyword argument on the call line and a block-form
declaration specify the same option, the block-form value wins.

```elixir
column spacing: 8 do
  spacing 16         # overrides the keyword arg -- spacing is 16
  text("hello")
end
```

This is implemented via `Keyword.merge/2` in `__build_container__/5`:
block opts are merged over keyword opts. The behaviour is consistent
across all container and leaf widgets.
