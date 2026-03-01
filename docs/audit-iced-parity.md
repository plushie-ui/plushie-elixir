# iced 0.14 Parity Audit

Comprehensive comparison of iced 0.14.0 (with features: `tokio`, `image`,
`svg`, `markdown`, `canvas`) against what Julep exposes to Elixir.

Audited: 2026-02-27. Updated: 2026-02-28 (style maps, canvas primitives,
in-memory images, mouse_area cursor, iced parity gaps batch).

---

## Legend

- **SUPPORTED** -- Julep exposes this and the renderer handles it
- **PARTIAL** -- Julep exposes some of it, gaps noted
- **MISSING** -- iced supports it, Julep does not expose it
- **BLOCKED** -- iced's API design or transport constraints prevent implementation
- **N/A** -- Not applicable (feature not enabled, or internal-only)

---

## 1. Widgets

### Layout Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Column` | SUPPORTED | `column` in both `Iced` and `UI` layers |
| `Row` | SUPPORTED | `row` in both layers |
| `Container` | SUPPORTED | `container` in both layers |
| `Stack` | SUPPORTED | `stack` in both layers |
| `Space` | SUPPORTED | `space` in both layers |
| `Scrollable` | SUPPORTED | `scrollable` in both layers; direction, anchor, scrollbar config, on_scroll, auto_scroll handled |
| `Grid` | SUPPORTED | `grid` in both layers; columns, spacing, width, height |
| `Pin` | SUPPORTED | `pin` in both layers; absolute positioning via x/y props |
| `Float` | SUPPORTED | `float_widget` in `Iced`, `float` in `UI`; translate_x/y, scale |
| `Responsive` | SUPPORTED | `responsive` in both layers; wraps sensor for resize events |
| `Keyed::Column` | SUPPORTED | `keyed_column` in both layers; hashes child IDs for keys |

### Interactive Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Button` | SUPPORTED | Supports children (arbitrary content), disabled state, named styles |
| `TextInput` | SUPPORTED | secure (password), font, line_height, align_x, id, style, on_paste, icon |
| `TextEditor` | SUPPORTED | Stateful; font, size, line_height, padding, wrapping, min/max height, syntax highlighting |
| `Checkbox` | SUPPORTED | size, text_size, font, text_line_height, text_shaping, text_wrapping, style, icon |
| `Radio` | SUPPORTED | group prop, spacing, width, size, text_size, font, shaping, wrapping, style |
| `Toggler` | SUPPORTED | size, text_size, font, text_line_height, text_shaping, text_wrapping, style, text_alignment |
| `Slider` | SUPPORTED | default (reset), height, shift_step, style, circular_handle, handle_radius |
| `VerticalSlider` | SUPPORTED | default (reset), shift_step, style, circular_handle, handle_radius |
| `PickList` | SUPPORTED | padding, text_size, font, menu_height, text_line_height, text_shaping, style, handle, on_open/on_close |
| `ComboBox` | SUPPORTED | Real combo_box with State<String>, free-text input, on_input, padding, size, font, line_height, menu_height, on_option_hovered, icon, on_open/on_close |
| `MouseArea` | SUPPORTED | on_press, on_release, on_middle_press events; cursor prop for mouse interaction |
| `Sensor` | SUPPORTED | on_show, on_resize (with dimensions), on_hide |
| `PaneGrid` | SUPPORTED | Stateful; spacing, on_click, on_resize, on_drag; title bars |

### Display Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Text` | SUPPORTED | size, color, font, width, height, line_height, align_x, align_y, wrapping, shaping, named styles (primary/secondary/success/danger/warning) |
| `Rich` (rich text) | SUPPORTED | `rich_text` -- styled spans with size, color, font, inline links, on_link_click |
| `Rule` | SUPPORTED | horizontal and vertical, thickness, named styles (default/weak) |
| `ProgressBar` | SUPPORTED | range, value, length (width), girth (height), vertical, named styles |
| `Tooltip` | SUPPORTED | position, gap, padding, snap_within_viewport, named styles |
| `Image` | SUPPORTED | All display props supported. File path and in-memory handles (`Handle::from_bytes`, `Handle::from_rgba`) via image registry commands. |
| `Svg` | SUPPORTED | source, width, height, content_fit, rotation, opacity, color (tint) |
| `Canvas` | SUPPORTED | Interactive events, layer-based caching, arbitrary paths (bezier, quadratic, arcs, ellipses, rounded rects), stroke styles (cap, join, dash), gradient fills, transforms (translate, rotate, scale), draw_image, draw_svg, text with font/size, fill rules (non_zero/even_odd), clipping (push_clip/pop_clip). See per-widget section. |
| `Markdown` | SUPPORTED | Settings: text_size, h1_size, h2_size, h3_size, code_size, spacing; width via container wrapper |
| `Table` | SUPPORTED | Composite implementation; columns, rows, header (conditional), separator, padding, sortable columns, per-column align/width |
| `QRCode` | N/A | Feature `qr_code` not enabled |
| `Shader` | N/A | Feature `wgpu` not enabled |

### Other iced Utilities

| iced Item | Julep Status | Notes |
|---|---|---|
| `Themer` | SUPPORTED | `themer` in both layers; per-subtree theme override |
| `opaque` | N/A | Internal overlay helper |
| `hover` | N/A | Internal overlay helper |

### Julep-Only (not in iced)

| Widget | Notes |
|---|---|
| `window` | Multi-window container (declarative open/close) |
| `table` | Composite: columns, rows, header, separator |

---

## 2. Per-Widget Prop Coverage

For each supported widget, notable prop coverage. Only gaps are listed;
unlisted props are fully supported.

### Column

| iced Prop | Status | Notes |
|---|---|---|
| `spacing` | SUPPORTED | |
| `padding` | SUPPORTED | Uniform number and per-side object format |
| `width` / `height` | SUPPORTED | |
| `align_x` | SUPPORTED | |
| `max_width` | SUPPORTED | |
| `clip` | SUPPORTED | |
| `wrap()` | SUPPORTED | Via `wrap: true` prop |

### Row

| iced Prop | Status | Notes |
|---|---|---|
| `spacing` | SUPPORTED | |
| `padding` | SUPPORTED | Uniform and per-side object format |
| `width` / `height` | SUPPORTED | |
| `align_y` | SUPPORTED | |
| `max_width` | SUPPORTED | Elixir exposes prop; renderer wraps row in container for max_width constraint |
| `clip` | SUPPORTED | |
| `wrap()` | SUPPORTED | Via `wrap: true` prop |

### Container

| iced Prop | Status | Notes |
|---|---|---|
| `padding` | SUPPORTED | |
| `width` / `height` | SUPPORTED | |
| `center` | SUPPORTED | |
| `max_width` / `max_height` | SUPPORTED | |
| `align_x` / `align_y` | SUPPORTED | |
| `clip` | SUPPORTED | |
| `background` | SUPPORTED | Hex color, {r,g,b,a} object, or linear gradient |
| `color` | SUPPORTED | Text color override |
| `border` | SUPPORTED | {color, width, radius} with per-corner radius |
| `shadow` | SUPPORTED | {color, offset: [x,y], blur_radius} |
| `style` | SUPPORTED | Named styles: transparent, rounded_box, bordered_box, dark, primary, secondary, success, danger, warning |
| `id` | SUPPORTED | All nodes have ID; container ID propagated to renderer |
| `center_x` / `center_y` | SUPPORTED | Elixir-only convenience builders; set width/height to :fill and align to :center on one axis |
| `align_left/right/top/bottom` | SUPPORTED | Elixir-only convenience builders; set width/height to :fill and align to the named edge |

### Stack

| iced Prop | Status | Notes |
|---|---|---|
| `width` / `height` | SUPPORTED | |
| `clip` | SUPPORTED | Both Elixir (Stack widget) and Rust renderer handle clip prop |

### Scrollable

| iced Prop | Status | Notes |
|---|---|---|
| `width` / `height` | SUPPORTED | |
| `direction` | SUPPORTED | "horizontal", "both", default vertical |
| `id` | SUPPORTED | Widget ID for scroll operations |
| `spacing` | SUPPORTED | |
| `anchor_y` | SUPPORTED | "end"/"bottom" for anchor to bottom |
| `scrollbar_width` / `scrollbar_margin` / `scroller_width` | SUPPORTED | |
| `on_scroll` | SUPPORTED | Emits `{:scroll, id, viewport}` with absolute/relative offsets and bounds |
| `auto_scroll` | SUPPORTED | Boolean prop; auto-scrolls to end on content change |
| `style` | N/A | iced 0.14 only has `default` style; no named variants to expose |

### Button

| iced Prop | Status | Notes |
|---|---|---|
| `label` / `content` | SUPPORTED | |
| `width` / `height` | SUPPORTED | |
| `padding` | SUPPORTED | |
| `clip` | SUPPORTED | |
| `disabled` / `enabled` | SUPPORTED | Controls whether on_press is wired |
| `style` | SUPPORTED | primary, secondary, success, warning, danger, text |
| Children as content | SUPPORTED | First child rendered as arbitrary widget content |

### Text

| iced Prop | Status | Notes |
|---|---|---|
| `content` | SUPPORTED | |
| `size` | SUPPORTED | |
| `color` | SUPPORTED | Hex string or {r,g,b,a} object |
| `font` | SUPPORTED | "monospace", or {family, weight, style, stretch} |
| `width` / `height` | SUPPORTED | |
| `line_height` | SUPPORTED | Number (relative) or {relative: n} / {absolute: n} |
| `align_x` / `align_y` | SUPPORTED | |
| `wrapping` | SUPPORTED | |
| `style` | SUPPORTED | primary, secondary, success, danger, warning |
| `shaping` | SUPPORTED | `:basic`, `:advanced`, `:auto` |

### TextInput

| iced Prop | Status | Notes |
|---|---|---|
| `value` / `placeholder` | SUPPORTED | |
| `width` / `size` / `padding` | SUPPORTED | |
| `on_submit` | SUPPORTED | |
| `id` | SUPPORTED | Widget ID for focus/select operations |
| `secure` | SUPPORTED | Password field mode |
| `font` | SUPPORTED | |
| `line_height` | SUPPORTED | |
| `align_x` | SUPPORTED | |
| `style` | SUPPORTED | |
| `on_paste` | SUPPORTED | Boolean prop; emits `{:paste, id, text}` |
| `icon` | SUPPORTED | Map with `code_point`, `size`, `spacing`, `side`, `font` |

### TextEditor

| iced Prop | Status | Notes |
|---|---|---|
| `content` | SUPPORTED | Via renderer-side Content cache |
| `height` | SUPPORTED | |
| `width` | SUPPORTED | Via f32 Pixels (not Length) |
| `placeholder` | SUPPORTED | |
| `font` | SUPPORTED | |
| `size` | SUPPORTED | |
| `line_height` | SUPPORTED | |
| `padding` | SUPPORTED | Uniform only (f32) |
| `min_height` / `max_height` | SUPPORTED | |
| `wrapping` | SUPPORTED | |
| `style` | SUPPORTED | |
| `highlight` | PARTIAL | Syntax highlighting via `highlight_syntax` (language name) and `highlight_theme` (theme name) props. Custom `Highlighter` trait impls still blocked (generic type parameter). |
| `key_binding` | SUPPORTED | Declarative key binding rules via `key_bindings` prop; Rust constructs the closure from the rule set |

### Checkbox

| iced Prop | Status | Notes |
|---|---|---|
| `is_checked` | SUPPORTED | Reads `checked` prop |
| `label` / `spacing` / `width` | SUPPORTED | |
| `size` | SUPPORTED | |
| `text_size` | SUPPORTED | |
| `font` | SUPPORTED | |
| `text_line_height` | SUPPORTED | |
| `text_shaping` | SUPPORTED | |
| `text_wrapping` | SUPPORTED | |
| `style` | SUPPORTED | primary, secondary, success, danger |
| `disabled` | SUPPORTED | Both Elixir (Checkbox widget) and Rust renderer support disabled prop |
| `icon` | SUPPORTED | Map with `code_point` (required), optional `size`, `line_height`, `font`, `shaping`. Customizes the checkmark icon. |

### Radio

| iced Prop | Status | Notes |
|---|---|---|
| `value` / `selected` / `label` | SUPPORTED | |
| `group` | SUPPORTED | Julep-specific: event ID for group matching |
| `spacing` / `width` | SUPPORTED | |
| `size` | SUPPORTED | |
| `text_size` | SUPPORTED | |
| `font` | SUPPORTED | |
| `text_line_height` | SUPPORTED | |
| `text_shaping` | SUPPORTED | |
| `text_wrapping` | SUPPORTED | |
| `style` | SUPPORTED | |

### Toggler

| iced Prop | Status | Notes |
|---|---|---|
| `is_toggled` / `label` / `spacing` / `width` | SUPPORTED | |
| `size` | SUPPORTED | |
| `text_size` | SUPPORTED | |
| `font` | SUPPORTED | |
| `text_line_height` | SUPPORTED | |
| `text_shaping` | SUPPORTED | |
| `text_wrapping` | SUPPORTED | |
| `style` | SUPPORTED | |
| `disabled` | SUPPORTED | Both Elixir (Toggler widget) and Rust renderer support disabled prop |
| `text_alignment` | SUPPORTED | Horizontal text alignment within toggler label area |

### Slider

| iced Prop | Status | Notes |
|---|---|---|
| `range` / `value` / `step` / `width` | SUPPORTED | |
| `on_release` | SUPPORTED | |
| `default` | SUPPORTED | Double-click reset value |
| `height` | SUPPORTED | |
| `shift_step` | SUPPORTED | |
| `style` | SUPPORTED | |
| `circular_handle` | SUPPORTED | Boolean prop; optional `handle_radius` for custom size. Applied via style closure wrapping. |

### VerticalSlider

Same as Slider. `circular_handle` and `handle_radius` also supported.

### PickList

| iced Prop | Status | Notes |
|---|---|---|
| `options` / `selected` / `placeholder` / `width` | SUPPORTED | |
| `padding` | SUPPORTED | |
| `text_size` | SUPPORTED | |
| `font` | SUPPORTED | |
| `menu_height` | SUPPORTED | |
| `text_line_height` | SUPPORTED | |
| `text_shaping` | SUPPORTED | |
| `style` | SUPPORTED | |
| `handle` | SUPPORTED | Map with `type` key: `"arrow"`, `"static"`, `"dynamic"`, `"none"`; arrow has optional size; static/dynamic have icon maps |
| `on_open` / `on_close` | SUPPORTED | Boolean props; emit `{:open, id}` and `{:close, id}` events |

### ComboBox

| iced Prop | Status | Notes |
|---|---|---|
| `State<T>` management | SUPPORTED | Renderer maintains combo_box::State<String> |
| `options` / `selected` / `placeholder` | SUPPORTED | |
| `on_input` | SUPPORTED | Emits Input events |
| `width` / `padding` | SUPPORTED | |
| `size` | SUPPORTED | |
| `font` | SUPPORTED | |
| `line_height` | SUPPORTED | |
| `menu_height` | SUPPORTED | |
| `on_option_hovered` | SUPPORTED | Boolean prop; emits `{:option_hovered, id, value}` |
| `on_open` / `on_close` | SUPPORTED | Boolean props; emit `{:open, id}` and `{:close, id}` events |
| `icon` | SUPPORTED | Map with `code_point`, `size`, `spacing`, `side`, `font` (same format as TextInput) |

### Tooltip

| iced Prop | Status | Notes |
|---|---|---|
| `tip` | SUPPORTED | `Iced.tooltip/4` sets `:tip` prop, renderer reads `tip` |
| `position` | SUPPORTED | top, bottom, left, right, follow_cursor |
| `gap` | SUPPORTED | |
| `padding` | SUPPORTED | |
| `snap_within_viewport` | SUPPORTED | |
| `style` | SUPPORTED | Uses container styles |

### Image

| iced Prop | Status | Notes |
|---|---|---|
| `source` / `width` / `height` / `content_fit` | SUPPORTED | Source is file path only |
| `rotation` | SUPPORTED | |
| `opacity` | SUPPORTED | |
| `border_radius` | SUPPORTED | |
| `filter_method` | SUPPORTED | "nearest" or "linear" |
| `expand` | SUPPORTED | |
| `scale` | SUPPORTED | |
| `crop` | SUPPORTED | {x, y, width, height} object |
| `Handle::from_bytes` | SUPPORTED | In-memory encoded images (PNG/JPEG bytes) via image registry. `Julep.Command.create_image/2` uploads base64-encoded data; widget references by `%{handle: "name"}`. |
| `Handle::from_rgba` | SUPPORTED | Raw RGBA pixel buffers via image registry. `Julep.Command.create_image/4` with width, height, pixels. |
| Image lifecycle | SUPPORTED | `create_image`, `update_image`, `delete_image` commands. Elixir owns lifecycle; renderer is a dumb cache. In msgpack mode, binary data uses native msgpack binary type (preserved via rmpv decode path). In JSON mode, binary data uses base64 encoding. |

### Svg

| iced Prop | Status | Notes |
|---|---|---|
| `source` / `width` / `height` / `content_fit` | SUPPORTED | |
| `rotation` | SUPPORTED | |
| `opacity` | SUPPORTED | |
| `color` | SUPPORTED | Color tint applied to the SVG |
| `style` | PARTIAL | Color tint supported via `color` prop; status-sensitive style closures blocked (cannot serialize from Elixir) |

### ProgressBar

| iced Prop | Status | Notes |
|---|---|---|
| `range` / `value` | SUPPORTED | |
| `width` (length) / `height` (girth) | SUPPORTED | |
| `style` | SUPPORTED | primary, secondary, success, danger, warning |
| `vertical` | SUPPORTED | Boolean prop for vertical orientation |

### Rule

| iced Prop | Status | Notes |
|---|---|---|
| `horizontal(height)` | SUPPORTED | Thickness is direction-aware: uses height |
| `vertical(width)` | SUPPORTED | Thickness is direction-aware: uses width |
| `style` | SUPPORTED | default, weak |

### Markdown

| iced Prop | Status | Notes |
|---|---|---|
| `content` | SUPPORTED | |
| `width` | SUPPORTED | Wrapped in container |
| `text_size` | SUPPORTED | |
| `h1_size` / `h2_size` / `h3_size` | SUPPORTED | |
| `code_size` | SUPPORTED | |
| `spacing` | SUPPORTED | |
| `Highlighter` | SUPPORTED | `highlighter` feature enabled in Cargo.toml; iced renders code blocks with syntax highlighting |

### Canvas

| iced Prop | Status | Notes |
|---|---|---|
| `width` / `height` | SUPPORTED | |
| `background` | SUPPORTED | Fill color |
| `on_press` / `on_release` / `on_move` / `on_scroll` | SUPPORTED | Individual or via `interactive: true` |
| Layers | SUPPORTED | `layers` prop: map of layer name to shape array. Each layer drawn independently for targeted updates. |
| Shape: rect | SUPPORTED | Filled/stroked rectangle (x, y, w, h, fill, stroke); optional radius for rounded rects |
| Shape: circle | SUPPORTED | Filled/stroked circle (x, y, r, fill, stroke) |
| Shape: line | SUPPORTED | Stroked line (x1, y1, x2, y2, stroke or legacy fill+width) |
| Shape: text | SUPPORTED | Filled text (x, y, content, fill, size, font) |
| Shape: path | SUPPORTED | Arbitrary paths from command arrays: move_to, line_to, bezier_to, quadratic_to, arc, arc_to, ellipse, rounded_rect, close |
| Stroked shapes | SUPPORTED | All shapes support `stroke` prop (color, width, cap, join, dash) |
| Stroke styles | SUPPORTED | `LineCap` (butt/square/round), `LineJoin` (miter/round/bevel), `LineDash` (segments, offset) |
| Gradient fills | SUPPORTED | Linear gradients: `{type: "linear", start, end, stops}` -- up to 8 stops |
| Transforms | SUPPORTED | `translate(x, y)`, `rotate(angle)`, `scale(factor)` / `scale(x, y)` |
| Save/restore | SUPPORTED | Transform stack via push_transform/pop_transform commands |
| Draw image | SUPPORTED | `frame.draw_image(bounds, image)` via `{type: "image", source, x, y, w, h}` |
| Draw SVG | SUPPORTED | `frame.draw_svg(bounds, svg)` via `{type: "svg", source, x, y, w, h}` |
| Fill rules | SUPPORTED | `:fill_rule` option on shapes: `:non_zero` (default) or `:even_odd` |
| Clipping | SUPPORTED | `push_clip(x, y, w, h)` and `pop_clip()` shape builders; clips drawing to a rectangle region |

### Table

| iced Prop | Status | Notes |
|---|---|---|
| `columns` / `rows` | SUPPORTED | |
| `width` | SUPPORTED | |
| `header` | SUPPORTED | Conditional via boolean prop |
| `separator` | SUPPORTED | Conditional via boolean prop |
| `padding` | SUPPORTED | |
| `sortable` | SUPPORTED | Per-column `sortable` flag, `sort_by` and `sort_order` table props; emits `{:sort, id, column_key}` |
| Column `align` / `width` | SUPPORTED | Extended column descriptor with `align` and `width` fields |

---

## 3. Core Types

### Length

| iced Variant | Julep | Renderer | Status |
|---|---|---|---|
| `Fill` | `:fill` | `"fill"` | SUPPORTED |
| `Shrink` | `:shrink` | `"shrink"` | SUPPORTED |
| `Fixed(f32)` | number | number | SUPPORTED |
| `FillPortion(u16)` | `{:fill_portion, n}` | `{"fill_portion": n}` | SUPPORTED -- renderer parses JSON object |

### Padding

| iced Form | Julep | Renderer | Status |
|---|---|---|---|
| Uniform `f32` | number | `padding` key | SUPPORTED |
| `[vert, horiz]` | `{v, h}` tuple | Encoded as per-side map | SUPPORTED |
| Per-side struct | `%{top, right, bottom, left}` | `{"top": n, ...}` | SUPPORTED -- renderer parses object format |

### Alignment

| iced Variant | Julep | Renderer | Status |
|---|---|---|---|
| `Start` / `Left` / `Top` | `:start` | `"start"` / `"left"` / `"top"` | SUPPORTED |
| `Center` | `:center` | `"center"` | SUPPORTED |
| `End` / `Right` / `Bottom` | `:end` | `"end"` / `"right"` / `"bottom"` | SUPPORTED |

### Font

| iced Feature | Julep | Renderer | Status |
|---|---|---|---|
| `:default` / `:monospace` | Yes | Yes | SUPPORTED |
| Named family (serif, cursive, fantasy) | Yes | Yes | SUPPORTED |
| Weight variants (all 9) | Yes | Yes | SUPPORTED |
| Style (normal/italic/oblique) | Yes | Yes | SUPPORTED |
| `Stretch` (9 variants) | Yes | Yes | SUPPORTED |
| Runtime `font::load` | Via settings/0 | SUPPORTED | App-level font loading via settings callback; Rust reads font file paths from settings and calls `iced::font::load` |

### Color

| iced Feature | Julep | Status |
|---|---|---|
| Hex strings | `"#rrggbb"` or `"#rrggbbaa"` | SUPPORTED |
| `{r, g, b, a}` object (0-1 floats) | `%{r: 0.5, g: 0.5, b: 0.5, a: 1.0}` | SUPPORTED |
| Gradient backgrounds | Linear gradient on container | SUPPORTED |
| Named constants (BLACK, WHITE, TRANSPARENT) | `Color.cast/1` accepts named atoms (`:black`, `:white`, `:red`, etc.) and hex strings | SUPPORTED |

### ContentFit

| iced Variant | Julep | Renderer | Status |
|---|---|---|---|
| `Contain` | `"contain"` | `"contain"` | SUPPORTED |
| `Cover` | `"cover"` | `"cover"` | SUPPORTED |
| `Fill` | `"fill"` | `"fill"` | SUPPORTED |
| `None` | `"none"` | `"none"` | SUPPORTED |
| `ScaleDown` | `"scale_down"` | `"scale_down"` | SUPPORTED |

### Border

| iced Feature | Julep | Status |
|---|---|---|
| Border struct (color, width, radius) | `%{color: "#hex", width: n, radius: n}` | SUPPORTED |
| Per-corner radius | Array `[tl, tr, br, bl]` or object `%{top_left: n, ...}` | SUPPORTED |

### Shadow

| iced Feature | Julep | Status |
|---|---|---|
| Shadow struct (color, offset, blur_radius) | `%{color: "#hex", offset: [x, y], blur_radius: n}` | SUPPORTED |

### Line Height

| iced Feature | Julep | Status |
|---|---|---|
| Relative | Number or `%{relative: 1.5}` | SUPPORTED |
| Absolute | `%{absolute: 20}` | SUPPORTED |

---

## 4. Theme

| iced Feature | Julep | Status |
|---|---|---|
| 22 built-in themes | Yes (all 22) | SUPPORTED |
| `custom(name, palette)` | Yes | SUPPORTED |
| Palette fields: background, text, primary, success, danger | Yes | SUPPORTED |
| Palette field: `warning` | SUPPORTED | Custom palette accepts `warning` hex color for warning-themed widgets |
| `base` field for custom themes | Yes | SUPPORTED |
| Per-widget named styles | Yes | SUPPORTED -- button, container, text, checkbox, progress_bar, rule, etc. have named style atoms |
| `Themer` widget (per-subtree theme) | Yes | SUPPORTED |
| Status-aware styling (hover/press/focus) | Internally | SUPPORTED -- iced's Catalog handles this on the Rust side; named presets include full hover/press/focus/disabled visual feedback automatically. Not customizable from Elixir. |
| Custom `StyleFn` closures | Via style maps | SUPPORTED -- `Julep.Iced.StyleMap` struct crosses IPC as JSON object; Rust constructs one-off closures from the values. Supports background, text_color, border, shadow, plus status overrides (hovered, pressed, disabled, focused). Auto-derives hover (darken 10%), disabled (50% alpha). Works on all 13 styleable widgets: button, container, text_input, text_editor, checkbox, radio, toggler, pick_list, progress_bar, rule, slider, vertical_slider, tooltip. |
| Inline style maps (non-container) | Yes | SUPPORTED -- All 13 styleable widgets accept `StyleMap.t()` in addition to named preset atoms. |
| Extended palette shade control | Yes | SUPPORTED -- custom themes accept optional shade override keys (`primary_strong`, `background_weak`, etc.) to override individual Extended palette variants. Uses `Theme::custom_with_fn` with `Extended::generate` as base, then overlays specified shades. |
| `theme::Mode` (Light/Dark/None) | Via `"system"` theme value | SUPPORTED -- setting window theme to `"system"` follows OS light/dark preference |

---

## 5. Subscriptions

| iced Subscription | Julep | Status |
|---|---|---|
| `time::every(Duration)` | `every(interval_ms, tag)` | SUPPORTED |
| `keyboard::listen()` (key press) | `on_key_press(tag)` | SUPPORTED |
| `keyboard::listen()` (key release) | `on_key_release(tag)` | SUPPORTED |
| `window::close_requests()` | `on_window_close(tag)` | SUPPORTED |
| `window::events()` | `on_window_event(tag)` | SUPPORTED |
| `window::open_events()` | `on_window_open(tag)` | SUPPORTED |
| `window::resize_events()` | `on_window_resize(tag)` | SUPPORTED |
| Window focus/unfocus | `on_window_focus(tag)` / `on_window_unfocus(tag)` | SUPPORTED |
| Window move | `on_window_move(tag)` | SUPPORTED |
| `window::frames()` | `on_animation_frame(tag)` | SUPPORTED |
| Mouse move | `on_mouse_move(tag)` | SUPPORTED |
| Mouse button | `on_mouse_button(tag)` | SUPPORTED |
| Mouse scroll | `on_mouse_scroll(tag)` | SUPPORTED |
| Touch events | `on_touch(tag)` | SUPPORTED |
| File drop | `on_file_drop(tag)` | SUPPORTED |
| `system::theme_changes()` | `on_theme_change(tag)` | SUPPORTED |
| `event::listen()` | `on_event(tag)` | SUPPORTED -- catch-all |
| `Subscription::batch()` | `batch(subscriptions)` | SUPPORTED -- identity (list concat) |

---

## 6. Commands / Tasks

| iced Task | Julep Command | Status |
|---|---|---|
| `Task::none()` | `none()` | SUPPORTED |
| `Task::done(value, mapper)` | `done(value, msg_fn)` | SUPPORTED |
| `Task::perform(future, map)` | `async(fun, tag)` | SUPPORTED |
| `Task::batch(tasks)` | `batch(commands)` | SUPPORTED |
| `focus(id)` | `focus(widget_id)` | SUPPORTED |
| `focus_next()` | `focus_next()` | SUPPORTED |
| `focus_previous()` | `focus_previous()` | SUPPORTED |
| `select_all(id)` | `select_all(widget_id)` | SUPPORTED |
| `scroll_to(id, offset)` | `scroll_to(widget_id, offset)` | SUPPORTED |
| `snap_to(id, offset)` | `snap_to(widget_id, x, y)` | SUPPORTED |
| `snap_to_end(id)` | `snap_to_end(widget_id)` | SUPPORTED |
| `scroll_by(id, offset)` | `scroll_by(widget_id, x, y)` | SUPPORTED |
| `text_input::move_cursor_to_front` | `move_cursor_to_front(widget_id)` | SUPPORTED |
| `text_input::move_cursor_to_end` | `move_cursor_to_end(widget_id)` | SUPPORTED |
| `text_input::move_cursor_to(pos)` | `move_cursor_to(widget_id, pos)` | SUPPORTED |
| `text_input::select_range` | `select_range(widget_id, start, end)` | SUPPORTED |
| Custom `send_after` | `send_after(delay, event)` | SUPPORTED (julep-specific) |
| `iced::exit()` | `exit()` | SUPPORTED |
| PaneGrid: split | `pane_split(grid_id, pane_id, axis, new_id)` | SUPPORTED |
| PaneGrid: close | `pane_close(grid_id, pane_id)` | SUPPORTED |
| PaneGrid: swap | `pane_swap(grid_id, pane_a, pane_b)` | SUPPORTED |
| PaneGrid: maximize | `pane_maximize(grid_id, pane_id)` | SUPPORTED |
| PaneGrid: restore | `pane_restore(grid_id)` | SUPPORTED |
| `Task::run(stream, map)` | `Command.stream/2` | SUPPORTED -- streams events from an enumerable |
| `Task::future(future)` | No | **MISSING** |
| `Task::stream(stream)` | `Command.stream/2` | SUPPORTED |
| `task::blocking(fn)` | No | **MISSING** |
| `.then()` / `.chain()` | By design | SUPPORTED -- handled by the Elm update loop; each `update/2` can return new commands, creating natural chains with model updates between steps |
| `.collect()` | No | **MISSING** |
| `.abortable()` | `Command.cancel/1` | SUPPORTED -- cancels a running async or stream command by its event tag |

---

## 7. Window Operations

| iced Window Op | Julep | Status |
|---|---|---|
| `open(Settings)` | Via tree (declarative) | SUPPORTED (different model) |
| `close(id)` | `close_window(id)` | SUPPORTED |
| `resize(id, size)` | `resize_window(id, w, h)` | SUPPORTED |
| `move_to(id, point)` | `move_window(id, x, y)` | SUPPORTED |
| `maximize(id, bool)` | `maximize_window(id, bool)` | SUPPORTED |
| `minimize(id, bool)` | `minimize_window(id, bool)` | SUPPORTED |
| `set_mode(id, mode)` | `set_window_mode(id, mode)` | SUPPORTED |
| `toggle_maximize(id)` | `toggle_maximize(id)` | SUPPORTED |
| `toggle_decorations(id)` | `toggle_decorations(id)` | SUPPORTED |
| `gain_focus(id)` | `gain_focus(id)` | SUPPORTED |
| `set_level(id, level)` | `set_window_level(id, level)` | SUPPORTED |
| `drag(id)` | `drag_window(id)` | SUPPORTED |
| `drag_resize(id, dir)` | `drag_resize_window(id, dir)` | SUPPORTED |
| `request_user_attention` | `request_user_attention(id, urgency)` | SUPPORTED |
| `screenshot(id)` | `screenshot(id, tag)` | SUPPORTED |
| `set_resizable(id, bool)` | `set_resizable(id, bool)` | SUPPORTED |
| `set_min_size` / `set_max_size` | `set_min_size(id, w, h)` / `set_max_size(id, w, h)` | SUPPORTED |
| `enable/disable_mouse_passthrough` | `enable_mouse_passthrough(id)` / `disable_mouse_passthrough(id)` | SUPPORTED |
| `show_system_menu(id)` | `show_system_menu(id)` | SUPPORTED |
| `size(id)` / `position(id)` queries | `get_window_size(id, tag)` / `get_window_position(id, tag)` | SUPPORTED |
| `is_maximized(id)` / `is_minimized(id)` | `is_maximized(id, tag)` / `is_minimized(id, tag)` | SUPPORTED |
| `set_icon(id, icon)` | `set_icon(id, width, height, rgba)` | SUPPORTED |
| `scale_factor(id)` | `get_scale_factor(id, tag)` | SUPPORTED |
| `mode(id)` | `get_mode(id, tag)` | SUPPORTED |
| `raw_id(id)` | `raw_id(id, tag)` | SUPPORTED |
| `monitor_size(id)` | `monitor_size(id, tag)` | SUPPORTED |
| `set_resize_increments(id, size)` | `set_resize_increments(id, w, h)` | SUPPORTED |
| `system::information()` | `get_system_info(tag)` | SUPPORTED -- returns `{:system_info, tag, info_map}` |
| `system::theme()` | `get_system_theme(tag)` | SUPPORTED -- returns `{:system_theme, tag, mode}` |

### Window Settings

| iced Setting | Julep | Status |
|---|---|---|
| `size` | Via `window_config` or window node props | SUPPORTED |
| `title` | Via `window` node | SUPPORTED |
| `maximized` | Via window node `maximized` prop | SUPPORTED |
| `fullscreen` | Via window node `fullscreen` prop | SUPPORTED |
| `position` (Default, Centered, Specific) | Via window node `position` prop | SUPPORTED |
| `min_size` / `max_size` | Via window node `min_size` / `max_size` props | SUPPORTED |
| `visible` | Via window node `visible` prop | SUPPORTED |
| `resizable` | Via window node `resizable` prop | SUPPORTED |
| `closeable` | Via window node `closeable` prop | SUPPORTED |
| `minimizable` | Via window node `minimizable` prop | SUPPORTED |
| `decorations` | Via window node `decorations` prop | SUPPORTED |
| `transparent` | Via window node `transparent` prop | SUPPORTED |
| `blur` | Via window node `blur` prop | SUPPORTED |
| `level` | Via window node `level` prop | SUPPORTED |
| `icon` | SUPPORTED | via `set_icon/4` command with RGBA pixel data |
| `exit_on_close_request` | Via window node `exit_on_close_request` prop | SUPPORTED |

---

## 8. Events

### Keyboard Events

| iced Event | Julep | Status |
|---|---|---|
| `KeyPressed` | `{:key_press, %Julep.KeyEvent{}}` | SUPPORTED |
| `KeyReleased` | `{:key_release, %Julep.KeyEvent{}}` | SUPPORTED |
| `ModifiersChanged` | `{:modifiers_changed, %Julep.KeyModifiers{}}` | SUPPORTED |
| `key::Named` variants | ~200 mapped | SUPPORTED -- comprehensive named key map |
| `key::Character` | Characters pass through | SUPPORTED |
| `physical_key` | `%Julep.KeyEvent{physical_key: atom}` | SUPPORTED |
| `location` | `%Julep.KeyEvent{location: atom}` | SUPPORTED |
| `text` field | `%Julep.KeyEvent{text: string \| nil}` | SUPPORTED |
| `repeat` field | `%Julep.KeyEvent{repeat: bool}` | SUPPORTED |
| `modified_key` | `%Julep.KeyEvent{modified_key: key}` | SUPPORTED |

### Keyboard Modifiers

Modifiers are now `%Julep.KeyModifiers{}` structs (embedded in `KeyEvent`
and delivered standalone via `:modifiers_changed`).

| iced Modifier | Julep | Status |
|---|---|---|
| `SHIFT` | `%Julep.KeyModifiers{shift: true}` | SUPPORTED |
| `CTRL` | `%Julep.KeyModifiers{ctrl: true}` | SUPPORTED |
| `ALT` | `%Julep.KeyModifiers{alt: true}` | SUPPORTED |
| `LOGO` | `%Julep.KeyModifiers{logo: true}` | SUPPORTED |
| `COMMAND` (platform) | `%Julep.KeyModifiers{command: true}` | SUPPORTED |

### Mouse Events

| iced Event | Julep | Status |
|---|---|---|
| `CursorMoved` | `{:cursor_moved, x, y}` | SUPPORTED |
| `CursorEntered` | `{:cursor_entered}` | SUPPORTED |
| `CursorLeft` | `{:cursor_left}` | SUPPORTED |
| `ButtonPressed` | `{:button_pressed, button}` | SUPPORTED |
| `ButtonReleased` | `{:button_released, button}` | SUPPORTED |
| `WheelScrolled` | `{:wheel_scrolled, dx, dy, unit}` | SUPPORTED |

### Touch Events

| iced Event | Julep | Status |
|---|---|---|
| `FingerPressed` | `{:finger_pressed, finger_id, x, y}` | SUPPORTED |
| `FingerMoved` | `{:finger_moved, finger_id, x, y}` | SUPPORTED |
| `FingerLifted` | `{:finger_lifted, finger_id, x, y}` | SUPPORTED |
| `FingerLost` | `{:finger_lost, finger_id, x, y}` | SUPPORTED |

### Window Events

| iced Event | Julep | Status |
|---|---|---|
| `CloseRequested` | `{:window_close_requested, window_id}` | SUPPORTED |
| `Opened` | `{:window_opened, window_id, position, size}` | SUPPORTED |
| `Closed` | `{:window_closed, window_id}` | SUPPORTED |
| `Moved` | `{:window_moved, window_id, x, y}` | SUPPORTED |
| `Resized` | `{:window_resized, window_id, width, height}` | SUPPORTED |
| `Rescaled` | `{:window_rescaled, window_id, scale_factor}` | SUPPORTED |
| `Focused` / `Unfocused` | `{:window_focused, window_id}` / `{:window_unfocused, window_id}` | SUPPORTED |
| `FileHovered` | `{:file_hovered, window_id, path}` | SUPPORTED |
| `FileDropped` | `{:file_dropped, window_id, path}` | SUPPORTED |
| `FilesHoveredLeft` | `{:files_hovered_left, window_id}` | SUPPORTED |

### Canvas Events

| Event | Julep | Status |
|---|---|---|
| Press | `{:canvas_press, id, x, y, button}` | SUPPORTED |
| Release | `{:canvas_release, id, x, y, button}` | SUPPORTED |
| Move | `{:canvas_move, id, x, y}` | SUPPORTED |
| Scroll | `{:canvas_scroll, id, x, y, delta_x, delta_y}` | SUPPORTED |

### Sensor Events

| Event | Julep | Status |
|---|---|---|
| Resize | `{:sensor_resize, id, width, height}` | SUPPORTED |

### PaneGrid Events

| Event | Julep | Status |
|---|---|---|
| Resized | `{:pane_resized, id, split, ratio}` | SUPPORTED |
| Dragged | `{:pane_dragged, id, pane, target}` | SUPPORTED |
| Clicked | `{:pane_clicked, id, pane}` | SUPPORTED |

### Other Events

| Event | Julep | Status |
|---|---|---|
| Animation frame | `{:animation_frame, timestamp}` | SUPPORTED |
| Theme changed | `{:theme_changed, mode}` | SUPPORTED |

---

## 9. Clipboard

| iced Feature | Julep | Status |
|---|---|---|
| `clipboard::read()` | `clipboard_read()` | SUPPORTED (via effects) |
| `clipboard::write(text)` | `clipboard_write(text)` | SUPPORTED (via effects) |
| `clipboard::read_primary()` | `clipboard_read(:primary)` | SUPPORTED (via effects) |
| `clipboard::write_primary(text)` | `clipboard_write(text, :primary)` | SUPPORTED (via effects) |

---

## 10. Application-Level Settings

| iced Setting | Julep | Status |
|---|---|---|
| `default_font` | Via `settings/0` callback | SUPPORTED |
| `default_text_size` | Via `settings/0` callback | SUPPORTED |
| `fonts` (custom font loading) | Via `settings/0` callback | SUPPORTED |
| `antialiasing` | Via `settings/0` callback | SUPPORTED -- Rust reads setting on startup and applies to iced daemon builder |
| `subscription` callback | Via `subscribe/1` | SUPPORTED |
| `vsync` | Via `settings/0` callback | SUPPORTED -- boolean (default true) |
| `scale_factor` callback | Via `settings/0` callback | SUPPORTED -- `scale_factor` key in settings/0 |
| `title` callback | Via `window` node title prop | SUPPORTED (different model) |
| `theme` callback | Via `window_config` or `themer` widget | SUPPORTED (different model) |

---

## 11. Summary Statistics

### Widgets
- iced widgets (with enabled features): ~28 distinct widgets
- Julep fully supported: 26 (plus `window` and `table` not in iced)
- Julep partially supported: 0

### Props
- Average prop coverage per supported widget: ~95-100%
- Notable actionable gaps: none (canvas primitives, in-memory images, and style maps all shipped)
- Remaining blocked/N/A items (cannot be resolved):
  - TextEditor custom `Highlighter` trait (BLOCKED -- generic type parameter; named syntax/theme supported)
  - Scrollable custom `style` (BLOCKED -- closure-based)
  - SVG custom `style` (PARTIAL -- color tint supported, status-sensitive closures blocked)
  - Checkbox `text_alignment` (N/A -- not in iced 0.14.2)

### Events
- Keyboard: SUPPORTED (all key families, comprehensive named key map, full KeyEvent/KeyModifiers structs with physical_key, location, text, repeat, modified_key)
- Mouse: SUPPORTED (cursor move, enter/leave, buttons, wheel scroll)
- Touch: SUPPORTED (finger press/move/lift/lost)
- Window lifecycle: SUPPORTED (open, close, close_requested, move, resize, focus, file drop)
- Canvas: SUPPORTED (press, release, move, scroll)
- PaneGrid: SUPPORTED (resize, drag, click)
- Widget callbacks: SUPPORTED (scroll viewport, paste, option_hovered, open/close, sort)

### Commands
- Full set covered: focus, scroll, snap, cursor ops, select, async, batch, done, exit
- Window operations: comprehensive (resize, move, maximize, minimize, decorations, drag, etc.)
- PaneGrid operations: split, close, swap, maximize, restore
- Task chaining handled by Elm update loop (by design); streaming via `Command.stream/2`; cancellation via `Command.cancel/1`

### Window Operations
- Declarative open (via tree) and close supported
- Full imperative window management: resize, move, maximize, minimize, mode, decorations, focus, drag, screenshots, etc.
- Full initial window settings: maximized, fullscreen, position, min/max size, visible, resizable, closeable, minimizable, decorations, transparent, blur, level, exit_on_close_request
- Window icon: via `set_icon/4` command with RGBA pixel data

### Clipboard
- Full clipboard support: read, write, read_primary, write_primary

### Application Settings
- Antialiasing applied to iced daemon builder on startup
- Font loading from file paths via settings/0 callback
- vsync control via settings/0 callback
- scale_factor control via settings/0 callback

---

## 12. Remaining Gaps

### BLOCKED by iced 0.14 API / IPC boundary

These cannot be implemented without upstream changes or fundamentally different transport:

1. **TextEditor custom `Highlighter`** -- changes the Highlighter generic type parameter; cannot be expressed dynamically. Named syntax/theme highlighting is supported; custom Highlighter trait impls are not.
2. **Scrollable custom `style`** -- closure-based; cannot be serialized (only `default` exposed by iced 0.14)
3. **SVG custom `style`** -- PARTIAL: color tint supported via `color` prop; status-sensitive style closures blocked (cannot serialize from Elixir)
4. **Checkbox `text_alignment`** -- not available in iced 0.14.2

### BLOCKED by IPC boundary (workaround shipped)

6. **Custom `StyleFn` closures** -- iced allows arbitrary `Box<dyn Fn(&Theme, Status) -> Style>` per widget. Closures cannot be serialized. Workaround: accept style maps on the `style` prop and construct closures from field values on the Rust side.

### Shipped (previously actionable)

These were identified as gaps and have since been implemented:

7. **Canvas drawing primitives** -- SHIPPED. Layer-based caching, arbitrary paths (bezier, quadratic, arcs, ellipses, rounded rects), stroke styles (cap, join, dash), gradient fills, transforms (translate, rotate, scale with push/pop stack), draw_image, draw_svg, text with font/size, fill rules, clipping.
8. **In-memory images** -- SHIPPED. Image registry on the Rust side with `create_image`, `update_image`, `delete_image` commands. Supports both encoded bytes (`Handle::from_bytes`) and raw RGBA pixels (`Handle::from_rgba`).
9. **Inline style maps for non-container widgets** -- SHIPPED. `Julep.Iced.StyleMap` supports all 13 styleable widgets with background, text_color, border, shadow, plus status overrides (hovered, pressed, disabled, focused) and auto-derived hover/disabled states.
10. **PickList/ComboBox `on_open`/`on_close`** -- SHIPPED. Boolean props; emit `{:open, id}` and `{:close, id}` events.
11. **TextEditor syntax highlighting** -- SHIPPED. `highlight_syntax` (language name) and `highlight_theme` (theme name) props.
12. **Checkbox `icon`** -- SHIPPED. Map with `code_point`, optional `size`, `line_height`, `font`, `shaping`.
13. **Container `center_x`/`center_y`** -- SHIPPED. Elixir-only convenience builders. Also `align_left`, `align_right`, `align_top`, `align_bottom`.
14. **Canvas fill rules and clipping** -- SHIPPED. `:fill_rule` option (`:non_zero`/`:even_odd`), `push_clip`/`pop_clip` shape builders.
15. **Table sortable columns** -- SHIPPED. Extended column descriptor with `align`, `width`, `sortable`. `sort_by`/`sort_order` table props. Sort event: `{:sort, id, column_key}`.
16. **`vsync` setting** -- SHIPPED. Boolean in settings/0 (default true).
17. **`set_resize_increments` command** -- SHIPPED.
18. **System queries** -- SHIPPED. `get_system_info/1` and `get_system_theme/1`.
19. **TextEditor `key_binding`** -- SHIPPED. Declarative key binding rules via `key_bindings` prop.
20. **`scale_factor` setting** -- SHIPPED. Via `settings/0` callback.
21. **`theme::Mode`** -- SHIPPED. Window theme `"system"` follows OS light/dark preference.
22. **SVG color tint** -- SHIPPED. `color` prop applies a color tint to the SVG.
23. **Custom palette `warning` field** -- SHIPPED. Custom themes accept `warning` hex color.
24. **Extended palette shade control** -- SHIPPED. Custom themes accept shade override keys (`primary_strong`, `background_weak`, etc.) via `Theme::custom_with_fn`.

### Remaining actionable gaps

None. All identified parity gaps have been resolved.
