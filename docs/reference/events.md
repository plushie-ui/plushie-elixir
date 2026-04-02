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
| Pointer (mouse)    | `Plushie.Event.WidgetEvent`                     | Subscription (global pointer)            |
| Pointer (touch)    | `Plushie.Event.WidgetEvent`                     | Subscription (touchscreen)               |
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
| `:scrolled`        | data    | Scrollable viewport offset changed (`absolute_x`, `absolute_y`, `relative_x`, `relative_y`, `bounds`, `content_bounds`) |
| `:pane_focus_cycle` | none   | Pane focus cycle requested                 |
| `:transition_complete` | value (any) | Emitted when a renderer-side transition completes (requires `on_complete: tag`) |

### Pointer events

Unified pointer events for canvas-level, pointer area, and sensor
interactions. These replace the previous `canvas_*`, `mouse_*`, and
`sensor_*` families with a device-agnostic model. The `pointer` field
identifies the input device (`:mouse`, `:touch`, `:pen`) and `button`
identifies which button was involved.

| Type              | Carrier | Fields                                              |
| ----------------- | ------- | --------------------------------------------------- |
| `:press`          | data    | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `:release`        | data    | `x`, `y`, `button`, `pointer`, `finger`, `modifiers` |
| `:move`           | data    | `x`, `y`, `pointer`, `finger`, `modifiers`           |
| `:scroll` | data    | `x`, `y`, `delta_x`, `delta_y`, `pointer`, `modifiers` |
| `:enter`          | none    |                                                       |
| `:exit`           | none    |                                                       |
| `:double_click`   | data    | `x`, `y`, `pointer`, `modifiers`                     |
| `:resize`         | data    | `width`, `height`                                     |

The `button` field is one of `:left`, `:right`, `:middle`, `:back`,
`:forward`. The `pointer` field is one of `:mouse`, `:touch`, `:pen`.
The `finger` field is an integer for touch events, nil otherwise.
`modifiers` is a `Plushie.KeyModifiers` struct.

Note: `:scroll` is pointer input (wheel delta at coordinates).
`:scrolled` (in the standard widget events table above) is container
state: a scrollable widget reporting its viewport offset changed.

### Generic element events

Focus, blur, drag, and key events emitted by interactive elements
(canvas groups, widgets, etc.). Canvas element clicks are regular
`:click` events with the canvas ID in scope. See the [Canvas
reference](canvas.md#element-level-events) for details.

| Type                | Carrier | Fields                              |
| ------------------- | ------- | ----------------------------------- |
| `:focused`          | none    |                                     |
| `:blurred`          | none    |                                     |
| `:drag`             | data    | `x`, `y`, `delta_x`, `delta_y`     |
| `:drag_end`         | data    | `x`, `y`                            |
| `:key_press`        | data    | `key`, `modifiers`, `text`          |
| `:key_release`      | data    | `key`, `modifiers`                  |

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
inputs, sliders, canvas, pointer areas, sensors, panes, and custom widgets.

| Field       | Type                         | Description                          |
| ----------- | ---------------------------- | ------------------------------------ |
| `type`      | `atom \| {atom, atom}`       | Event family (see tables above)      |
| `id`        | `String.t()`                 | Widget ID                            |
| `scope`     | `[String.t()]`               | Ancestor scope chain (nearest first, window last) |
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

### Subscription pointer events

Global mouse and touch subscription events are delivered as
`Plushie.Event.WidgetEvent` structs where `id` is the window ID
(or `"__global__"` when no window context) and `scope` is `[]`.

**Mouse move** (`cursor_moved`): `%WidgetEvent{type: :move, data: %{x, y, pointer: :mouse, captured, modifiers}}`

**Cursor enter/exit**: `%WidgetEvent{type: :enter | :exit, data: %{captured}}`

**Button press/release** (`button_pressed`, `button_released`):
`%WidgetEvent{type: :press | :release, data: %{button, pointer: :mouse, x: nil, y: nil, captured, modifiers}}`

**Scroll** (`wheel_scrolled`):
`%WidgetEvent{type: :scroll, data: %{delta_x, delta_y, unit, pointer: :mouse, captured, modifiers}}`

**Touch press** (`finger_pressed`):
`%WidgetEvent{type: :press, data: %{pointer: :touch, finger, x, y, button: :left, captured, modifiers}}`

**Touch move** (`finger_moved`):
`%WidgetEvent{type: :move, data: %{pointer: :touch, finger, x, y, captured, modifiers}}`

**Touch release** (`finger_lifted`):
`%WidgetEvent{type: :release, data: %{pointer: :touch, finger, x, y, button: :left, captured, modifiers}}`

**Touch lost** (`finger_lost`):
`%WidgetEvent{type: :release, data: %{pointer: :touch, finger, x, y, button: :left, lost: true, captured, modifiers}}`

### `Plushie.Event.ImeEvent`

Input Method Editor events from subscriptions. Lifecycle:
`:opened` -> `:preedit` (repeated) -> `:commit` -> `:closed`.

| Field       | Type                                          | Description               |
| ----------- | --------------------------------------------- | ------------------------- |
| `type`      | `:opened \| :preedit \| :commit \| :closed`  | IME phase                 |
| `id`        | `String.t() \| nil`                           | Target widget ID          |
| `scope`     | `[String.t()]`                                | Ancestor scope chain (nearest first, window last) |
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

### Match pointer event with device type

```elixir
# Mouse click
def update(model, %WidgetEvent{type: :press, id: "area",
    data: %{pointer: :mouse, button: :left}}) do
  select(model)
end

# Touch press
def update(model, %WidgetEvent{type: :press, id: "area",
    data: %{pointer: :touch, finger: finger_id}}) do
  touch_start(model, finger_id)
end
```

### Match pointer event with modifiers

```elixir
# Shift-click for multi-select
def update(model, %WidgetEvent{type: :press, id: "item",
    data: %{modifiers: %{shift: true}}}) do
  add_to_selection(model)
end

# Ctrl-drag for special behaviour
def update(model, %WidgetEvent{type: :move, id: "canvas",
    data: %{x: x, y: y, modifiers: %{ctrl: true}}}) do
  pan(model, x, y)
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
event = %WidgetEvent{type: :click, id: "save", scope: ["form", "sidebar", "main"], window_id: "main"}
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

High-frequency events (pointer moves with `WidgetEvent`
`type: :move`, and resize events with `WidgetEvent`
`type: :resize`) are coalescable. When multiple events of
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
