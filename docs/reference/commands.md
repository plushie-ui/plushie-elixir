# Commands and Effects

Commands are pure data returned from `update/2` and `init/1`. The
runtime executes them after the update cycle completes. They are how
your app triggers side effects: background work, focus changes, window
operations, platform effects, and more.

See `Plushie.Command` for full API docs and `Plushie.Effect` for
platform effect functions.

## Returning commands

`update/2` and `init/1` support three return forms:

```elixir
# Bare model (no commands)
def update(model, _event), do: model

# Model + single command
def update(model, %WidgetEvent{type: :click, id: "save"}) do
  {model, Command.focus("editor")}
end

# Model + command list
def update(model, %WidgetEvent{type: :click, id: "export"}) do
  {model, [
    Effect.file_save(:export, title: "Export"),
    Effect.notification(:notify, "Exporting", "Saving to file...")
  ]}
end
```

Invalid return shapes (e.g. `{model, :ok}` or 3-element tuples) raise
`ArgumentError` immediately. See
[App Lifecycle](app-lifecycle.md#return-value-validation) for details.

## Command categories

All functions live in `Plushie.Command` unless noted otherwise.

### Control flow

| Function | Purpose |
|---|---|
| `none/0` | No-op command (useful in conditional pipelines) |
| `done/2` | Lift a value into the command pipeline. Calls `mapper.(value)` and queues the result for `update/2` in the next message cycle, no task spawned. |
| `batch/1` | Execute a list of commands sequentially |
| `exit/0` | Shut down the app |

`batch/1` executes commands in order via `Enum.reduce`. Each command
threads through the runtime state sequentially. Use it to combine
multiple side effects from a single `update/2` clause.

### Async

| Function | Purpose |
|---|---|
| `async/2` | Run a function in a background Task. Result delivered as `%AsyncEvent{tag: tag, result: result}`. |
| `stream/2` | Run a function with an `emit` callback. Each `emit.(value)` delivers `%StreamEvent{tag: tag, value: value}`. Final return delivered as `%AsyncEvent{}`. |
| `cancel/1` | Kill an in-flight async or stream task by tag. |
| `send_after/2` | One-shot delayed event. Sends `event` through `update/2` after `delay_ms` milliseconds. If a timer with the same event is already pending, the old one is cancelled. |

`send_after/2` is a one-shot timer (fires once). For recurring timers,
use `Plushie.Subscription.every/2` instead.

### Focus

| Function | Purpose |
|---|---|
| `focus/1` | Set focus on a widget by scoped ID path |
| `focus_element/2` | Set focus on a canvas element within a canvas |
| `focus_next/0` | Move focus to the next focusable widget |
| `focus_previous/0` | Move focus to the previous focusable widget |

### Text

| Function | Purpose |
|---|---|
| `select_all/1` | Select all text in a text input/editor |
| `move_cursor_to_front/1` | Move cursor to start |
| `move_cursor_to_end/1` | Move cursor to end |
| `move_cursor_to/2` | Move cursor to a specific position |
| `select_range/3` | Select a text range |

### Scroll

| Function | Purpose |
|---|---|
| `scroll_to/2` | Scroll to absolute position |
| `snap_to/3` | Snap scroll to a position |
| `snap_to_end/1` | Snap scroll to the end |
| `scroll_by/3` | Scroll by a relative offset |

### Window operations

| Function | Purpose |
|---|---|
| `close_window/1` | Close a window |
| `resize_window/3` | Set window size |
| `move_window/3` | Set window position |
| `maximize_window/2` | Maximize/unmaximize |
| `minimize_window/2` | Minimize/unminimize |
| `set_window_mode/2` | Set fullscreen/windowed mode |
| `toggle_maximize/1` | Toggle maximized state |
| `toggle_decorations/1` | Toggle window decorations |
| `focus_window/1` | Bring window to front |
| `set_window_level/2` | Set window z-level |
| `drag_window/1` | Begin window drag |
| `drag_resize_window/2` | Begin window resize drag |
| `screenshot/2` | Capture window screenshot |

Screenshot results arrive as a raw `{:screenshot_response, data}` tuple
in `update/2` (not a `SystemEvent`). The data map contains `name`,
`hash`, `width`, `height`, and optionally `rgba` binary image data.

### Window queries

| Function | Purpose |
|---|---|
| `get_window_size/2` | Query window dimensions |
| `get_window_position/2` | Query window position |
| `is_maximized/2` | Query maximized state |
| `is_minimized/2` | Query minimized state |
| `get_mode/2` | Query fullscreen/windowed mode |
| `get_scale_factor/2` | Query DPI scale factor |
| `raw_id/2` | Query platform window handle |
| `monitor_size/2` | Query monitor dimensions |

Results arrive as `%SystemEvent{type: type, tag: tag, data: data}`.
The `tag` matches the atom you provided. Data maps use atom keys:
`%{width: 800, height: 600}`.

### System

| Function | Purpose |
|---|---|
| `get_system_theme/1` | Query OS light/dark preference |
| `get_system_info/1` | Query system information |
| `allow_automatic_tabbing/1` | macOS automatic tab management |
| `announce/1` | Screen reader announcement |

`announce/1` triggers a live-region assertion for assistive technology.
The text is immediately spoken by the screen reader without requiring
a visible widget. Use for status updates, error notifications, and
dynamic content.

### Other

| Function | Purpose |
|---|---|
| `load_font/1` | Load a font from binary data at runtime |
| `tree_hash/1` | Query structural hash of the UI tree |
| `find_focused/1` | Query which widget has focus |
| `advance_frame/1` | Manual animation frame advance (test/headless mode) |
| `widget_command/3` | Command to a native Rust widget |
| `pane_split/4` | Split a pane in a pane grid |
| `pane_close/2` | Close a pane |

## Platform effects

All functions live in `Plushie.Effect`. Each takes an atom **tag** as
its first argument and returns a `Plushie.Command` struct. Results
arrive as `%Plushie.Event.EffectEvent{tag: tag, result: result}` in
`update/2`.

### File dialogs

| Function | Purpose |
|---|---|
| `file_open/2` | Single file picker |
| `file_open_multiple/2` | Multi-file picker |
| `file_save/2` | Save dialog |
| `directory_select/2` | Single directory picker |
| `directory_select_multiple/2` | Multi-directory picker |

```elixir
{model, Effect.file_open(:import, title: "Import", filters: [{"Elixir", "*.ex"}])}

def update(model, %EffectEvent{tag: :import, result: {:ok, %{path: path}}}), do: ...
def update(model, %EffectEvent{tag: :import, result: :cancelled}), do: model
```

### Clipboard

| Function | Purpose |
|---|---|
| `clipboard_read/1` | Read plain text |
| `clipboard_write/2` | Write plain text |
| `clipboard_read_html/1` | Read HTML content |
| `clipboard_write_html/3` | Write HTML content (with optional alt text) |
| `clipboard_clear/1` | Clear clipboard |
| `clipboard_read_primary/1` | Read primary selection (Linux) |
| `clipboard_write_primary/2` | Write primary selection (Linux) |

### Notifications

```elixir
{model, Effect.notification(:saved, "Exported", "File saved to #{path}")}
```

Options: `:icon`, `:timeout` (auto-dismiss ms), `:urgency`
(`:low`, `:normal`, `:critical`), `:sound`.

## Async mechanics

- **One task per tag.** Starting `async/2` or `stream/2` with a tag
  that is already in-flight kills the previous task. Use unique tags for
  concurrent work.

- **Nonce-based stale rejection.** Each task gets a nonce at creation.
  Results from killed tasks carry a stale nonce and are silently
  discarded.

- **Crashes become errors.** If the task process crashes (exception,
  exit), the result is `{:error, {:crashed, reason}}`.

- **Renderer restarts.** In-flight async tasks survive a renderer
  restart (they run in the BEAM, not the renderer). Results may be stale
  if the work depended on renderer state.

### Streaming

```elixir
cmd = Command.stream(fn emit ->
  for chunk <- fetch_chunks() do
    emit.(%{progress: chunk.index, data: chunk.data})
  end
  :done
end, :import)
```

Each `emit.()` delivers a `%StreamEvent{tag: :import, value: value}`.
The function's final return value is delivered directly as
`%AsyncEvent{tag: :import, result: :done}`. Wrap in `{:ok, ...}`
yourself if you want to follow the async convention.

## Effect lifecycle

- **Tag-based matching.** Every effect takes an atom tag. The tag
  returns in `%EffectEvent{tag: tag}` for direct pattern matching.

- **One effect per tag.** Starting a new effect with a tag that has a
  pending request discards the previous one.

- **Default timeouts:** file dialogs 120s, clipboard/notifications 5s.
  Override with `:timeout` option.

- **Timeout delivery.** `result: {:error, :timeout}`.

- **Cancellation.** User dismissing a dialog delivers
  `result: :cancelled` (not an error).

- **Effect stubs.** `register_effect_stub(:file_open, {:ok, %{path: "..."}})`
  intercepts effects by kind in tests. See the
  [Testing reference](testing.md).

## DIY patterns

The runtime is a GenServer. You can bypass the command system and send
messages directly:

```elixir
def update(model, %WidgetEvent{type: :click, id: "fetch"}) do
  pid = self()
  spawn(fn ->
    result = MyApp.HTTP.get!("/api/data")
    send(pid, {:fetched, result})
  end)
  model
end

def update(model, {:fetched, result}) do
  %{model | data: result}
end
```

This is useful for integrating with existing OTP infrastructure --
supervisors, GenServers, Phoenix PubSub. Messages arrive as events in
the next update cycle. The tradeoff: you lose tag-based cancellation
and stale-result rejection that `async/2` provides.

## See also

- `Plushie.Command` - full module docs with specs
- `Plushie.Effect` - platform effect functions
- [Async and Effects guide](../guides/11-async-and-effects.md) -
  effects, async, streaming, and multi-window
- [App Lifecycle reference](app-lifecycle.md) - return value
  validation and update cycle
- [Testing reference](testing.md) - effect stubs
