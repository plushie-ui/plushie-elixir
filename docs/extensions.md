# Writing Widget Extensions

Guide for building custom widget extensions for Toddy. Extensions let you
render arbitrary Rust-native widgets (iced widgets, custom `iced::advanced::Widget`
implementations, third-party crates) while keeping your app's state and logic
in Elixir.

## Quick start

An extension has two halves:

1. **Elixir side:** use the `Toddy.Extension` macro. This declares the widget's
   props, commands, and (for native widgets) the Rust crate and constructor.

2. **Rust side:** implement the `WidgetExtension` trait from `toddy-core`. This
   receives tree nodes from Elixir and returns `iced::Element`s for rendering.

```elixir
# lib/my_sparkline/extension.ex
defmodule MySparkline do
  use Toddy.Extension, :native_widget

  widget :sparkline

  rust_crate "native/my_sparkline"
  rust_constructor "my_sparkline::SparklineExtension::new()"

  prop :data, {:list, :number}, doc: "Sample values to plot"
  prop :color, :color, default: "#4CAF50", doc: "Line color"
  prop :capacity, :number, default: 100, doc: "Max samples in the ring buffer"

  command :push, value: :number
end
```

This generates:

- `MySparkline.new(id, opts)` -- builds a widget node with typed props
- `MySparkline.push(widget, value:)` -- sends a command to the Rust extension
- `MySparkline.type_names/0`, `native_crate/0`, `rust_constructor/0` callbacks
- Compile-time validation of prop types, required declarations, and duplicates

```rust
// native/my_sparkline/src/lib.rs
use toddy_core::prelude::*;

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

Build with `mix toddy.build` (discovers extensions via the behaviour) or run
the renderer binary directly. The `ToddyAppBuilder` chains `.extension()` calls
in the generated `main.rs`:

```rust
toddy::run(
    ToddyAppBuilder::new()
        .extension(my_sparkline::SparklineExtension::new())
)
```

## Extension kinds

The macro supports two kinds:

### `:native_widget` -- Rust-backed extensions

Use `use Toddy.Extension, :native_widget` for widgets rendered by a Rust
crate. Requires `rust_crate` and `rust_constructor` declarations.

```elixir
defmodule MyApp.HexView do
  use Toddy.Extension, :native_widget

  widget :hex_view
  rust_crate "native/hex_view"
  rust_constructor "hex_view::HexViewExtension::new()"

  prop :data, :string, doc: "Binary data (base64)"
  prop :columns, :number, default: 16
end
```

### `:widget` -- Pure Elixir composite widgets

Use `use Toddy.Extension, :widget` for widgets composed entirely from
existing Toddy widgets. No Rust code needed. Must define a `render/2`
(or `render/3` if the widget accepts children) callback.

```elixir
defmodule MyApp.Card do
  use Toddy.Extension, :widget

  widget :card, container: true

  prop :title, :string
  prop :subtitle, :string, default: nil

  def render(props, children) do
    import Toddy.UI

    column padding: 16, spacing: 8 do
      text("ext_title", props.title, size: 20)
      if props.subtitle, do: text("ext_subtitle", props.subtitle, size: 14)
      children
    end
  end
end
```

## DSL reference

| Macro | Required | Description |
|---|---|---|
| `widget :name` | yes | Declares the widget type name (atom) |
| `widget :name, container: true` | -- | Marks the widget as accepting children |
| `prop :name, :type` | no | Declares a prop with type |
| `prop :name, :type, opts` | no | Options: `default:`, `doc:` |
| `command :name, params` | no | Declares a command (native widgets only) |
| `rust_crate "path"` | native only | Path to the Rust crate |
| `rust_constructor "expr"` | native only | Rust constructor expression |

### Supported prop types

`:number`, `:string`, `:boolean`, `:color`, `:length`, `:padding`,
`:alignment`, `:font`, `:style`, `:atom`, `:map`, `:any`, `{:list, inner}`


## Extension tiers

Not every extension needs the full trait. The `WidgetExtension` trait has
sensible defaults for all methods except `type_names`, `config_key`, and
`render`. Choose the tier that fits your widget:

### Tier A: render-only (~200 lines)

Implement `type_names`, `config_key`, and `render`. Everything else uses
defaults. Good for widgets that compose existing iced widgets (e.g.
`column`, `row`, `text`, `scrollable`, `container`) with no Rust-side
interaction state.

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
For example, a canvas-based plotting widget might handle pan/zoom entirely
in Rust while forwarding click events to Elixir as semantic `plot_click`
events.

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
`cleanup` for resource teardown when nodes are removed. Typical uses
include ring buffers fed by extension commands with canvas rendering,
generation-tracked cache invalidation, and custom `iced::advanced::Widget`
implementations with viewport state, hit testing, and pan/zoom persisted
in `ExtensionCaches`.

```rust
fn prepare(&mut self, node: &TreeNode, caches: &mut ExtensionCaches, theme: &Theme) {
    // Initialize or sync per-node state.
    // First arg is the namespace (typically config_key()), second is the node ID.
    let state = caches.get_or_insert::<SparklineState>(self.config_key(), &node.id, || {
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
            if let Some(state) = caches.get_mut::<SparklineState>(self.config_key(), node_id) {
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
    caches.remove(self.config_key(), node_id);
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
use toddy_core::message::Message;
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
use toddy_core::prelude::*;
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
        if let Some(data) = caches.get_mut::<SparklineData>(self.config_key(), node_id) {
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


## toddy-iced Widget trait guide

Extensions implementing `iced::advanced::Widget` directly (Tier C) need to
be aware of the toddy-iced API. Several methods changed names and signatures
from earlier versions.

### Key changes

**`on_event` is now `update`:**

```rust
// toddy-iced
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
`toddy_core::prelude`.

### Full Widget skeleton

```rust
use iced::advanced::widget::{self, Widget};
use iced::advanced::{layout, mouse, renderer, Clipboard, Layout, Shell};
use iced::event;
use iced::{Element, Length, Rectangle, Size, Theme};
use toddy_core::prelude::*;

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

The `toddy_core::prop_helpers` module (re-exported via `prelude::*`) provides
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

Test your extension's generated functions and callbacks:

```elixir
defmodule MySparklineTest do
  use ExUnit.Case

  test "type_names returns expected types" do
    assert MySparkline.type_names() == [:sparkline]
  end

  test "new/2 creates a widget struct" do
    widget = MySparkline.new("spark-1", color: "#ff0000")
    assert widget.id == "spark-1"
    assert widget.color == "#ff0000"
  end

  test "native_crate path exists" do
    assert File.dir?(MySparkline.native_crate())
  end
end
```

### Rust-side tests

Test pure logic functions, `handle_command`, and `prepare`/`cleanup` using
the helpers from `toddy_core::testing`:

```rust
#[cfg(test)]
mod tests {
    use toddy_core::testing::*;
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

        let state = caches.get::<SparklineState>("sparkline", "s-1").unwrap();
        assert_eq!(state.samples.len(), 1);
    }

    #[test]
    fn cleanup_removes_state() {
        let mut ext = SparklineExtension::new();
        let mut caches = ext_caches();

        let n = node("s-1", "sparkline");
        ext.prepare(&n, &mut caches, &iced::Theme::Dark);
        assert!(caches.contains("sparkline", "s-1"));

        ext.cleanup("s-1", &mut caches);
        assert!(!caches.contains("sparkline", "s-1"));
    }
}
```

### Render smoke testing

Use `widget_env_with()` from `toddy_core::testing` to construct a
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

### Testing with the pooled_mock backend

The pooled_mock backend (`:pooled_mock`) uses `Backend.Pooled` with a
shared renderer process. Standard test helpers like `click/1`,
`type_text/2`, etc. work with extension widget types out of the box --
the pooled backend infers events for known widget interaction patterns.

For integration tests that exercise the full wire protocol round-trip
(including extension commands), build a custom renderer with
`mix toddy.build` and use the `:headless` backend. See the
[Testing extensions](testing.md#testing-extensions) section in the
testing guide for the full workflow.


## ExtensionCaches

`ExtensionCaches` is type-erased storage keyed by `(namespace, key)` pairs.
The namespace is typically your extension's `config_key()`, and the key is
the node ID. This is the primary mechanism for persisting state between
`prepare`/`render`/`handle_event`/`handle_command` calls.

Key methods:

| Method | Signature | Notes |
|---|---|---|
| `get::<T>(ns, key)` | `-> Option<&T>` | Immutable access |
| `get_mut::<T>(ns, key)` | `-> Option<&mut T>` | Mutable access |
| `get_or_insert::<T>(ns, key, default_fn)` | `-> &mut T` | Initialize if absent. Replaces on type mismatch. |
| `insert::<T>(ns, key, value)` | `-> ()` | Overwrites existing |
| `remove(ns, key)` | `-> bool` | Returns whether key existed |
| `contains(ns, key)` | `-> bool` | |
| `remove_namespace(ns)` | `-> ()` | Remove all entries for a namespace |

Common keying patterns:

- **Per-node state:** `caches.get::<MyState>(self.config_key(), &node.id)`
- **Per-node sub-keys:** `caches.get::<GenerationCounter>(self.config_key(), &format!("{}:gen", node.id))`
- **Global extension state:** `caches.get::<GlobalConfig>(self.config_key(), "_global")`

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


## Publishing widget packages

Widget packages come in two tiers:

1. **Pure Elixir** -- compose existing primitives (canvas, column, container,
   etc.) into higher-level widgets. Works with prebuilt renderer binaries.
   No Rust toolchain needed.
2. **Elixir + Rust** -- custom native rendering via a `WidgetExtension`
   trait. Requires a Rust toolchain to compile a custom renderer binary.

The rest of this section covers Tier 1 (pure Elixir packages). For Tier 2,
see the extension quick start and trait reference above.

### When pure Elixir is enough

Canvas + Shape builders cover custom 2D rendering: charts, diagrams,
gauges, sparklines, colour pickers, drawing tools. The overlay widget
enables dropdowns, popovers, and context menus. Style maps provide
per-instance visual customization. Composition of layout primitives
(column, row, container, stack) covers cards, tab bars, sidebars, toolbars,
and other structural patterns.

See [composition-patterns.md](composition-patterns.md) for examples.

Pure Elixir falls short when you need: custom text layout engines, GPU
shaders, platform-native controls (e.g. a native file tree), or
performance-critical rendering that canvas can't handle efficiently.

### Package structure

A toddy widget package is a standard Mix project:

```
my_widget/
  lib/
    my_widget.ex              # public API (convenience constructors)
    my_widget/
      donut_chart.ex          # widget struct + Widget protocol impl
  test/
    my_widget/
      donut_chart_test.exs    # struct, builder, and to_node tests
  mix.exs
```

#### mix.exs

```elixir
defmodule MyWidget.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_widget,
      version: "0.1.0",
      elixir: "~> 1.16",
      deps: deps()
    ]
  end

  defp deps do
    [
      {:toddy, "~> 0.3"}
    ]
  end
end
```

toddy is a compile-time dependency. Your package does not need the renderer
binary -- it only uses toddy's Elixir modules (`Toddy.Iced.Widget`,
`Toddy.Iced.Widget.Build`, `Toddy.Iced.Encode`, type modules).

### Building a widget

Implement the `Toddy.Iced.Widget` protocol on your struct. The `to_node/1`
implementation composes existing built-in node types. The renderer handles
them without modification.

#### Example: DonutChart

A ring chart rendered via canvas:

```elixir
defmodule MyWidget.DonutChart do
  @moduledoc """
  A donut chart widget rendered via canvas.

  ## Usage

      DonutChart.new("revenue", [
        {"Product A", 45.0, "#3498db"},
        {"Product B", 30.0, "#e74c3c"},
        {"Product C", 25.0, "#2ecc71"}
      ], size: 200, thickness: 40)
      |> DonutChart.build()
  """

  alias Toddy.Iced.Widget.Build
  alias Toddy.Canvas.Shape

  @type segment :: {label :: String.t(), value :: number(), color :: String.t()}

  @type option ::
          {:size, number()}
          | {:thickness, number()}
          | {:background, Toddy.Iced.Color.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          segments: [segment()],
          size: number(),
          thickness: number(),
          background: Toddy.Iced.Color.t() | nil
        }

  defstruct [:id, :segments, size: 200, thickness: 40, background: nil]

  @spec new(id :: String.t(), segments :: [segment()], opts :: [option()]) :: t()
  def new(id, segments, opts \\ []) when is_binary(id) and is_list(segments) do
    %__MODULE__{id: id, segments: segments} |> with_options(opts)
  end

  @spec size(donut_chart :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = chart, size), do: %{chart | size: size}

  @spec thickness(donut_chart :: t(), thickness :: number()) :: t()
  def thickness(%__MODULE__{} = chart, thickness), do: %{chart | thickness: thickness}

  @spec background(donut_chart :: t(), color :: Toddy.Iced.Color.t()) :: t()
  def background(%__MODULE__{} = chart, color) do
    %{chart | background: Toddy.Iced.Color.cast(color)}
  end

  @spec with_options(donut_chart :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = chart, []), do: chart

  def with_options(%__MODULE__{} = chart, opts) do
    Enum.reduce(opts, chart, fn
      {:size, v}, acc -> size(acc, v)
      {:thickness, v}, acc -> thickness(acc, v)
      {:background, v}, acc -> background(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @spec build(donut_chart :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = chart), do: Toddy.Iced.Widget.to_node(chart)

  # -- Widget protocol --

  defimpl Toddy.Iced.Widget do
    def to_node(chart) do
      layers = %{"arcs" => build_arc_shapes(chart)}

      props =
        %{"layers" => layers, "width" => chart.size, "height" => chart.size}
        |> Toddy.Iced.Widget.Build.put_if(chart.background, "background")

      %{id: chart.id, type: "canvas", props: props, children: []}
    end

    defp build_arc_shapes(chart) do
      total = chart.segments |> Enum.map(&elem(&1, 1)) |> Enum.sum()
      if total == 0, do: throw(:empty)

      r = chart.size / 2
      inner_r = r - chart.thickness

      {shapes, _} =
        Enum.reduce(chart.segments, {[], -:math.pi() / 2}, fn {_label, value, color}, {acc, start} ->
          sweep = value / total * 2 * :math.pi()
          stop = start + sweep

          arc_shape =
            Shape.path(
              [
                Shape.arc(r, r, r, start, stop),
                Shape.line_to(
                  r + inner_r * :math.cos(stop),
                  r + inner_r * :math.sin(stop)
                ),
                Shape.arc(r, r, inner_r, stop, start),
                Shape.close()
              ],
              fill: color
            )

          {[arc_shape | acc], stop}
        end)

      Enum.reverse(shapes)
    catch
      :throw, :empty -> []
    end
  end
end
```

Key points:

- The struct follows toddy's builder pattern.
- `to_node/1` emits a `"canvas"` node with `"layers"` -- a type the stock
  renderer already handles.
- No Rust code. No custom node types. The renderer sees a canvas widget.
- Color builders call `Color.cast/1` to normalize input.

#### Convenience constructors

For consumer ergonomics, add a top-level module with functions that mirror
the `Toddy.UI` / `Toddy.Iced` calling conventions:

```elixir
defmodule MyWidget do
  alias MyWidget.DonutChart

  @doc "Creates a donut chart node."
  @spec donut_chart(id :: String.t(), segments :: [DonutChart.segment()], opts :: Keyword.t()) ::
          Toddy.Iced.ui_node()
  def donut_chart(id, segments, opts \\ []) do
    DonutChart.new(id, segments, opts) |> DonutChart.build()
  end
end
```

Consumers use it like any other widget:

```elixir
import Toddy.UI

column do
  text("Revenue breakdown")
  MyWidget.donut_chart("revenue", model.segments, size: 300)
end
```

The result of `donut_chart/3` is a plain `ui_node()` map. It composes
naturally with `Toddy.UI` do-blocks, `Column.push/2`, or any other tree
builder.

### Testing widget packages

#### Unit tests (no renderer needed)

Test the struct, builders, and `to_node/1` output directly:

```elixir
defmodule MyWidget.DonutChartTest do
  use ExUnit.Case, async: true

  alias MyWidget.DonutChart

  test "new/3 creates struct with defaults" do
    chart = DonutChart.new("c1", [{"A", 50, "#ff0000"}])
    assert chart.id == "c1"
    assert chart.size == 200
    assert chart.thickness == 40
  end

  test "build/1 produces a canvas node" do
    node = DonutChart.new("c1", [{"A", 50, "#ff0000"}]) |> DonutChart.build()
    assert node.type == "canvas"
    assert node.id == "c1"
    assert is_map(node.props["layers"])
  end
end
```

#### Integration tests with pooled_mock backend

For testing widget behaviour in a running app, use toddy's pooled_mock
backend:

```elixir
defmodule MyWidget.IntegrationTest do
  use Toddy.Test.Case, async: true

  defmodule ChartApp do
    @behaviour Toddy.App

    def init(_opts), do: %{segments: [{"A", 50, "#ff0000"}, {"B", 50, "#0000ff"}]}
    def update(model, _event), do: model

    def view(model) do
      import Toddy.UI
      window "main" do
        MyWidget.donut_chart("chart", model.segments, size: 200)
      end
    end
  end

  test "chart renders in the tree" do
    session = start!(ChartApp)
    element = find!(session, "#chart")
    assert element.type == "canvas"
  end
end
```

### What consumers need to know

Document these in your package README:

1. **Minimum toddy version.** Your package depends on toddy; specify the
   compatible range.
2. **No renderer changes needed.** Pure Elixir packages work with the stock
   toddy binary. Consumers do not need to rebuild anything.
3. **Which built-in features are required.** If your widget uses canvas,
   consumers need the feature enabled (it is by default). Document this if
   it matters.

### Limitations of pure Elixir packages

- **No custom node types.** Your `to_node/1` must emit node types the stock
  renderer understands (`canvas`, `column`, `container`, etc.).
- **Canvas performance ceiling.** Complex canvas scenes (thousands of shapes,
  60fps animation) may hit limits.
- **No access to iced internals.** You cannot customize widget state
  continuity, keyboard focus, accessibility, or rendering internals.
- **Overlay requires the overlay node type.** If your widget needs popover
  behaviour, it depends on the `overlay` node type being available.
