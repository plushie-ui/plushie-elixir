# Custom Canvas Elements

Canvas elements are reusable, typed building blocks for canvas drawing.
Like custom widgets compose UI from built-in widgets, custom canvas
elements compose visuals from built-in shapes. They produce tree nodes
(same wire format as widgets) but operate in the canvas coordinate
domain: positioned by x/y coordinates, drawn by the canvas renderer.

For the canvas system itself, see the [Canvas guide](../guides/12-canvas.md)
and [Canvas reference](canvas.md). For widgets that wrap canvas elements
with behaviour and state, see [Custom Widgets](custom-widgets.md).

## When to use what

| Situation | Approach |
|---|---|
| One-off visual in a view | Inline shapes in a canvas block |
| Reusable visual component | Custom canvas element |
| Visual with internal state | Custom widget with canvas view |
| Standard UI control | Built-in widget |

**Inline shapes** are fine for visuals you use once. When you find
yourself copying the same group of shapes between views, extract an
element.

**Custom canvas elements** are pure visual components: typed fields,
validated input, reusable across canvases. No state, no event handling.
They produce tree nodes like any other shape.

**Custom widgets** add behaviour on top. A widget can wrap a canvas
element, add state management, handle events, and expose a high-level
API. See [From element to widget](#from-element-to-widget) for the
full progression.

**Built-in widgets** cover standard controls (buttons, inputs, sliders).
Reach for canvas when you need custom visuals that built-in widgets
do not provide.

## Your first element

A color swatch: a filled rectangle with optional corner radius.

```elixir
defmodule MyApp.Canvas.ColorSwatch do
  use Plushie.Canvas.Element

  element :color_swatch do
    field :x, :float
    field :y, :float
    field :w, :float
    field :h, :float
    field :color, Plushie.Type.Color
    field :radius, :float, default: 4
  end
end
```

`use Plushie.Canvas.Element` imports the declaration macros and
registers the `@before_compile` hook that generates all the code.

`element :color_swatch` declares the type name. This becomes the
wire type string and the struct module identity.

`field` declarations define typed properties. Primitive shortcuts
(`:float`, `:string`, `:boolean`) and domain types
(`Plushie.Type.Color`) work exactly as they do in widget declarations.

### Generated API

The macro generates:

- **`new/1`**: `ColorSwatch.new(opts)` returns a struct with no ID
  (auto-assigned by the parent container)
- **`new/2`**: `ColorSwatch.new(id, opts)` returns a struct with
  explicit ID
- **Setters**: `ColorSwatch.color(swatch, "#ff0000")` for pipeline
  composition
- **`with_options/2`**: apply keyword options
- **`build/1`**: explicit conversion to a `ui_node()` map
- **`type_name/0`**: returns `"color_swatch"`
- **`encode/1`**: wire-format conversion
- **`Plushie.Tree.Node`** protocol implementation

### Using it in a canvas

Inside a canvas block, use the auto-ID form (the container assigns
IDs automatically):

```elixir
canvas "palette", width: 200, height: 50 do
  layer "swatches" do
    ColorSwatch.new(x: 0, y: 0, w: 40, h: 40, color: "#ef4444")
    ColorSwatch.new(x: 50, y: 0, w: 40, h: 40, color: "#3b82f6")
    ColorSwatch.new(x: 100, y: 0, w: 40, h: 40, color: "#22c55e")
  end
end
```

Use explicit IDs when you need stable identity for event matching
or dynamic lists:

```elixir
for {color, i} <- Enum.with_index(colors) do
  ColorSwatch.new("swatch-#{i}", x: i * 50, y: 0, w: 40, h: 40, color: color)
end
```

### Tree node output

`ColorSwatch.new("red", x: 0, y: 0, w: 40, h: 40, color: "#ef4444") |> ColorSwatch.build()` produces:

```elixir
%{
  id: "red",
  type: "color_swatch",
  props: %{x: 0, y: 0, w: 40, h: 40, color: "#ef4444", radius: 4},
  children: []
}
```

This is the same structure as any built-in shape node. The renderer
sees a flat tree node with typed props.

## Typed fields

Element fields use the same `Plushie.Type` system as widget fields.
When you declare `field :color, Plushie.Type.Color`, the macro:

1. Generates a setter with a guard: `def color(el, value) when is_binary(value) or is_atom(value)`
2. Validates input through `Color.cast/1` (accepts hex strings, named
   atoms, RGB maps)
3. Generates the typespec for documentation
4. Encodes via `Color.encode/1` during wire conversion

```elixir
# All valid, all normalize to hex:
ColorSwatch.new("s1", x: 0, y: 0, w: 40, h: 40, color: :red)
ColorSwatch.new("s2", x: 0, y: 0, w: 40, h: 40, color: "#ff0000")
ColorSwatch.new("s3", x: 0, y: 0, w: 40, h: 40, color: %{r: 255, g: 0, b: 0})

# Invalid, raises ArgumentError:
ColorSwatch.new("s4", x: 0, y: 0, w: 40, h: 40, color: 42)
```

For simple elements, `:any` and `:float` are fine. Use domain types
when you want validation and documentation. See the
[Custom Types reference](custom-types.md) for building your own.

## Using elements

Three ways to use the same element.

### In a canvas block (DSL)

```elixir
canvas "palette", width: 200, height: 50 do
  layer "swatches" do
    ColorSwatch.new(x: 0, y: 0, w: 40, h: 40, color: "#ef4444")
    ColorSwatch.new(x: 50, y: 0, w: 40, h: 40, color: "#3b82f6")
  end
end
```

### Pipeline construction

```elixir
swatch =
  ColorSwatch.new("red")
  |> ColorSwatch.x(0)
  |> ColorSwatch.y(0)
  |> ColorSwatch.w(40)
  |> ColorSwatch.h(40)
  |> ColorSwatch.color("#ef4444")
  |> ColorSwatch.radius(8)
```

### Helper function returning structs

```elixir
defp swatch_row(colors) do
  for {color, i} <- Enum.with_index(colors) do
    ColorSwatch.new("swatch-#{i}",
      x: i * 50, y: 0, w: 40, h: 40, color: color
    )
  end
end
```

This is particularly useful with `import Plushie.Canvas.Shape` for
helper functions outside canvas blocks. The returned structs are
valid tree nodes that the canvas renderer processes like any built-in
shape.

## Positional arguments

Elements support positional constructor arguments for frequently used
fields. Declare them with `positional`:

```elixir
element :color_swatch do
  positional [:x, :y, :w, :h]

  field :x, :float
  field :y, :float
  field :w, :float
  field :h, :float
  field :color, Plushie.Type.Color
  field :radius, :float, default: 4
end
```

This generates `new(id, x, y, w, h, opts \\ [])` instead of the
default `new(id, opts \\ [])`:

```elixir
ColorSwatch.new("red", 0, 0, 40, 40, color: "#ef4444")
```

The built-in elements (`Rect`, `Circle`, `Text`, `Line`) all use
positional arguments for their coordinate fields.

## Composite elements

Elements that decompose into built-in shapes use a `view/2` callback.
Define typed fields for the public API, and let `view/2` produce the
primitive shapes.

A labeled dot: a filled circle with a text label underneath.

```elixir
defmodule MyApp.Canvas.LabeledDot do
  use Plushie.Canvas.Element

  element :labeled_dot do
    field :x, :float
    field :y, :float
    field :label, :string
    field :color, Plushie.Type.Color, default: "#3b82f6"
    field :radius, :float, default: 6.0
  end

  def view(_id, props) do
    import Plushie.Canvas.Shape

    [
      circle(props.x, props.y, props.radius, fill: props.color),
      text(props.x, props.y + props.radius + 12, props.label,
        fill: "#333", size: 11, align_x: "center"
      )
    ]
  end
end
```

The `view/2` callback receives the element ID and a map of the
declared fields. It returns a list of shape structs (or a single
struct). These replace the element node in the final tree.

When `view/2` is not defined, the element encodes as a single typed
node (like the ColorSwatch above). When `view/2` is defined, the
element is composite: it expands into its constituent shapes during
tree normalization.

Usage:

```elixir
canvas "status", width: 200, height: 60 do
  layer "dots" do
    LabeledDot.new(x: 40, y: 20, label: "CPU", color: "#22c55e")
    LabeledDot.new(x: 100, y: 20, label: "Memory", color: "#eab308")
    LabeledDot.new(x: 160, y: 20, label: "Disk", color: "#ef4444")
  end
end
```

## Container elements

Elements with `container: true` accept children. This is for
structural grouping (transforms, clips) rather than visual
composition.

```elixir
element :group, container: true do
  field :transforms, :any
  field :clip, :any
end
```

Container elements get `push/2` and `extend/2` for adding children
programmatically:

```elixir
group =
  Group.new("rotated")
  |> Group.push(rect(0, 0, 40, 40, fill: "#ef4444"))
  |> Group.push(circle(20, 20, 10, fill: "#fff"))
```

The built-in `Group` and `Interactive` are the primary container
elements. Most custom elements will be non-container (visual
components that produce shapes, not structural wrappers).

## Property types

Element fields support the full range of Plushie types. Some types
are particularly useful in canvas contexts:

### Stroke

A stroke descriptor for shape outlines:

```elixir
field :border, :any  # accepts Stroke structs

# Usage:
MyElement.new("el", border: stroke("#333", 2, cap: :round))
```

### Canvas gradients

Point-based linear gradients for canvas fills:

```elixir
field :fill, :any  # accepts color strings or Gradient structs

# Usage:
MyElement.new("el",
  fill: linear_gradient({0, 0}, {100, 0}, [{0.0, "#3b82f6"}, {1.0, "#1d4ed8"}])
)
```

### ShapeStyle

Style overrides for hover/pressed/focus states on interactive
elements. Accepts `fill`, `stroke`, and `opacity` fields:

```elixir
field :hover_style, :any  # accepts ShapeStyle maps

# Usage in interactive wrapper:
interactive "btn", hover_style: %{fill: "#2563eb"} do
  MyElement.new("el", ...)
end
```

See `Plushie.Canvas.ShapeStyle`, `Plushie.Canvas.Stroke`, and
`Plushie.Canvas.Gradient`.

## Interaction and accessibility

Canvas elements are visual primitives. They do not handle events or
manage state. For interaction, wrap them in an `interactive` element.

If it responds to interaction, it needs an accessible name.

### Clickable color swatch grid

```elixir
defp swatch_grid(colors, selected) do
  for {color, i} <- Enum.with_index(colors) do
    x = rem(i, 6) * 44
    y = div(i, 6) * 44

    interactive "color-#{i}", x: x, y: y,
      on_click: true,
      on_hover: true,
      cursor: :pointer,
      focusable: true,
      hover_style: %{opacity: 0.8},
      a11y: %{role: :button, label: "Select #{color}"} do

      ColorSwatch.new("swatch",
        x: 0, y: 0, w: 40, h: 40,
        color: color,
        radius: if(color == selected, do: 0, else: 4)
      )

      # Selection indicator: sharp border around the selected swatch
      if color == selected do
        rect(0, 0, 40, 40, stroke: stroke("#000", 2))
      end
    end
  end
end
```

Key points:

- **`interactive`** wraps the swatch and selection indicator in a
  clickable, focusable group.
- **`a11y: %{role: :button, label: ...}`** tells screen readers what
  this element is and what it does. Without this, the swatch is
  invisible to assistive technology.
- **`focusable: true`** adds the element to the Tab order. Keyboard
  users can navigate and activate it with Space or Enter.
- **`hover_style`** provides visual feedback without event handling.
  The renderer applies it automatically.
- **`cursor: :pointer`** signals clickability to sighted users.

The click event arrives scoped under the canvas:

```elixir
def update(model, %WidgetEvent{type: :click, id: "color-" <> index, scope: ["palette" | _]}) do
  %{model | selected_color: Enum.at(model.colors, String.to_integer(index))}
end
```

### Focus ring

Interactive elements with `focusable: true` show a focus ring by
default. Customize it:

```elixir
interactive "btn",
  focusable: true,
  show_focus_ring: true,
  focus_ring_radius: 6,
  focus_style: %{stroke: "#1d4ed8"} do
  # shapes...
end
```

Set `show_focus_ring: false` to suppress the default ring and draw
your own focus indicator in the view (driven by model state from
`:focused`/`:blurred` events).

## From element to widget

The capstone pattern. Build a ProgressRing element for the visuals,
then wrap it in a widget for the public API.

### Step 1: The element (pure visuals)

The element handles drawing. Typed fields, validated input, a view
callback that produces shape primitives. No state, no events.

```elixir
defmodule MyApp.Canvas.ProgressRing do
  use Plushie.Canvas.Element

  element :progress_ring do
    field :cx, :float
    field :cy, :float
    field :radius, :float
    field :value, :float
    field :max, :float, default: 100.0
    field :track_color, :string, default: "#e5e7eb"
    field :fill_color, :string, default: "#3b82f6"
    field :thickness, :float, default: 6.0
  end

  def view(_id, props) do
    import Plushie.Canvas.Shape

    pct = min(props.value / props.max, 1.0)

    [
      # Track (full circle)
      path([arc(props.cx, props.cy, props.radius, 0, 360)],
        stroke: stroke(props.track_color, props.thickness, cap: :round)
      ),
      # Value arc
      path([arc(props.cx, props.cy, props.radius, -90, -90 + pct * 360)],
        stroke: stroke(props.fill_color, props.thickness, cap: :round)
      ),
      # Percentage label
      text(props.cx, props.cy - 6, "#{round(pct * 100)}%",
        fill: "#333", size: 14, align_x: "center"
      )
    ]
  end
end
```

### Step 2: The widget (wraps element in canvas, adds props)

The widget provides the public API: size, label, and value. It wraps
the element in a canvas with accessibility annotations.

```elixir
defmodule MyApp.ProgressRingWidget do
  use Plushie.Widget

  widget :progress_ring

  field :value, :float, default: 0
  field :max, :float, default: 100
  field :size, :float, default: 120
  field :color, :string, default: "#3b82f6"
  field :label, :string, default: "Progress"

  def view(id, props) do
    import Plushie.UI
    alias MyApp.Canvas.ProgressRing

    pct = min(props.value / props.max, 1.0)
    half = props.size / 2
    radius = half - 8

    canvas id, width: props.size, height: props.size,
      a11y: %{role: :progress_bar, label: props.label,
              value_now: props.value, value_min: 0, value_max: props.max} do
      layer "ring" do
        ProgressRing.new("ring",
          cx: half, cy: half, radius: radius,
          value: props.value, max: props.max,
          fill_color: props.color
        )
      end
    end
  end
end
```

### Step 3: Usage in an app

```elixir
def view(model) do
  window "main", title: "Upload" do
    column spacing: 16, padding: 24 do
      MyApp.ProgressRingWidget.new("upload-progress",
        value: model.upload_progress,
        max: 100,
        label: "Upload progress",
        color: "#22c55e"
      )

      text("status", "#{round(model.upload_progress)}% complete")
    end
  end
end
```

The separation is clear: the element knows how to draw a progress
ring. The widget knows how to present it as a UI component with
accessibility, sizing, and a clean API. Neither needs to know about
the other's internals.

## Testing

### Element encode output

Test that an element produces the expected tree node structure:

```elixir
describe "ColorSwatch" do
  test "encodes to correct wire format" do
    node =
      ColorSwatch.new("red", x: 0, y: 0, w: 40, h: 40, color: "#ef4444")
      |> ColorSwatch.build()

    assert node.type == "color_swatch"
    assert node.props.color == "#ef4444"
    assert node.props.radius == 4
  end

  test "validates color field" do
    assert_raise ArgumentError, fn ->
      ColorSwatch.new("bad", x: 0, y: 0, w: 40, h: 40, color: 42)
    end
  end
end
```

### Composite view output

Test that a composite element's `view/2` returns the expected
primitives:

```elixir
describe "ProgressRing" do
  test "view produces track arc, value arc, and label" do
    result = ProgressRing.view("ring", %{
      cx: 60, cy: 60, radius: 45,
      value: 50, max: 100,
      track_color: "#e5e7eb", fill_color: "#3b82f6",
      thickness: 6.0
    })

    assert length(result) == 3
    assert %Plushie.Canvas.Path{} = Enum.at(result, 0)
    assert %Plushie.Canvas.Path{} = Enum.at(result, 1)
    assert %Plushie.Canvas.Text{} = Enum.at(result, 2)
  end
end
```

### Widget integration

Test the full widget that wraps the element, using `Plushie.Test.Case`
with a real renderer:

```elixir
defmodule MyApp.ProgressRingWidgetTest do
  use Plushie.Test.WidgetCase, widget: MyApp.ProgressRingWidget

  setup do
    init_widget("ring", value: 75, max: 100)
  end

  test "renders the progress ring" do
    assert_exists("#ring")
  end
end
```

See the [Testing reference](testing.md) for the full test helper API.

## See also

- [Canvas reference](canvas.md) - shapes, transforms, interactive
  elements
- [Canvas guide](../guides/12-canvas.md) - building a canvas button
- [Custom Widgets reference](custom-widgets.md) - wrapping elements
  in widgets with state and events
- [Custom Types reference](custom-types.md) - building typed fields
- [Composition Patterns](composition-patterns.md) - recipes for
  common UI patterns
- `Plushie.Canvas.Element` - behaviour module docs
- `Plushie.Canvas.Shape` - builder functions for all built-in shapes
