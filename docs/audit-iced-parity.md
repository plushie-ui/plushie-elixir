# iced 0.14 Parity Audit

Comprehensive comparison of iced 0.14.0 (with features: `tokio`, `image`,
`svg`, `markdown`, `canvas`) against what Julep exposes to Elixir.

Audited: 2026-02-26

---

## Legend

- **SUPPORTED** -- Julep exposes this and the renderer handles it
- **PARTIAL** -- Julep exposes some of it, or there are encoding/decoding bugs
- **MISSING** -- iced supports it, Julep does not expose it
- **N/A** -- Not applicable (feature not enabled, or internal-only)
- **BUG** -- Encoding mismatch between Elixir and Rust sides

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
| `Scrollable` | SUPPORTED | `scrollable` in both layers |
| `Grid` | **MISSING** | iced has `Grid` with `.columns()`, `.fluid()`, `.spacing()` -- no equivalent |
| `Pin` | **MISSING** | Absolute positioning widget with `.position()`, `.x()`, `.y()` |
| `Float` | **MISSING** | Floating overlay with scale/translate |
| `Responsive` | **MISSING** | Size-aware responsive layout |
| `Keyed::Column` | **MISSING** | Keyed column for efficient diffing |

### Interactive Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Button` | SUPPORTED | |
| `TextInput` | SUPPORTED | |
| `TextEditor` | SUPPORTED | |
| `Checkbox` | SUPPORTED | |
| `Radio` | SUPPORTED | |
| `Toggler` | SUPPORTED | |
| `Slider` | SUPPORTED | |
| `VerticalSlider` | SUPPORTED | |
| `PickList` | SUPPORTED | |
| `ComboBox` | **PARTIAL** | Renderer delegates to `render_pick_list` -- no free-text input, no `State<T>` |
| `MouseArea` | **MISSING** | Rich mouse event handling (press, release, double-click, right-click, hover, scroll) |
| `Sensor` | **MISSING** | Visibility/resize detection |
| `PaneGrid` | **MISSING** | Draggable, resizable pane layout with splits |

### Display Widgets

| iced Widget | Julep Status | Notes |
|---|---|---|
| `Text` | SUPPORTED | |
| `Rich` (rich text) | **MISSING** | Styled spans, inline links, `on_link_click` |
| `Rule` | SUPPORTED | |
| `ProgressBar` | SUPPORTED | |
| `Tooltip` | SUPPORTED | |
| `Image` | SUPPORTED | |
| `Svg` | SUPPORTED | |
| `Canvas` | SUPPORTED | Custom shape drawing |
| `Markdown` | SUPPORTED | |
| `Table` | SUPPORTED | Basic implementation |
| `QRCode` | N/A | Feature `qr_code` not enabled |
| `Shader` | N/A | Feature `wgpu` not enabled |

### Julep-Only Composites (not in iced)

These are higher-level widgets Julep composes from iced primitives:

| Widget | Notes |
|---|---|
| `window` | Multi-window container |
| `tabs` | Tab switching |
| `nav` | Navigation sidebar |
| `modal` | Modal overlay |
| `card` | Card container |
| `panel` | Collapsible panel |
| `form` | Form layout |
| `split_pane` | Split layout |

### Other iced Utilities Not Exposed

| iced Item | Notes |
|---|---|
| `Themer` | Per-subtree theme override |
| `opaque` | Overlay helper |
| `hover` | Overlay helper |

---

## 2. Per-Widget Prop Gaps

For each supported widget, props that iced offers but Julep doesn't expose.

### Column

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `spacing` | Yes | Yes | SUPPORTED |
| `padding` | Yes | Yes | **BUG** (see encoding issues) |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `align_x` | Yes | Yes | SUPPORTED |
| `max_width` | No | No | **MISSING** |
| `clip` | No | No | **MISSING** |
| `wrap()` (flex-wrap) | No | No | **MISSING** |

### Row

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `spacing` | Yes | Yes | SUPPORTED |
| `padding` | Yes | Yes | **BUG** |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `align_y` | Yes | Yes | SUPPORTED |
| `max_width` | No | No | **MISSING** |
| `clip` | No | No | **MISSING** |
| `wrap()` (flex-wrap) | No | No | **MISSING** |

### Container

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `padding` | Yes | Yes | **BUG** |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `center` | Yes | Yes | SUPPORTED |
| `id` | No | No | **MISSING** |
| `max_width` | No | No | **MISSING** |
| `max_height` | No | No | **MISSING** |
| `center_x` / `center_y` | No | No | **MISSING** (iced has separate axis centering) |
| `align_left/right/top/bottom` | No | No | **MISSING** |
| `align_x` / `align_y` | No | No | **MISSING** |
| `clip` | No | No | **MISSING** |
| `style` | Elixir-side only | No | **BUG** -- prop accepted but renderer ignores |
| `color` | No | No | **MISSING** |
| `border` | No | No | **MISSING** |
| `background` | No | No | **MISSING** |
| `shadow` | No | No | **MISSING** |

### Stack

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `clip` | No | No | **MISSING** |

### Scrollable

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `direction` | Elixir-side only | No | **BUG** -- prop accepted but not handled |
| `horizontal()` | No | No | **MISSING** |
| `id` | No | No | **MISSING** |
| `on_scroll` | No | No | **MISSING** |
| `anchor_top/bottom/left/right` | No | No | **MISSING** |
| `spacing` | No | No | **MISSING** |
| `auto_scroll` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |
| Scrollbar config (width, margin, scroller_width) | No | No | **MISSING** |

### Button

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `label`/`content` | Yes | Yes | SUPPORTED |
| `width` | Yes | No | **BUG** -- Elixir accepts, renderer ignores |
| `height` | Yes | No | **BUG** -- Elixir accepts, renderer ignores |
| `padding` | No | No | **MISSING** |
| `on_press_maybe` | No | No | **MISSING** (disabled state) |
| `clip` | No | No | **MISSING** |
| `style` | Elixir-side only | No | **BUG** -- prop accepted but not rendered |
| Children as content | No | No | **MISSING** -- iced buttons can contain arbitrary widgets |

### Text

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `content` | Yes | Yes | SUPPORTED |
| `size` | Yes | Yes | SUPPORTED |
| `color` | Elixir-side only | No | **BUG** -- prop accepted but not rendered |
| `font` | Elixir-side only | No | **BUG** -- prop accepted but not rendered |
| `width` | No | No | **MISSING** |
| `height` | No | No | **MISSING** |
| `line_height` | No | No | **MISSING** |
| `center` / `align_x` / `align_y` | No | No | **MISSING** |
| `shaping` | No | No | **MISSING** |
| `wrapping` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### TextInput

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `value` | Yes | Yes | SUPPORTED |
| `placeholder` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `size` | Yes | Yes | SUPPORTED |
| `padding` | Yes | Yes | SUPPORTED |
| `on_submit` | Yes | Yes | SUPPORTED |
| `id` | No | No | **MISSING** |
| `secure` | No | No | **MISSING** (password fields) |
| `on_paste` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `icon` | No | No | **MISSING** |
| `line_height` | No | No | **MISSING** |
| `align_x` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### TextEditor

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `content` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `placeholder` | Yes | Yes | SUPPORTED |
| `id` | No | No | **MISSING** |
| `width` | Elixir-side only | No | **BUG** -- renderer uses fixed Pixels type |
| `min_height` | No | No | **MISSING** |
| `max_height` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `size` | No | No | **MISSING** |
| `line_height` | No | No | **MISSING** |
| `padding` | No | No | **MISSING** |
| `wrapping` | No | No | **MISSING** |
| `highlight` | No | No | **MISSING** |
| `key_binding` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Checkbox

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `is_checked` | Yes | Yes | SUPPORTED |
| `label` | Yes | Yes | SUPPORTED |
| `spacing` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `on_toggle_maybe` | No | No | **MISSING** (disabled state) |
| `size` | No | No | **MISSING** |
| `text_size` | No | No | **MISSING** |
| `text_line_height` | No | No | **MISSING** |
| `text_shaping` | No | No | **MISSING** |
| `text_wrapping` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `icon` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Radio

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `value` | Yes | Yes | SUPPORTED |
| `selected` | Yes | Yes | SUPPORTED |
| `label` | Yes | Yes | SUPPORTED |
| `group` | Yes | Yes | SUPPORTED (julep-specific) |
| `spacing` | Elixir-side only | No | **BUG** |
| `width` | Elixir-side only | No | **BUG** |
| `size` | No | No | **MISSING** |
| `text_size` | No | No | **MISSING** |
| `text_line_height` | No | No | **MISSING** |
| `text_shaping` | No | No | **MISSING** |
| `text_wrapping` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Toggler

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `is_toggled` | Yes | Yes | SUPPORTED |
| `label` | Yes | Yes | SUPPORTED |
| `spacing` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `on_toggle_maybe` | No | No | **MISSING** (disabled state) |
| `size` | No | No | **MISSING** |
| `text_size` | No | No | **MISSING** |
| `text_line_height` | No | No | **MISSING** |
| `text_alignment` | No | No | **MISSING** |
| `text_shaping` | No | No | **MISSING** |
| `text_wrapping` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Slider

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `range` | Yes | Yes | SUPPORTED |
| `value` | Yes | Yes | SUPPORTED |
| `step` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `on_release` | Yes | Yes | SUPPORTED (as `slide_release` event) |
| `default` | No | No | **MISSING** (double-click reset value) |
| `height` | No | No | **MISSING** |
| `shift_step` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |
| `with_circular_handle` | No | No | **MISSING** |

### VerticalSlider

Same gaps as Slider.

### PickList

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `options` | Yes | Yes | SUPPORTED |
| `selected` | Yes | Yes | SUPPORTED |
| `placeholder` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `menu_height` | No | No | **MISSING** |
| `padding` | No | No | **MISSING** |
| `text_size` | No | No | **MISSING** |
| `text_line_height` | No | No | **MISSING** |
| `text_shaping` | No | No | **MISSING** |
| `font` | No | No | **MISSING** |
| `handle` | No | No | **MISSING** |
| `on_open` / `on_close` | No | No | **MISSING** |
| `style` / `menu_style` | No | No | **MISSING** |

### ComboBox

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| Full ComboBox behavior | No | No | **BUG** -- delegates to pick_list, no free-text |
| `State<T>` management | No | No | **MISSING** |
| `on_input` | No | No | **MISSING** |
| `on_option_hovered` | No | No | **MISSING** |
| `on_open` / `on_close` | No | No | **MISSING** |
| `padding` | No | No | **MISSING** |
| `font` / `icon` | No | No | **MISSING** |
| `size` / `line_height` | No | No | **MISSING** |

### Tooltip

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `tip_text` / `tip` | **BUG** | Yes | `Iced` layer emits `tip_text`, renderer reads `tip` |
| `position` | Yes | Yes | SUPPORTED |
| `gap` | Yes | Yes | SUPPORTED |
| `padding` | No | No | **MISSING** |
| `delay` | No | No | **MISSING** |
| `snap_within_viewport` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Image

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `source` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `content_fit` | Yes | Yes | SUPPORTED |
| `expand` | No | No | **MISSING** |
| `filter_method` | No | No | **MISSING** |
| `rotation` | No | No | **MISSING** |
| `opacity` | No | No | **MISSING** |
| `scale` | No | No | **MISSING** |
| `crop` | No | No | **MISSING** |
| `border_radius` | No | No | **MISSING** |

### Svg

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `source` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `content_fit` | Yes | Yes | SUPPORTED |
| `rotation` | No | No | **MISSING** |
| `opacity` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### ProgressBar

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `range` | Yes | Yes | SUPPORTED |
| `value` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `vertical()` | No | No | **MISSING** |
| `girth` | No | No | **MISSING** |
| `style` | No | No | **MISSING** |

### Rule

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `horizontal(height)` | Yes | Yes | SUPPORTED |
| `vertical(width)` | Elixir-side only | No | **BUG** -- renderer always renders horizontal |
| `style` | No | No | **MISSING** |

### Markdown

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `content` | Yes | Yes | SUPPORTED |
| `width` | Elixir-side only | No | **BUG** -- renderer doesn't read width |
| `Settings` (text_size, style) | No | No | **MISSING** |
| `Highlighter` | No | No | **MISSING** |

### Canvas

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `width` | Yes | Yes | SUPPORTED |
| `height` | Yes | Yes | SUPPORTED |
| `shapes` | Yes | Yes | SUPPORTED (rect, circle, line, text) |
| `background` | Elixir-side only | No | **BUG** -- renderer doesn't read it |
| Full `Program` trait | No | No | **MISSING** -- iced canvas uses a `Program` trait for interactive drawing |

### Table

| iced Prop | Julep | Renderer | Status |
|---|---|---|---|
| `columns` | Yes | Yes | SUPPORTED |
| `rows` | Yes | Yes | SUPPORTED |
| `width` | Yes | Yes | SUPPORTED |
| `header` | Elixir-side only | No | **BUG** -- renderer always renders headers |
| `sortable` | Elixir-side only | No | **BUG** -- renderer has no sort handling |
| `padding` / `padding_x` / `padding_y` | No | No | **MISSING** |
| `separator` / `separator_x` / `separator_y` | No | No | **MISSING** |
| Column `align_x` / `align_y` | No | No | **MISSING** |

---

## 3. Core Types

### Length

| iced Variant | Julep | Renderer | Status |
|---|---|---|---|
| `Fill` | `:fill` | `"fill"` | SUPPORTED |
| `Shrink` | `:shrink` | `"shrink"` | SUPPORTED |
| `Fixed(f32)` | number | number | SUPPORTED |
| `FillPortion(u16)` | `{:fill_portion, n}` | -- | **BUG** -- Elixir encodes `%{"fill_portion" => n}`, renderer only handles Number and String |

### Padding

| iced Form | Julep | Renderer | Status |
|---|---|---|---|
| Uniform `f32` | number | `padding` key | SUPPORTED |
| `[vert, horiz]` | `{v, h}` tuple | -- | **BUG** -- Elixir encodes `%{top: v, ...}` map, renderer reads `padding_top` etc. |
| Per-side struct | `%{top, right, bottom, left}` | `padding_top` etc. | **BUG** -- key name mismatch |

### Alignment

| iced Variant | Julep | Renderer | Status |
|---|---|---|---|
| `Start` / `Left` / `Top` | `:start` | `"start"` / `"left"` / `"top"` | SUPPORTED |
| `Center` | `:center` | `"center"` | SUPPORTED |
| `End` / `Right` / `Bottom` | `:end` | `"end"` / `"right"` / `"bottom"` | SUPPORTED |

### Font

| iced Feature | Julep | Renderer | Status |
|---|---|---|---|
| `:default` / `:monospace` | Yes | No | **BUG** -- Elixir encodes but renderer doesn't read font prop on text |
| Named family | Yes | No | **BUG** |
| Weight variants | Yes (9 weights) | No | **BUG** |
| Style (normal/italic/oblique) | Yes | No | **BUG** |
| `Stretch` (9 variants) | No | No | **MISSING** |
| Runtime `font::load` | No | No | **MISSING** |

### Color

| iced Feature | Julep | Status |
|---|---|---|
| `Color` struct (r,g,b,a) | Hex strings only | **PARTIAL** -- only hex color support via theming |
| `from_rgb8` / `from_rgba8` | No | **MISSING** |
| Named constants (BLACK, WHITE, TRANSPARENT) | No | **MISSING** |
| Gradient backgrounds | No | **MISSING** |

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
| Border struct (color, width, radius) | No | **MISSING** |
| Per-corner radius | No | **MISSING** |

### Shadow

| iced Feature | Julep | Status |
|---|---|---|
| Shadow struct (color, offset, blur_radius) | No | **MISSING** |

---

## 4. Theme

| iced Feature | Julep | Status |
|---|---|---|
| 22 built-in themes | Yes (all 22) | SUPPORTED |
| `custom(name, palette)` | Yes | SUPPORTED |
| Palette fields: background, text, primary, success, danger | Yes | SUPPORTED |
| Palette field: `warning` | No | **MISSING** |
| Extended palette generation | No | **MISSING** |
| Per-widget style functions | No | **MISSING** -- iced has `primary`, `secondary`, `success`, `warning`, `danger`, `text` etc. per widget |
| `Themer` widget (per-subtree theme) | No | **MISSING** |
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
| `window::frames()` | No | **MISSING** -- animation frame subscription |
| `window::open_events()` | No | **MISSING** |
| `window::resize_events()` | No | **MISSING** |
| `event::listen()` | No | **MISSING** -- all runtime events |
| `event::listen_with()` | No | **MISSING** -- filtered events |
| `system::theme_changes()` | No | **MISSING** -- OS theme change subscription |
| `Subscription::batch()` | No | **MISSING** -- combining multiple subscriptions |
| Mouse events subscription | No | **MISSING** -- no mouse event subscriptions at all |
| Touch events subscription | No | **MISSING** -- no touch event subscriptions at all |

---

## 6. Commands / Tasks

| iced Task | Julep Command | Status |
|---|---|---|
| `Task::none()` | `none()` | SUPPORTED |
| `Task::perform(future, map)` | `async(fun, tag)` | SUPPORTED |
| `Task::batch(tasks)` | `batch(commands)` | SUPPORTED |
| `focus(id)` | `focus(widget_id)` | SUPPORTED |
| `focus_next()` | `focus_next()` | SUPPORTED |
| `focus_previous()` | `focus_previous()` | SUPPORTED |
| `select_all(id)` | `select_all(widget_id)` | SUPPORTED |
| `scroll_to(id, offset)` | `scroll_to(widget_id, offset)` | SUPPORTED |
| Custom send_after | `send_after(delay, event)` | SUPPORTED (julep-specific) |
| `window::close(id)` | `close_window(window_id)` | SUPPORTED |
| `Task::done(value)` | No | **MISSING** |
| `Task::run(stream, map)` | No | **MISSING** |
| `Task::future(future)` | No | **MISSING** |
| `Task::stream(stream)` | No | **MISSING** |
| `task::blocking(fn)` | No | **MISSING** |
| `.then()` / `.chain()` | No | **MISSING** -- task chaining |
| `.collect()` | No | **MISSING** |
| `.abortable()` | No | **MISSING** -- task cancellation |
| `iced::exit()` | No | **MISSING** -- graceful app exit |
| `snap_to(id, offset)` | No | **MISSING** -- snap scrollable |
| `snap_to_end(id)` | No | **MISSING** |
| `scroll_by(id, offset)` | No | **MISSING** |
| `text_input::move_cursor_to_front/end/to` | No | **MISSING** |
| `text_input::select_range` | No | **MISSING** |

---

## 7. Window Operations

| iced Window Op | Julep | Status |
|---|---|---|
| `open(Settings)` | Via tree (declarative) | SUPPORTED (different model) |
| `close(id)` | `close_window(id)` | SUPPORTED |
| `resize(id, size)` | No | **MISSING** |
| `move_to(id, point)` | No | **MISSING** |
| `maximize(id, bool)` | No | **MISSING** |
| `minimize(id, bool)` | No | **MISSING** |
| `set_mode(id, mode)` | No | **MISSING** (fullscreen, hidden) |
| `toggle_maximize(id)` | No | **MISSING** |
| `toggle_decorations(id)` | No | **MISSING** |
| `gain_focus(id)` | No | **MISSING** |
| `set_level(id, level)` | No | **MISSING** (always-on-top etc.) |
| `drag(id)` | No | **MISSING** |
| `drag_resize(id, dir)` | No | **MISSING** |
| `request_user_attention` | No | **MISSING** |
| `set_icon(id, icon)` | No | **MISSING** |
| `screenshot(id)` | No | **MISSING** |
| `set_resizable(id, bool)` | No | **MISSING** |
| `set_min_size` / `set_max_size` | No | **MISSING** |
| `enable/disable_mouse_passthrough` | No | **MISSING** |
| `show_system_menu(id)` | No | **MISSING** |
| `size(id)` / `position(id)` queries | No | **MISSING** |
| `is_maximized(id)` / `is_minimized(id)` | No | **MISSING** |
| `scale_factor(id)` | No | **MISSING** |
| `mode(id)` | No | **MISSING** |
| `raw_id(id)` | No | **MISSING** |
| `monitor_size(id)` | No | **MISSING** |

### Window Settings

| iced Setting | Julep | Status |
|---|---|---|
| `size` | Via `window_config` | PARTIAL |
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
| `KeyPressed` | `{:key_press, key, modifiers}` | **BUG** -- protocol family mismatch (see below) |
| `KeyReleased` | Subscription exists, no decoder | **BUG** -- no `key_release` handler in decoder |
| `ModifiersChanged` | No | **MISSING** |
| `key::Named` variants (200+) | 20 mapped | **PARTIAL** -- only common keys mapped |
| `key::Character` | Single chars pass through | SUPPORTED |
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
| `CursorMoved` | No | **MISSING** |
| `ButtonPressed` | No | **MISSING** |
| `ButtonReleased` | No | **MISSING** |
| `WheelScrolled` | No | **MISSING** |
| `CursorEntered` / `CursorLeft` | No | **MISSING** |
| All `mouse::Button` variants | No | **MISSING** |
| `ScrollDelta` (Lines/Pixels) | No | **MISSING** |

### Touch Events

| iced Event | Julep | Status |
|---|---|---|
| `FingerPressed` | No | **MISSING** |
| `FingerMoved` | No | **MISSING** |
| `FingerLifted` | No | **MISSING** |
| `FingerLost` | No | **MISSING** |

### Window Events

| iced Event | Julep | Status |
|---|---|---|
| `CloseRequested` | `on_window_close` sub | SUPPORTED |
| `Opened` | No | **MISSING** |
| `Closed` | No | **MISSING** |
| `Moved` | No | **MISSING** |
| `Resized` | No | **MISSING** |
| `Rescaled` | No | **MISSING** |
| `Focused` / `Unfocused` | No | **MISSING** |
| `FileHovered` / `FileDropped` / `FilesHoveredLeft` | No | **MISSING** |

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
| `default_font` | No | **MISSING** |
| `default_text_size` | No | **MISSING** |
| `fonts` (custom font loading) | No | **MISSING** |
| `antialiasing` | No | **MISSING** |
| `vsync` | No | **MISSING** |
| `scale_factor` callback | No | **MISSING** |
| `title` callback | No | **MISSING** (per-window title from Elixir) |
| `theme` callback | No | **MISSING** (dynamic theme from Elixir) |
| `subscription` callback | Via `subscribe/1` | SUPPORTED |

---

## 11. Protocol Bugs (Elixir <-> Rust Mismatches)

These are cases where Julep's Elixir side and Rust side disagree on the
wire format, meaning the feature is broken even though both sides have code.

### P1: Padding Encoding

**Elixir** (`Julep.Iced.Padding.encode/1`): Produces `%{"top" => n, "right" => n, "bottom" => n, "left" => n}`.

**Rust** (`widgets.rs`): Reads `padding` (uniform), `padding_top`, `padding_right`, `padding_bottom`, `padding_left` (prefixed keys).

The four-side map from Elixir will be set as the `padding` prop value (a JSON object), but the renderer tries to read `padding` as a number. Per-side keys would need to be `padding_top` etc., not nested inside a map. Uniform padding (a single number) works; per-side does not.

### P2: FillPortion Length

**Elixir** (`Julep.Iced.Length.encode/1`): `{:fill_portion, 3}` -> `%{"fill_portion" => 3}`.

**Rust** (`value_to_length`): Only handles `Number` and `String` JSON values. A JSON object is not matched.

### P3: Key Event Family

**Elixir** (`Julep.Protocol.decode_message/1`): Expects `"family": "key"` with `"key"` field.

**Rust** (`OutgoingEvent`): Emits `"family": "key_press"` / `"family": "key_release"` with key in `"value"` field.

### P4: Key Release Decoding

**Elixir**: No handler for `key_release` family. Subscription `on_key_release` exists but decoded events would be dropped.

### P5: Window Event Family

**Elixir**: Expects `"family": "window"` with `"action"` and `"window_id"` fields.

**Rust**: Emits `"family": "window_close"` with `"tag"` field.

### P6: Tooltip Prop Name

**Elixir** (`Julep.Iced.tooltip/4`): Sets prop `tip_text`.

**Rust** (`render_tooltip`): Reads prop `tip`.

The `Julep.UI` layer correctly passes `tip` -- only the strict parity layer is broken.

---

## 12. Summary Statistics

### Widgets
- iced widgets (with enabled features): ~28 distinct widgets
- Julep supported: 21 (plus 7 composites not in iced)
- Missing: Grid, Pin, Float, Responsive, MouseArea, Sensor, PaneGrid, Rich, Keyed::Column
- Broken: ComboBox (delegates to PickList)

### Props
- Average prop coverage per supported widget: ~40-60%
- Most common missing prop categories:
  - `style` / visual customization (missing on nearly every widget)
  - `font` / text configuration (missing where applicable)
  - `max_width` / `max_height` constraints
  - `clip` on layout containers
  - `id` for widget operations

### Events
- Keyboard: PARTIAL (protocol bugs, limited key mapping)
- Mouse: MISSING entirely
- Touch: MISSING entirely
- Window lifecycle: MISSING (only close request supported)

### Commands
- Basic set covered (focus, scroll, async, batch)
- Missing: task chaining, cancellation, exit, cursor ops, scroll_by/snap_to

### Window Operations
- Only open (declarative) and close supported
- Missing: resize, move, maximize, minimize, fullscreen, decorations, focus, drag, etc.

---

## 13. Prioritized Gaps

### Critical (Broken Features)

1. **P1-P5: Protocol mismatches** -- Keyboard events, window events, per-side padding, and fill_portion are encoded but silently broken
2. **P6: Tooltip prop name** -- `Julep.Iced` layer produces wrong key
3. **ComboBox** -- Renders as PickList, not a real combo box

### High Priority (Common Use Cases)

4. **`style` props on all widgets** -- No visual customization possible beyond themes
5. **`font` prop on Text** -- Can't change text font/weight/style
6. **`color` prop on Text** -- Can't color individual text elements
7. **Button children** -- iced buttons can contain arbitrary widgets, not just labels
8. **`secure` on TextInput** -- No password fields
9. **Disabled states** -- `on_press_maybe`, `on_toggle_maybe` etc. for disabled widgets
10. **`max_width` / `max_height`** -- Important layout constraints
11. **Mouse events** -- No hover, click position, scroll delta, right-click
12. **Window resize/move/maximize** -- Basic window management
13. **`warning` palette color** -- Missing from custom themes
14. **Grid widget** -- Common layout need

### Medium Priority (Power User Features)

15. **PaneGrid** -- Resizable split panes (iced's most complex widget)
16. **MouseArea** -- Rich mouse interaction zone
17. **Rich text** -- Styled spans, inline links
18. **Responsive** -- Size-dependent layouts
19. **Window settings** -- min/max size, decorations, resizable, etc.
20. **Scrollable direction/anchoring** -- Horizontal scroll, auto-scroll
21. **Per-widget styling** -- button::primary, button::danger, etc.
22. **Text alignment/wrapping** -- Essential text layout
23. **File drag-and-drop events** -- FileHovered, FileDropped
24. **OS theme change subscription** -- Respond to dark/light mode changes
25. **Animation frames subscription** -- `window::frames()` for smooth animation

### Low Priority (Nice-to-Have)

26. **Pin / Float** -- Absolute positioning, floating overlays
27. **Sensor** -- Visibility detection
28. **Keyed::Column** -- Performance optimization
29. **Primary clipboard** -- Linux middle-click paste
30. **Touch events** -- Mobile/tablet support
31. **Font loading** -- Custom fonts at runtime
32. **App-level settings** -- default_font, default_text_size, antialiasing
33. **Task chaining** -- `.then()`, `.chain()`, `.collect()`
34. **Canvas Program trait** -- Interactive canvas with state
35. **Markdown highlighter/settings** -- Code highlighting, text size
