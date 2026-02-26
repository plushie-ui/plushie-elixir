# Iced parity guide

Julep mirrors iced's API as closely as Elixir allows. If you know iced, you
know julep. This doc maps iced Rust code to its julep Elixir equivalent.

## Module structure

| Iced (Rust) | Julep (Elixir) |
|---|---|
| `iced::widget::*` | `Julep.Iced.*` (strict parity) |
| -- | `Julep.UI` (ergonomic layer, delegates to `Julep.Iced`) |
| `iced::Length` | `Julep.Iced.Length` |
| `iced::Padding` | `Julep.Iced.Padding` |
| `iced::alignment` | `Julep.Iced.Alignment` |
| `iced::Theme` | `Julep.Iced.Theme` |
| `iced::Font` | `Julep.Iced.Font` |
| `iced::Task` | `Julep.Command` |
| `iced::Subscription` | `Julep.Subscription` |
| `iced::window` | `Julep.Window` |
| `iced::keyboard` | (events delivered as tuples) |

`Julep.Iced` is the strict parity layer. Each function maps directly to
an iced widget with the same name and the same prop vocabulary. If iced
calls it `spacing`, julep calls it `spacing`. If iced calls it `align_x`,
julep calls it `align_x`.

`Julep.UI` is the ergonomic layer. It delegates to `Julep.Iced` for node
construction but adds `do` block syntax, auto-ID generation for anonymous
nodes, and keyword-list conveniences. The output is identical -- same
nodes, same props.

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

**Julep.Iced (strict parity):**
```elixir
Iced.column("main_col", %{spacing: 16, padding: 20}, [
  Iced.text("greeting", %{content: "Hello, world!", size: 24}),
  Iced.row("btn_row", %{spacing: 8}, [
    Iced.button("inc", %{label: "Increment", on_press: "increment"}),
    Iced.button("dec", %{label: "Decrement", on_press: "decrement"})
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

All three produce the same tree. Use whichever reads best for your context.

### Text input

**Iced:**
```rust
text_input("Enter name...", &self.name)
    .on_input(Message::NameChanged)
    .on_submit(Message::NameSubmitted)
    .padding(8)
    .width(Length::Fill)
```

**Julep.Iced:**
```elixir
Iced.text_input("name_field", %{
  placeholder: "Enter name...",
  value: model.name,
  on_input: "name_changed",
  on_submit: "name_submitted",
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

**Julep.Iced:**
```elixir
Iced.checkbox("remember", %{
  label: "Remember me",
  is_checked: model.remember,
  on_toggle: "remember_toggled",
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

**Julep.Iced:**
```elixir
Iced.slider("volume", %{
  range: {0, 100},
  value: model.volume,
  on_change: "volume_changed",
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

**Julep.Iced:**
```elixir
Iced.pick_list("size_picker", %{
  options: ["Small", "Medium", "Large"],
  selected: model.size,
  on_selected: "size_selected",
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

**Julep.Iced:**
```elixir
Iced.container("wrapper", %{
  padding: 16,
  center: :fill,
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

**Julep.Iced:**
```elixir
Iced.tooltip("help_tip", %{position: :top}, [
  Iced.button("help_btn", %{label: "?", on_press: "help"})
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
| `Color::from_rgb(r, g, b)` | `{r, g, b}` or `"#rrggbb"` |
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
| Keyboard event via subscription | `{:key_press, key, modifiers}` |
| Window close request | `{:window, :close_requested, window_id}` |
| Window resize | `{:window, :resized, window_id, size}` |
| Timer tick | `{:tick, timestamp}` |

Custom events are strings. The renderer maps widget interactions to event
tuples using the node's `id` and the interaction type.

## Task / Command mapping

Iced's `Task<Message>` maps to `Julep.Command`:

| Iced | Julep |
|---|---|
| `Task::none()` | (return bare model) |
| `Task::perform(future, map)` | `Julep.Command.async(fun, event_tag)` |
| `Task::batch(tasks)` | `Julep.Command.batch([...])` |
| `text_input::focus(id)` | `Julep.Command.focus(id)` |
| `text_input::select_all(id)` | `Julep.Command.select_all(id)` |
| `scrollable::snap_to(id, off)` | `Julep.Command.scroll_to(id, offset)` |
| `widget::focus_next()` | `Julep.Command.focus_next()` |
| `widget::focus_previous()` | `Julep.Command.focus_previous()` |
| `window::open(settings)` | `Julep.Command.open_window(id, opts)` |
| `window::close(id)` | `Julep.Command.close_window(id)` |
| `window::resize(id, size)` | `Julep.Command.resize_window(id, size)` |

See [commands.md](commands.md) for details.

## Subscription mapping

Iced's `Subscription<Message>` maps to `Julep.Subscription`:

| Iced | Julep |
|---|---|
| `Subscription::none()` | `[]` |
| `time::every(Duration)` | `Julep.Subscription.every(ms)` |
| `keyboard::on_key_press(f)` | `Julep.Subscription.on_key_press()` |
| `window::close_requests()` | `Julep.Subscription.on_window_close()` |
| `window::events()` | `Julep.Subscription.on_window_event()` |
| `Subscription::batch(subs)` | concatenate lists: `sub_a ++ sub_b` |

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
  Julep uses prop maps or keyword lists. Same data, different syntax.
- **Closures for styling.** Iced passes closure references for custom styles.
  Julep uses style atoms (`:primary`, `:danger`) or property maps.
- **Generic type parameters.** Iced widgets are parameterized over Theme,
  Renderer, and Message. Julep hides this entirely -- the renderer handles
  type resolution from the JSON props.
