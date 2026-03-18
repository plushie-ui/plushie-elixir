# Iced parity guide

Julep mirrors iced's API as closely as Elixir allows. If you know iced, you
know julep. This doc maps iced Rust code to its julep Elixir equivalent.

## Module structure

| Iced (Rust) | Julep (Elixir) |
|---|---|
| `iced::widget::*` | `Julep.Iced.Widget.*` (typed structs with builders) |
| -- | `Julep.Iced` (untyped convenience facade, produces raw node maps) |
| -- | `Julep.UI` (ergonomic layer, `do` blocks and keyword props) |
| `iced::Length` | `Julep.Iced.Length` |
| `iced::Padding` | `Julep.Iced.Padding` |
| `iced::alignment` | `Julep.Iced.Alignment` |
| `iced::Theme` | `Julep.Iced.Theme` |
| `iced::Font` | `Julep.Iced.Font` |
| `iced::Color` | `Julep.Iced.Color` |
| `iced::Shadow` | `Julep.Iced.Shadow` |
| `iced::text::Wrapping` | `Julep.Iced.Wrapping` |
| `iced::text::Shaping` | `Julep.Iced.Shaping` |
| `iced::ContentFit` | `Julep.Iced.ContentFit` |
| `iced::widget::scrollable::Direction` | `Julep.Iced.Direction` |
| `iced::widget::tooltip::Position` | `Julep.Iced.Position` |
| `iced::widget::image::FilterMethod` | `Julep.Iced.FilterMethod` |
| `iced::widget::scrollable::Anchor` | `Julep.Iced.Anchor` |
| -- | `Julep.Iced.Encode` (wire-format encoding protocol) |
| `iced::Task` | `Julep.Command` |
| `iced::Subscription` | `Julep.Subscription` |
| `iced::window` | `Julep.Command` (window_open, window_close, resize_window, etc.) |
| `iced::keyboard` | Events delivered as `%Julep.Event.Key{}` / `%Julep.KeyModifiers{}` structs |
| `iced::keyboard::Event` | `Julep.Event.Key` (key, modified_key, physical_key, location, modifiers, text, repeat) |
| `iced::keyboard::Modifiers` | `Julep.KeyModifiers` (ctrl, shift, alt, logo, command; query functions like `ctrl?/1`) |
| -- | `Julep.Features` (feature flag resolution for iced widget features) |

`Julep.Iced.Widget.*` is the typed parity layer. Each widget module matches
an iced widget 1:1 -- same name, same prop vocabulary. If iced calls it
`spacing`, julep calls it `spacing`. Widgets are typed structs with builder
functions and keyword opts, giving you compile-time safety via dialyzer.

`Julep.Iced` is the untyped convenience facade. Each function produces a
raw `ui_node()` map from a props map. Useful for quick prototyping or when
you don't need compile-time type checking.

`Julep.UI` is the ergonomic layer. It produces the same node maps but adds
`do` block syntax, auto-ID generation for anonymous nodes, and keyword-list
conveniences.

## Side-by-side examples

### Basic layout

**Iced (Rust):**
```rust
column![
    text("Hello, world!").size(24),
    row![
        button("Increment").on_press(Message::Increment),
        button("Decrement").on_press(Message::Decrement),
    ].spacing(8),
].spacing(16).padding(20)
```

**Julep.Iced.Widget (typed builders):**
```elixir
alias Julep.Iced.Widget.{Column, Row, Text, Button}

Column.new("main_col", spacing: 16, padding: 20)
|> Column.push(Text.new("greeting", "Hello, world!", size: 24))
|> Column.push(
  Row.new("btn_row", spacing: 8)
  |> Row.push(Button.new("inc", "Increment"))
  |> Row.push(Button.new("dec", "Decrement"))
)
|> Column.build()
```

**Julep.Iced (untyped facade):**
```elixir
Iced.column("main_col", %{spacing: 16, padding: 20}, [
  Iced.text("greeting", %{content: "Hello, world!", size: 24}),
  Iced.row("btn_row", %{spacing: 8}, [
    Iced.button("inc", %{label: "Increment"}),
    Iced.button("dec", %{label: "Decrement"})
  ])
])
```

**Julep.UI (ergonomic):**
```elixir
import Julep.UI

column spacing: 16, padding: 20 do
  text("Hello, world!", size: 24)
  row spacing: 8 do
    button("inc", "Increment")
    button("dec", "Decrement")
  end
end
```

All three produce the same `ui_node()` tree. Use whichever reads best for
your context. The typed builders catch errors at compile time via dialyzer;
the facade and UI layer are quicker to write for simple cases.

### Text input

**Iced:**
```rust
text_input("Enter name...", &self.name)
    .on_input(Message::NameChanged)
    .on_submit(Message::NameSubmitted)
    .padding(8)
    .width(Length::Fill)
```

**Julep.Iced.Widget:**
```elixir
TextInput.new("name_field", model.name,
  placeholder: "Enter name...",
  on_submit: true,
  padding: 8,
  width: :fill
)
```

**Julep.Iced (facade):**
```elixir
Iced.text_input("name_field", %{
  placeholder: "Enter name...",
  value: model.name,
  on_submit: true,
  padding: 8,
  width: :fill
})
```

**Julep.UI:**
```elixir
text_input("name_field", model.name,
  placeholder: "Enter name...",
  on_submit: "name_submitted",
  padding: 8,
  width: :fill
)
```

### Checkbox

**Iced:**
```rust
checkbox("Remember me", self.remember)
    .on_toggle(Message::RememberToggled)
    .spacing(8)
```

**Julep.Iced.Widget:**
```elixir
Checkbox.new("remember", "Remember me", model.remember, spacing: 8)
```

**Julep.Iced (facade):**
```elixir
Iced.checkbox("remember", %{
  label: "Remember me",
  is_toggled: model.remember,
  spacing: 8
})
```

### Slider

**Iced:**
```rust
slider(0..=100, self.volume, Message::VolumeChanged)
    .step(1)
    .width(200)
```

**Julep.Iced.Widget:**
```elixir
Slider.new("volume", {0, 100}, model.volume, step: 1, width: 200)
```

**Julep.Iced (facade):**
```elixir
Iced.slider("volume", %{
  range: {0, 100},
  value: model.volume,
  step: 1,
  width: 200
})
```

### Pick list

**Iced:**
```rust
pick_list(&["Small", "Medium", "Large"][..], self.size.as_deref(), Message::SizeSelected)
    .placeholder("Choose size")
```

**Julep.Iced.Widget:**
```elixir
PickList.new("size_picker", ["Small", "Medium", "Large"],
  selected: model.size,
  placeholder: "Choose size"
)
```

**Julep.Iced (facade):**
```elixir
Iced.pick_list("size_picker", %{
  options: ["Small", "Medium", "Large"],
  selected: model.size,
  placeholder: "Choose size"
})
```

### Container with styling

**Iced:**
```rust
container(content)
    .padding(16)
    .center(Fill)
    .style(container::rounded_box)
```

**Julep.Iced.Widget:**
```elixir
Container.new("wrapper", padding: 16, center: true, style: :rounded_box)
|> Container.push(content)
|> Container.build()
```

**Julep.Iced (facade):**
```elixir
Iced.container("wrapper", %{
  padding: 16,
  center: true,
  style: :rounded_box
}, [content])
```

### Tooltip

**Iced:**
```rust
tooltip(
    button("?").on_press(Message::Help),
    "Click for help",
    tooltip::Position::Top,
)
```

**Julep.Iced.Widget:**
```elixir
Tooltip.new("help_tip", "Click for help", position: :top)
|> Tooltip.push(Button.new("help_btn", "?"))
|> Tooltip.build()
```

**Julep.Iced (facade):**
```elixir
Iced.tooltip("help_tip", %{position: :top}, [
  Iced.button("help_btn", %{label: "?"})
], "Click for help")
```

### Scrollable

**Iced:**
```rust
scrollable(column(items))
    .width(Fill)
    .height(400)
```

**Julep.UI:**
```elixir
scrollable "item_scroll", width: :fill, height: 400 do
  column do
    for item <- items do
      text(item.name, id: "item:#{item.id}")
    end
  end
end
```

## Prop type mapping

| Iced type | Julep Elixir equivalent |
|---|---|
| `Length::Fill` | `:fill` |
| `Length::Shrink` | `:shrink` |
| `Length::FillPortion(2)` | `{:fill_portion, 2}` |
| `Length::Fixed(200.0)` | `200` or `200.0` |
| `Padding::new(10)` | `10` |
| `Padding { top: 5, right: 10, .. }` | `%{top: 5, right: 10, bottom: 5, left: 10}` |
| `[vertical, horizontal]` | `{10, 20}` (vertical, horizontal) |
| `Alignment::Start` | `:start` |
| `Alignment::Center` | `:center` |
| `Alignment::End` | `:end` |
| `Horizontal::Left` | `:left` |
| `Horizontal::Right` | `:right` |
| `Vertical::Top` | `:top` |
| `Vertical::Bottom` | `:bottom` |
| `Color::from_rgb(r, g, b)` | `Color.from_rgb(255, 128, 0)` returns `"#ff8000"` |
| `Color::from_rgba(r, g, b, a)` | `Color.from_rgba(255, 128, 0, 0.5)` returns `"#ff800080"` |
| Named colors (BLACK, WHITE, etc.) | `Color.cast(:black)`, `Color.cast(:red)`, etc. |
| `Font::MONOSPACE` | `:monospace` |
| `Font::with_name("Inter")` | `"Inter"` |
| `font::Weight::Bold` | `:bold` |
| `true` / `false` | `true` / `false` |
| `String` | binary |

## Event mapping

In iced, events are enum variants constructed by the framework and matched
in `update`. In julep, events are tuples received by `update/2`:

| Iced pattern | Julep event |
|---|---|
| `Message::ButtonPressed` via `.on_press()` | `%Widget{type: :click, id: id}` |
| `Message::InputChanged(s)` via `.on_input()` | `%Widget{type: :input, id: id, value: val}` |
| `Message::InputSubmitted` via `.on_submit()` | `%Widget{type: :submit, id: id, value: val}` |
| `Message::Toggled(b)` via `.on_toggle()` | `%Widget{type: :toggle, id: id, value: val}` |
| `Message::Selected(v)` via `pick_list`/`combo_box` | `%Widget{type: :select, id: id, value: val}` |
| `Message::SliderChanged(v)` via `.on_change()` | `%Widget{type: :slide, id: id, value: val}` |
| `Message::SliderReleased` via `.on_release()` | `%Widget{type: :slide_release, id: id, value: val}` |
| Key press via subscription | `%Key{type: :press, ...}` |
| Key release via subscription | `%Key{type: :release, ...}` |
| Modifiers changed via subscription | `%Modifiers{shift: bool, ctrl: bool, ...}` |
| Cursor moved via subscription | `%Mouse{type: :moved, x: x, y: y}` |
| Mouse button pressed via subscription | `%Mouse{type: :button_pressed, button: btn}` |
| Mouse button released via subscription | `%Mouse{type: :button_released, button: btn}` |
| Wheel scrolled via subscription | `%Mouse{type: :wheel_scrolled, delta_x: dx, delta_y: dy, unit: u}` |
| Finger pressed via subscription | `%Touch{type: :pressed, finger_id: fid, x: x, y: y}` |
| Window close request | `%Window{type: :close_requested, window_id: wid}` |
| Window opened | `%Window{type: :opened, window_id: wid, position: pos, width: w, height: h}` |
| Window closed | `%Window{type: :closed, window_id: wid}` |
| Window moved | `%Window{type: :moved, window_id: wid, x: x, y: y}` |
| Window resized | `%Window{type: :resized, window_id: wid, width: w, height: h}` |
| Window focused / unfocused | `%Window{type: :focused, window_id: wid}` / `%Window{type: :unfocused, window_id: wid}` |
| File dropped | `%Window{type: :file_dropped, window_id: wid, path: p}` |
| Canvas press | `%Canvas{type: :press, id: id, x: x, y: y, button: btn}` |
| Canvas move | `%Canvas{type: :move, id: id, x: x, y: y}` |
| Scrollable on_scroll | `%Widget{type: :scroll, id: id, data: %{...}}` |
| TextInput on_paste | `%Widget{type: :paste, id: id, value: text}` |
| ComboBox on_option_hovered | `%Widget{type: :option_hovered, id: id, value: val}` |
| Sensor resize | `%Sensor{type: :resize, id: id, width: w, height: h}` |
| PaneGrid click | `%Pane{type: :clicked, id: id, pane: pane}` |
| PaneGrid resize | `%Pane{type: :resized, id: id, split: split, ratio: ratio}` |
| Animation frame | `%System{type: :animation_frame, data: timestamp}` |
| Theme changed | `%System{type: :theme_changed, data: mode}` |
| Timer tick | `%Timer{tag: :tick, timestamp: ts}` |
| IME opened | `%Ime{type: :opened}` |
| IME preedit | `%Ime{type: :preedit, text: text, cursor: cursor}` |
| IME commit | `%Ime{type: :commit, text: text}` |
| IME closed | `%Ime{type: :closed}` |

Custom events are strings. The renderer maps widget interactions to event
tuples using the node's `id` and the interaction type.

## Task / Command mapping

Iced's `Task<Message>` maps to `Julep.Command`:

| Iced | Julep |
|---|---|
| `Task::none()` | (return bare model) |
| `Task::done(value, mapper)` | `Julep.Command.done(value, msg_fn)` |
| `Task::perform(future, map)` | `Julep.Command.async(fun, event_tag)` |
| `Task::batch(tasks)` | `Julep.Command.batch([...])` |
| `text_input::focus(id)` | `Julep.Command.focus(id)` |
| `text_input::select_all(id)` | `Julep.Command.select_all(id)` |
| `text_input::move_cursor_to(id, pos)` | `Julep.Command.move_cursor_to(id, pos)` |
| `text_input::move_cursor_to_end(id)` | `Julep.Command.move_cursor_to_end(id)` |
| `text_input::select_range(id, s, e)` | `Julep.Command.select_range(id, start, end)` |
| `scrollable::snap_to(id, off)` | `Julep.Command.snap_to(id, x, y)` |
| `scrollable::snap_to_end(id)` | `Julep.Command.snap_to_end(id)` |
| `scrollable::scroll_by(id, off)` | `Julep.Command.scroll_by(id, x, y)` |
| `scrollable::scroll_to(id, off)` | `Julep.Command.scroll_to(id, offset)` |
| `widget::focus_next()` | `Julep.Command.focus_next()` |
| `widget::focus_previous()` | `Julep.Command.focus_previous()` |
| `iced::exit()` | `Julep.Command.exit()` |
| `window::open(settings)` | Via tree (declarative window nodes) |
| `window::close(id)` | `Julep.Command.close_window(id)` |
| `window::resize(id, size)` | `Julep.Command.resize_window(id, w, h)` |
| `window::move_to(id, point)` | `Julep.Command.move_window(id, x, y)` |
| `window::maximize(id, bool)` | `Julep.Command.maximize_window(id, bool)` |
| `window::minimize(id, bool)` | `Julep.Command.minimize_window(id, bool)` |
| `window::toggle_maximize(id)` | `Julep.Command.toggle_maximize(id)` |
| `window::toggle_decorations(id)` | `Julep.Command.toggle_decorations(id)` |
| `window::gain_focus(id)` | `Julep.Command.gain_focus(id)` |
| `window::drag(id)` | `Julep.Command.drag_window(id)` |
| `window::screenshot(id)` | `Julep.Command.screenshot(id, tag)` |
| PaneGrid split | `Julep.Command.pane_split(grid_id, pane_id, axis, new_id)` |
| PaneGrid close | `Julep.Command.pane_close(grid_id, pane_id)` |
| PaneGrid swap | `Julep.Command.pane_swap(grid_id, pane_a, pane_b)` |
| PaneGrid maximize | `Julep.Command.pane_maximize(grid_id, pane_id)` |
| PaneGrid restore | `Julep.Command.pane_restore(grid_id)` |
| `window::allow_automatic_tabbing(bool)` | `Julep.Command.allow_automatic_tabbing(bool)` |

See [commands.md](commands.md) for details.

## Subscription mapping

Iced's `Subscription<Message>` maps to `Julep.Subscription`:

| Iced | Julep |
|---|---|
| `Subscription::none()` | `[]` |
| `time::every(Duration)` | `Julep.Subscription.every(ms, tag)` |
| `keyboard::on_key_press(f)` | `Julep.Subscription.on_key_press(tag)` |
| `keyboard::on_key_release(f)` | `Julep.Subscription.on_key_release(tag)` |
| `window::close_requests()` | `Julep.Subscription.on_window_close(tag)` |
| `window::events()` | `Julep.Subscription.on_window_event(tag)` |
| `window::open_events()` | `Julep.Subscription.on_window_open(tag)` |
| `window::resize_events()` | `Julep.Subscription.on_window_resize(tag)` |
| `window::frames()` | `Julep.Subscription.on_animation_frame(tag)` |
| Mouse movement | `Julep.Subscription.on_mouse_move(tag)` |
| Mouse buttons | `Julep.Subscription.on_mouse_button(tag)` |
| Mouse scroll | `Julep.Subscription.on_mouse_scroll(tag)` |
| Touch events | `Julep.Subscription.on_touch(tag)` |
| IME events | `Julep.Subscription.on_ime(tag)` |
| File drop | `Julep.Subscription.on_file_drop(tag)` |
| Theme changes | `Julep.Subscription.on_theme_change(tag)` |
| Catch-all events | `Julep.Subscription.on_event(tag)` |
| `Subscription::batch(subs)` | `Julep.Subscription.batch(list)` or concatenate lists |

See [commands.md](commands.md) for details.

## Theme mapping

| Iced | Julep |
|---|---|
| `Theme::Dark` | `theme: "dark"` |
| `Theme::CatppuccinMocha` | `theme: "catppuccin_mocha"` |
| `Theme::custom(name, palette)` | `theme: %{name: "mine", background: "#1e1e2e", ...}` |

Theme names are snake_case strings matching the iced `Theme` enum variant
names.

## Type system

### Encode protocol

`Julep.Iced.Encode` is a protocol that handles wire-format encoding
automatically. `Build.put_if/3` calls `Encode.encode/1` on every prop value,
so widget `to_node/1` implementations do not need manual transforms for
atoms, tuples, maps, or custom types.

Built-in implementations:

| Elixir type | Wire encoding |
|---|---|
| Atom (non-boolean) | String (`Atom.to_string/1`) |
| `true` / `false` / `nil` | Pass through |
| String / Integer / Float | Pass through |
| Tuple | List (recursive encoding) |
| Map | Map (values recursively encoded) |
| List | List (elements recursively encoded) |
| `Julep.Iced.Shadow` | `%{"color" => hex, "offset" => [x, y], "blur_radius" => n}` |

Custom types can implement `Julep.Iced.Encode` to define their own wire
encoding. The `Any` fallback passes values through unchanged.

### Shared type modules

These modules provide typed representations and wire encoding for iced's
core value types. Each defines a `@type t`, a set of valid atoms, and an
`encode/1` function.

| Module | iced equivalent | Values |
|---|---|---|
| `Julep.Iced.Length` | `iced::Length` | `:fill`, `:shrink`, number, `{:fill_portion, n}` |
| `Julep.Iced.Padding` | `iced::Padding` | number, `{v, h}` tuple, `%{top, right, bottom, left}` |
| `Julep.Iced.Alignment` | `iced::alignment` | `:start`, `:center`, `:end`, `:left`, `:right`, `:top`, `:bottom` |
| `Julep.Iced.Theme` | `iced::Theme` | 22 built-in theme strings, custom palette maps |
| `Julep.Iced.Font` | `iced::Font` | `:default`, `:monospace`, family string, `%{family, weight, style, stretch}` |
| `Julep.Iced.Wrapping` | `iced::text::Wrapping` | `:none`, `:word`, `:glyph`, `:word_or_glyph` |
| `Julep.Iced.Shaping` | `iced::text::Shaping` | `:basic`, `:advanced` |
| `Julep.Iced.ContentFit` | `iced::ContentFit` | `:contain`, `:cover`, `:fill`, `:none`, `:scale_down` |
| `Julep.Iced.Direction` | `iced::widget::scrollable::Direction` | `:horizontal`, `:vertical` |
| `Julep.Iced.Position` | `iced::widget::tooltip::Position` | `:top`, `:bottom`, `:left`, `:right`, `:follow_cursor` |
| `Julep.Iced.FilterMethod` | `iced::widget::image::FilterMethod` | `:nearest`, `:linear` |
| `Julep.Iced.Anchor` | `iced::widget::scrollable::Anchor` | `:start`, `:end` |
| `Julep.Iced.Border` | `iced::Border` | `%{color, width, radius}` with uniform or per-corner radius |
| `Julep.Iced.Gradient` | `iced::gradient::Linear` | `%{type, angle, stops}` linear gradient backgrounds |
| `Julep.Iced.Shadow` | `iced::Shadow` | `%Shadow{color, offset_x, offset_y, blur_radius}` struct |
| `Julep.Iced.StyleMap` | -- | Per-instance style overrides with status variants (hovered, pressed, disabled, focused) |

### Color

`Julep.Iced.Color` uses hex strings as the canonical form. All constructors
return `"#rrggbb"` or `"#rrggbbaa"` strings.

| Function | Input | Output |
|---|---|---|
| `from_rgb(r, g, b)` | 0-255 integers | `"#rrggbb"` |
| `from_rgba(r, g, b, a)` | 0-255 integers + 0.0-1.0 float | `"#rrggbbaa"` |
| `from_hex(hex)` | Hex string with or without `#` | Normalized `"#rrggbb"` or `"#rrggbbaa"` |
| `cast(atom_or_hex)` | Named atom or hex string | Canonical hex string |
| `black()` / `white()` / `transparent()` | -- | Convenience constants |

`cast/1` is the normalization entrypoint. It accepts named atoms (`:black`,
`:white`, `:transparent`, `:red`, `:green`, `:blue`, `:yellow`, `:cyan`,
`:magenta`, `:gray`, `:grey`) and hex strings. Raises `ArgumentError` for
unknown atom names.

The `{r, g, b, a}` float object format from earlier iterations has been
replaced by hex-only canonical form. All color values on the wire are
strings.

### Shadow

`Julep.Iced.Shadow` is a typed struct with builder functions:

```elixir
Shadow.new()
|> Shadow.color("#00000040")
|> Shadow.offset(2, 2)
|> Shadow.blur_radius(6)
```

Fields: `color` (`Color.t()`), `offset_x` (number), `offset_y` (number),
`blur_radius` (number). The `color/2` builder accepts any form that
`Color.cast/1` supports (named atoms and hex strings).

Shadow implements the `Julep.Iced.Encode` protocol, encoding to the wire
format `%{"color" => hex, "offset" => [x, y], "blur_radius" => n}`.
Widget `to_node/1` implementations pass Shadow structs directly via
`Build.put_if/3` -- no manual conversion needed.

## Testing and iced_test integration

iced provides `iced_test`, a crate for headless widget testing with a
`Simulator` type. Julep's test framework draws from the same ideas but
adapts them to the cross-process architecture.

### How julep uses iced_test concepts

| iced_test concept | Julep equivalent |
|---|---|
| `Simulator` (in-process headless) | `Julep.Test.Backend.Headless` (cross-process via `julep --headless`) |
| `Simulator::click(id)` | `click("#id")` via test protocol |
| `Simulator::find(id)` | `find!("#id")` via query protocol |
| `Simulator::snapshot()` | `snapshot("name")` structural tree snapshot via snapshot_capture protocol |
| -- | `screenshot("name")` pixel screenshot (full backend only, no-op on mock/headless) |
| `.ice` test scripts | `.julep` scripts (superset of `.ice` format) |

### Widget ID propagation

iced_test relies on widget IDs to locate elements in the rendered tree.
Julep has the same requirement: the `id` field from Elixir's `ui_node()`
maps must propagate all the way through to the iced `Element` in
`widgets.rs`. This is critical for both `find` and `interact` operations
in the headless and full test backends.

Every julep widget module assigns an ID at construction time. The renderer
preserves these IDs in its internal `Tree` structure and uses them for
test protocol queries.

### Core extraction for testability

To support headless testing without an `iced::daemon`, julep extracts
renderer state into a `Core` struct (`julep/julep-core/src/engine.rs`).
Core holds the tree, widget caches, and subscription state. It processes
`IncomingMessage`s and returns `CoreEffect`s that the host (App or
headless loop) can handle.

This mirrors iced_test's approach of separating state management from
rendering, but operates at the process boundary rather than in-process.

### `.julep` format as superset of `.ice`

iced's `.ice` format defines a simple instruction set for test scripts:
`click`, `type`, `expect`, `snapshot`. Julep's `.julep` format extends
this with:

- A **header section** declaring the app module, viewport, theme, and
  backend (separated from instructions by `-----`).
- **`assert_text`** for targeted text assertions on specific widgets.
- **`wait`** for timing control in replay mode.

A `.julep` parser can handle `.ice` files by treating the absence of a
header as defaults. The core instruction syntax is compatible.

### Where julep uses its own implementations vs iced_test APIs

| Capability | Implementation |
|---|---|
| Tree storage and query | Julep's `Tree` struct in Rust, queried via wire protocol (MessagePack default, JSONL via `--json`) |
| Event simulation | Mock backend: `Julep.Test.EventMap` (pure Elixir inference). Headless/Full: events generated by renderer and sent back via wire protocol. |
| Structural snapshots | `snapshot("name")` / `assert_snapshot("name")` -- SHA-256 of serialized tree JSON, works on all backends. |
| Pixel screenshots | `screenshot("name")` / `assert_screenshot("name")` -- SHA-256 of RGBA pixel data. Full and headless backends produce real screenshots; mock returns stubs. |
| Widget finding | Headless/Full: tree traversal in Rust (`headless.rs`, `test_mode.rs`). Mock: tree traversal in Elixir. |
| Script execution | `Julep.Test.Script.Runner` (Elixir) |

Julep does not link against `iced_test` directly in its current
implementation. The headless backend uses `Core` with wire protocol serialization
rather than iced_test's in-process `Simulator`. This is a consequence of
the cross-process architecture: Elixir owns state and logic, Rust owns
rendering. Testing must cross that boundary.

## Detailed widget examples

### Scrollable on_scroll and auto_scroll

**Iced:**
```rust
scrollable(content)
    .on_scroll(Message::Scrolled)
```

**Julep.Iced.Widget:**
```elixir
Scrollable.new("log", on_scroll: true, auto_scroll: true)
|> Scrollable.push(content)
```

`on_scroll: true` emits `{:scroll, id, viewport}` where viewport contains
`absolute_x`, `absolute_y`, `relative_x`, `relative_y`, `bounds`, and
`content_bounds`. `auto_scroll: true` keeps the scrollable pinned to the
end when content changes.

### ProgressBar vertical

**Iced:**
```rust
progress_bar(0.0..=100.0, value).vertical()
```

**Julep.Iced.Widget:**
```elixir
ProgressBar.new("upload", {0, 100}, progress, vertical: true)
```

### Text shaping

**Iced:**
```rust
text("Hello").shaping(text::Shaping::Advanced)
```

**Julep.Iced.Widget:**
```elixir
Text.new("greeting", "Hello", shaping: :advanced)
```

Values: `:basic`, `:advanced`, `:auto`.

### Keyboard events (Key and KeyModifiers structs)

Keyboard events use the `%Julep.Event.Key{}` struct:

```elixir
%Julep.Event.Key{
  type: :press | :release,
  key: key,
  modified_key: key,
  physical_key: atom,
  location: :standard | :left | :right | :numpad,
  modifiers: %Julep.KeyModifiers{shift: bool, ctrl: bool, alt: bool, logo: bool, command: bool},
  text: string | nil,
  repeat: bool,
  captured: bool
}
```

All fields from iced's keyboard event are now captured: `physical_key`,
`location`, `text`, `repeat`, and `modified_key`.

### Toggler text_alignment

**Iced:**
```rust
toggler(value).text_alignment(alignment::Horizontal::Right)
```

**Julep.Iced.Widget:**
```elixir
Toggler.new("dark_mode", "Dark mode", model.dark, text_alignment: :right)
```

### TextInput on_paste and icon

**Iced:**
```rust
text_input("placeholder", &value)
    .on_paste(Message::Pasted)
    .icon(text_input::Icon { code_point: '\u{1F50D}', ... })
```

**Julep.Iced.Widget:**
```elixir
TextInput.new("search", model.query,
  on_paste: true,
  icon: %{code_point: "magnifying_glass", size: 16, spacing: 8, side: "left"}
)
```

`on_paste: true` emits `{:paste, id, text}`. The `icon` prop accepts a map
with `code_point`, `size`, `spacing`, `side`, and `font`.

### ComboBox on_option_hovered and icon

```elixir
ComboBox.new("search", options,
  on_option_hovered: true,
  icon: %{code_point: "search", size: 14, spacing: 8, side: "left"}
)
```

`on_option_hovered: true` emits `{:option_hovered, id, value}`. Icon format
is the same as TextInput.

### PickList handle

**Iced:**
```rust
pick_list(options, selected, Message::Selected)
    .handle(pick_list::Handle::Arrow { size: Some(16.0) })
```

**Julep.Iced.Widget:**
```elixir
PickList.new("size", options,
  handle: %{type: "arrow", size: 16}
)
```

Handle types: `"arrow"` (optional size), `"static"` (icon map), `"dynamic"`
(icon map), `"none"`.

### Slider circular_handle

**Iced:**
```rust
slider(0..=100, value, Message::Changed)
    .style(|theme, status| {
        let mut style = slider::default(theme, status);
        style.handle.shape = HandleShape::Circle { radius: 8.0 };
        style
    })
```

**Julep.Iced.Widget:**
```elixir
Slider.new("volume", {0, 100}, model.volume,
  circular_handle: true,
  handle_radius: 8
)
```

### Window initial settings

Window nodes now accept all iced window settings as props. The Runtime
extracts them and merges with `app.window_config`:

```elixir
def view(model) do
  window "editor",
    width: 1200, height: 800,
    position: {100, 100},
    min_size: {400, 300},
    maximized: model.start_maximized,
    decorations: true,
    transparent: false,
    resizable: true do
    # window content
  end
end
```

Supported props: `width`, `height`, `position`, `min_size`, `max_size`,
`maximized`, `fullscreen`, `visible`, `resizable`, `closeable`,
`minimizable`, `decorations`, `transparent`, `blur`, `level`,
`exit_on_close_request`.

### Application settings (antialiasing and fonts)

The Rust startup sequence now reads the first stdin line synchronously for
settings before spawning the iced daemon:

```elixir
def settings do
  %{
    antialiasing: true,
    fonts: ["/path/to/CustomFont.ttf", "/path/to/Icons.otf"]
  }
end
```

Antialiasing is applied to the iced daemon builder. Font file paths are
loaded at startup via `iced::font::load`.

## What julep adds that iced does not have

- **`do` block syntax** for nesting children (Julep.UI layer).
- **Automatic diffing.** Iced re-renders the full widget tree each frame.
  Julep diffs and sends only changes.
- **Plain-map trees.** Inspectable, serializable, testable without the
  renderer.
- **Headless mode.** Run and test your app without any GUI.
- **IEx integration.** Dispatch events and inspect state from the shell.
- **Hot code reload.** Update your Elixir code and see changes without
  restarting the renderer (because only the tree changes, not the process).

## What iced has that julep exposes differently

- **Builder pattern.** Iced uses method chaining (`button("x").on_press(M).width(100)`).
  Julep mirrors this with typed builder functions on each widget module
  (`Button.new("x", "label") |> Button.width(100)`). Keyword opts on the
  constructor are also supported (`Button.new("x", "label", width: 100)`).
  The untyped facade and Julep.UI layers use prop maps and keyword lists
  respectively.
- **Closures for styling.** Iced passes closure references for custom styles.
  Julep uses style atoms (`:primary`, `:danger`) or property maps, since
  closures can't be serialized over the wire protocol. The renderer
  resolves style names to iced's built-in style functions.
- **Generic type parameters.** Iced widgets are parameterized over Theme,
  Renderer, and Message. Julep hides this entirely -- the renderer handles
  type resolution from the JSON props.
