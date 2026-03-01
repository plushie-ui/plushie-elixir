# UI trees

A julep UI tree is a plain Elixir map. No structs, no protocols, no macros
required.

## Node shape

Every node in the tree has this shape:

```elixir
%{
  id: "unique-id",
  type: "button",
  props: %{"label" => "Click me", "event" => "do_thing"},
  children: []
}
```

- **id** -- unique string within the tree. Used for diffing, event routing,
  and renderer-side widget state continuity (scroll position, focus, etc.).
- **type** -- string identifying the widget type. Maps directly to an iced
  widget or a composite julep widget on the renderer side.
- **props** -- string-keyed map of widget properties. Serialized as JSON.
- **children** -- ordered list of child nodes.

IDs must be stable across renders for the same logical element. If a list
item's ID changes, the renderer treats it as a removal + insertion, losing
any widget-local state (text cursor position, scroll offset).

## Building trees with Julep.UI

`Julep.UI` provides builder functions that produce these maps. The `do`
block syntax is optional sugar.

```elixir
import Julep.UI

# These are equivalent:
column(padding: 8, children: [text("hello")])

column padding: 8 do
  text("hello")
end
```

### Layout widgets

| Function | Type | Description |
|---|---|---|
| `window(id, opts)` | `window` | Top-level window container |
| `column(opts)` | `column` | Vertical flex layout |
| `row(opts)` | `row` | Horizontal flex layout |
| `container(id, opts)` | `container` | Generic box with alignment/padding |
| `scrollable(id, opts)` | `scrollable` | Scrollable region |
| `stack(opts)` | `stack` | Z-axis stacking (overlays) |
| `space(opts)` | `space` | Flexible spacer |
| `grid(opts)` | `grid` | Two-dimensional grid layout |
| `keyed_column(opts)` | `keyed_column` | Column with explicit child keys |
| `pin(opts)` | `pin` | Pins child to a position within parent |
| `float(opts)` | `float` | Floats child over siblings |
| `responsive(id, opts)` | `responsive` | Responds to available size (alias for sensor) |

### Input widgets

| Function | Type | Description |
|---|---|---|
| `button(id, label, opts)` | `button` | Clickable button |
| `text_input(id, value, opts)` | `text_input` | Single-line text field |
| `checkbox(id, checked, opts)` | `checkbox` | Boolean toggle (checkbox) |
| `toggler(id, checked, opts)` | `toggler` | Boolean toggle (switch) |
| `radio(id, value, selected, opts)` | `radio` | Radio button |
| `pick_list(id, options, selected, opts)` | `pick_list` | Dropdown select |
| `combo_box(id, options, value, opts)` | `combo_box` | Searchable select |
| `slider(id, range, value, opts)` | `slider` | Horizontal slider |
| `vertical_slider(id, range, value, opts)` | `vertical_slider` | Vertical slider |
| `text_editor(id, content, opts)` | `text_editor` | Multi-line text editor |

### Display widgets

| Function | Type | Description |
|---|---|---|
| `text(content, opts)` | `text` | Text label |
| `progress_bar(range, value, opts)` | `progress_bar` | Progress indicator |
| `tooltip(id, opts)` | `tooltip` | Hover tooltip |
| `image(id, path_or_url, opts)` | `image` | Raster image |
| `svg(id, path_or_data, opts)` | `svg` | Vector image |
| `markdown(id, content, opts)` | `markdown` | Rendered markdown |
| `rule(opts)` | `rule` | Horizontal/vertical divider |
| `rich_text(id, opts)` | `rich_text` | Styled text with multiple spans |
| `themer(id, opts)` | `themer` | Per-subtree theme override |

### Interactive widgets

| Function | Type | Description |
|---|---|---|
| `mouse_area(id, opts)` | `mouse_area` | Captures mouse events on children |
| `sensor(id, opts)` | `sensor` | Detects layout changes and resize |
| `pane_grid(id, panes, opts)` | `pane_grid` | Resizable tiled pane layout |
| `canvas(id, shapes, opts)` | `canvas` | 2D drawing surface |

### Canvas drawing with Julep.Canvas.Shape

The `canvas` widget renders 2D graphics from a `layers` prop -- a map of
named layers, each containing a list of shape descriptors. `Julep.Canvas.Shape`
provides builder functions that produce these descriptors as plain maps.

```elixir
alias Julep.Canvas.Shape

canvas("my_canvas",
  layers: %{
    "background" => [
      Shape.rect(0, 0, 400, 300, fill: "#e0e0e0"),
      Shape.circle(200, 150, 50, fill: "#3498db")
    ],
    "overlay" => [
      Shape.text(180, 160, "Hello", fill: "#ffffff", size: 24)
    ]
  },
  width: 400,
  height: 300
)
```

Layers are rendered in alphabetical order by name. The renderer caches each
layer independently and only re-tessellates when the layer's content changes.

#### Shape builders

| Function | Description |
|---|---|
| `rect(x, y, w, h, opts)` | Rectangle at position `(x, y)` with given width and height. |
| `circle(x, y, r, opts)` | Circle centered at `(x, y)` with radius `r`. |
| `line(x1, y1, x2, y2, opts)` | Line from `(x1, y1)` to `(x2, y2)`. |
| `text(x, y, content, opts)` | Text string at `(x, y)`. Opts: `:fill`, `:size`, `:font`. |
| `path(commands, opts)` | Arbitrary path from a list of path commands. |
| `image(source, x, y, w, h)` | Raster image drawn at `(x, y)` with given dimensions. |
| `svg(source, x, y, w, h)` | SVG drawn at `(x, y)` with given dimensions. |

All shape builders accept `:fill` and `:stroke` keyword options (except
`line` which only accepts `:stroke`, and `image`/`svg` which accept neither).
`:fill` is a color hex string or a gradient map. `:stroke` is a stroke
descriptor built with `stroke/3`.

Shapes that use `:fill` also accept `:fill_rule` to control how overlapping
paths determine interior regions:

- `:non_zero` (default) -- standard winding-number rule
- `:even_odd` -- alternating fill for shapes with holes

```elixir
Shape.path(
  [Shape.move_to(0, 0), Shape.line_to(100, 0), Shape.line_to(50, 80), Shape.close()],
  fill: "#0088ff",
  fill_rule: :even_odd
)
```

#### Stroke builder

`stroke(color, width, opts)` builds a stroke descriptor.

Options:
- `:cap` -- `"butt"`, `"round"`, or `"square"` (default: `"butt"`)
- `:join` -- `"miter"`, `"round"`, or `"bevel"` (default: `"miter"`)
- `:dash` -- `{segments, offset}` where segments is a list of numbers

```elixir
Shape.line(0, 0, 100, 100,
  stroke: Shape.stroke("#333", 2, cap: "round", dash: {[5, 3], 0})
)
```

#### Gradient fills

`linear_gradient(from, to, stops)` builds a gradient usable as a `:fill`
value. `from` and `to` are `{x, y}` coordinate tuples. `stops` is a list of
`{offset, color}` tuples where offset ranges from 0.0 to 1.0.

```elixir
Shape.rect(0, 0, 200, 100,
  fill: Shape.linear_gradient({0, 0}, {200, 0}, [{0.0, "#ff0000"}, {1.0, "#0000ff"}])
)
```

#### Path commands

Build paths from a list of commands passed to `path/2`:

| Function | Description |
|---|---|
| `move_to(x, y)` | Move the pen to `(x, y)` without drawing. |
| `line_to(x, y)` | Draw a line to `(x, y)`. |
| `bezier_to(cp1x, cp1y, cp2x, cp2y, x, y)` | Cubic bezier curve with two control points. |
| `quadratic_to(cpx, cpy, x, y)` | Quadratic bezier curve with one control point. |
| `arc(cx, cy, r, start_angle, end_angle)` | Arc centered at `(cx, cy)` with radius and angles in radians. |
| `arc_to(x1, y1, x2, y2, radius)` | Tangent arc through two points with given radius. |
| `ellipse(cx, cy, rx, ry, rotation, start_angle, end_angle)` | Elliptical arc. |
| `rounded_rect(x, y, w, h, radius)` | Rounded rectangle as a path command. |
| `close()` | Close the current path. |

```elixir
Shape.path(
  [Shape.move_to(0, 0), Shape.line_to(100, 0), Shape.line_to(50, 80), Shape.close()],
  fill: "#0088ff",
  stroke: Shape.stroke("#000", 2)
)
```

#### Transform commands

Transform commands are interleaved with shapes in a layer's shape list.
Use `push_transform/0` and `pop_transform/0` to save and restore state.

| Function | Description |
|---|---|
| `push_transform()` | Save the current transform state onto the stack. |
| `pop_transform()` | Restore the previously saved transform state. |
| `translate(x, y)` | Translate the coordinate origin by `(x, y)`. |
| `rotate(angle)` | Rotate the coordinate system (angle in radians). |
| `scale(x, y)` | Scale the coordinate system by `(x, y)`. |

```elixir
[
  Shape.push_transform(),
  Shape.translate(100, 100),
  Shape.rotate(:math.pi() / 4),
  Shape.rect(0, 0, 50, 50, fill: "#f00"),
  Shape.pop_transform()
]
```

#### Clipping

Clip commands restrict drawing to a rectangular region. Use
`push_clip/4` and `pop_clip/0` to scope the clip. They are interleaved
with shapes in a layer's shape list, similar to transforms.

| Function | Description |
|---|---|
| `push_clip(x, y, w, h)` | Clip all subsequent drawing to the rectangle at `(x, y)` with `w` x `h`. |
| `pop_clip()` | Restore the previous clip region. |

```elixir
[
  Shape.push_clip(50, 50, 200, 100),
  Shape.circle(100, 100, 80, fill: "#3498db"),
  Shape.pop_clip()
]
```

On the wire, these are encoded as:

```json
{"type": "push_clip", "x": 50, "y": 50, "w": 200, "h": 100}
{"type": "pop_clip"}
```

### Table column descriptors

The `table` widget accepts a `columns` prop -- a list of column descriptor
maps. Each descriptor supports the following fields:

| Field | Required | Description |
|---|---|---|
| `key` | yes | String key identifying the column. Used in sort events. |
| `label` | yes | Display label for the column header. |
| `align` | no | Horizontal alignment of cell content: `"left"`, `"center"`, `"right"`. |
| `width` | no | Column width: number (fixed pixels), `"fill"`, or `{"fill_portion": n}`. |
| `sortable` | no | Boolean. When true, the column header is clickable and emits `{:sort, id, column_key}`. |

The table itself accepts `sort_by` (string, the key of the currently sorted
column) and `sort_order` (`"asc"` or `"desc"`) props to reflect sort state
in the header.

```elixir
table("users",
  columns: [
    %{key: "name", label: "Name", sortable: true, width: "fill"},
    %{key: "age", label: "Age", sortable: true, width: 80, align: "right"},
    %{key: "role", label: "Role", width: {:fill_portion, 2}}
  ],
  rows: model.users,
  sort_by: model.sort_by,
  sort_order: model.sort_order
)
```

### SVG widget props

The `svg` widget renders vector graphics from an SVG file.

| Prop | Type | Description |
|---|---|---|
| `source` | string | Path to the SVG file |
| `width` | length | Widget width (`:fill`, `:shrink`, or number) |
| `height` | length | Widget height (`:fill`, `:shrink`, or number) |
| `content_fit` | string | How the SVG fits its bounds: `"contain"`, `"cover"`, `"fill"`, `"none"`, `"scale_down"` |
| `rotation` | number | Rotation angle in degrees |
| `opacity` | number | Opacity from 0.0 (transparent) to 1.0 (opaque) |
| `color` | color | Color tint applied to the SVG |

```elixir
svg("logo", "priv/logo.svg",
  width: 200,
  height: 200,
  content_fit: "contain",
  opacity: 0.8,
  color: "#3498db"
)
```

### TextEditor widget props

The `text_editor` widget provides a multi-line text editing area with
optional syntax highlighting and key binding customization.

| Prop | Type | Description |
|---|---|---|
| `placeholder` | string | Placeholder text shown when empty |
| `width` | number | Width in pixels (f32, not Length) |
| `height` | length | Widget height (`:fill`, `:shrink`, or number) |
| `min_height` | number | Minimum height in pixels |
| `max_height` | number | Maximum height in pixels |
| `font` | font | Font specification (family, weight, style, stretch) |
| `size` | number | Text size in pixels |
| `line_height` | number or map | Line height: number (relative), `%{relative: n}`, or `%{absolute: n}` |
| `padding` | number | Uniform padding in pixels |
| `wrapping` | atom | Text wrapping: `:none`, `:word`, `:glyph`, `:word_or_glyph` |
| `highlight_syntax` | string | Language name for syntax highlighting (e.g. `"elixir"`, `"rust"`) |
| `highlight_theme` | string | Syntax highlighting theme: `"solarized_dark"`, `"base16_mocha"`, `"base16_ocean"`, `"base16_eighties"`, `"inspired_github"` |
| `key_bindings` | list | Declarative key binding rules for editor behavior |
| `style` | atom or StyleMap | Named style preset or custom style map |

```elixir
text_editor("code",
  model.source_code,
  placeholder: "Enter code...",
  font: %{family: "monospace"},
  size: 14,
  line_height: 1.5,
  padding: 12,
  wrapping: :word,
  highlight_syntax: "elixir",
  highlight_theme: "inspired_github",
  height: :fill
)
```

## Props

Props are always string-keyed maps when serialized. All three builder layers
produce the same node shape:

```elixir
# Julep.Iced.Widget (typed struct with builders):
alias Julep.Iced.Widget.Button
Button.new("save", "Save", style: :primary, padding: 8) |> Button.build()

# Julep.UI (keyword syntax):
button("save", "Save", style: :primary, padding: 8)

# Resulting node (identical from both):
%{
  id: "save",
  type: "button",
  props: %{"label" => "Save", "style" => "primary", "padding" => 8},
  children: []
}
```

### Common props

These props are recognized across most widget types:

- `padding` -- number or `{top, right, bottom, left}` tuple
- `spacing` -- gap between children (layout widgets)
- `width` / `height` -- `:fill`, `:shrink`, or a fixed number
- `align_x` / `align_y` -- `:start`, `:center`, `:end`
- `style` -- atom or map for widget-specific styling
- `theme` -- override theme for this subtree
- `visible` -- boolean, controls rendering

### Events

Interactive widgets emit events. The event is specified in the props:

```elixir
button("my_btn", "Click")
# Emits: {:click, "my_btn"}

text_input("name", model.name, on_submit: "save_name")
# On typing: {:input, "name", "typed value"}
# On enter:  {:submit, "name", "final value"}

checkbox("agree", model.agreed)
# Emits: {:toggle, "agree", true/false}
```

Event routing uses the node's `id` by default. Custom events can be
specified with `event` or `on_*` props.

## Tree diffing

The runtime diffs consecutive trees by walking them in parallel:

- Nodes with the same ID and type are compared for prop/children changes.
- Changed props produce a `:props` patch operation.
- Added children produce `:insert` operations.
- Removed children produce `:remove` operations.
- Changed ID or type produces a full `:replace` operation.

The diff is position-based within each parent's children list. For dynamic
lists, use stable IDs to help the differ match elements correctly. Keyed
children (via `keyed_column`/`keyed_row`) provide explicit identity for
efficient reordering.

## Inspecting trees

Since trees are plain maps, they can be inspected with standard tools:

```elixir
model = MyApp.init([])
tree = MyApp.view(model)

# Print the tree
IO.inspect(tree, pretty: true)

# Find a node by ID
Julep.Tree.find(tree, "my_button")

# Encode as JSON (what the renderer sees)
Jason.encode!(tree, pretty: true)
```

This makes debugging straightforward: you can see exactly what the renderer
will receive without running it.
