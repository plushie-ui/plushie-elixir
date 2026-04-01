# Canvas Reference

The canvas system provides 2D drawing with typed shape structs, transforms,
interactive groups, and accessibility support.

For a narrative introduction, see the [Canvas guide](../guides/12-canvas.md).

## Canvas widget

See `Plushie.Widget.Canvas` for all props.

Key props: `width`, `height`, `background`, `on_press`, `on_release`,
`on_move`, `on_scroll`, `a11y`.

## Shape catalog

All shapes are builder functions in `Plushie.Canvas.Shape` that return typed
structs. Use them inside `layer` blocks.

| Function | Struct | Required args | Key options |
|---|---|---|---|
| `rect/4` | `Plushie.Canvas.Shape.Rect` | x, y, w, h | fill, stroke, opacity, radius |
| `circle/3` | `Plushie.Canvas.Shape.Circle` | x, y, r | fill, stroke, opacity |
| `line/4` | `Plushie.Canvas.Shape.Line` | x1, y1, x2, y2 | stroke, opacity |
| `text/3` | `Plushie.Canvas.Shape.CanvasText` | x, y, content | fill, size, font, align_x, align_y, opacity |
| `path/1` | `Plushie.Canvas.Shape.Path` | commands | fill, stroke, opacity, fill_rule |
| `image/5` | `Plushie.Canvas.Shape.CanvasImage` | source, x, y, w, h | rotation, opacity |
| `svg/5` | `Plushie.Canvas.Shape.CanvasSvg` | source, x, y, w, h | -- |

See each struct module for full field documentation.

## Path commands

Functions in `Plushie.Canvas.Shape` that return path command data:

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
| `close/0` | -- | Close the current path |

## Strokes

`stroke/3` creates a stroke descriptor:

```elixir
stroke(colour, width, opts \\ [])
```

Options: `cap:` (`:butt`, `:round`, `:square`), `join:` (`:miter`, `:round`,
`:bevel`), `dash:` (`{segments, offset}`).

See `Plushie.Canvas.Shape.Stroke`.

## Gradients

`linear_gradient/3` creates a linear gradient for use as a fill:

```elixir
linear_gradient({from_x, from_y}, {to_x, to_y}, [{offset, colour}, ...])
```

Offsets range from 0.0 to 1.0. See `Plushie.Canvas.Shape.LinearGradient`.

## Transforms

Transforms apply to **groups only**, not individual shapes. They are applied
in declaration order.

| Function | Arguments | Description |
|---|---|---|
| `translate/2` | x, y | Move the group |
| `rotate/1` | angle (radians) | Rotate around origin |
| `scale/1` | factor | Uniform scale |
| `scale/2` | x, y | Non-uniform scale |

The `x:` and `y:` keyword options on groups desugar to a leading
`translate`.

## Clips

`clip/4` restricts drawing to a rectangular region. One clip per group.

```elixir
clip(x, y, w, h)
```

See `Plushie.Canvas.Shape.Clip`.

## Interactive groups

`Plushie.Canvas.Shape.Group` is the only shape type that supports
interactivity. Full prop list:

| Prop | Type | Description |
|---|---|---|
| `id` | string | Stable identifier (required for interactivity) |
| `on_click` | boolean | Enable click events |
| `on_hover` | boolean | Enable enter/leave events |
| `draggable` | boolean | Enable drag events |
| `drag_axis` | string | `"x"`, `"y"`, or `"both"` |
| `drag_bounds` | DragBounds | Min/max drag region |
| `cursor` | atom/string | Cursor style on hover |
| `tooltip` | string | Tooltip text |
| `hit_rect` | HitRect | Custom hit testing region |
| `focusable` | boolean | Allow keyboard focus (Tab) |
| `a11y` | map | Accessibility properties |
| `hover_style` | ShapeStyle | Visual overrides on hover |
| `pressed_style` | ShapeStyle | Visual overrides while pressed |
| `focus_style` | ShapeStyle | Visual overrides when focused |
| `show_focus_ring` | boolean | Show focus indicator |
| `focus_ring_radius` | number | Focus ring corner radius |
| `transforms` | list | Transform list |
| `clip` | Clip | Clip region |

See `Plushie.Canvas.Shape.Group`, `Plushie.Canvas.Shape.ShapeStyle`,
`Plushie.Canvas.Shape.DragBounds`, `Plushie.Canvas.Shape.HitRect`.

## Canvas events

### Canvas-level events

Require `on_press`/`on_release`/`on_move`/`on_scroll` props on the canvas:

| Event type | Data fields |
|---|---|
| `:canvas_press` | x, y, button |
| `:canvas_release` | x, y, button |
| `:canvas_move` | x, y |
| `:canvas_scroll` | x, y, delta_x, delta_y |

### Element-level events

Require `on_click`/`on_hover`/`draggable`/`focusable` on interactive groups:

| Event type | Data fields |
|---|---|
| `:canvas_element_click` | element_id, x, y, button |
| `:canvas_element_enter` | element_id, x, y |
| `:canvas_element_leave` | element_id |
| `:canvas_element_drag` | x, y, dx, dy |
| `:canvas_element_drag_end` | element_id, x, y |
| `:canvas_element_key_press` | key, modifiers, text |
| `:canvas_element_key_release` | key, modifiers |
| `:canvas_element_focused` | element_id |
| `:canvas_element_blurred` | element_id |

### Focus events

| Event type | Description |
|---|---|
| `:canvas_focused` | Canvas gained focus |
| `:canvas_blurred` | Canvas lost focus |
| `:canvas_group_focused` | A group within canvas gained focus |
| `:canvas_group_blurred` | A group within canvas lost focus |

## Canvas element scoping

Element IDs within a canvas use the `canvas_id/element_id` wire format. In
events, this is split into `id: element_id` with `scope: [canvas_id]`,
following the same scoping rules as regular widget containers.

Inside custom widgets, canvas-internal events (`:canvas_element_*`) that are
not intercepted by `handle_event/2` are auto-consumed by the runtime and
never reach `update/2`.

## See also

- `Plushie.Canvas.Shape` -- builder functions
- `Plushie.Widget.Canvas` -- canvas widget props
- [Canvas guide](../guides/12-canvas.md) -- narrative introduction
- [Patterns reference](patterns.md) -- canvas composition recipes
