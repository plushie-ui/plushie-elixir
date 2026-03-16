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

### The a11y prop

Any widget node can include an `a11y` key in its props map to annotate
accessibility semantics:

```elixir
%{
  id: "heading",
  type: "text",
  props: %{
    "content" => "Welcome",
    "a11y" => %{"role" => "heading", "level" => 1}
  },
  children: []
}
```

See [accessibility](accessibility.md) for the full list of `a11y` fields.
The renderer auto-infers roles and labels from widget types and props, so
most widgets need no explicit `a11y` annotation.

## Building trees with Julep.UI

`Julep.UI` provides builder functions that produce these maps. The `do`
block syntax is optional sugar.

> **WARNING: Auto-generated IDs are unstable.** `Julep.UI` builders that
> don't receive an explicit `:id` option generate one from the call site
> line number (e.g. `"auto:MyApp:42"`). These IDs change when you refactor
> code, add or remove lines, or wrap calls in conditional branches. When
> an ID changes, the renderer treats it as a removal + insertion, losing
> widget-local state (scroll position, focus, editor content).
>
> **Always supply explicit IDs for stateful widgets:** `text_editor`,
> `combo_box`, `pane_grid`, `scrollable`, `text_input`.

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
| `pin(id, opts)` | `pin` | Pins child to a position within parent |
| `float_widget(id, opts)` | `float` | Floats child over siblings |
| `responsive(opts)` | `responsive` | Responds to available size (alias for sensor) |

### Input widgets

| Function | Type | Description |
|---|---|---|
| `button(id, label, opts)` | `button` | Clickable button |
| `text_input(id, value, opts)` | `text_input` | Single-line text field |
| `checkbox(id, checked, opts)` | `checkbox` | Boolean toggle (checkbox) |
| `toggler(id, is_toggled, opts)` | `toggler` | Boolean toggle (switch) |
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
| `image(id, source, opts)` | `image` | Raster image |
| `svg(id, source, opts)` | `svg` | Vector image |
| `markdown(content, opts)` | `markdown` | Rendered markdown |
| `rule(opts)` | `rule` | Horizontal/vertical divider |
| `rich_text(id, opts)` | `rich_text` | Styled text with multiple spans |
| `themer(id, opts)` | `themer` | Per-subtree theme override |
| `qr_code(id, data, opts)` | `qr_code` | QR code from string data |

### Interactive widgets

| Function | Type | Description |
|---|---|---|
| `mouse_area(id, opts)` | `mouse_area` | Captures mouse events on children |
| `sensor(id, opts)` | `sensor` | Detects layout changes and resize |
| `pane_grid(id, opts)` | `pane_grid` | Resizable tiled pane layout |
| `canvas(id, opts)` | `canvas` | 2D drawing surface (layers via `layers:` option) |
| `overlay(id, opts)` | `overlay` | Positions child as floating overlay above anchor |

### How `Julep.UI` handles widget IDs

`Julep.UI` builders use two different conventions for the `id` argument.
This is the #1 source of confusion for new users, so it is worth
understanding the rule behind it.

**The rule:** Widgets that emit events or hold renderer-side state take `id`
as a required positional first argument. Widgets that are purely structural
(layout containers, display-only) take `id` as an optional keyword in `opts`
and auto-generate one from the call site if omitted.

The rationale: if a widget emits events, the `id` appears in every event
tuple your `update/2` receives (e.g. `{:click, "save"}`). Making it
positional forces you to choose a meaningful, stable ID up front. Layout
containers rarely need explicit IDs -- the auto-generated ones work fine
for diffing.

#### Positional `id` -- macros (required, first arg)

These are macros defined as `defmacro widget(id, opts \\ [])`. The first
argument is always the id string. All support `do` blocks for children.

| Widget | Signature |
|---|---|
| `window` | `window(id, opts)` |
| `container` | `container(id, opts)` |
| `scrollable` | `scrollable(id, opts)` |
| `pin` | `pin(id, opts)` |
| `float_widget` | `float_widget(id, opts)` |
| `overlay` | `overlay(id, opts)` |
| `tooltip` | `tooltip(id, opts)` |
| `mouse_area` | `mouse_area(id, opts)` |
| `sensor` | `sensor(id, opts)` |
| `themer` | `themer(id, opts)` |
| `pane_grid` | `pane_grid(id, opts)` |
| `table` | `table(id, opts)` |

#### Positional `id` -- functions (required, first arg)

These are plain functions, not macros. They do not support `do` blocks.
`id` is the first positional argument; remaining positional arguments carry
the widget's primary data (label, value, range, etc.).

| Widget | Signature |
|---|---|
| `button` | `button(id, label, opts)` |
| `text_input` | `text_input(id, value, opts)` |
| `checkbox` | `checkbox(id, checked, opts)` |
| `toggler` | `toggler(id, is_toggled, opts)` |
| `radio` | `radio(id, value, selected, opts)` |
| `slider` | `slider(id, range, value, opts)` |
| `vertical_slider` | `vertical_slider(id, range, value, opts)` |
| `pick_list` | `pick_list(id, options, selected, opts)` |
| `combo_box` | `combo_box(id, options, value, opts)` |
| `text_editor` | `text_editor(id, content, opts)` |
| `image` | `image(id, source, opts)` |
| `svg` | `svg(id, source, opts)` |
| `canvas` | `canvas(id, opts)` |
| `rich_text` | `rich_text(id, opts)` |
| `qr_code` | `qr_code(id, data, opts)` |

#### Keyword `id:` -- auto-generated if omitted

These macros take only `opts` (no positional `id`). If you need a stable
ID, pass `id: "my_id"` in the keyword options. Otherwise an auto-ID is
generated from the call site (`"auto:ModuleName:42"`).

| Widget | Signature | Notes |
|---|---|---|
| `column` | `column(opts)` | Layout container |
| `row` | `row(opts)` | Layout container |
| `stack` | `stack(opts)` | Layout container |
| `grid` | `grid(opts)` | Layout container |
| `keyed_column` | `keyed_column(opts)` | Layout container |
| `responsive` | `responsive(opts)` | Layout container |
| `space` | `space(opts)` | Spacer (no children) |
| `rule` | `rule(opts)` | Divider (no children) |
| `text` | `text(content, opts)` | Content is positional; id from keyword |
| `markdown` | `markdown(content, opts)` | Content is positional; id from keyword |
| `progress_bar` | `progress_bar(range, value, opts)` | Range and value are positional; id from keyword |

#### Why the split matters

```elixir
# GOOD: button emits {:click, "save"} -- positional id is clear
button("save", "Save")

# GOOD: column is structural -- auto-id is fine
column padding: 8 do
  text("Hello")
end

# CAREFUL: if you need a column's id for scrolling or testing,
# pass it explicitly via keyword
column id: "main_list", spacing: 4 do
  for item <- items, do: text(item.name)
end

# WRONG: this does NOT work -- column does not take positional id
# column("main_list", spacing: 4)  # <-- compile error
```

> **Tip:** When in doubt, check whether the widget emits events. If it does,
> `id` is positional. If it doesn't, `id` is keyword (or omitted).

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

### QR Code widget props

The `qr_code` widget renders a QR code from a data string. Requires the
`widget-qr-code` Cargo feature flag on the renderer (enabled by default
via `builtin-all`).

| Prop | Type | Description |
|---|---|---|
| `data` | string | Data to encode. Required. |
| `cell_size` | number | Pixels per QR module (default: 4.0) |
| `cell_color` | color | Color of dark modules (default: black) |
| `background_color` | color | Color of light modules (default: white) |
| `error_correction` | atom | `:low`, `:medium` (default), `:quartile`, `:high` |

```elixir
qr_code("invite", "https://example.com/join/abc123",
  cell_size: 6,
  cell_color: "#1a1a2e",
  background_color: "#ffffff",
  error_correction: :quartile
)
```

### Overlay widget props

The `overlay` widget positions a floating child relative to an anchor child.
It expects exactly two children: the first is the **anchor**, rendered inline
in the normal layout flow; the second is the **overlay content**, rendered in
iced's overlay layer above all other widgets. The overlay escapes parent
clipping bounds, making it suitable for dropdowns, popovers, and tooltips.

| Prop | Type | Description |
|---|---|---|
| `position` | atom | Position relative to anchor: `:below` (default), `:above`, `:left`, `:right` |
| `gap` | number | Space in pixels between anchor and overlay (default: 0) |
| `offset_x` | number | Horizontal offset in pixels applied after positioning |
| `offset_y` | number | Vertical offset in pixels applied after positioning |
| `width` | length | Width of the overlay node (`:fill`, `:shrink`, or number) |

```elixir
overlay("dropdown", position: :below, gap: 4) do
  button("toggle", "Options")

  column padding: 8, spacing: 4 do
    button("opt_a", "Option A")
    button("opt_b", "Option B")
    button("opt_c", "Option C")
  end
end
```

## Choosing a builder layer

Julep provides three ways to build UI trees. All three produce identical
`ui_node()` maps -- pick based on your needs:

| Layer | Best for | Trade-offs |
|---|---|---|
| `Julep.UI` | View functions, prototyping | Ergonomic `do` blocks, keyword props, auto-generated IDs. Readable and concise. No compile-time type checking on props. |
| `Julep.Iced.Widget.*` | Production code, library authors | Typed structs with builder pattern. IDE autocompletion, dialyzer-checked types, explicit prop names. More verbose. Ground truth layer -- every widget is a module with full iced parity. |
| `Julep.Iced` | Dynamic widget construction | Untyped facade: pass widget type and props as maps. Useful when widget types or props come from data at runtime. No type safety. |

**`Julep.UI`** -- import it and use `do` blocks for a clean, readable `view/1`:

```elixir
import Julep.UI

column padding: 8, spacing: 4 do
  text("Hello")
  button("save", "Save", style: :primary)
end
```

**`Julep.Iced.Widget.*`** -- typed structs with builder chaining. Best when
you want dialyzer catching prop mistakes:

```elixir
alias Julep.Iced.Widget.{Column, Text, Button}

Column.new("main", padding: 8, spacing: 4)
|> Column.push(Text.new("Hello"))
|> Column.push(Button.new("save", "Save", style: :primary))
|> Column.build()
```

**`Julep.Iced`** -- untyped convenience when building widgets dynamically:

```elixir
Julep.Iced.column("main", %{"padding" => 8, "spacing" => 4}, [
  Julep.Iced.text("hello", %{"content" => "Hello"}),
  Julep.Iced.button("save", %{"label" => "Save", "style" => "primary"})
])
```

You can mix layers freely -- the output is always the same `%{id, type,
props, children}` map.

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

## Widget type reference

Maps the `type` string in `ui_node()` maps to the corresponding typed widget
module and `Julep.UI` builder function.

| Type string | Widget module | UI builder |
|---|---|---|
| `"button"` | `Julep.Iced.Widget.Button` | `Julep.UI.button/3` |
| `"canvas"` | `Julep.Iced.Widget.Canvas` | `Julep.UI.canvas/2` |
| `"checkbox"` | `Julep.Iced.Widget.Checkbox` | `Julep.UI.checkbox/3` |
| `"column"` | `Julep.Iced.Widget.Column` | `Julep.UI.column/1` |
| `"combo_box"` | `Julep.Iced.Widget.ComboBox` | `Julep.UI.combo_box/4` |
| `"container"` | `Julep.Iced.Widget.Container` | `Julep.UI.container/2` |
| `"float"` | `Julep.Iced.Widget.Float` | `Julep.UI.float_widget/2` |
| `"grid"` | `Julep.Iced.Widget.Grid` | `Julep.UI.grid/1` |
| `"image"` | `Julep.Iced.Widget.Image` | `Julep.UI.image/3` |
| `"keyed_column"` | `Julep.Iced.Widget.KeyedColumn` | `Julep.UI.keyed_column/1` |
| `"markdown"` | `Julep.Iced.Widget.Markdown` | `Julep.UI.markdown/2` |
| `"mouse_area"` | `Julep.Iced.Widget.MouseArea` | `Julep.UI.mouse_area/2` |
| `"overlay"` | `Julep.Iced.Widget.Overlay` | `Julep.UI.overlay/2` |
| `"pane_grid"` | `Julep.Iced.Widget.PaneGrid` | `Julep.UI.pane_grid/2` |
| `"pick_list"` | `Julep.Iced.Widget.PickList` | `Julep.UI.pick_list/4` |
| `"pin"` | `Julep.Iced.Widget.Pin` | `Julep.UI.pin/2` |
| `"progress_bar"` | `Julep.Iced.Widget.ProgressBar` | `Julep.UI.progress_bar/3` |
| `"qr_code"` | `Julep.Iced.Widget.QrCode` | `Julep.UI.qr_code/3` |
| `"radio"` | `Julep.Iced.Widget.Radio` | `Julep.UI.radio/4` |
| `"responsive"` | `Julep.Iced.Widget.Responsive` | `Julep.UI.responsive/1` |
| `"rich_text"` | `Julep.Iced.Widget.RichText` | `Julep.UI.rich_text/2` |
| `"row"` | `Julep.Iced.Widget.Row` | `Julep.UI.row/1` |
| `"rule"` | `Julep.Iced.Widget.Rule` | `Julep.UI.rule/1` |
| `"scrollable"` | `Julep.Iced.Widget.Scrollable` | `Julep.UI.scrollable/2` |
| `"sensor"` | `Julep.Iced.Widget.Sensor` | `Julep.UI.sensor/2` |
| `"slider"` | `Julep.Iced.Widget.Slider` | `Julep.UI.slider/4` |
| `"space"` | `Julep.Iced.Widget.Space` | `Julep.UI.space/1` |
| `"stack"` | `Julep.Iced.Widget.Stack` | `Julep.UI.stack/1` |
| `"svg"` | `Julep.Iced.Widget.Svg` | `Julep.UI.svg/3` |
| `"table"` | `Julep.Iced.Widget.Table` | `Julep.UI.table/2` |
| `"text"` | `Julep.Iced.Widget.Text` | `Julep.UI.text/2` |
| `"text_editor"` | `Julep.Iced.Widget.TextEditor` | `Julep.UI.text_editor/3` |
| `"text_input"` | `Julep.Iced.Widget.TextInput` | `Julep.UI.text_input/3` |
| `"themer"` | `Julep.Iced.Widget.Themer` | `Julep.UI.themer/2` |
| `"toggler"` | `Julep.Iced.Widget.Toggler` | `Julep.UI.toggler/3` |
| `"tooltip"` | `Julep.Iced.Widget.Tooltip` | `Julep.UI.tooltip/2` |
| `"vertical_slider"` | `Julep.Iced.Widget.VerticalSlider` | `Julep.UI.vertical_slider/4` |
| `"window"` | -- | `Julep.UI.window/2` |
