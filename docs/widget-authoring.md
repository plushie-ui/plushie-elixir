# Widget authoring guide

How to add a new widget to the typed `Julep.Iced.Widget.*` layer.

## Overview

Three builder layers produce the same `ui_node()` maps:

```elixir
%{id: "save", type: "button", props: %{"label" => "Save"}, children: []}
```

| Layer | Module | Purpose |
|---|---|---|
| **Typed structs** | `Julep.Iced.Widget.*` | Ground truth. One module per widget, builder pattern, full typespecs. |
| **Untyped facade** | `Julep.Iced` | Props maps in, node maps out. Quick prototyping. |
| **Ergonomic DSL** | `Julep.UI` | `do` blocks, keyword-list props, auto-ID. |

When adding a new widget, you write a typed struct module. The other two
layers get support automatically (the facade uses `Node.build/4`; the UI
layer delegates to the facade).

## Widget struct anatomy

Every widget module defines:

1. **`defstruct`** with all props as fields.
2. **`@type t`** with every field typed. Optional fields use `| nil`.
3. **`@type option`** union of `{:prop, type()}` tuples (if the widget has options).
4. **`@type style`** for constrained style values (if applicable).

### Typespec conventions

- Every `@spec` uses named parameters: `name :: Type`.
- First parameter in builders uses the full widget name, not abbreviations
  (`button :: t()`, not `btn :: t()`).
- Use proper type aliases (`Julep.Iced.Color.t()`) not `term()`.
- `@type option` variants mirror builder function types exactly.
- Options parameters are always `opts :: [option()]`, never `keyword()`.

## Builder pattern

### `new/N`

Required args come first, then `opts \\ []`:

```elixir
# Leaf with label
def new(id, label, opts \\ [])

# Layout (no required args beyond id)
def new(id, opts \\ [])

# Multi-arg (range + value required)
def new(id, range, value, opts \\ [])

# Required arg, no options
def new(id, theme)
```

### Prop setters

One function per settable prop. Each returns `t()`:

```elixir
@spec width(button :: t(), width :: Julep.Iced.Length.t()) :: t()
def width(%__MODULE__{} = btn, width), do: %{btn | width: width}
```

### `with_options/2`

Applies keyword opts by dispatching to prop setters. Catch-all raises:

```elixir
@spec with_options(button :: t(), opts :: [option()]) :: t()
def with_options(%__MODULE__{} = btn, []), do: btn

def with_options(%__MODULE__{} = btn, opts) do
  Enum.reduce(opts, btn, fn
    {:width, v}, acc -> width(acc, v)
    {:style, v}, acc -> style(acc, v)
    {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
  end)
end
```

Omit `with_options/2` entirely for widgets with zero options (MouseArea,
Sensor, Themer). A catch-all-only lambda triggers a dialyzer `no_return`
warning.

### `push/2` and `extend/2`

Layout widgets that accept children provide both:

```elixir
@spec push(column :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
def push(%__MODULE__{} = col, child), do: %{col | children: col.children ++ [child]}

@spec extend(column :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
def extend(%__MODULE__{} = col, children), do: %{col | children: col.children ++ children}
```

### `build/1`

Delegates to the Widget protocol:

```elixir
@spec build(button :: t()) :: Julep.Iced.ui_node()
def build(%__MODULE__{} = btn), do: Julep.Iced.Widget.to_node(btn)
```

## The Widget protocol and `to_node/1`

Every widget module contains a `defimpl Julep.Iced.Widget` block that
converts the struct to a `%{id, type, props, children}` map.

```elixir
defimpl Julep.Iced.Widget do
  import Julep.Iced.Widget.Build

  def to_node(btn) do
    props =
      %{}
      |> put_if(btn.label, "label")
      |> put_if(btn.width, "width")
      |> put_if(btn.style, "style")
      |> put_if(btn.disabled, "disabled")

    %{id: btn.id, type: "button", props: props, children: []}
  end
end
```

### Build helpers

`Julep.Iced.Widget.Build` provides:

| Function | Purpose |
|---|---|
| `put_if(props, value, key)` | Adds `key => Encode.encode(value)` if value is not nil. |
| `put_if(props, value, key, transform)` | Adds `key => transform.(value)` if value is not nil. |
| `children_to_nodes(children)` | Converts a list of structs/maps to `ui_node()` maps. |
| `to_node(child)` | Converts a single struct or map to a `ui_node()`. |
| `unknown_option!(module, key)` | Raises `ArgumentError` for bad option keys. |

Key detail: `put_if/3` skips `nil` but **not** `false` or `0`. A
`disabled: false` prop is meaningful and will be included.

### Layout widgets with children

Use `children_to_nodes/1` in the `to_node` implementation:

```elixir
%{id: col.id, type: "column", props: props, children: children_to_nodes(col.children)}
```

This handles mixed children -- plain maps pass through, structs dispatch
through the Widget protocol.

## The Encode protocol

`Build.put_if/3` calls `Julep.Iced.Encode.encode/1` on every value
automatically. Widget authors do not need manual transforms for atoms,
tuples, or standard types.

### Built-in conversions

| Elixir type | Wire format |
|---|---|
| `:primary` (non-boolean atom) | `"primary"` (string) |
| `true` / `false` / `nil` | pass through |
| `{0, 100}` (tuple) | `[0, 100]` (list) |
| `%{"a" => :b}` (map) | `%{"a" => "b"}` (recursive) |
| `[1, :x]` (list) | `[1, "x"]` (recursive) |
| strings, integers, floats | pass through |

This means you can store atoms and tuples in your struct fields and they
will serialize correctly without explicit transforms in `to_node/1`.

### Implementing Encode for custom types

If your widget uses a custom struct as a prop value (like `Shadow`), implement
the Encode protocol so `put_if/3` can serialize it. Put the impl in
`lib/julep/iced/encode.ex` alongside the built-in impls:

```elixir
defimpl Julep.Iced.Encode, for: Julep.Iced.Shadow do
  def encode(shadow) do
    %{
      "color" => shadow.color,
      "offset" => [shadow.offset_x, shadow.offset_y],
      "blur_radius" => shadow.blur_radius
    }
  end
end
```

With this in place, `put_if(props, shadow, "shadow")` just works.

## Type modules

Shared type modules provide constructors, casts, and canonical `t()` types.
Use them in your specs and `@type` definitions instead of bare `atom()` or
`term()`.

| Module | `t()` | Notes |
|---|---|---|
| `Julep.Iced.Color` | `String.t()` (hex) | `cast/1` normalizes atoms and hex strings |
| `Julep.Iced.Length` | `:fill \| :shrink \| number()` | Maps to iced's `Length` enum |
| `Julep.Iced.Padding` | `number() \| map()` | Uniform or `%{top, right, bottom, left}` |
| `Julep.Iced.Alignment` | `:left \| :center \| :right \| ...` | Horizontal/vertical alignment |
| `Julep.Iced.Font` | `map()` | Font family, weight, style |
| `Julep.Iced.Shadow` | `%Shadow{}` | Struct with Encode impl |
| `Julep.Iced.Theme` | `String.t() \| map()` | Named theme or custom palette |

### Using `cast/1` in builders

When a prop accepts multiple input forms, use the type module's `cast/1`
to normalize in the builder:

```elixir
def color(%__MODULE__{} = shadow, color) do
  %{shadow | color: Julep.Iced.Color.cast(color)}
end
```

This lets callers pass `:red` or `"#ff0000"` and get the same canonical
hex string stored in the struct.

## Reference patterns by category

### Leaf with options: Button

`new/3` with label + opts, prop setters, `with_options/2`, `build/1`,
`defimpl`. No children. Reference: `lib/julep/iced/widget/button.ex`.

### Layout with children: Column

`new/2` with opts only, `push/2`, `extend/2`, `with_options/2`, `build/1`.
Uses `children_to_nodes/1` in `to_node`. Reference:
`lib/julep/iced/widget/column.ex`.

### Multi-arg constructor: Slider

`new/4` with required `range` and `value` args, `opts \\ []` last. Note the
`__MODULE__.default(acc, v)` call in `with_options` -- `default` shadows
`Kernel.default`, so it needs the module prefix. Reference:
`lib/julep/iced/widget/slider.ex`.

### No options: MouseArea, Sensor

`new/1` with just `id`. No `@type option`, no `with_options`, no opts
parameter. Has `push/2` and `extend/2` for children. Reference:
`lib/julep/iced/widget/mouse_area.ex`.

### Required arg, no options: Themer

`new/2` with required `theme` arg. No options machinery. Has `push/2` and
`extend/2` for children. Reference: `lib/julep/iced/widget/themer.ex`.

## Worked example: ProgressRing

A hypothetical circular progress indicator. Leaf widget, no children, a few
options.

```elixir
defmodule Julep.Iced.Widget.ProgressRing do
  @moduledoc """
  Circular progress indicator.

  ## Props

  - `value` (number) -- progress from 0.0 to 1.0. Default: 0.0.
  - `size` (number) -- diameter in pixels.
  - `thickness` (number) -- ring thickness in pixels.
  - `color` (color) -- ring color. See `Julep.Iced.Color`.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:size, number()}
          | {:thickness, number()}
          | {:color, Julep.Iced.Color.t() | atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          value: number(),
          size: number() | nil,
          thickness: number() | nil,
          color: Julep.Iced.Color.t() | nil
        }

  defstruct [:id, :value, :size, :thickness, :color]

  @doc "Creates a new progress ring with the given value (0.0 to 1.0)."
  @spec new(id :: String.t(), value :: number(), opts :: [option()]) :: t()
  def new(id, value, opts \\ []) when is_binary(id) and is_number(value) do
    %__MODULE__{id: id, value: value} |> with_options(opts)
  end

  @spec with_options(progress_ring :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = ring, []), do: ring

  def with_options(%__MODULE__{} = ring, opts) do
    Enum.reduce(opts, ring, fn
      {:size, v}, acc -> size(acc, v)
      {:thickness, v}, acc -> thickness(acc, v)
      {:color, v}, acc -> color(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @spec size(progress_ring :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = ring, size), do: %{ring | size: size}

  @spec thickness(progress_ring :: t(), thickness :: number()) :: t()
  def thickness(%__MODULE__{} = ring, thickness), do: %{ring | thickness: thickness}

  @spec color(progress_ring :: t(), color :: Julep.Iced.Color.t() | atom()) :: t()
  def color(%__MODULE__{} = ring, color) do
    %{ring | color: Julep.Iced.Color.cast(color)}
  end

  @spec build(progress_ring :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ring), do: Julep.Iced.Widget.to_node(ring)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ring) do
      props =
        %{}
        |> put_if(ring.value, "value")
        |> put_if(ring.size, "size")
        |> put_if(ring.thickness, "thickness")
        |> put_if(ring.color, "color")

      %{id: ring.id, type: "progress_ring", props: props, children: []}
    end
  end
end
```

Usage:

```elixir
alias Julep.Iced.Widget.ProgressRing

ProgressRing.new("dl", 0.75, size: 48, color: :blue)
|> ProgressRing.build()
# => %{id: "dl", type: "progress_ring",
#      props: %{"value" => 0.75, "size" => 48, "color" => "#0000ff"},
#      children: []}
```

## Dialyzer pitfalls

Things that will bite you if you don't know about them:

- **Catch-all-only lambdas.** If `Enum.reduce/3` has a lambda where every
  clause raises, dialyzer flags `no_return`. For widgets with zero options,
  omit `with_options` entirely.
- **Kernel function shadows.** If a builder is named `default/2`, `send/2`,
  etc., the bare call inside `with_options` resolves to `Kernel.x/n`. Use
  `__MODULE__.default(acc, v)`.
- **`put_if` skips nil, not false.** `false` and `0` are valid prop values.
  Don't add nil guards where you mean to preserve falsy values.

## Plain maps escape hatch

You can always build `ui_node()` maps directly without widget structs:

```elixir
%{
  id: "my_widget",
  type: "progress_bar",
  props: %{"range" => [0, 100], "value" => 42},
  children: []
}
```

This works anywhere a `ui_node()` is expected -- in `view/1` return values,
as children of layout widgets, and in test assertions. Useful for rapid
prototyping or when you don't need type safety.
