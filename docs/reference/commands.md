# Commands and effects reference

Commands are pure data returned from `update/2`. The runtime executes
them after the update cycle completes. See `Plushie.Command` for full
API docs and examples. Platform effects are a special command category
with their own module; see `Plushie.Effects`.

## Command categories

All functions live in `Plushie.Command` unless noted otherwise.

| Category | Functions | Description |
|---|---|---|
| Control flow | `none/0`, `done/2`, `batch/1`, `exit/0` | No-ops, lifting values, batching, shutdown |
| Async | `async/2`, `stream/2`, `cancel/1`, `send_after/2` | Background work with tagged result delivery |
| Focus | `focus/1`, `focus_element/2`, `focus_next/0`, `focus_previous/0` | Widget and canvas element focus management |
| Text | `select_all/1`, `move_cursor_to_front/1`, `move_cursor_to_end/1`, `move_cursor_to/2`, `select_range/3` | Text input cursor and selection control |
| Scroll | `scroll_to/2`, `snap_to/3`, `snap_to_end/1`, `scroll_by/3` | Scrollable widget positioning |
| Window ops | `close_window/1`, `resize_window/3`, `move_window/3`, `maximize_window/2`, `minimize_window/2`, `set_window_mode/2`, `toggle_maximize/1`, `toggle_decorations/1`, `gain_focus/1`, `set_window_level/2`, `drag_window/1`, `drag_resize_window/2`, `request_user_attention/2`, `screenshot/2`, `set_resizable/2`, `set_min_size/3`, `set_max_size/3`, `enable_mouse_passthrough/1`, `disable_mouse_passthrough/1`, `show_system_menu/1`, `set_icon/4`, `set_resize_increments/3` | Window manipulation |
| Window queries | `get_window_size/2`, `get_window_position/2`, `is_maximized/2`, `is_minimized/2`, `get_mode/2`, `get_scale_factor/2`, `raw_id/2`, `monitor_size/2` | Async window state queries (results arrive as events) |
| System | `allow_automatic_tabbing/1` | Platform-specific system ops (macOS) |
| System queries | `get_system_theme/1`, `get_system_info/1` | Async system state queries |
| PaneGrid | `pane_split/4`, `pane_close/2`, `pane_swap/3`, `pane_maximize/2`, `pane_restore/1` | Pane grid layout manipulation |
| Image | `create_image/2`, `create_image/4`, `update_image/2`, `update_image/4`, `delete_image/1`, `list_images/1`, `clear_images/0` | In-memory image lifecycle |
| Queries | `tree_hash/1`, `find_focused/1` | Renderer state introspection |
| Font | `load_font/1` | Runtime font loading from binary data |
| Accessibility | `announce/1` | Screen reader announcements |
| Native widget | `widget_command/3`, `widget_commands/1` | Direct commands to Rust-backed widgets |
| Test/Headless | `advance_frame/1` | Manual animation frame advance |

## Platform effects

All functions live in `Plushie.Effects`. Each returns a `Plushie.Command`
struct. Results arrive as `%Plushie.Event.Effect{}` events in `update/2`.

**File dialogs**

- `file_open/1` -- single file picker
- `file_open_multiple/1` -- multi-file picker
- `file_save/1` -- save dialog
- `directory_select/1` -- single directory picker
- `directory_select_multiple/1` -- multi-directory picker

**Clipboard**

- `clipboard_read/0`, `clipboard_write/1` -- plain text
- `clipboard_read_html/0`, `clipboard_write_html/2` -- HTML content
- `clipboard_clear/0` -- clear clipboard
- `clipboard_read_primary/0`, `clipboard_write_primary/1` -- primary selection (Linux middle-click)

**Notifications**

- `notification/3` -- OS-level notification with title, body, and options

## Async mechanics

- **One task per tag.** Starting `async/2` or `stream/2` with a tag that
  is already in-flight kills the previous task and replaces it. Use
  unique tags for concurrent work.

- **Nonce-based stale rejection.** Each task gets a nonce at creation.
  Results from killed tasks carry a stale nonce and are silently
  discarded by the runtime.

- **Renderer restarts.** In-flight async tasks survive a renderer restart
  (they run in the BEAM, not the renderer). However, if the task's work
  depends on renderer state, the result may be stale. The runtime does
  not cancel tasks on restart.

## Effect lifecycle

- **Auto-generated request IDs.** Each effect gets a unique ID (e.g.
  `"ef_1"`, `"ef_2"`, ...) stored in `cmd.payload.id`. Use it to
  correlate concurrent requests with their responses.

- **Default timeouts:**
  - File dialogs: 120 seconds
  - Clipboard operations: 5 seconds
  - Notifications: 5 seconds

  Override with the `:timeout` option on any effect function.

- **Timeout delivery.** When a timeout fires, the result event carries
  `result: {:error, :timeout}`. Cancellations carry `result: :cancelled`.

- **Effect stubs for testing.** `Plushie.Runtime.register_effect_stub/3`
  intercepts effect commands in tests and returns controlled responses
  without executing the real platform operation. Remove with
  `Plushie.Runtime.unregister_effect_stub/2`. In test helpers, the
  shorter `register_effect_stub/2` and `unregister_effect_stub/1`
  delegate through the test session.

## Result key format

Results from the renderer use **string keys**, not atom keys. This
applies uniformly across all response types:

- Effect results: `%{"path" => "/tmp/file.txt"}`
- System query data: `%{"system_name" => "Linux", "cpu_cores" => 8}`
- Window/image query data: `%{"width" => 800, "height" => 600}`
- System query tags are stringified: `get_system_theme(:my_tag)` delivers
  `tag: "my_tag"` in the `%SystemEvent{}`.

Query results (system, window, image, tree hash, focused widget) arrive
as `%Plushie.Event.SystemEvent{type: type, tag: tag, data: data}`.
Effect results arrive as `%Plushie.Event.Effect{request_id: id, result: result}`.

## DIY patterns

The runtime is a GenServer. You can bypass the command system entirely
and send messages to `self()` from `update/2`:

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
supervisors, GenServers, Phoenix PubSub, etc. Messages arrive as
events in the next update cycle. The tradeoff: you lose automatic
tag-based cancellation and stale-result rejection that `async/2`
provides.

## See also

- `Plushie.Command` -- full module docs with specs and examples
- `Plushie.Effects` -- platform effect functions and timeout details
- [Async and Effects](../guides/10-async-and-effects.md) -- guide with patterns
