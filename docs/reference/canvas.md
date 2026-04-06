# Canvas

The canvas system provides 2D drawing with typed shape structs,
transforms, interactive groups, and accessibility support. Unlike
layout widgets that compose children, canvas draws shapes on a
surface: rectangles, circles, lines, paths, text, images, and SVG.

For a narrative introduction, see the [Canvas guide](../guides/12-canvas.md).

## Canvas widget

`Plushie.Widget.Canvas`

The canvas is a widget that contains named layers of shapes. It
participates in the layout system like any other widget (has width,
height, background) but its content is drawn shapes, not child widgets.

### Props

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `width` | Length | `:fill` | Canvas width |
| `height` | Length | `200` | Canvas height (pixels) |
| `background` | Color | *n/a* | Canvas background colour |
| `on_press` | boolean | `false` | Emit `:press` events |
| `on_release` | boolean | `false` | Emit `:release` events |
| `on_move` | boolean | `false` | Emit `:move` events |
| `on_scroll` | boolean | `false` | Emit `:scroll` events |
| `event_rate` | integer | *n/a* | Max events/sec for canvas-level events |
| `a11y` | map | *n/a* | Accessibility overrides. See [Accessibility](accessibility.md). |

## Layers

Canvas content is organised into named layers. Each layer is drawn
independently:

```elixir
canvas "chart", width: 400, height: 200 do
  layer "background" do
    rect(0, 0, 400, 200, fill: "#f5f5f5")
  end

  layer "data" do
    rect(10, 50, 80, 150, fill: "#3b82f6")
    rect(110, 100, 80, 100, fill: "#22c55e")
  end

  layer "labels" do
    text(50, 190, "A", fill: "#333", size: 12)
    text(150, 190, "B", fill: "#333", size: 12)
  end
end
```

**Drawing order**: layers are drawn in alphabetical order by name.
`"background"` draws before `"data"` which draws before `"labels"`.
This is the z-ordering mechanism. Name your layers to control which
appears on top.

**Independent caching**: each layer maps to a separate cache on the
renderer side. When a layer's shapes change, only that layer is
re-tessellated. Unchanged layers are drawn from cache. For canvases
with many shapes, splitting into layers (static background, dynamic
data, interactive controls) significantly reduces rendering work.

## Shape catalog

All shapes are builder functions in `Plushie.Canvas.Shape` that return
typed structs. Use them inside `layer` or `group` blocks.

| Function | Struct | Required args | Key options |
|---|---|---|---|
| `rect/4` | `Rect` | x, y, w, h | `fill`, `stroke`, `opacity`, `radius` (uniform number or per-corner map) |
| `circle/3` | `Circle` | x, y, r | `fill`, `stroke`, `opacity` |
| `line/4` | `Line` | x1, y1, x2, y2 | `stroke`, `opacity` |
| `text/3` | `CanvasText` | x, y, content | `fill`, `size`, `font`, `align_x`, `align_y`, `opacity` |
| `path/1` | `Path` | commands | `fill`, `stroke`, `opacity`, `fill_rule` |
| `image/5` | `CanvasImage` | source, x, y, w, h | `rotation`, `opacity` |
| `svg/5` | `CanvasSvg` | source, x, y, w, h | *n/a* |

Common shape options:

- **`fill`**: hex colour string, named atom, or gradient
  (`linear_gradient`). Fills the shape interior.
- **`stroke`**: a stroke descriptor (see [Strokes](#strokes)). Draws
  the shape outline.
- **`opacity`**: 0.0 (transparent) to 1.0 (opaque).
- **`radius`** (rect only): corner radius for rounded rectangles.
  Accepts a single number for uniform corners, or a map with
  `:top_left`, `:top_right`, `:bottom_right`, `:bottom_left` keys
  for per-corner control.

## Path commands

Functions that return path command data for use with `path/1`:

| Function | Arguments | Description |
|---|---|---|
| `move_to/2` | x, y | Move pen without drawing |
| `line_to/2` | x, y | Straight line to point |
| `bezier_to/6` | cp1x, cp1y, cp2x, cp2y, x, y | Cubic bezier curve |
| `quadratic_to/4` | cpx, cpy, x, y | Quadratic bezier curve |
| `arc/5` | cx, cy, r, start_angle, end_angle | Arc by centre |
| `arc_to/5` | x1, y1, x2, y2, radius | Tangent arc |
| `ellipse/7` | cx, cy, rx, ry, rotation, start, end | Ellipse arc |
| `rounded_rect/5` | x, y, w, h, radius | Rounded rectangle path |
| `close/0` | *n/a* | Close the current subpath |

```elixir
path([
  move_to(10, 0),
  line_to(20, 20),
  line_to(0, 20),
  close()
], fill: "#22c55e")
```

## Strokes

`stroke/3` creates a stroke descriptor:

```elixir
stroke("#333", 2)                        # colour and width
stroke("#333", 2, cap: :round)           # with line cap
stroke("#333", 2, dash: {[5, 3], 0})     # dashed line
```

| Option | Values | Default | Purpose |
|---|---|---|---|
| `cap:` | `:butt`, `:round`, `:square` | `:butt` | Line end style |
| `join:` | `:miter`, `:round`, `:bevel` | `:miter` | Corner join style |
| `dash:` | `{segments, offset}` | *n/a* | Dash pattern (segment lengths + initial offset) |

Strokes support the do-block syntax:

```elixir
rect(0, 0, 100, 50) do
  fill "#3b82f6"
  stroke do
    color "#333"
    width 2
    cap :round
  end
end
```

See `Plushie.Canvas.Shape.Stroke` and `Plushie.Canvas.Shape.Dash`.

## Gradients (canvas)

`linear_gradient/3` creates a gradient for use as a fill in canvas
shapes. This is different from `Plushie.Type.Gradient.linear/2` (which
uses an angle for widget backgrounds). Canvas gradients use coordinate
pairs:

```elixir
rect(0, 0, 200, 50,
  fill: linear_gradient({0, 0}, {200, 0}, [
    {0.0, "#3b82f6"},
    {1.0, "#1d4ed8"}
  ])
)
```

The first argument is the start point `{x, y}`, the second is the end
point `{x, y}`. Stops are `{offset, colour}` tuples where offset is
0.0-1.0.

See `Plushie.Canvas.Shape.LinearGradient`.

## SVG and images

Embed external visuals in canvas layers:

```elixir
layer "icons" do
  svg(File.read!("priv/icons/save.svg"), 10, 8, 20, 20)
  image("priv/images/logo.png", 50, 8, 32, 32, opacity: 0.8)
end
```

`svg/5` takes an SVG source string (not a file path; read the file
first). `image/5` takes a file path string.

Combined with interactive groups, SVG content can be made clickable,
hoverable, and keyboard-accessible:

```elixir
group "save", on_click: true, cursor: :pointer,
  focusable: true, a11y: %{role: :button, label: "Save"} do
  svg(File.read!("priv/icons/save.svg"), 0, 0, 36, 36)
end
```

## Transforms

Transforms apply to **groups only**, not individual shapes. They are
applied in declaration order.

| Function | Arguments | Description |
|---|---|---|
| `translate/2` | x, y | Move the group |
| `rotate/1` | angle | Rotate around origin (degrees by default) |
| `rotate/1` | `degrees: n` or `radians: n` | Explicit unit |
| `scale/1` | factor | Uniform scale |
| `scale/2` | x, y | Non-uniform scale |

```elixir
group x: 100, y: 50 do
  rotate(45)                    # 45 degrees
  rotate(radians: 0.785)        # explicit radians
  rect(0, 0, 40, 40, fill: "#ef4444")
end
```

The `x:` and `y:` keyword options on groups desugar to a leading
`translate`.

## Clips

`clip/4` restricts drawing to a rectangular region. One clip per group.

```elixir
group do
  clip(0, 0, 80, 80)
  circle(40, 40, 60, fill: "#3b82f6")  # clipped to 80x80 square
end
```

See `Plushie.Canvas.Shape.Clip`.

## Interactive groups

`Plushie.Canvas.Shape.Group` is the only shape type that supports
interactivity. Any collection of shapes can become clickable, hoverable,
draggable, or keyboard-focusable by wrapping them in an interactive
group.

### Interaction props

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `on_click` | boolean | `false` | Enable `:click` events (scoped under canvas ID) |
| `on_hover` | boolean | `false` | Enable `:enter`/`:exit` events |
| `draggable` | boolean | `false` | Enable `:drag`/`:drag_end` events |
| `drag_axis` | `"x"` / `"y"` / `"both"` | *n/a* | Constrain drag direction (unconstrained when not set) |
| `drag_bounds` | DragBounds | *n/a* | Limit drag region (`%{min_x, max_x, min_y, max_y}`) |
| `focusable` | boolean | `false` | Add to Tab order for keyboard navigation |
| `cursor` | atom/string | *n/a* | Cursor style on hover (`:pointer`, `:grab`, etc.) |
| `tooltip` | string | *n/a* | Tooltip text on hover |
| `hit_rect` | HitRect | *n/a* | Custom hit testing region (`%{x, y, w, h}`) |

### Visual feedback props

| Prop | Type | Purpose |
|---|---|---|
| `hover_style` | ShapeStyle | Override `fill`, `stroke`, `opacity` on hover |
| `pressed_style` | ShapeStyle | Override while pressed |
| `focus_style` | ShapeStyle | Override when keyboard-focused |
| `show_focus_ring` | boolean | Show/hide the default focus indicator |
| `focus_ring_radius` | number | Corner radius for the focus ring |

ShapeStyle accepts: `fill` (colour or gradient), `stroke` (colour or
stroke descriptor), `opacity` (0.0-1.0). Only specified fields are
overridden; others inherit from the shape's base values.

### Accessibility

Canvas is a raw drawing surface with no inherent semantic knowledge.
Interactive groups need explicit `a11y` annotations for screen reader
and keyboard support:

```elixir
group "hue-ring",
  on_click: true,
  focusable: true,
  a11y: %{role: :slider, label: "Hue", value: "#{round(hue)} degrees"} do
  # ... shapes
end
```

Without `a11y` annotations, interactive groups are invisible to
assistive technology. See the [Accessibility reference](accessibility.md)
for the full set of fields and roles.

## Canvas events

All canvas events arrive as `Plushie.Event.WidgetEvent` structs.

### Canvas-level events

Require `on_press`/`on_release`/`on_move`/`on_scroll` props on the
canvas widget. These use the unified pointer event model with device
type and modifier information. Mouse, touch, and pen input all produce
the same event types with full hit testing, drag, and click support.
The `pointer` field identifies the device, `finger` carries the touch
finger ID (nil for mouse), and `modifiers` carries the current modifier
key state:

| Event type | Data fields |
|---|---|
| `:press` | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `:release` | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `:move` | `x`, `y`, `pointer`, `finger`, `modifiers` |
| `:scroll` | `x`, `y`, `delta_x`, `delta_y`, `pointer`, `modifiers` |

Touch events use `pointer: :touch` with `button: :left` and include
a `finger` integer identifying the touch point:

```elixir
# Handle touch press on canvas
def update(model, %WidgetEvent{type: :press, id: "drawing",
    data: %{x: x, y: y, pointer: :touch, finger: 0}}) do
  start_stroke(model, x, y)
end

# Handle touch drag
def update(model, %WidgetEvent{type: :move, id: "drawing",
    data: %{x: x, y: y, pointer: :touch, finger: 0}}) do
  continue_stroke(model, x, y)
end
```

### Element-level events

Require interaction props on interactive groups:

| Event type | Trigger | Data fields |
|---|---|---|
| `:click` | `on_click: true` | Scoped under canvas ID (see below) |
| `:enter` | `on_hover: true` | *n/a* |
| `:exit` | `on_hover: true` | *n/a* |
| `:drag` | `draggable: true` | `x`, `y`, `delta_x`, `delta_y` |
| `:drag_end` | `draggable: true` | `x`, `y` |
| `:key_press` | `focusable: true` | `key`, `modifiers`, `text` |
| `:key_release` | `focusable: true` | `key`, `modifiers` |
| `:focused` | `focusable: true` | *n/a* |
| `:blurred` | `focusable: true` | *n/a* |

Canvas element clicks are regular `:click` events. The renderer
emits them with the element's scoped ID (e.g., `"my-canvas/handle"`),
and the SDK's scoped ID system splits this into `id: "handle"` with
`scope: ["my-canvas", window_id]`. Match them like any scoped click:

```elixir
def update(model, %WidgetEvent{type: :click, id: "handle", scope: ["my-canvas" | _]}) do
  # handle canvas element click
end
```

Other element events (enter, leave, drag, key, focus) use standard
generic event families shared across all widget types.

### Pointer events in custom widgets

Canvas-level pointer events (`:press`, `:release`, `:move`,
`:scroll`) are delivered through the widget handler pipeline
like any other event. If a custom widget's `handle_event/2` does not
intercept them, they reach the parent app's `update/2`.

To transform a pointer event before it reaches `update/2`, handle it in
`handle_event/2` and emit a new event via `{:emit, family, data}`.

## Element scoping

Canvas element IDs participate in the standard
[scoped ID](scoped-ids.md) system. The canvas widget's ID creates a
scope, and interactive group IDs within it are scoped under it:

```
canvas "drawing"              ->  "drawing"
  group "handle" ...          ->  "drawing/handle"
```

Events arrive with the group's local ID, the canvas in the scope, and
the window ID at the end:

```elixir
%WidgetEvent{type: :click, id: "handle", scope: ["drawing", "main"], window_id: "main"}
```

## Examples

### Toggle switch

An interactive group with state-driven thumb position and accessibility
annotations:

```elixir
canvas "switch", width: 64, height: 32 do
  layer "track" do
    group "toggle", on_click: true, cursor: :pointer,
      a11y: %{role: :switch, label: "Dark mode", toggled: model.dark} do
      rect(0, 0, 64, 32, fill: if(model.dark, do: "#3b82f6", else: "#ddd"), radius: 16)
      circle(if(model.dark, do: 44, else: 20), 16, 12, fill: "#fff")
    end
  end
end
```

### Bar chart

Focusable bars with accessibility annotations for screen reader
navigation. Each bar reports its position in the data set:

```elixir
canvas "chart", width: 300, height: 200 do
  layer "bars" do
    for {value, i} <- Enum.with_index(model.data) do
      x = i * 40 + 10
      h = value * 2

      group "bar-#{i}", x: x, y: 200 - h, focusable: true,
        tooltip: "#{value}",
        a11y: %{role: :image, label: "Value: #{value}",
               position_in_set: i + 1, size_of_set: length(model.data)} do
        rect(0, 0, 30, h, fill: "#3b82f6")
      end
    end
  end
end
```

### Canvas with widget overlay

Layer a canvas (custom visuals) under a text_input (standard widget)
using `stack`. The transparent background on the input lets the canvas
decoration show through:

```elixir
stack width: 200, height: 40 do
  canvas "bg", width: 200, height: 40 do
    layer "decor" do
      rect(0, 0, 200, 40, fill: "#f5f5f5", radius: 8)
    end
  end

  text_input("input", model.value,
    placeholder: "Search...",
    style: StyleMap.new() |> StyleMap.background(:transparent)
  )
end
```

## See also

- `Plushie.Canvas.Shape` - all builder functions
- `Plushie.Widget.Canvas` - canvas widget props
- [Canvas guide](../guides/12-canvas.md) - building a canvas button
  for the pad
- [Custom Widgets guide](../guides/13-custom-widgets.md) - canvas-based
  custom widgets
- [Accessibility reference](accessibility.md) - canvas accessibility
  annotations
- [Styling reference](themes-and-styling.md) - `Plushie.Type.Gradient.linear/2`
  for widget background gradients (different from canvas
  `linear_gradient/3`)
