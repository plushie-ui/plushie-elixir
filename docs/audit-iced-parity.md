# iced 0.14 Parity Audit

Comprehensive comparison of iced 0.14.0 (with features: `tokio`, `image`,
`svg`, `markdown`, `canvas`) against what Julep exposes to Elixir.

Audited: 2026-02-27

---

## Legend

- **SUPPORTED** -- Julep exposes this and the renderer handles it
- **PARTIAL** -- Julep exposes some of it, gaps noted
- **MISSING** -- iced supports it, Julep does not expose it
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
| `Scrollable` | SUPPORTED | `scrollable` in both layers; direction, anchor, scrollbar config handled |
| `Grid` | SUPPORTED | `grid` in both layers; columns, spacing, width, height |
| `Pin` | SUPPORTED | `pin` in both layers; absolute positioning via x/y props |
| `Float` | SUPPORTED | `float_widget` in `Iced`, `float` in `UI`; translate_x/y, scale |
| `Responsive` | SUPPORTED | `responsive` in both layers; wraps sensor for resize events |
| `Keyed::Column` | SUPPORTED | `keyed_column` in both layers; hashes child IDs for keys |

### Interactive Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Button` | SUPPORTED | Supports children (arbitrary content), disabled state, named styles |
| `TextInput` | SUPPORTED | secure (password), font, line_height, align_x, id, style |
| `TextEditor` | SUPPORTED | Stateful; font, size, line_height, padding, wrapping, min/max height |
| `Checkbox` | SUPPORTED | size, text_size, font, text_line_height, text_shaping, text_wrapping, style |
| `Radio` | SUPPORTED | group prop, spacing, width, size, text_size, font, shaping, wrapping, style |
| `Toggler` | SUPPORTED | size, text_size, font, text_line_height, text_shaping, text_wrapping, style |
| `Slider` | SUPPORTED | default (reset), height, shift_step, style |
| `VerticalSlider` | SUPPORTED | default (reset), shift_step, style |
| `PickList` | SUPPORTED | padding, text_size, font, menu_height, text_line_height, text_shaping, style |
| `ComboBox` | SUPPORTED | Real combo_box with State<String>, free-text input, on_input, padding, size, font, line_height, menu_height |
| `MouseArea` | SUPPORTED | on_press, on_release, on_middle_press events |
| `Sensor` | SUPPORTED | on_show, on_resize (with dimensions), on_hide |
| `PaneGrid` | SUPPORTED | Stateful; spacing, on_click, on_resize, on_drag; title bars |

### Display Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Text` | SUPPORTED | size, color, font, width, height, line_height, align_x, align_y, wrapping, named styles (primary/secondary/success/danger/warning) |
| `Rich` (rich text) | SUPPORTED | `rich_text` -- styled spans with size, color, font, inline links, on_link_click |
| `Rule` | SUPPORTED | horizontal and vertical, thickness, named styles (default/weak) |
| `ProgressBar` | SUPPORTED | range, value, length (width), girth (height), named styles |
| `Tooltip` | SUPPORTED | position, gap, padding, snap_within_viewport, named styles |
| `Image` | SUPPORTED | All props: source, width, height, content_fit, rotation, opacity, border_radius, filter_method, expand, scale, crop |
| `Svg` | SUPPORTED | source, width, height, content_fit, rotation, opacity |
| `Canvas` | SUPPORTED | Interactive via Program trait; on_press, on_release, on_move, on_scroll; background; shapes (rect, circle, line, text) |
| `Markdown` | SUPPORTED | Settings: text_size, h1_size, h2_size, h3_size, code_size, spacing; width via container wrapper |
| `Table` | SUPPORTED | Composite implementation; columns, rows, header (conditional), separator, padding |
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
| `id` | **MISSING** | Container ID for widget ops not exposed |
| `center_x` / `center_y` | **MISSING** | Separate axis centering (use center + align_x/y instead) |
| `align_left/right/top/bottom` | **MISSING** | Use align_x/align_y strings instead |

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
| `on_scroll` | **DEFERRED** | Requires custom event middleware for scroll position callbacks |
| `auto_scroll` | **MISSING** | |
| `style` | **MISSING** | |

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
| `shaping` | **MISSING** | Not on text widget (available on checkbox, radio, etc.) |

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
| `on_paste` | **MISSING** | |
| `icon` | **MISSING** | |

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
| `highlight` | **MISSING** | |
| `key_binding` | **MISSING** | |

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
| `icon` | **MISSING** | |

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
| `text_alignment` | **MISSING** | |

### Slider

| iced Prop | Status | Notes |
|---|---|---|
| `range` / `value` / `step` / `width` | SUPPORTED | |
| `on_release` | SUPPORTED | |
| `default` | SUPPORTED | Double-click reset value |
| `height` | SUPPORTED | |
| `shift_step` | SUPPORTED | |
| `style` | SUPPORTED | |
| `with_circular_handle` | **MISSING** | |

### VerticalSlider

Same as Slider. Missing: `with_circular_handle`.

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
| `handle` | **MISSING** | |
| `on_open` / `on_close` | **BLOCKED** | Not exposed by iced 0.14 API |

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
| `on_option_hovered` | **MISSING** | |
| `on_open` / `on_close` | **BLOCKED** | Not exposed by iced 0.14 API |
| `icon` | **MISSING** | |

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
| `source` / `width` / `height` / `content_fit` | SUPPORTED | |
| `rotation` | SUPPORTED | |
| `opacity` | SUPPORTED | |
| `border_radius` | SUPPORTED | |
| `filter_method` | SUPPORTED | "nearest" or "linear" |
| `expand` | SUPPORTED | |
| `scale` | SUPPORTED | |
| `crop` | SUPPORTED | {x, y, width, height} object |

### Svg

| iced Prop | Status | Notes |
|---|---|---|
| `source` / `width` / `height` / `content_fit` | SUPPORTED | |
| `rotation` | SUPPORTED | |
| `opacity` | SUPPORTED | |
| `style` | **MISSING** | |

### ProgressBar

| iced Prop | Status | Notes |
|---|---|---|
| `range` / `value` | SUPPORTED | |
| `width` (length) / `height` (girth) | SUPPORTED | |
| `style` | SUPPORTED | primary, secondary, success, danger, warning |
| `vertical()` | **MISSING** | |

### Rule

| iced Prop | Status | Notes |
|---|---|---|
| `horizontal(height)` | SUPPORTED | |
| `vertical(width)` | SUPPORTED | |
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
| `shapes` | SUPPORTED | rect, circle, line, text |
| `background` | SUPPORTED | Fill color |
| Full `Program` trait | SUPPORTED | Interactive canvas via `CanvasProgram` impl |
| `on_press` / `on_release` / `on_move` / `on_scroll` | SUPPORTED | Individual or via `interactive: true` |

### Table

| iced Prop | Status | Notes |
|---|---|---|
| `columns` / `rows` | SUPPORTED | |
| `width` | SUPPORTED | |
| `header` | SUPPORTED | Conditional via boolean prop |
| `separator` | SUPPORTED | Conditional via boolean prop |
| `padding` | SUPPORTED | |
| `sortable` | **MISSING** | No sort handling |
| Column `align_x` / `align_y` | **MISSING** | |

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
| Runtime `font::load` | Via settings/0 | **PARTIAL** | App-level font loading via settings callback |

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
| Palette field: `warning` | N/A | iced's Palette has no warning field; removed from Julep |
| `base` field for custom themes | Yes | SUPPORTED |
| Per-widget style functions | Yes | SUPPORTED -- button, container, text, checkbox, progress_bar, rule, etc. have named styles |
| `Themer` widget (per-subtree theme) | Yes | SUPPORTED |
| Extended palette generation | No | **MISSING** -- iced auto-generates extended palettes |
| `theme::Mode` (Light/Dark/None) | No | **MISSING** |

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
| `set_icon(id, icon)` | No | **UNSUPPORTED** -- requires RGBA pixel data impractical over JSONL |
| `scale_factor(id)` | `get_scale_factor(id, tag)` | SUPPORTED |
| `mode(id)` | `get_mode(id, tag)` | SUPPORTED |
| `raw_id(id)` | `raw_id(id, tag)` | SUPPORTED |
| `monitor_size(id)` | `monitor_size(id, tag)` | SUPPORTED |

### Window Settings

| iced Setting | Julep | Status |
|---|---|---|
| `size` | Via `window_config` | SUPPORTED |
| `title` | Via `window` node | SUPPORTED |
| `maximized` | No | **MISSING** |
| `fullscreen` | No | **MISSING** |
| `position` (Default, Centered, Specific) | No | **MISSING** |
| `min_size` / `max_size` | No | **MISSING** |
| `visible` | No | **MISSING** |
| `resizable` | No | **MISSING** |
| `closeable` | No | **MISSING** |
| `minimizable` | No | **MISSING** |
| `decorations` | No | **MISSING** |
| `transparent` | No | **MISSING** |
| `blur` | No | **MISSING** |
| `level` | No | **MISSING** |
| `icon` | No | **MISSING** |
| `exit_on_close_request` | No | **MISSING** |

---

## 8. Events

### Keyboard Events

| iced Event | Julep | Status |
|---|---|---|
| `KeyPressed` | `{:key_press, key, modifiers}` | SUPPORTED |
| `KeyReleased` | `{:key_release, key, modifiers}` | SUPPORTED |
| `ModifiersChanged` | `{:modifiers_changed, modifiers}` | SUPPORTED |
| `key::Named` variants | ~200 mapped | SUPPORTED -- comprehensive named key map |
| `key::Character` | Characters pass through | SUPPORTED |
| `physical_key` / `location` | No | **MISSING** |
| `text` field | No | **MISSING** |
| `repeat` field | No | **MISSING** |
| `modified_key` | No | **MISSING** |

### Keyboard Modifiers

| iced Modifier | Julep | Status |
|---|---|---|
| `SHIFT` | `shift` | SUPPORTED |
| `CTRL` | `ctrl` | SUPPORTED |
| `ALT` | `alt` | SUPPORTED |
| `LOGO` | `logo` | SUPPORTED |
| `COMMAND` (platform) | `command` | SUPPORTED |

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
| `clipboard::read_primary()` | No | **MISSING** |
| `clipboard::write_primary(text)` | No | **MISSING** |

---

## 10. Application-Level Settings

| iced Setting | Julep | Status |
|---|---|---|
| `default_font` | Via `settings/0` callback | SUPPORTED |
| `default_text_size` | Via `settings/0` callback | SUPPORTED |
| `fonts` (custom font loading) | Via `settings/0` callback | SUPPORTED |
| `antialiasing` | Via `settings/0` callback | SUPPORTED |
| `subscription` callback | Via `subscribe/1` | SUPPORTED |
| `vsync` | No | **MISSING** |
| `scale_factor` callback | No | **MISSING** |
| `title` callback | Via `window` node title prop | SUPPORTED (different model) |
| `theme` callback | Via `window_config` or `themer` widget | SUPPORTED (different model) |

---

## 11. Summary Statistics

### Widgets
- iced widgets (with enabled features): ~28 distinct widgets
- Julep supported: 28 (plus `window` and `table` not in iced)
- Missing: none
- All widgets fully implemented in both Elixir and Rust layers

### Props
- Average prop coverage per supported widget: ~85-95%
- Most common remaining gaps:
  - Widget-specific icons
  - `on_open`/`on_close` for pick_list/combo_box (BLOCKED by iced 0.14)
  - `on_scroll` for scrollable (DEFERRED -- requires custom event middleware)
  - Some style props (scrollable style, svg style)

### Events
- Keyboard: SUPPORTED (all key families, comprehensive named key map, modifiers)
- Mouse: SUPPORTED (cursor move, enter/leave, buttons, wheel scroll)
- Touch: SUPPORTED (finger press/move/lift/lost)
- Window lifecycle: SUPPORTED (open, close, close_requested, move, resize, focus, file drop)
- Canvas: SUPPORTED (press, release, move, scroll)
- PaneGrid: SUPPORTED (resize, drag, click)

### Commands
- Full set covered: focus, scroll, snap, cursor ops, select, async, batch, done, exit
- Window operations: comprehensive (resize, move, maximize, minimize, decorations, drag, etc.)
- PaneGrid operations: split, close, swap, maximize, restore
- Task chaining handled by Elm update loop (by design); streaming via `Command.stream/2`; cancellation via `Command.cancel/1`

### Window Operations
- Declarative open (via tree) and close supported
- Full imperative window management: resize, move, maximize, minimize, mode, decorations, focus, drag, screenshots, etc.
- Missing: set_icon (intentionally unsupported -- RGBA pixel data impractical over JSONL)

---

## 12. Remaining Gaps (Prioritized)

### Medium Priority (Power User Features)

1. **Window initial settings** -- maximized, fullscreen, position, min/max size, decorations, transparent, etc. at window creation time
2. **`on_scroll` callback for Scrollable** -- DEFERRED; requires custom event middleware for scroll position tracking
3. **`on_open`/`on_close` for pick_list/combo_box** -- BLOCKED by iced 0.14; not exposed in the API
4. **Primary clipboard** -- Linux middle-click paste

### Low Priority (Nice-to-Have)

5. **`set_icon`** -- requires RGBA pixel data; intentionally unsupported
6. **Widget icons** -- icon prop for text_input, checkbox
7. **`on_paste` for TextInput** -- paste event callback
8. **`vsync` setting** -- vsync control
9. **Extended palette generation** -- full iced extended palette support
10. **`theme::Mode`** -- light/dark/none mode enum
