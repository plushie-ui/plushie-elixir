# Built-in Widgets

All built-in widgets are available via `import Plushie.UI`. Each widget
has a corresponding typed builder module under `Plushie.Widget.*` for
programmatic use.

## Widget catalog

### Layout

| DSL macro | Module | Description |
|---|---|---|
| `window` | `Plushie.Widget.Window` | Top-level window with title, size, position, theme |
| `column` | `Plushie.Widget.Column` | Arranges children vertically |
| `row` | `Plushie.Widget.Row` | Arranges children horizontally |
| `container` | `Plushie.Widget.Container` | Single-child wrapper for styling, scoping, alignment |
| `scrollable` | `Plushie.Widget.Scrollable` | Scrollable viewport around child content |
| `stack` | `Plushie.Widget.Stack` | Layers children on top of each other (z-axis) |
| `grid` | `Plushie.Widget.Grid` | Fixed-column or fluid grid layout |
| `keyed_column` | `Plushie.Widget.KeyedColumn` | Vertical layout with ID-based diffing for dynamic lists |
| `responsive` | `Plushie.Widget.Responsive` | Emits resize events for adaptive layouts |
| `pin` | `Plushie.Widget.Pin` | Positions child at absolute coordinates |
| `floating` | `Plushie.Widget.Floating` | Applies translate/scale transforms to child |
| `space` | `Plushie.Widget.Space` | Invisible spacer |

Full prop tables for all layout containers are in the
[Layout reference](windows-and-layout.md).

### Input

| DSL macro | Macro form | Events |
|---|---|---|
| `button` | `button(id, label)` | `:click` |
| `text_input` | `text_input(id, value, opts)` | `:input`, `:submit`, `:paste` |
| `text_editor` | `text_editor(id, content, opts)` | `:input` |
| `checkbox` | `checkbox(id, checked, opts)` | `:toggle` (value: boolean) |
| `toggler` | `toggler(id, checked, opts)` | `:toggle` (value: boolean) |
| `radio` | `radio(id, value, selected, opts)` | `:select` |
| `slider` | `slider(id, range, value, opts)` | `:slide`, `:slide_release` |
| `vertical_slider` | `vertical_slider(id, range, value, opts)` | `:slide`, `:slide_release` |
| `pick_list` | `pick_list(id, options, selected, opts)` | `:select`, `:open`, `:close` |
| `combo_box` | `combo_box(id, value, opts)` | `:input`, `:select`, `:open`, `:close` |

**button** is the simplest interactive widget. The label is the second
positional argument. Emits `:click` on press.

**text_input** is a single-line editable field. Emits `:input` on every
keystroke with the full text as `value`. Emits `:submit` on Enter when
`on_submit: true` is set. Emits `:paste` when `on_paste: true` is set.

**text_editor** is a multi-line editable area with syntax highlighting
support (`highlight_syntax: "ex"`). The `content` argument seeds the
initial text. Holds renderer-side state (cursor, selection, scroll).

**checkbox** / **toggler** are boolean toggles. Both emit `:toggle` with
the new boolean value. `checkbox` shows a box; `toggler` shows a switch.
Add `label:` for accessible text.

**slider** / **vertical_slider** are range inputs. `range` is a
`{min, max}` tuple. Emits `:slide` continuously while dragging and
`:slide_release` when the drag ends with the final value.

**pick_list** is a dropdown selection. `options` is a list of strings.
`selected` is the currently selected value (or nil). Emits `:select`
when an option is chosen.

**combo_box** is a searchable dropdown. Combines a text input with a
filtered option list. Holds renderer-side state (search text, open
state). Emits `:input` on typing and `:select` on option selection.

**radio** is a one-of-many selection. `value` is the option this radio
represents; `selected` is the currently selected value from the model.
The radio is checked when `value == selected`. Emits `:select` with the
radio's value.

### Display

| DSL macro | Macro form | Description |
|---|---|---|
| `text` | `text(content)` or `text(id, content)` | Static text display |
| `rich_text` | `rich_text(id, spans)` | Styled text with per-span formatting |
| `rule` | `rule()` or `rule(id)` | Horizontal or vertical divider |
| `progress_bar` | `progress_bar(id, range, value)` | Progress indicator |
| `tooltip` | `tooltip(id, tip, opts) do child end` | Popup tip on hover |
| `image` | `image(id, source, opts)` | Raster image from file path |
| `svg` | `svg(id, source, opts)` | Vector image from SVG file |
| `qr_code` | `qr_code(id, data, opts)` | QR code from a data string |
| `markdown` | `markdown(content)` or `markdown(id, content)` | Rendered markdown |
| `canvas` | `canvas(id, opts) do layers end` | Drawing surface with named layers |

**text** supports auto-ID (`text("Hello")`) and explicit-ID
(`text("greeting", "Hello")`). Key props: `size`, `color`, `font`,
`wrapping`, `shaping`, `align_x`, `align_y`.

**rich_text** displays styled text with individually formatted spans.
Each span is a map with optional keys: `text` (content), `size`,
`color`, `font`, `link` (clickable URL), `underline`, `strikethrough`,
`line_height`, `padding`, and `highlight` (background with optional
border). Example:

```elixir
rich_text("greeting", [
  %{text: "Hello, ", size: 16},
  %{text: "world", size: 16, color: "#3b82f6", underline: true},
  %{text: "!", size: 16}
])
```

**tooltip** wraps a child widget. The child is the anchor; `tip` is
the tooltip text. Props: `position` (`:top`, `:bottom`, `:left`,
`:right`, `:follow_cursor`), `gap`.

**image** renders a raster image. Two source modes:

- **Path-based** (preferred): `image("photo", "path/to/file.png")`.
  The renderer loads the file directly. No wire transfer.
- **Handle-based**: `image("photo", handle: "avatar")`. References
  an in-memory image created via `Command.create_image/2`.

Key props: `content_fit`, `filter_method`, `width`, `height`,
`opacity`, `rotation` (degrees), `border_radius`, `scale`, `crop`
(`%{x, y, width, height}`), `alt` (accessible label).

**In-memory image handles:**

```elixir
# Create from encoded PNG/JPEG bytes:
{model, Command.create_image("avatar", png_bytes)}

# Create from raw RGBA pixels:
{model, Command.create_image("avatar", 512, 512, rgba_pixels)}

# Reference in view:
image("display", handle: "avatar")

# Update pixels:
{model, Command.update_image("avatar", new_pixels)}

# Delete:
{model, Command.delete_image("avatar")}
```

Handle-based images send the entire payload over the wire in a single
message, which blocks all other protocol traffic for large images.
Prefer path-based loading when the file exists on disk. A chunked
streaming alternative for large dynamic images is planned.

**canvas** contains named layers of shapes. See the
[Canvas reference](canvas.md).

## Table

`Plushie.Widget.Table`

Data table with typed columns, rows, sorting, and scrolling.

```elixir
table "users",
  columns: [
    %{key: "name", label: "Name", sortable: true},
    %{key: "email", label: "Email", width: {:fill_portion, 2}},
    %{key: "role", label: "Role", align: "center", sortable: true}
  ],
  rows: [
    %{"name" => "Alice", "email" => "alice@example.com", "role" => "Admin"},
    %{"name" => "Bob", "email" => "bob@example.com", "role" => "User"}
  ],
  sort_by: model.sort_by,
  sort_order: model.sort_order
```

### Column format

Maps with these keys:

| Key | Type | Required | Default | Purpose |
|---|---|---|---|---|
| `key` | string | yes | *n/a* | Lookup key into row data |
| `label` | string | yes | *n/a* | Header display text |
| `sortable` | boolean | no | `false` | Enable sort on header click |
| `align` | `"left"` / `"center"` / `"right"` | no | `"left"` | Text alignment |
| `width` | Length | no | `:fill` | Column width |

### Row format

Rows are **string-keyed** maps where keys match column `key` values.
String keys are required to avoid dynamic atom creation from external
data (databases, JSON APIs). Values are rendered as text via
`to_string/1`.

### Table props

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `columns` | `[column()]` | *n/a* | Column definitions |
| `rows` | `[row()]` | *n/a* | Data rows |
| `header` | boolean | *n/a* | Show header row |
| `separator` | boolean | *n/a* | Show line below header |
| `sort_by` | string | *n/a* | Currently sorted column key |
| `sort_order` | `:asc` / `:desc` | *n/a* | Sort direction |
| `width` | Length | `:fill` | Table width |
| `padding` | Padding | *n/a* | Table padding |
| `header_text_size` | number | *n/a* | Header font size |
| `row_text_size` | number | *n/a* | Body font size |
| `cell_spacing` | number | *n/a* | Horizontal cell gap |
| `row_spacing` | number | *n/a* | Vertical row gap |
| `separator_thickness` | number | *n/a* | Separator line thickness |
| `separator_color` | Color | *n/a* | Separator line colour |
| `a11y` | map | *n/a* | Accessibility overrides |

### Sorting

Set `sortable: true` on columns that support sorting. The table emits
`:sort` events when a sortable header is clicked:

```elixir
def update(model, %WidgetEvent{type: :sort, id: "users", value: %{column: col}}) do
  dir = if model.sort_by == col and model.sort_order == :asc, do: :desc, else: :asc
  %{model | sort_by: col, sort_order: dir}
end
```

The table itself does not sort. It displays rows in the order you
provide. Sort in your model or use `Plushie.Data.query/2`.

## Interaction wrappers

### pointer_area

Wraps a single child and captures pointer events from mouse, touch,
and pen input. Use for right-click menus, hover detection, drag
tracking, scroll capture, and custom cursor styles. All events use the
unified pointer model: the `pointer` field (`:mouse`, `:touch`,
`:pen`) identifies the device, and `modifiers` carries the current
modifier key state for shift-click, ctrl-drag, and similar patterns.

| Prop | Type | Purpose |
|---|---|---|
| `cursor` | cursor atom | Mouse cursor on hover |
| `on_press` | atom / string | Left button press event tag |
| `on_release` | atom / string | Left button release event tag |
| `on_right_press` | boolean | Enable right button press |
| `on_right_release` | boolean | Enable right button release |
| `on_middle_press` | boolean | Enable middle button press |
| `on_middle_release` | boolean | Enable middle button release |
| `on_double_click` | boolean | Enable double-click |
| `on_enter` | boolean | Enable cursor enter |
| `on_exit` | boolean | Enable cursor exit |
| `on_move` | boolean | Enable cursor move (coalescable) |
| `on_scroll` | boolean | Enable scroll wheel (coalescable) |
| `event_rate` | integer | Max events/sec for move and scroll |
| `a11y` | map | Accessibility overrides |

Cursor values: `:pointer`, `:grab`, `:grabbing`, `:crosshair`, `:text`,
`:move`, `:not_allowed`, `:progress`, `:wait`, `:help`,
`:resizing_horizontally`, `:resizing_vertically`, and others.

Move and scroll events carry `pointer` (device type) and `modifiers`
(current modifier key state):

```elixir
pointer_area "canvas-area",
  on_move: true,
  on_press: :area_press,
  on_scroll: true,
  cursor: :crosshair do
  canvas "drawing", width: 400, height: 300 do
    # ...
  end
end

# Shift-click for multi-select
def update(model, %WidgetEvent{type: :press, id: "canvas-area",
    data: %{pointer: :mouse, modifiers: %{shift: true}}}) do
  add_to_selection(model)
end

# Ctrl-drag for panning
def update(model, %WidgetEvent{type: :move, id: "canvas-area",
    data: %{x: x, y: y, modifiers: %{ctrl: true}}}) do
  pan_canvas(model, x, y)
end

# Scroll with pointer type
def update(model, %WidgetEvent{type: :scroll, id: "canvas-area",
    data: %{delta_y: dy, pointer: :mouse}}) do
  zoom(model, dy)
end
```

### sensor

Wraps a single child and emits events when the child's size changes
or when it enters/exits visibility. Useful for responsive layouts,
lazy loading, and intersection observation.

| Prop | Type | Purpose |
|---|---|---|
| `delay` | integer | Delay (ms) before emitting events |
| `anticipate` | number | Distance (px) to anticipate visibility |
| `on_resize` | atom / string | Event tag for resize events |
| `event_rate` | integer | Max events/sec for resize |
| `a11y` | map | Accessibility overrides |

Events: `:resize` with `%{width: w, height: h}` in data.

### overlay

Positions the second child as a floating overlay relative to the first
child (anchor). Exactly two children required.

| Prop | Type | Default | Purpose |
|---|---|---|---|
| `position` | `:below` / `:above` / `:left` / `:right` | `:below` | Overlay position |
| `gap` | number | `0` | Space between anchor and overlay |
| `offset_x` | number | `0` | Horizontal offset after positioning |
| `offset_y` | number | `0` | Vertical offset after positioning |
| `flip` | boolean | `false` | Auto-flip when overlay overflows viewport |
| `align` | `:start` / `:center` / `:end` | `:center` | Cross-axis alignment |
| `width` | Length | *n/a* | Overlay container width |
| `a11y` | map | *n/a* | Accessibility overrides |

The overlay renders above all other content at the positioned location.
See the [Composition Patterns](composition-patterns.md#popover)
reference for a popover menu example.

### themer

Applies a different theme to its children. Single child, single prop:

```elixir
themer "dark-section", theme: :dark do
  container padding: 12 do
    text("info", "This section uses the dark theme")
  end
end
```

## Common props

Most widgets support a subset of these cross-cutting props:

- **`:style`** - visual appearance. Accepts a preset atom (e.g.
  `:primary`, `:danger`) or a `StyleMap`. See the
  [Styling reference](themes-and-styling.md).
- **`:a11y`** - accessibility attributes. See the
  [Accessibility reference](accessibility.md).
- **`:width` / `:height`** - sizing. Accepts `:fill`, `:shrink`,
  `{:fill_portion, n}`, or a pixel number. See the
  [Layout reference](windows-and-layout.md).
- **`:event_rate`** - max events per second for high-frequency events.
  Supported on `slider`, `vertical_slider`, `pointer_area`, `sensor`,
  `canvas`, and `pane_grid`.

## Renderer-side state

Some widgets hold state in the renderer that persists across re-renders.
If their ID changes, this state resets:

- **`text_input`** - cursor position, selection, undo history
- **`text_editor`** - cursor, selection, scroll position, undo
- **`combo_box`** - search text, open/closed state
- **`scrollable`** - scroll position
- **`pane_grid`** - pane sizes and arrangement

These widgets require explicit string IDs. `scrollable` and `pane_grid`
produce compile-time errors if you forget the ID.

## keyed_column vs column

Use `column` for static layouts. Use `keyed_column` when children are
dynamic (added, removed, reordered). It diffs by child ID instead of
position, preserving widget state across list changes. Same props as
column minus `align_x`, `clip`, and `wrap`.

## Auto-ID vs explicit ID

Layout containers (`column`, `row`, `stack`, `grid`, `keyed_column`,
`responsive`) and some display widgets (`text`, `markdown`, `rule`,
`space`, `progress_bar`) support auto-generated IDs. Omit the ID and
one is generated from the call site.

All interactive and stateful widgets require explicit string IDs for
event routing and state persistence. See the
[DSL reference](dsl.md#auto-ids) for the full breakdown.

## Animatable props

Numeric props support renderer-side transitions via `transition()`,
`spring()`, and `loop()`. Commonly animated: `max_width`, `max_height`,
`opacity`, `translate_x`, `translate_y`, `scale`. See the
[Animation reference](animation.md).

## Prop value types

These prop types are used across multiple widgets. The full styling
types (Color, Theme, StyleMap, Border, Shadow, Gradient) are in the
[Styling reference](themes-and-styling.md). Layout types (Length, Padding,
Alignment) are in the [Layout reference](windows-and-layout.md).

### Font

Used by: `text`, `rich_text`, `text_input`, `text_editor`.

| Value | Meaning |
|---|---|
| `:default` | System default proportional font |
| `:monospace` | System monospace font |
| `"Family Name"` | Specific font family (must be loaded via `settings/0`) |

The full font spec struct (`Plushie.Type.Font`) also supports `weight:`
(`:thin` through `:black`), `style:` (`:normal`, `:italic`, `:oblique`),
and `stretch:` (`:ultra_condensed` through `:ultra_expanded`).

### Shaping

Used by: `text`, `rich_text`, `text_input`, `text_editor`.

| Value | Meaning |
|---|---|
| `:basic` | Simple left-to-right shaping (fastest) |
| `:advanced` | Full Unicode shaping (ligatures, RTL, complex scripts) |
| `:auto` | Let the renderer decide based on content |

### Wrapping

Used by: `text`, `rich_text`.

| Value | Meaning |
|---|---|
| `:none` | No wrapping (text overflows) |
| `:word` | Break at word boundaries |
| `:glyph` | Break at any character |
| `:word_or_glyph` | Try word boundaries first, fall back to glyph |

### Content fit

Used by: `image`, `svg`.

| Value | Meaning |
|---|---|
| `:contain` | Scale to fit within bounds, preserving aspect ratio |
| `:cover` | Scale to fill bounds, cropping if needed |
| `:fill` | Stretch to fill bounds exactly (may distort) |
| `:none` | No scaling (original size) |
| `:scale_down` | Like `:contain` but never scales up |

### Filter method

Used by: `image`.

| Value | Meaning |
|---|---|
| `:nearest` | Pixel-perfect interpolation (blocky, good for pixel art) |
| `:linear` | Smooth interpolation (good for photos) |

### Tooltip position

Used by: `tooltip`.

| Value | Meaning |
|---|---|
| `:top` | Above the widget |
| `:bottom` | Below the widget |
| `:left` | Left of the widget |
| `:right` | Right of the widget |
| `:follow_cursor` | Follows the mouse cursor |

### Scroll direction

Used by: `scrollable`.

| Value | Meaning |
|---|---|
| `:vertical` | Vertical scrolling (default) |
| `:horizontal` | Horizontal scrolling |
| `:both` | Bidirectional scrolling |

### Scroll anchor

Used by: `scrollable`.

| Value | Meaning |
|---|---|
| `:start` | Anchor at the top/left (default) |
| `:end` | Anchor at the bottom/right |

## See also

- [Layout reference](windows-and-layout.md) - sizing, alignment, and all layout
  containers with full prop tables
- [Styling reference](themes-and-styling.md) - Color, Theme, StyleMap, Border,
  Shadow, Gradient
- [Canvas reference](canvas.md) - shapes, layers, interactive groups
- [Accessibility reference](accessibility.md) - the `a11y` prop, roles,
  and keyboard navigation
- [Events reference](events.md) - all event types delivered by widgets
- [DSL reference](dsl.md) - three forms, auto-IDs, compile-time
  validation
- [Animation reference](animation.md) - transition, spring, loop
  descriptors
- [Layout guide](../guides/07-layout.md) - layout applied to the pad
- [Styling guide](../guides/08-styling.md) - themes and visual
  customization
