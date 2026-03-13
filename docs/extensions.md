# Writing Widget Extensions

Guide for building custom widget extensions for Julep. Extensions let you
render arbitrary Rust-native widgets (iced widgets, custom `iced::advanced::Widget`
implementations, third-party crates) while keeping your app's state and logic
in Elixir.

## Quick start

An extension has two halves:

1. **Elixir side:** implement the `Julep.Extension` behaviour. This tells the
   build system where the Rust crate lives, how to construct it, and what node
   type strings it handles.

2. **Rust side:** implement the `WidgetExtension` trait from `julep-core`. This
   receives tree nodes from Elixir and returns `iced::Element`s for rendering.

```elixir
# lib/my_sparkline/extension.ex
defmodule MySparkline.Extension do
  @behaviour Julep.Extension

  @impl true
  def native_crate, do: "native/my_sparkline"

  @impl true
  def rust_constructor, do: "my_sparkline::SparklineExtension::new()"

  @impl true
  def type_names, do: ["sparkline"]
end
```

```rust
// native/my_sparkline/src/lib.rs
use julep_core::prelude::*;

pub struct SparklineExtension;

impl SparklineExtension {
    pub fn new() -> Self { Self }
}

impl WidgetExtension for SparklineExtension {
    fn type_names(&self) -> &[&str] { &["sparkline"] }
    fn config_key(&self) -> &str { "sparkline" }

    fn render<'a>(&self, node: &'a TreeNode, env: &WidgetEnv<'a>) -> Element<'a, Message> {
        let label = prop_str(node, "label").unwrap_or_default();
        text(label).into()
    }
}
```

Build with `mix julep.build` (discovers extensions via the behaviour) or run
the renderer binary directly. The `JulepAppBuilder` chains `.extension()` calls
in the generated `main.rs`:

```rust
julep_renderer::run(
    JulepAppBuilder::new()
        .extension(Box::new(my_sparkline::SparklineExtension::new()))
)
```

Reference the 5 example packages from the dogfooding exercise for complete
working examples: julep_sparkline (Tier C), julep_hex_view (Tier A),
julep_code_view (Tier A), julep_plot (Tier B), julep_timeline (Tier C).


## Extension tiers

Not every extension needs the full trait. The `WidgetExtension` trait has
sensible defaults for all methods except `type_names`, `config_key`, and
`render`. Choose the tier that fits your widget:

### Tier A: render-only (~200 lines)

Implement `type_names`, `config_key`, and `render`. Everything else uses
defaults. Good for widgets that compose existing iced widgets with no
Rust-side interaction state.

**Example:** julep_hex_view -- renders binary data as a hex dump using
`column`, `row`, `text`, `scrollable`, and `container` from iced's standard
widget set.

```rust
impl WidgetExtension for HexViewExtension {
    fn type_names(&self) -> &[&str] { &["hex_view"] }
    fn config_key(&self) -> &str { "hex_view" }

    fn render<'a>(&self, node: &'a TreeNode, env: &WidgetEnv<'a>) -> Element<'a, Message> {
        // Compose standard iced widgets from node props
        let data = prop_str(node, "data").unwrap_or_default();
        // ... build column/row/text layout ...
        container(content).into()
    }
}
```

### Tier B: interactive (+handle_event)

Add `handle_event` to intercept events from your widgets before they reach
Elixir. Use this when the extension needs to process mouse/keyboard input
internally (pan, zoom, hover tracking) or transform events before forwarding.

**Example:** julep_plot -- canvas-based plotting with pan/zoom handled
entirely in Rust, while click events are forwarded to Elixir as semantic
`plot_click` events.

```rust
fn handle_event(
    &mut self,
    node_id: &str,
    family: &str,
    data: &Value,
    caches: &mut ExtensionCaches,
) -> EventResult {
    match family {
        "canvas_press" => {
            // Transform raw canvas coordinates into plot-space click
            let x = data.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let y = data.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0);
            let plot_event = OutgoingEvent::extension_event(
                "plot_click".to_string(),
                node_id.to_string(),
                Some(serde_json::json!({"plot_x": x, "plot_y": y})),
            );
            EventResult::Consumed(vec![plot_event])
        }
        "canvas_move" => {
            // Update hover state internally, don't forward
            EventResult::Consumed(vec![])
        }
        _ => EventResult::PassThrough,
    }
}
```

### Tier C: full lifecycle (+prepare, handle_command, cleanup)

Add `prepare` for mutable state synchronization before each render pass,
`handle_command` for commands sent from Elixir to the extension, and
`cleanup` for resource teardown when nodes are removed.

**Example:** julep_sparkline -- ring buffer of data samples pushed via
extension commands, canvas rendering with generation-tracked cache
invalidation, timer-driven animation state.

**Example:** julep_timeline -- custom `iced::advanced::Widget` implementation
with viewport state, hit testing, pan/zoom, all persisted in
`ExtensionCaches`.

```rust
fn prepare(&mut self, node: &TreeNode, caches: &mut ExtensionCaches, theme: &Theme) {
    // Initialize or sync per-node state
    let state = caches.get_or_insert::<SparklineState>(&node.id, || {
        SparklineState::new(prop_usize(node, "capacity").unwrap_or(100))
    });
    // Update from props if needed
    state.color = prop_color(node, "color");
}

fn handle_command(
    &mut self,
    node_id: &str,
    op: &str,
    payload: &Value,
    caches: &mut ExtensionCaches,
) -> Vec<OutgoingEvent> {
    match op {
        "push" => {
            if let Some(state) = caches.get_mut::<SparklineState>(node_id) {
                if let Some(value) = payload.as_f64() {
                    state.push(value as f32);
                    state.generation.bump();
                }
            }
            vec![]
        }
        _ => vec![],
    }
}

fn cleanup(&mut self, node_id: &str, caches: &mut ExtensionCaches) {
    caches.remove(node_id);
}
```

The full list of trait methods:

| Method | Required | Phase | Receives | Returns |
|---|---|---|---|---|
| `type_names` | yes | registration | -- | `&[&str]` |
| `config_key` | yes | registration | -- | `&str` |
| `init` | no | startup | `&Value` (config) | -- |
| `prepare` | no | mutable (pre-view) | `&TreeNode`, `&mut ExtensionCaches`, `&Theme` | -- |
| `render` | yes | immutable (view) | `&TreeNode`, `&WidgetEnv` | `Element<Message>` |
| `handle_event` | no | update | node_id, family, data, `&mut ExtensionCaches` | `EventResult` |
| `handle_command` | no | update | node_id, op, payload, `&mut ExtensionCaches` | `Vec<OutgoingEvent>` |
| `cleanup` | no | tree diff | node_id, `&mut ExtensionCaches` | -- |


## Message::Event construction

Extensions that implement custom `iced::advanced::Widget` types need to
publish events back through the extension system. Use the `Message::Event`
variant:

```rust
use julep_core::message::Message;
use serde_json::json;

// In your Widget::update() method:
shell.publish(Message::Event(
    self.node_id.clone(),           // node ID (String)
    json!({"key": "value"}),        // event data (serde_json::Value)
    "my_event_family".to_string(),  // family string (String)
));
```

The event flows through the system like this:

```
Widget::update()
  -> shell.publish(Message::Event(id, data, family))
  -> App::update() in renderer.rs
  -> ExtensionDispatcher::handle_event(id, family, data, caches)
  -> your extension's handle_event() method
  -> EventResult determines what reaches Elixir
```

If your extension does not implement `handle_event` (or returns
`EventResult::PassThrough`), the event is serialized as-is and sent to
Elixir over the wire as an `OutgoingEvent` with the family and data you
provided.

### Constructing OutgoingEvent from extensions

When your `handle_event` or `handle_command` needs to emit events to Elixir,
use `OutgoingEvent::extension_event`:

```rust
OutgoingEvent::extension_event(
    "my_custom_family".to_string(),  // family string
    node_id.to_string(),             // node ID
    Some(json!({"detail": 42})),     // optional data payload (None for bare events)
)
```

This is equivalent to `OutgoingEvent::generic(family, id, data)`. The
resulting JSON sent to Elixir looks like:

```json
{"type": "event", "family": "my_custom_family", "id": "node-1", "data": {"detail": 42}}
```


## Event family reference

Every event sent over the wire carries a `family` string that identifies
what kind of interaction produced it. Extension authors need to know these
strings when implementing `handle_event` -- the `family` parameter tells
you what happened.

### Widget events (node ID in `id` field)

These are emitted by built-in widgets. They use dedicated `Message` variants
internally but arrive at extensions via `Message::Event` when the widget is
inside an extension's node tree.

| Family | Source widget | Data fields |
|---|---|---|
| `click` | button | -- |
| `input` | text_input, text_editor | `value`: new text (in `value` field) |
| `submit` | text_input | `value`: current text (in `value` field) |
| `toggle` | checkbox, toggler | `value`: bool (in `value` field) |
| `slide` | slider, vertical_slider | `value`: f64 (in `value` field) |
| `slide_release` | slider, vertical_slider | `value`: f64 (in `value` field) |
| `select` | pick_list, combo_box, radio | `value`: selected string (in `value` field) |
| `open` | pick_list, combo_box | -- |
| `close` | pick_list, combo_box | -- |
| `paste` | text_input | `value`: pasted text (in `value` field) |
| `option_hovered` | combo_box | `value`: hovered option (in `value` field) |
| `sort` | table | `data.column`: column key |
| `key_binding` | text_editor | `data`: binding tag and key data |
| `scroll` | scrollable | `data`: absolute/relative offsets, bounds, content size |

### Canvas events (node ID in `id` field)

Emitted by canvas widgets via `Message::CanvasEvent` and `Message::CanvasScroll`.

| Family | Data fields |
|---|---|
| `canvas_press` | `data.x`, `data.y`, `data.button` |
| `canvas_release` | `data.x`, `data.y`, `data.button` |
| `canvas_move` | `data.x`, `data.y` |
| `canvas_scroll` | `data.x`, `data.y`, `data.delta_x`, `data.delta_y` |

### MouseArea events (node ID in `id` field)

Emitted by mouse_area widgets.

| Family | Data fields |
|---|---|
| `mouse_right_press` | -- |
| `mouse_right_release` | -- |
| `mouse_middle_press` | -- |
| `mouse_middle_release` | -- |
| `mouse_double_click` | -- |
| `mouse_enter` | -- |
| `mouse_exit` | -- |
| `mouse_move` | `data.x`, `data.y` |
| `mouse_scroll` | `data.delta_x`, `data.delta_y` |

### Sensor events (node ID in `id` field)

| Family | Data fields |
|---|---|
| `sensor_resize` | `data.width`, `data.height` |

### PaneGrid events (grid ID in `id` field)

| Family | Data fields |
|---|---|
| `pane_resized` | `data.split`, `data.ratio` |
| `pane_dragged` | `data.pane`, `data.target` |
| `pane_clicked` | `data.pane` |

### Subscription events (subscription tag in `tag` field, empty `id`)

These are only routed through extensions if the extension widget's node ID
matches. In practice, extensions mostly see the widget-scoped events above.
Listed here for completeness.

| Family | Data fields |
|---|---|
| `key_press` | `value`: key name, `modifiers`, `data`: modified_key, physical_key, location, text, repeat |
| `key_release` | `value`: key name, `modifiers`, `data`: same as key_press |
| `modifiers_changed` | `data.shift`, `data.ctrl`, `data.alt`, `data.logo`, `data.command` |
| `cursor_moved` | `data.x`, `data.y` |
| `cursor_entered` | -- |
| `cursor_left` | -- |
| `button_pressed` | `data.button` |
| `button_released` | `data.button` |
| `wheel_scrolled` | `data.delta_x`, `data.delta_y`, `data.unit` |
| `finger_pressed` | `data.finger_id`, `data.x`, `data.y` |
| `finger_moved` | `data.finger_id`, `data.x`, `data.y` |
| `finger_lifted` | `data.finger_id`, `data.x`, `data.y` |
| `finger_lost` | `data.finger_id`, `data.x`, `data.y` |
| `ime` | `data.kind` (opened/preedit/commit/closed), `data.text`, `data.cursor` |
| `animation_frame` | `data.timestamp_millis` |
| `theme_changed` | `data.mode` |

### Window events (subscription tag in `tag` field)

| Family | Data fields |
|---|---|
| `window_opened` | `data.window_id`, `data.position` |
| `window_closed` | `data.window_id` |
| `window_close_requested` | `data.window_id` |
| `window_moved` | `data.window_id`, `data.x`, `data.y` |
| `window_resized` | `data.window_id`, `data.width`, `data.height` |
| `window_focused` | `data.window_id` |
| `window_unfocused` | `data.window_id` |
| `window_rescaled` | `data.window_id`, `data.scale_factor` |
| `file_hovered` | `data.window_id`, `data.path` |
| `file_dropped` | `data.window_id`, `data.path` |
| `files_hovered_left` | `data.window_id` |


## EventResult guide

`handle_event` returns one of three variants that control event flow:

### PassThrough

"I don't care about this event. Forward it to Elixir as-is."

This is the default. Use it for events your extension doesn't need to
intercept. The original event is serialized and sent over the wire.

```rust
fn handle_event(&mut self, _id: &str, family: &str, _data: &Value, _caches: &mut ExtensionCaches) -> EventResult {
    match family {
        "canvas_press" => { /* handle it */ },
        _ => EventResult::PassThrough,
    }
}
```

### Consumed(events)

"I handled this event. Do NOT forward the original to Elixir. Optionally
emit different events instead."

Use this when the extension fully owns the interaction:

```rust
// Pan/zoom: handle internally, emit nothing to Elixir
EventResult::Consumed(vec![])

// Transform: swallow the raw canvas event, emit a semantic one
EventResult::Consumed(vec![
    OutgoingEvent::extension_event(
        "plot_click".to_string(),
        node_id.to_string(),
        Some(json!({"series": "cpu", "index": 42})),
    )
])
```

**Gotcha: canvas cache invalidation.** If your `handle_event` modifies
visual state (e.g., updates hover position, changes zoom level) and returns
`Consumed(vec![])`, iced will still call `view()` after the update (the
daemon always re-renders after every `update()`). Standard iced widgets
re-render correctly. But if your extension uses `canvas::Cache`, the cache
won't know to clear itself -- you need to invalidate it explicitly via
`GenerationCounter` (see below) or by structuring your `Program::draw()` to
detect the state change.

### Observed(events)

"I handled this event AND forward the original to Elixir. Also emit
additional events."

Use this when both the extension and Elixir need to see the event:

```rust
// Forward the original click AND emit a computed event
EventResult::Observed(vec![
    OutgoingEvent::extension_event(
        "sparkline_sample_clicked".to_string(),
        node_id.to_string(),
        Some(json!({"sample_index": 7, "value": 42.5})),
    )
])
```

The original event is sent first, then the additional events in order.


## canvas::Cache and GenerationCounter

`iced::widget::canvas::Cache` is `!Send + !Sync`. This means it cannot be
stored in `ExtensionCaches` (which requires `Send + Sync + 'static`). This
is a fundamental constraint of iced's rendering architecture, not a bug.

### The pattern

Instead of storing `canvas::Cache` in `ExtensionCaches`, use iced's built-in
tree state mechanism. The cache lives in your `Program::State` (initialized
via `Widget::state()` or `canvas::Program`), and a `GenerationCounter` in
`ExtensionCaches` tracks when your data changes.

```rust
use julep_core::prelude::*;
use iced::widget::canvas;

/// Stored in ExtensionCaches (Send + Sync).
struct SparklineData {
    samples: Vec<f32>,
    generation: GenerationCounter,
}

/// Stored in canvas Program::State (not Send, not Sync -- iced manages it).
struct SparklineState {
    last_generation: u64,
    cache: canvas::Cache,
}
```

In `prepare` or `handle_command`, bump the generation when data changes:

```rust
fn handle_command(&mut self, node_id: &str, op: &str, payload: &Value, caches: &mut ExtensionCaches) -> Vec<OutgoingEvent> {
    if op == "push" {
        if let Some(data) = caches.get_mut::<SparklineData>(node_id) {
            data.samples.push(payload.as_f64().unwrap_or(0.0) as f32);
            data.generation.bump();  // signal that a redraw is needed
        }
    }
    vec![]
}
```

In `draw`, compare generations to decide whether to clear the cache:

```rust
impl canvas::Program<Message> for SparklineProgram<'_> {
    type State = SparklineState;

    fn draw(
        &self,
        state: &Self::State,
        renderer: &iced::Renderer,
        _theme: &Theme,
        bounds: iced::Rectangle,
        _cursor: iced::mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        // Check if data has changed since last draw
        if state.last_generation != self.current_generation {
            state.cache.clear();
            // Note: state.last_generation is updated after draw via update()
        }

        let geometry = state.cache.draw(renderer, bounds.size(), |frame| {
            // Draw your content here
        });

        vec![geometry]
    }
}
```

### Why GenerationCounter instead of content hashing

`GenerationCounter` is a simple `u64` counter. Incrementing it is O(1) and
comparing two values is a single integer comparison. Content hashing is
more expensive and harder to get right (what do you hash? serialized JSON?
raw bytes?). The counter approach is the recommended pattern.

`GenerationCounter` implements `Send + Sync + Clone` and stores cleanly in
`ExtensionCaches`. Create it with `GenerationCounter::new()` (starts at 0),
call `.bump()` to increment, and `.get()` to read the current value.


## iced 0.14 Widget trait guide

Extensions implementing `iced::advanced::Widget` directly (Tier C) need to
be aware of the iced 0.14 API. Several methods changed names and signatures
from earlier versions.

### Key changes from iced 0.13

**`on_event` is now `update`:**

```rust
// iced 0.14
fn update(
    &mut self,
    tree: &mut widget::Tree,
    event: iced::Event,
    layout: Layout<'_>,
    cursor: mouse::Cursor,
    renderer: &Renderer,
    clipboard: &mut dyn Clipboard,
    shell: &mut Shell<'_, Message>,
    viewport: &Rectangle,
) -> event::Status {
    // ...
}
```

**Capturing events:** Instead of returning `event::Status::Captured`, call
`shell.capture_event()` and return `event::Status::Captured`:

```rust
// In update():
shell.capture_event();
event::Status::Captured
```

**Alignment fields renamed:**

```rust
// 0.13:
// fn horizontal_alignment(&self) -> alignment::Horizontal
// fn vertical_alignment(&self) -> alignment::Vertical

// 0.14:
fn align_x(&self) -> alignment::Horizontal { ... }
fn align_y(&self) -> alignment::Vertical { ... }
```

Note: the types are different too. `align_x` returns
`alignment::Horizontal`, `align_y` returns `alignment::Vertical`.

**Widget::size() returns Size\<Length\>:**

```rust
fn size(&self) -> iced::Size<Length> {
    iced::Size::new(self.width, self.height)
}
```

**Widget::state() initializes tree state:**

```rust
fn state(&self) -> widget::tree::State {
    widget::tree::State::new(MyWidgetState::default())
}
```

Called once on first mount. The state persists in iced's widget tree and is
accessible in `update()` and `draw()` via `tree.state.downcast_ref::<MyWidgetState>()`.

**Widget::tag() for state type verification:**

```rust
fn tag(&self) -> widget::tree::Tag {
    widget::tree::Tag::of::<MyWidgetState>()
}
```

### Publishing events from custom widgets

Use `shell.publish(Message::Event(...))` as described in the Message::Event
construction section above. The `Message` type is re-exported from
`julep_core::prelude`.

### Full Widget skeleton

```rust
use iced::advanced::widget::{self, Widget};
use iced::advanced::{layout, mouse, renderer, Clipboard, Layout, Shell};
use iced::event;
use iced::{Element, Length, Rectangle, Size, Theme};
use julep_core::prelude::*;

struct MyWidget<'a> {
    node_id: String,
    node: &'a TreeNode,
}

struct MyWidgetState {
    // your per-instance state
}

impl Default for MyWidgetState {
    fn default() -> Self { Self { /* ... */ } }
}

impl<'a> Widget<Message, Theme, iced::Renderer> for MyWidget<'a> {
    fn tag(&self) -> widget::tree::Tag {
        widget::tree::Tag::of::<MyWidgetState>()
    }

    fn state(&self) -> widget::tree::State {
        widget::tree::State::new(MyWidgetState::default())
    }

    fn size(&self) -> Size<Length> {
        Size::new(Length::Fill, Length::Shrink)
    }

    fn layout(&self, _tree: &mut widget::Tree, _renderer: &iced::Renderer, limits: &layout::Limits) -> layout::Node {
        let size = limits.max();
        layout::Node::new(Size::new(size.width, 200.0))
    }

    fn draw(
        &self,
        tree: &widget::Tree,
        renderer: &mut iced::Renderer,
        theme: &Theme,
        style: &renderer::Style,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        viewport: &Rectangle,
    ) {
        // Draw your widget
    }

    fn update(
        &mut self,
        tree: &mut widget::Tree,
        event: iced::Event,
        layout: Layout<'_>,
        cursor: mouse::Cursor,
        renderer: &iced::Renderer,
        clipboard: &mut dyn Clipboard,
        shell: &mut Shell<'_, Message>,
        viewport: &Rectangle,
    ) -> event::Status {
        if let iced::Event::Mouse(mouse::Event::ButtonPressed(mouse::Button::Left)) = &event {
            if cursor.is_over(layout.bounds()) {
                shell.publish(Message::Event(
                    self.node_id.clone(),
                    serde_json::json!({"x": 0, "y": 0}),
                    "my_widget_click".to_string(),
                ));
                shell.capture_event();
                return event::Status::Captured;
            }
        }
        event::Status::Ignored
    }
}

impl<'a> From<MyWidget<'a>> for Element<'a, Message> {
    fn from(w: MyWidget<'a>) -> Self {
        Self::new(w)
    }
}
```


## Prop helpers reference

The `julep_core::prop_helpers` module (re-exported via `prelude::*`) provides
typed accessors for reading props from `TreeNode`. Use these instead of
manually traversing `serde_json::Value`:

| Helper | Return type | Notes |
|---|---|---|
| `prop_str(node, key)` | `Option<String>` | |
| `prop_f32(node, key)` | `Option<f32>` | Accepts numbers and numeric strings |
| `prop_f64(node, key)` | `Option<f64>` | Accepts numbers and numeric strings |
| `prop_u32(node, key)` | `Option<u32>` | Rejects negative values |
| `prop_u64(node, key)` | `Option<u64>` | Rejects negative values |
| `prop_usize(node, key)` | `Option<usize>` | Via `prop_u64` |
| `prop_i64(node, key)` | `Option<i64>` | Signed integers |
| `prop_bool(node, key)` | `Option<bool>` | |
| `prop_bool_default(node, key, default)` | `bool` | Returns default when absent |
| `prop_length(node, key, fallback)` | `Length` | Parses "fill", "shrink", numbers, `{fill_portion: n}` |
| `prop_range_f32(node)` | `RangeInclusive<f32>` | Reads `range` prop as `[min, max]`, defaults to `0.0..=100.0` |
| `prop_range_f64(node)` | `RangeInclusive<f64>` | Same as above, f64 |
| `prop_color(node, key)` | `Option<iced::Color>` | Parses `#RRGGBB` / `#RRGGBBAA` hex strings |
| `prop_f32_array(node, key)` | `Option<Vec<f32>>` | Array of numbers |
| `prop_horizontal_alignment(node, key)` | `alignment::Horizontal` | "left"/"center"/"right", defaults Left |
| `prop_vertical_alignment(node, key)` | `alignment::Vertical` | "top"/"center"/"bottom", defaults Top |
| `prop_content_fit(node)` | `Option<ContentFit>` | Reads `content_fit` prop |


## Testing extensions

### Elixir-side tests

Test your Elixir module's callbacks and any struct builders or Widget
protocol implementations:

```elixir
defmodule MySparkline.ExtensionTest do
  use ExUnit.Case

  test "type_names returns expected types" do
    assert MySparkline.Extension.type_names() == ["sparkline"]
  end

  test "native_crate path exists" do
    assert File.dir?(MySparkline.Extension.native_crate())
  end

  test "rust_constructor is valid expression" do
    expr = MySparkline.Extension.rust_constructor()
    assert is_binary(expr)
    assert String.contains?(expr, "SparklineExtension")
  end
end
```

If your extension provides Elixir-side widget structs with the
`Julep.Iced.Widget` protocol, test the struct builders and `to_node`
conversion:

```elixir
test "sparkline widget builds correct node" do
  node = Sparkline.new("spark-1") |> Sparkline.build()
  assert node.type == "sparkline"
  assert node.id == "spark-1"
end
```

### Rust-side tests

Test pure logic functions, `handle_command`, and `prepare`/`cleanup` using
the helpers from `julep_core::testing`:

```rust
#[cfg(test)]
mod tests {
    use julep_core::testing::*;
    use super::*;

    #[test]
    fn handle_command_push_adds_sample() {
        let mut ext = SparklineExtension::new();
        let mut caches = ext_caches();

        // Simulate prepare to initialize state
        let n = node_with_props("s-1", "sparkline", json!({"capacity": 10}));
        ext.prepare(&n, &mut caches, &iced::Theme::Dark);

        // Push a sample
        let events = ext.handle_command("s-1", "push", &json!(42.0), &mut caches);
        assert!(events.is_empty());

        let state = caches.get::<SparklineState>("s-1").unwrap();
        assert_eq!(state.samples.len(), 1);
    }

    #[test]
    fn cleanup_removes_state() {
        let mut ext = SparklineExtension::new();
        let mut caches = ext_caches();

        let n = node("s-1", "sparkline");
        ext.prepare(&n, &mut caches, &iced::Theme::Dark);
        assert!(caches.contains("s-1"));

        ext.cleanup("s-1", &mut caches);
        assert!(!caches.contains("s-1"));
    }
}
```

### Render smoke testing

Use `widget_env_with()` from `julep_core::testing` to construct a
`WidgetEnv` for smoke-testing your `render()` method. This verifies the
method doesn't panic and returns a valid `Element`:

```rust
#[test]
fn render_does_not_panic() {
    let ext = HexViewExtension::new();
    let wc = widget_caches();
    let ec = ext_caches();
    let images = image_registry();
    let theme = iced::Theme::Dark;
    let disp = dispatcher();

    let env = widget_env_with(&ec, &wc, &images, &theme, &disp);
    let n = node_with_props("hv-1", "hex_view", json!({"data": "AQID"}));

    // Should not panic
    let _element = ext.render(&n, &env);
}
```

### Sim backend testing

For the Elixir sim test backend to interact with your custom widget types,
implement the optional `sim_events/3` callback on your `Julep.Extension`
module:

```elixir
defmodule MySparkline.Extension do
  @behaviour Julep.Extension
  # ... other callbacks ...

  @impl true
  def sim_events(:click, %{type: "sparkline", id: id}, _args) do
    {:ok, {:click, id}}
  end

  def sim_events(_verb, _element, _args), do: :not_handled
end
```

Register the extension for sim dispatch in your test setup:

```elixir
setup do
  Julep.Test.ExtensionEvents.register(MySparkline.Extension)
  on_exit(fn -> Julep.Test.ExtensionEvents.clear() end)
end
```

Or call `Julep.Test.ExtensionEvents.register_all/0` to auto-discover all
loaded extensions implementing `Julep.Extension`.

This lets standard test helpers like `click/1`, `type_text/2`, etc. work
with your extension's widget types in the sim backend.


## ExtensionCaches

`ExtensionCaches` is type-erased storage (`HashMap<String, Box<dyn Any + Send + Sync>>`)
keyed by node ID. It is the primary mechanism for persisting state between
`prepare`/`render`/`handle_event`/`handle_command` calls.

Key methods:

| Method | Signature | Notes |
|---|---|---|
| `get::<T>(key)` | `-> Option<&T>` | Immutable access |
| `get_mut::<T>(key)` | `-> Option<&mut T>` | Mutable access |
| `get_or_insert::<T>(key, default_fn)` | `-> &mut T` | Initialize if absent. Panics on type mismatch. |
| `insert::<T>(key, value)` | `-> ()` | Overwrites existing |
| `remove(key)` | `-> bool` | Returns whether key existed |
| `contains(key)` | `-> bool` | |
| `clear()` | `-> ()` | Remove all entries |

Common keying patterns:

- **Per-node state:** use the node ID directly: `caches.get::<MyState>(&node.id)`
- **Per-node sub-keys:** use `format!("{}:gen", node.id)` for auxiliary data
  like generation counters
- **Global extension state:** use your config key: `caches.get::<GlobalConfig>(self.config_key())`

The type parameter `T` must be `Send + Sync + 'static`. This is why
`canvas::Cache` (which is `!Send + !Sync`) cannot be stored here.


## Panic isolation

The `ExtensionDispatcher` wraps all mutable extension calls (`init`,
`prepare`, `handle_event`, `handle_command`, `cleanup`) in
`catch_unwind`. If your extension panics:

1. The panic is logged via `log::error!`.
2. The extension is marked as "poisoned".
3. All subsequent calls to the poisoned extension are skipped.
4. `render()` returns a red error placeholder text instead of calling your code.
5. Poisoned state is cleared on the next `Snapshot` message (full tree sync).

This means a bug in one extension cannot crash the renderer or affect other
extensions. But it also means panics are unrecoverable until the next
snapshot -- design your extension to avoid panics in production.

**Note:** `render()` panics ARE caught via `catch_unwind` in
`widgets::render()`. When a render panic is caught, the extension is
marked as "poisoned" and subsequent renders skip it, returning a red
error placeholder text until `clear_poisoned()` is called (typically on
the next `Snapshot` message).
