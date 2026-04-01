# Canvas

Canvas is a different paradigm from the widget tree. Instead of composing
layout containers and input widgets, you draw shapes on a 2D surface:
rectangles, circles, lines, paths, and text. Shapes can be grouped into
interactive elements with click handlers, hover effects, and accessibility
annotations.

In this chapter we will learn canvas by building a **custom save button** --
a styled, interactive canvas widget that replaces the plain `button("save")`
in the pad. Along the way we will cover shapes, interactive groups, style
overrides, and how canvas composes with the rest of the widget tree.

## Canvas do-blocks

Canvas blocks are the one exception to the "three equivalent DSL forms"
rule from [chapter 3](03-your-first-app.md). Inside a canvas block, you
write layers and shapes, not children and inline options. The `text`,
`image`, and `svg` functions resolve to their canvas shape variants (not
the widget variants) inside canvas and layer blocks. The compiler validates
this at compile time.

Canvas do-blocks also support **inline option declarations** -- bare
calls like `width`, `height`, and `background` inside the do-block
set canvas-level props without needing keyword arguments on the
opening line:

```elixir
canvas "chart" do
  width :fill
  height 200

  layer "data" do
    rect(0, 0, 100, 50, fill: "#3b82f6")
  end
end
```

This is equivalent to `canvas "chart", width: :fill, height: 200 do ...`.

## Shapes

All shapes are plain function calls that return typed structs. They live
inside `layer` blocks within a canvas. Variables assigned in one line of
a layer or group block are visible in subsequent lines -- standard
Elixir scoping rules apply:

```elixir
canvas "demo", width: 200, height: 100 do
  layer "bg" do
    bg_fill = "#f0f0f0"
    rect(0, 0, 200, 100, fill: bg_fill, radius: 8)
    circle(100, 50, 20, fill: "#3b82f6")
    line(10, 90, 190, 90, stroke: stroke("#ccc", 1))
    text(100, 50, "Hello", fill: "#333", size: 14)
  end
end
```

`rect` draws a rectangle, `circle` a circle, `line` a line segment, and
`text` renders text at a position. Each accepts optional `fill`, `stroke`,
and `opacity`.

### Strokes

The `stroke/3` helper creates stroke descriptors:

```elixir
stroke("#333", 2)                        # colour and width
stroke("#333", 2, cap: :round)           # with line cap
stroke("#333", 2, dash: {[5, 3], 0})     # dashed line
```

Shape do-blocks support nested Buildable types, so you can declare
stroke options inline:

```elixir
rect(0, 0, 100, 50) do
  fill "#3b82f6"
  radius 6
  stroke do
    color "#333"
    width 2
    cap :round
  end
end
```

### Gradients

`linear_gradient/3` creates a gradient for use as a fill:

```elixir
rect(0, 0, 100, 36,
  fill: linear_gradient({0, 0}, {100, 0}, [
    {0.0, "#3b82f6"},
    {1.0, "#1d4ed8"}
  ]),
  radius: 6
)
```

### Paths

For arbitrary shapes, use `path/2` with a list of commands:

```elixir
path([
  move_to(10, 0),
  line_to(20, 20),
  line_to(0, 20),
  close()
], fill: "#22c55e")
```

See the [Canvas reference](../reference/canvas.md) for the full list of
path commands (`bezier_to`, `quadratic_to`, `arc`, `arc_to`, `ellipse`,
`rounded_rect`).

## Interactive groups

Groups become interactive when you add event props. This is where canvas
gets powerful -- you can make any collection of shapes clickable, hoverable,
or draggable:

```elixir
group "my-btn", on_click: true, on_hover: true, cursor: :pointer do
  rect(0, 0, 100, 36, fill: "#3b82f6", radius: 6)
  text(50, 11, "Click me", fill: "#fff", size: 14)
end
```

### Hover and press styles

`hover_style` and `pressed_style` change the visual appearance during
interaction. No event handling needed -- the renderer applies them
automatically:

```elixir
group "my-btn",
  on_click: true,
  cursor: :pointer,
  hover_style: %{fill: "#2563eb"},
  pressed_style: %{fill: "#1d4ed8"} do
  rect(0, 0, 100, 36, fill: "#3b82f6", radius: 6)
  text(50, 11, "Save", fill: "#fff", size: 14)
end
```

On hover, the rectangle fill shifts to a darker blue. On press, it gets
darker still. The text stays white because the style override only affects
the properties you specify.

### Accessibility

Interactive groups should have accessibility annotations:

```elixir
group "save-btn",
  on_click: true,
  cursor: :pointer,
  focusable: true,
  a11y: %{role: :button, label: "Save experiment"} do
  # shapes...
end
```

`focusable: true` allows keyboard navigation (Tab to focus, Space/Enter to
activate). The `a11y` map provides the role and label for screen readers.

## Building the save button

Let us put it all together. Here is a custom save button with a gradient
fill, rounded corners, hover/press feedback, and accessibility:

```elixir
defp save_button do
  canvas "save-canvas", width: 100, height: 36 do
    layer "button" do
      group "save",
        on_click: true,
        cursor: :pointer,
        focusable: true,
        a11y: %{role: :button, label: "Save experiment"},
        hover_style: %{fill: "#2563eb"},
        pressed_style: %{fill: "#1d4ed8"} do

        rect(0, 0, 100, 36,
          fill: linear_gradient({0, 0}, {100, 0}, [
            {0.0, "#3b82f6"},
            {1.0, "#2563eb"}
          ]),
          radius: 6
        )
        text(50, 11, "Save", fill: "#ffffff", size: 14)
      end
    end
  end
end
```

### Applying it: replace the plain save button

In the pad's view, replace `button("save", "Save")` with the canvas
version:

```elixir
row padding: 4, spacing: 8 do
  save_button()
  checkbox("auto-save", model.auto_save)
  text("auto-label", "Auto-save")
end
```

The canvas button emits a `:canvas_element_click` event (not `:click` like
a regular button). Update the save handler to match:

```elixir
def update(model, %WidgetEvent{type: :canvas_element_click, id: "save"}) do
  case compile_preview(model.source) do
    {:ok, tree} ->
      if model.active_file, do: save_experiment(model.active_file, model.source)
      %{model | preview: tree, error: nil}
    {:error, msg} ->
      %{model | error: msg, preview: nil}
  end
end
```

Note the event type changed from `:click` to `:canvas_element_click` and the
scope includes the canvas ID. The `id` is `"save"` (the group ID), and it
arrives with `scope: ["save-canvas"]`.

You now have a custom-drawn, gradient-filled, hover-responsive save button
in your pad. This is the same technique you would use to build custom
controls, charts, diagrams, or any visual element that goes beyond the
built-in widgets.

## Layers

Layers control drawing order. Earlier layers are behind, later layers are
on top:

```elixir
canvas "layered", width: 200, height: 100 do
  layer "background" do
    rect(0, 0, 200, 100, fill: "#f5f5f5")
  end

  layer "foreground" do
    circle(100, 50, 30, fill: "#3b82f6")
  end
end
```

## Transforms and clips

Transforms apply to **groups**, not individual shapes. Three transforms are
available: `translate/2`, `rotate/1` (degrees by default), and `scale/1`
or `scale/2`.

```elixir
group x: 100, y: 50 do
  rotate(45)
  rect(0, 0, 40, 40, fill: "#ef4444")
end
```

`rotate/1` accepts degrees by default. For explicit units, use keyword
form: `rotate(degrees: 45)` or `rotate(radians: 0.785)`.

The `x:` and `y:` shorthand desugars to a leading `translate`.

`clip/4` restricts drawing to a rectangular region (one per group):

```elixir
group do
  clip(0, 0, 80, 80)
  circle(40, 40, 60, fill: "#3b82f6")
end
```

## Canvas events

Canvas events arrive as `Plushie.Event.WidgetEvent` structs:

**Canvas-level** (requires `on_press`/`on_release`/`on_move`/`on_scroll`
on the canvas):

```elixir
%WidgetEvent{type: :canvas_press, data: %{x: 150.0, y: 75.0, button: :left}}
```

**Element-level** (requires `on_click`/`on_hover`/`draggable` on the
group):

```elixir
%WidgetEvent{type: :canvas_element_click, id: "save", data: %{x: 50.0, y: 18.0}}
%WidgetEvent{type: :canvas_element_enter, id: "save"}
%WidgetEvent{type: :canvas_element_leave, id: "save"}
```

See the [Canvas reference](../reference/canvas.md) for the full event list.

## Composing canvas with widgets

Canvas is just another widget in the tree. It composes with layout
containers like anything else:

```elixir
column do
  row spacing: 8 do
    save_button()          # canvas widget
    button("clear", "Clear")  # regular widget
  end

  canvas "chart", width: :fill, height: 200 do
    # ...
  end
end
```

Mix canvas and regular widgets freely. Use canvas when you need custom
visuals; use widgets for standard controls.

## Try it

Write canvas experiments in your pad:

- Draw a few shapes: rectangles with gradients, circles with strokes,
  dashed lines.
- Build a bar chart: for each data point, draw a `rect` with height
  proportional to the value. Add `tooltip:` for hover labels.
- Create a path: draw a triangle, a star, or a curved shape.
- Add an interactive group with `on_hover: true` and `hover_style`. Watch
  the element highlight when you mouse over it.
- Try transforms: rotate a group, clip a shape to a smaller region.

The [Canvas reference](../reference/canvas.md) has the complete shape
catalog, all path commands, and full interactive group props.

In the next chapter, we will extract reusable components from the pad as
custom widgets.
