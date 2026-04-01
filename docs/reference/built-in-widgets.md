# Built-in Widgets

All built-in widgets are available via `import Plushie.UI`. Each widget
has a corresponding typed builder module under `Plushie.Widget.*` for
programmatic use. See individual module docs for full prop listings.

## Widget Catalog

### Layout

| DSL macro        | Module                          | Description                                              |
|------------------|---------------------------------|----------------------------------------------------------|
| `window`         | `Plushie.Widget.Window`         | Top-level window container with title, size, position    |
| `column`         | `Plushie.Widget.Column`         | Arranges children vertically                             |
| `row`            | `Plushie.Widget.Row`            | Arranges children horizontally                           |
| `container`      | `Plushie.Widget.Container`      | Wraps a single child with padding, sizing, and styling   |
| `scrollable`     | `Plushie.Widget.Scrollable`     | Scrollable viewport around child content                 |
| `stack`          | `Plushie.Widget.Stack`          | Layers children on top of each other (z-axis)            |
| `grid`           | `Plushie.Widget.Grid`           | Fixed-column grid layout                                 |
| `keyed_column`   | `Plushie.Widget.KeyedColumn`    | Vertical layout with stable identity keys for diffing    |
| `responsive`     | `Plushie.Widget.Responsive`     | Adapts to available size via resize events                |
| `pin`            | `Plushie.Widget.Pin`            | Positions child at absolute coordinates                  |
| `floating`       | `Plushie.Widget.Floating`       | Positions child with optional translation and scaling    |
| `space`          | `Plushie.Widget.Space`          | Invisible spacer                                         |

### Input

| DSL macro         | Module                            | Description                                          |
|-------------------|-----------------------------------|------------------------------------------------------|
| `button`          | `Plushie.Widget.Button`           | Clickable widget, emits `:click` events              |
| `text_input`      | `Plushie.Widget.TextInput`        | Single-line editable text field                      |
| `text_editor`     | `Plushie.Widget.TextEditor`       | Multi-line editable text area                        |
| `checkbox`        | `Plushie.Widget.Checkbox`         | Toggleable boolean input                             |
| `toggler`         | `Plushie.Widget.Toggler`          | On/off switch                                        |
| `radio`           | `Plushie.Widget.Radio`            | One-of-many selection (grouped by `:group` prop)     |
| `slider`          | `Plushie.Widget.Slider`           | Horizontal range input                               |
| `vertical_slider` | `Plushie.Widget.VerticalSlider`   | Vertical range input                                 |
| `pick_list`       | `Plushie.Widget.PickList`         | Dropdown selection                                   |
| `combo_box`       | `Plushie.Widget.ComboBox`         | Searchable dropdown with free-form text input        |

### Display

| DSL macro       | Module                         | Description                                           |
|-----------------|--------------------------------|-------------------------------------------------------|
| `text`          | `Plushie.Widget.Text`          | Renders static text                                   |
| `rich_text`     | `Plushie.Widget.RichText`      | Styled text with individually styled spans            |
| `rule`          | `Plushie.Widget.Rule`          | Horizontal or vertical divider line                   |
| `progress_bar`  | `Plushie.Widget.ProgressBar`   | Displays progress within a range                      |
| `tooltip`       | `Plushie.Widget.Tooltip`       | Popup tip shown on hover                              |
| `image`         | `Plushie.Widget.Image`         | Raster image from file path or in-memory handle       |
| `svg`           | `Plushie.Widget.Svg`           | Vector image from SVG file                            |
| `qr_code`       | `Plushie.Widget.QrCode`        | QR code from a data string                            |
| `markdown`      | `Plushie.Widget.Markdown`      | Rendered markdown content                             |
| `canvas`        | `Plushie.Widget.Canvas`        | Drawing surface with named layers of shapes           |

### Interaction Wrappers

| DSL macro    | Module                      | Description                                               |
|--------------|-----------------------------|-----------------------------------------------------------|
| `mouse_area` | `Plushie.Widget.MouseArea`  | Captures mouse events (click, hover, scroll) on children  |
| `sensor`     | `Plushie.Widget.Sensor`     | Detects visibility and size changes on children           |
| `overlay`    | `Plushie.Widget.Overlay`    | Positions second child as a floating overlay on first     |

### Composite

| DSL macro   | Module                     | Description                                          |
|-------------|----------------------------|------------------------------------------------------|
| `pane_grid` | `Plushie.Widget.PaneGrid`  | Resizable tiled panes                                |
| `table`     | `Plushie.Widget.Table`     | Data table with columns, rows, and scrolling         |
| `themer`    | `Plushie.Widget.Themer`    | Per-subtree theme override                           |

## Common Props

Most widgets support a subset of these cross-cutting props. Check
individual module docs for which props apply to each widget.

- **`:style`** -- visual appearance. Accepts a preset atom (e.g.
  `:primary`, `:danger`) or a `Plushie.Type.StyleMap` for custom
  styling. Supported on most input and display widgets.
- **`:a11y`** -- accessibility attributes. See `Plushie.Type.A11y`.
- **`:width` / `:height`** -- sizing via `Plushie.Type.Length`.
  Accepts `:fill`, `:shrink`, or a pixel number.
- **`:event_rate`** -- throttle interval in milliseconds for
  high-frequency events (e.g. slider drag, mouse movement).
  Supported on `slider`, `vertical_slider`, `mouse_area`, `sensor`,
  `canvas`, and `pane_grid`.

## `keyed_column` vs `column`

Use `column` for static or small lists. Use `keyed_column` when
children are dynamic (added, removed, or reordered) -- it uses
each child's `id` as a stable key for the renderer's internal
widget diffing, avoiding unnecessary rebuilds. Same props as `column`;
only the diffing strategy differs.

## Auto-ID vs Explicit ID

Layout containers (`column`, `row`, `stack`, `grid`,
`keyed_column`, `responsive`) and some display widgets (`text`,
`markdown`, `rule`, `space`, `progress_bar`) support auto-generated
IDs. You can omit the `id` argument and one will be generated from
the call site.

Stateful and interactive widgets (`text_input`, `text_editor`,
`combo_box`, `pick_list`, `pane_grid`, `checkbox`, `toggler`,
`radio`, `slider`, `button`) require explicit IDs. These widgets
emit events or maintain renderer-side state, so stable identity
matters for event routing and state caching.

See [Scoped IDs](scoped-ids.md) for how IDs compose inside
named containers.

## Animatable Props

Numeric props support renderer-side transitions via `transition()`,
`spring()`, and `loop()`: `max_width`, `max_height`, `translate_x`,
`translate_y`, `scale`, and `size`. See the
[animation reference](animation.md) for details.

## Row Wrapping

`row` supports `wrap: true` to flow children onto the next line
when they overflow the available width:

```elixir
row wrap: true, spacing: 8 do
  for tag <- tags do
    button(tag.id, tag.label)
  end
end
```

## See Also

- [Your First App](../guides/03-your-first-app.md) -- first
  hands-on use of layout and input widgets
- [Lists and Inputs](../guides/06-lists-and-inputs.md) --
  dynamic lists, keyed columns, composite patterns
- [Layout](../guides/07-layout.md) -- layout system deep dive
- [Styling](../guides/08-styling.md) -- StyleMap, themes, visual
  customization
