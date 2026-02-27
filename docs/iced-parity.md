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
| `iced::Task` | `Julep.Command` |
| `iced::Subscription` | `Julep.Subscription` |
| `iced::window` | `Julep.Command` (window_open, window_close, resize_window, etc.) |
| `iced::keyboard` | (events delivered as tuples) |

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
| `Color::from_rgb(r, g, b)` | `"#rrggbb"` or `%{r: 0.5, g: 0.5, b: 0.5, a: 1.0}` |
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
| `Message::ButtonPressed` via `.on_press()` | `{:click, button_id}` |
| `Message::InputChanged(s)` via `.on_input()` | `{:input, field_id, value}` |
| `Message::InputSubmitted` via `.on_submit()` | `{:submit, field_id, value}` |
| `Message::Toggled(b)` via `.on_toggle()` | `{:toggle, id, value}` |
| `Message::Selected(v)` via `pick_list`/`combo_box` | `{:select, id, value}` |
| `Message::SliderChanged(v)` via `.on_change()` | `{:slide, id, value}` |
| `Message::SliderReleased` via `.on_release()` | `{:slide_release, id, value}` |
| Key press via subscription | `{:key_press, key, modifiers}` |
| Key release via subscription | `{:key_release, key, modifiers}` |
| Modifiers changed via subscription | `{:modifiers_changed, modifiers}` |
| Cursor moved via subscription | `{:cursor_moved, x, y}` |
| Mouse button pressed via subscription | `{:button_pressed, button}` |
| Mouse button released via subscription | `{:button_released, button}` |
| Wheel scrolled via subscription | `{:wheel_scrolled, dx, dy, unit}` |
| Finger pressed via subscription | `{:finger_pressed, finger_id, x, y}` |
| Window close request | `{:window_close_requested, window_id}` |
| Window opened | `{:window_opened, window_id, position, size}` |
| Window closed | `{:window_closed, window_id}` |
| Window moved | `{:window_moved, window_id, x, y}` |
| Window resized | `{:window_resized, window_id, width, height}` |
| Window focused / unfocused | `{:window_focused, window_id}` / `{:window_unfocused, window_id}` |
| File dropped | `{:file_dropped, window_id, path}` |
| Canvas press | `{:canvas_press, id, x, y, button}` |
| Canvas move | `{:canvas_move, id, x, y}` |
| Sensor resize | `{:sensor_resize, id, width, height}` |
| PaneGrid click | `{:pane_clicked, id, pane}` |
| PaneGrid resize | `{:pane_resized, id, split, ratio}` |
| Animation frame | `{:animation_frame, timestamp}` |
| Theme changed | `{:theme_changed, mode}` |
| Timer tick | `{:tick, timestamp}` |

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
  closures can't be serialized over the JSONL transport. The renderer
  resolves style names to iced's built-in style functions.
- **Generic type parameters.** Iced widgets are parameterized over Theme,
  Renderer, and Message. Julep hides this entirely -- the renderer handles
  type resolution from the JSON props.
