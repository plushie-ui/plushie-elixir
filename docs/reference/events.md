# Events Reference

All user interactions, system responses, and asynchronous results are
delivered to your `c:Plushie.App.update/2` callback as typed structs
under the `Plushie.Event` namespace.

This page is a comprehensive reference. For a gentler introduction,
see the [Events guide](../guides/05-events.md).

## Event union type

`t:Plushie.Event.t/0` is a union of every event struct the runtime can
produce. `t:Plushie.Event.delivered_t/0` is the narrower subset that
guarantees fields like `window_id` are non-nil (events that came from
the renderer rather than being hand-constructed in tests).

Use the union type when writing generic event-handling helpers. For
`update/2` clauses, pattern-match on the concrete struct directly.

## Event taxonomy

| Category           | Struct                                          | Source                                   |
| ------------------ | ----------------------------------------------- | ---------------------------------------- |
| Widget interaction | `Plushie.Event.WidgetEvent`                     | Renderer (widget callbacks)              |
| Keyboard           | `Plushie.Event.KeyEvent`                        | Subscription (key press/release)         |
| Modifier state     | `Plushie.Event.ModifiersEvent`                  | Subscription (modifier change)           |
| Mouse              | `Plushie.Event.MouseEvent`                      | Subscription (global mouse)              |
| Touch              | `Plushie.Event.TouchEvent`                      | Subscription (touchscreen)               |
| IME                | `Plushie.Event.ImeEvent`                        | Subscription (input method editor)       |
| Window lifecycle   | `Plushie.Event.WindowEvent`                     | Renderer (open, close, resize, etc.)     |
| System             | `Plushie.Event.SystemEvent`                     | Renderer (queries, theme, diagnostics)   |
| Timer              | `Plushie.Event.TimerEvent`                      | Subscription (`every/2`)                 |
| Async result       | `Plushie.Event.AsyncEvent`                      | Command (`async/2`)                      |
| Stream value       | `Plushie.Event.StreamEvent`                     | Command (`stream/2`)                     |
| Effect response    | `Plushie.Event.EffectEvent`                     | Renderer (file dialogs, clipboard, etc.) |
| Widget cmd error   | `Plushie.Event.WidgetCommandError`              | Renderer (native widget command failure) |

## WidgetEvent built-in types

Every built-in `:type` atom, its payload carrier, and a short description.
Carrier indicates where data lands in the `Plushie.Event.WidgetEvent` struct:
**none** (no payload), **value** (`value` field), or **data** (`data` field as
an atom-keyed map).

### Standard widget events

| Type               | Carrier | Description                                |
| ------------------ | ------- | ------------------------------------------ |
| `:click`           | none    | Button pressed                             |
| `:input`           | value (string) | Text input changed                  |
| `:submit`          | value (string) | Text input submitted (Enter)        |
| `:toggle`          | value (boolean) | Toggler/checkbox toggled           |
| `:select`          | value (any) | Pick list / combo box selection         |
| `:slide`           | value (number) | Slider moved                        |
| `:slide_release`   | value (number) | Slider released at final value      |
| `:paste`           | value (string) | Paste action on a text input        |
| `:open`            | none    | Expandable opened                          |
| `:close`           | none    | Expandable closed                          |
| `:option_hovered`  | value (any) | Pick list option hovered                |
| `:key_binding`     | data    | Key binding activated (empty data map)     |
| `:sort`            | data    | Table column sort requested (`column`)     |
| `:scroll`          | data    | Scroll position changed (`absolute_x`, `absolute_y`, `relative_x`, `relative_y`) |
| `:pane_focus_cycle` | none   | Pane focus cycle requested                 |
| `:transition_complete` | value (any) | Emitted when a renderer-side transition completes (requires `on_complete: tag`) |

### Canvas events

Canvas-level interaction events. These target the canvas widget itself.

| Type               | Carrier | Fields                                     |
| ------------------ | ------- | ------------------------------------------ |
| `:canvas_press`    | data    | `x`, `y`, `button`                        |
| `:canvas_release`  | data    | `x`, `y`, `button`                        |
| `:canvas_move`     | data    | `x`, `y`                                  |
| `:canvas_scroll`   | data    | `x`, `y`, `delta_x`, `delta_y`            |
| `:canvas_focused`  | none    |                                            |
| `:canvas_blurred`  | none    |                                            |
| `:canvas_group_focused` | none |                                          |
| `:canvas_group_blurred` | none |                                          |

### Canvas element events

Events targeting specific interactive elements inside a canvas widget.

| Type                           | Carrier | Fields                              |
| ------------------------------ | ------- | ----------------------------------- |
| `:canvas_element_enter`        | data    | `element_id`, `x`, `y`             |
| `:canvas_element_leave`        | data    | `element_id`                        |
| `:canvas_element_click`        | data    | `element_id`, `x`, `y`, `button`   |
| `:canvas_element_key_press`    | data    | `key`, `modifiers`, `text`          |
| `:canvas_element_key_release`  | data    | `key`, `modifiers`                  |
| `:canvas_element_drag`         | data    | `x`, `y`, `dx`, `dy`               |
| `:canvas_element_drag_end`     | data    | `element_id`, `x`, `y`             |
| `:canvas_element_focused`      | data    | `element_id`                        |
| `:canvas_element_blurred`      | data    | `element_id`                        |

> Canvas-internal events (all `canvas_*` and `canvas_element_*` types) that
> are not intercepted by a widget `handle_event/2` callback are auto-consumed
> by the runtime and never reach `update/2`.

### Mouse area events

Events from `mouse_area` containers.

| Type                    | Carrier | Fields                              |
| ----------------------- | ------- | ----------------------------------- |
| `:mouse_right_press`    | none    |                                     |
| `:mouse_right_release`  | none    |                                     |
| `:mouse_middle_press`   | none    |                                     |
| `:mouse_middle_release` | none    |                                     |
| `:mouse_double_click`   | none    |                                     |
| `:mouse_enter`          | none    |                                     |
| `:mouse_exit`           | none    |                                     |
| `:mouse_move`           | data    | `x`, `y`                           |
| `:mouse_scroll`         | data    | `delta_x`, `delta_y`               |

### Sensor events

| Type              | Carrier | Fields                                  |
| ----------------- | ------- | --------------------------------------- |
| `:sensor_resize`  | data    | `width`, `height`                       |

### Pane grid events

| Type              | Carrier | Fields                                  |
| ----------------- | ------- | --------------------------------------- |
| `:pane_resized`   | data    | `split`, `ratio`                        |
| `:pane_dragged`   | data    | `pane`, `target`, `action`, `region`, `edge` |
| `:pane_clicked`   | data    | `pane`                                  |

### Custom widget event types

Custom widgets declare events with the `event` macro. Their `:type` field
uses a `{widget_type, event_name}` tuple instead of a bare atom:

```elixir
%WidgetEvent{type: {:color_picker, :change}, id: "picker", data: %{hue: 180}}
```

The carrier (value vs. data) and field types are defined by the widget's
`event` declaration. See `Plushie.Widget` for details.

## Struct reference

### `Plushie.Event.WidgetEvent`

The workhorse event struct. Covers all widget interactions: buttons,
inputs, sliders, canvas, mouse areas, sensors, panes, and custom widgets.

| Field       | Type                         | Description                          |
| ----------- | ---------------------------- | ------------------------------------ |
| `type`      | `atom \| {atom, atom}`       | Event family (see tables above)      |
| `id`        | `String.t()`                 | Widget ID                            |
| `scope`     | `[String.t()]`               | Ancestor scope chain (nearest first) |
| `value`     | `term() \| nil`              | Scalar payload                       |
| `data`      | `map() \| nil`               | Structured payload (atom keys)       |
| `window_id` | `String.t() \| nil`          | Source window                        |

### `Plushie.Event.KeyEvent`

Keyboard press and release events from subscriptions.

| Field          | Type                              | Description                      |
| -------------- | --------------------------------- | -------------------------------- |
| `type`         | `:press \| :release`              | Key action                       |
| `key`          | `atom() \| String.t()`           | Logical key                      |
| `modified_key` | `atom() \| String.t() \| nil`    | Key with modifiers applied       |
| `physical_key` | `atom() \| String.t() \| nil`    | Physical scan code               |
| `location`     | `:standard \| :left \| :right \| :numpad` | Key location              |
| `modifiers`    | `Plushie.KeyModifiers.t()`        | Modifier state                   |
| `text`         | `String.t() \| nil`              | Text produced by key             |
| `repeat`       | `boolean()`                       | Whether this is a repeat event   |
| `captured`     | `boolean()`                       | Whether a subscription captured  |
| `window_id`    | `String.t() \| nil`              | Source window                    |

#### KeyModifiers

The `modifiers` field is a `Plushie.KeyModifiers` struct with boolean
fields:

| Field | Purpose |
|---|---|
| `ctrl` | Control key |
| `shift` | Shift key |
| `alt` | Alt key (Option on macOS) |
| `logo` | Logo/Super key (Windows key, Command on macOS) |
| `command` | **Platform-aware**: Ctrl on Linux/Windows, Cmd on macOS |

`command` is the one to use for cross-platform shortcuts. Match on
`command: true` and it works on all platforms.

Helper functions `ctrl?/1`, `shift?/1`, `alt?/1`, `logo?/1`,
`command?/1` are available for readable conditionals.

### `Plushie.Event.ModifiersEvent`

Modifier state change event. Fires when the set of held modifiers changes.

| Field       | Type                       | Description               |
| ----------- | -------------------------- | ------------------------- |
| `modifiers` | `Plushie.KeyModifiers.t()` | Current modifier state    |
| `captured`  | `boolean()`                | Subscription captured     |
| `window_id` | `String.t() \| nil`       | Source window             |

### `Plushie.Event.MouseEvent`

Global mouse events from subscriptions.

| Field       | Type                                                | Description          |
| ----------- | --------------------------------------------------- | -------------------- |
| `type`      | `:moved \| :entered \| :left \| :button_pressed \| :button_released \| :wheel_scrolled` | Mouse action |
| `x`, `y`   | `number() \| nil`                                   | Cursor position      |
| `button`    | `:left \| :right \| :middle \| :back \| :forward \| nil` | Button involved |
| `delta_x`, `delta_y` | `number() \| nil`                           | Scroll delta         |
| `unit`      | `:line \| :pixel \| nil`                            | Scroll unit          |
| `captured`  | `boolean()`                                         | Subscription captured|
| `window_id` | `String.t() \| nil`                                | Source window        |

### `Plushie.Event.TouchEvent`

Touchscreen events from subscriptions.

| Field       | Type                                   | Description                |
| ----------- | -------------------------------------- | -------------------------- |
| `type`      | `:pressed \| :moved \| :lifted \| :lost` | Touch phase             |
| `finger_id` | `term()`                              | Finger identifier          |
| `x`, `y`   | `number()`                             | Touch position             |
| `captured`  | `boolean()`                            | Subscription captured      |
| `window_id` | `String.t() \| nil`                   | Source window              |

### `Plushie.Event.ImeEvent`

Input Method Editor events from subscriptions. Lifecycle:
`:opened` -> `:preedit` (repeated) -> `:commit` -> `:closed`.

| Field       | Type                                          | Description               |
| ----------- | --------------------------------------------- | ------------------------- |
| `type`      | `:opened \| :preedit \| :commit \| :closed`  | IME phase                 |
| `id`        | `String.t() \| nil`                           | Target widget ID          |
| `scope`     | `[String.t()]`                                | Ancestor scope chain      |
| `text`      | `String.t() \| nil`                           | Composition/commit text   |
| `cursor`    | `{start, end} \| nil`                         | Byte offsets in preedit   |
| `captured`  | `boolean()`                                   | Subscription captured     |
| `window_id` | `String.t() \| nil`                           | Source window             |

### `Plushie.Event.WindowEvent`

Window lifecycle events from the renderer.

| Field          | Type                           | Description                     |
| -------------- | ------------------------------ | ------------------------------- |
| `type`         | see below                      | Window event kind               |
| `window_id`    | `String.t()`                   | Window identifier               |
| `x`, `y`       | `number() \| nil`             | Position (for `:moved`)         |
| `width`, `height` | `number() \| nil`          | Size (for `:resized`)          |
| `position`     | `{number(), number()} \| nil`  | Window position tuple           |
| `path`         | `String.t() \| nil`           | File path (for file drop)       |
| `scale_factor` | `number() \| nil`             | DPI scale (for `:rescaled`)     |

Window event types: `:opened`, `:closed`, `:close_requested`, `:moved`,
`:resized`, `:focused`, `:unfocused`, `:rescaled`, `:file_hovered`,
`:file_dropped`, `:files_hovered_left`.

### `Plushie.Event.SystemEvent`

System query responses and platform events.

| Field  | Type                               | Description                      |
| ------ | ---------------------------------- | -------------------------------- |
| `type` | see below                          | System event kind                |
| `tag`  | `String.t() \| nil`               | Correlation tag from the query   |
| `data` | `map() \| String.t() \| number() \| nil` | Payload (shape depends on type) |

System event types: `:system_info`, `:system_theme`, `:animation_frame`,
`:theme_changed`, `:all_windows_closed`, `:image_list`, `:tree_hash`,
`:find_focused`, `:diagnostic`, `:announce`, `:error`.

### `Plushie.Event.TimerEvent`

Timer tick events from `Plushie.Subscription.every/2`.

| Field       | Type         | Description                        |
| ----------- | ------------ | ---------------------------------- |
| `tag`       | `atom()`     | User-defined tag from subscription |
| `timestamp` | `integer()`  | Monotonic timestamp in ms          |

### `Plushie.Event.AsyncEvent`

Results from `Plushie.Command.async/2` tasks.

| Field    | Type                              | Description        |
| -------- | --------------------------------- | ------------------ |
| `tag`    | `atom()`                          | User-defined tag   |
| `result` | `{:ok, term()} \| {:error, term()}` | Task result     |

### `Plushie.Event.StreamEvent`

Intermediate values from `Plushie.Command.stream/2` tasks.

| Field   | Type      | Description             |
| ------- | --------- | ----------------------- |
| `tag`   | `atom()`  | User-defined tag        |
| `value` | `term()`  | Emitted stream value    |

### `Plushie.Event.EffectEvent`

Platform effect responses (file dialogs, clipboard, notifications).

| Field    | Type                                          | Description        |
| -------- | --------------------------------------------- | ------------------ |
| `tag`    | `atom()`                                      | User-defined tag   |
| `result` | `{:ok, term()} \| :cancelled \| {:error, term()}` | Effect result |

The `:cancelled` result is a normal outcome (user dismissed a dialog),
not an error.

### `Plushie.Event.WidgetCommandError`

Renderer error for a native widget command.

| Field       | Type                | Description                     |
| ----------- | ------------------- | ------------------------------- |
| `reason`    | `String.t()`        | Machine-readable reason         |
| `node_id`   | `String.t() \| nil` | Target widget node ID          |
| `op`        | `String.t() \| nil` | Command operation name         |
| `extension` | `String.t() \| nil` | Native widget type             |
| `message`   | `String.t() \| nil` | Human-readable error text      |

## Pattern matching cookbook

### Match by widget ID

```elixir
def update(model, %WidgetEvent{type: :click, id: "save"}) do
  save(model)
end
```

### Match by type with payload

```elixir
def update(model, %WidgetEvent{type: :input, id: "search", value: text}) do
  %{model | query: text}
end

def update(model, %WidgetEvent{type: :toggle, id: "dark_mode", value: on?}) do
  %{model | dark_mode: on?}
end

def update(model, %WidgetEvent{type: :slide, id: "volume", value: level}) do
  %{model | volume: level}
end
```

### Match by scope (dynamic lists)

When items are rendered in a named container with a dynamic ID, the
container's ID appears in the event's scope:

```elixir
def update(model, %WidgetEvent{type: :click, id: "delete", scope: [item_id | _]}) do
  %{model | items: Map.delete(model.items, item_id)}
end
```

### Match key with modifiers

```elixir
def update(model, %KeyEvent{type: :press, key: "s", modifiers: %{command: true}}) do
  save(model)
end

def update(model, %KeyEvent{type: :press, key: :escape}) do
  close_dialog(model)
end
```

### Match custom widget event

```elixir
def update(model, %WidgetEvent{type: {:color_picker, :change}, data: %{hue: h}}) do
  %{model | hue: h}
end
```

### Match async result

```elixir
def update(model, %AsyncEvent{tag: :fetch, result: {:ok, data}}) do
  %{model | items: data, loading: false}
end

def update(model, %AsyncEvent{tag: :fetch, result: {:error, reason}}) do
  %{model | error: reason, loading: false}
end
```

### Match stream values

```elixir
def update(model, %StreamEvent{tag: :download, value: %{progress: pct}}) do
  %{model | progress: pct}
end
```

### Match effect result

```elixir
def update(model, %EffectEvent{tag: :open_file, result: {:ok, %{path: path}}}) do
  load_file(model, path)
end

def update(model, %EffectEvent{tag: :open_file, result: :cancelled}) do
  model
end
```

### Match timer tick

```elixir
def update(model, %TimerEvent{tag: :tick}) do
  %{model | ticks: model.ticks + 1}
end
```

### Match window events

```elixir
def update(model, %WindowEvent{type: :close_requested, window_id: wid}) do
  close_window(model, wid)
end

def update(model, %WindowEvent{type: :resized, width: w, height: h}) do
  %{model | width: w, height: h}
end
```

### Reconstruct the full scoped path

`Plushie.Event.target/1` reconstructs the forward-order path from
`id` and `scope`:

```elixir
event = %WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar"]}
Plushie.Event.target(event)
# => "sidebar/form/save"
```

### Catch-all clause

Always include a catch-all as the last `update/2` clause:

```elixir
def update(model, _event), do: model
```

## Event flow

Events travel through a fixed pipeline before reaching your `update/2`:

1. **Renderer** - the renderer detects a user interaction and
   encodes an event message.
2. **Bridge** - `Plushie.Bridge` receives the wire frame, decodes
   it via `Plushie.Protocol`, and forwards the struct to the runtime.
3. **Runtime** - `Plushie.Runtime` receives the event. If the
   event targets a widget with a registered `handle_event/2`
   callback, the runtime walks the scope chain (innermost widget
   handler first) before delivering to the app. Widget handlers
   can emit, transform, consume, or ignore events.
4. **App** - your `update/2` receives the event (unless a widget
   handler consumed it).

### Coalescable events

High-frequency events (global mouse moves with `MouseEvent`
`type: :moved`, and sensor resizes with `WidgetEvent`
`type: :sensor_resize`) are coalescable. When multiple events of
the same type arrive for the same source before the runtime processes
them, only the latest is delivered. This prevents queue backup during
rapid mouse movement or window resizing. A zero-delay timer ensures
coalescable events are flushed before the next non-coalescable event,
preserving relative ordering.

### Widget handler interception

Custom widgets with `handle_event/2` callbacks are registered in a
handler registry derived from the current view tree. When an event
arrives, the runtime checks the scope chain for registered handlers.
Each handler can return:

- `{:emit, family, data}` - transform and re-emit as a new event
- `{:update_state, new_state}` - update widget state, suppress event
- `:ignored` - pass through to the next handler
- `:consumed` - suppress the event entirely

Render-only widgets (no events, no state) are skipped in the registry
and have zero overhead in the event path.

## See also

- [Events](../guides/05-events.md) - events, pattern matching, and the event log
- [Subscriptions](../guides/10-subscriptions.md) - keyboard, timer, and other event sources
- [Scoped IDs](scoped-ids.md) - how container scoping affects event IDs
- [Commands](commands.md) - the command structs that produce async/effect events
