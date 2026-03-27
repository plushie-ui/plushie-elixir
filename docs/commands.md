# Commands and subscriptions

Iced has two mechanisms beyond the basic update/view cycle: `Task` (async
commands from update) and `Subscription` (ongoing event sources). Plushie
provides Elixir equivalents for both.

## Commands

Sometimes `update/2` needs to do more than return a new model. It might
need to focus a text input, start an HTTP request, open a new window, or
schedule a delayed event. These are commands.

### Returning commands from update

`update/2` can return either a bare model or a `{model, commands}` tuple:

```elixir
# No commands -- just return the model:
def update(model, %WidgetEvent{type: :click, id: "simple"}), do: model

# With commands -- return a tuple:
def update(model, %WidgetEvent{type: :click, id: "save"}) do
  {model, Plushie.Command.async(fn -> save_to_disk(model) end, :save_result)}
end

def update(model, {:save_result, :ok}) do
  %{model | saved: true}
end

def update(model, {:save_result, {:error, reason}}) do
  %{model | error: reason}
end
```

### Available commands

#### Async work

<!-- test: commands_async_construct_test -- keep this code block in sync with the test -->
```elixir
# Run a function asynchronously. Result is delivered as an event.
Plushie.Command.async(fun, event_tag)

# The function runs in a Task. When it returns, the runtime calls:
#   update(model, {event_tag, result})
```

```elixir
def update(model, %WidgetEvent{type: :click, id: "fetch"}) do
  cmd = Plushie.Command.async(fn ->
    {:ok, resp} = HTTP.get("https://api.example.com/data")
    resp.body
  end, :data_fetched)

  {%{model | loading: true}, cmd}
end

def update(model, {:data_fetched, body}) do
  %{model | loading: false, data: body}
end
```

#### Streaming async work

`Command.stream/2` is sugar for spawning a process that sends multiple
intermediate results to `update/2` over time. The function receives an
`emit` callback; each call to `emit` delivers a `{event_tag, value}` event
through the normal update cycle. The function's final return value is also
delivered as `{event_tag, result}`.

<!-- test: commands_stream_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.stream(fun, event_tag)

# fun receives an emit callback: fn value -> sends {:async_result, tag, value}
# Each emit call dispatches {event_tag, value} through update/2.
# The function's final return value is dispatched the same way.
```

```elixir
def update(model, %WidgetEvent{type: :click, id: "import"}) do
  cmd = Plushie.Command.stream(fn emit ->
    rows =
      "big.csv"
      |> File.stream!()
      |> Enum.with_index(1)
      |> Enum.map(fn {line, n} ->
        row = parse_row(line)
        emit.({:progress, n})
        row
      end)

    {:complete, rows}
  end, :file_import)

  {%{model | importing: true}, cmd}
end

def update(model, {:file_import, {:progress, n}}) do
  %{model | rows_imported: n}
end

def update(model, {:file_import, {:complete, rows}}) do
  %{model | importing: false, data: rows}
end
```

This is convenience sugar. You can achieve the same thing with a bare
`Task` and `send/2` -- see [DIY patterns](#diy-patterns) below.

#### Cancelling async work

`Command.cancel/1` cancels a running `async` or `stream` command by its
event tag. The runtime tracks running tasks by tag and terminates the
associated process. If the task has already completed, this is a no-op.

<!-- test: commands_cancel_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.cancel(event_tag)
```

```elixir
def update(model, %WidgetEvent{type: :click, id: "cancel_import"}) do
  {%{model | importing: false}, Plushie.Command.cancel(:file_import)}
end
```

#### Done (lift a value)

`Command.done/2` wraps an already-resolved value as a command. The runtime
immediately dispatches `msg_fn.(value)` through `update/2` without spawning
a task. Useful for lifting a pure value into the command pipeline.

<!-- test: commands_done_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.done(value, msg_fn)
```

```elixir
def update(model, %WidgetEvent{type: :click, id: "reset"}) do
  {model, Plushie.Command.done(:defaults, fn v -> {:config_loaded, v} end)}
end
```

#### Exit

`Command.exit/0` terminates the application.

<!-- test: commands_exit_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.exit()
```

#### Widget operations

##### Focus

<!-- test: commands_focus_construct_test, commands_focus_next_construct_test, commands_focus_previous_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.focus(widget_id)           # Focus a text input
Plushie.Command.focus_next()               # Focus next focusable widget
Plushie.Command.focus_previous()           # Focus previous focusable widget
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "new_todo"}) do
  {%{model | input: ""}, Plushie.Command.focus("todo_input")}
end
```

##### Text operations

<!-- test: commands_select_all_construct_test, commands_select_range_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.select_all(widget_id)                    # Select all text
Plushie.Command.move_cursor_to_front(widget_id)          # Cursor to start
Plushie.Command.move_cursor_to_end(widget_id)            # Cursor to end
Plushie.Command.move_cursor_to(widget_id, position)      # Cursor to char position
Plushie.Command.select_range(widget_id, start_pos, end_pos) # Select character range
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "select_word"}) do
  {model, Plushie.Command.select_range("editor", 5, 10)}
end
```

##### Scroll operations

<!-- test: commands_snap_to_end_construct_test, commands_snap_to_construct_test, commands_scroll_by_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.scroll_to(widget_id, offset_y)  # Scroll to absolute vertical position
Plushie.Command.snap_to(widget_id, x, y)       # Snap scroll to absolute offset
Plushie.Command.snap_to_end(widget_id)          # Snap to end of scrollable content
Plushie.Command.scroll_by(widget_id, x, y)     # Scroll by relative delta
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "scroll_bottom"}) do
  {model, Plushie.Command.snap_to_end("chat_log")}
end
```

#### Window management

Windows are opened declaratively by including window nodes in the view tree.
There is no `open_window` command. To open a window, add a `window` node to
the tree returned by `view/1`. To close one, remove it or use
`close_window/1`.

<!-- test: commands_close_window_construct_test, commands_set_window_mode_construct_test, commands_set_window_level_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.close_window(window_id)                        # Close a window
Plushie.Command.resize_window(window_id, width, height)        # Resize
Plushie.Command.move_window(window_id, x, y)                   # Move
Plushie.Command.maximize_window(window_id)                     # Maximize (default: true)
Plushie.Command.maximize_window(window_id, false)              # Restore from maximized
Plushie.Command.minimize_window(window_id)                     # Minimize (default: true)
Plushie.Command.minimize_window(window_id, false)              # Restore from minimized
Plushie.Command.set_window_mode(window_id, mode)               # :fullscreen, :windowed, etc.
Plushie.Command.toggle_maximize(window_id)                     # Toggle maximize state
Plushie.Command.toggle_decorations(window_id)                  # Toggle title bar/borders
Plushie.Command.gain_focus(window_id)                          # Bring window to front
Plushie.Command.set_window_level(window_id, level)             # :normal, :always_on_top, etc.
Plushie.Command.drag_window(window_id)                         # Initiate OS window drag
Plushie.Command.drag_resize_window(window_id, direction)       # Initiate OS resize from edge
Plushie.Command.request_user_attention(window_id, urgency)     # Flash taskbar (:informational, :critical)
Plushie.Command.screenshot(window_id, tag)                     # Capture window pixels
Plushie.Command.set_resizable(window_id, value)                # Enable/disable resize
Plushie.Command.set_min_size(window_id, width, height)         # Set minimum window size
Plushie.Command.set_max_size(window_id, width, height)         # Set maximum window size
Plushie.Command.enable_mouse_passthrough(window_id)            # Click-through window
Plushie.Command.disable_mouse_passthrough(window_id)           # Normal click handling
Plushie.Command.show_system_menu(window_id)                    # Show OS window menu
Plushie.Command.set_icon(window_id, rgba_data, width, height)  # Set window icon (raw RGBA)
Plushie.Command.set_resize_increments(window_id, width, height) # Set resize step increments
Plushie.Command.allow_automatic_tabbing(enabled)               # Enable/disable macOS automatic tab grouping
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "go_fullscreen"}) do
  {model, Plushie.Command.set_window_mode("main", :fullscreen)}
end

def update(model, %WidgetEvent{type: :click, id: "pin_on_top"}) do
  {model, Plushie.Command.set_window_level("main", :always_on_top)}
end
```

`set_icon/4` sends raw RGBA pixel data (base64-encoded for wire transport).
The `rgba_data` must be a binary of `width * height * 4` bytes.

#### Window queries

Window queries are commands whose results arrive as events in `update/2`.
Despite accepting a `tag` parameter, window property queries use the
**effect response** transport -- results arrive as `%Effect{request_id: id, result: result}`
tuples where `id` is the **window_id string** (the `tag` is currently
unused for these queries). System queries use a separate path where the
tag is used.

##### Window property queries

These go through the effect/window_op system. Results arrive in `update/2`
as `%Effect{request_id: window_id, result: {:ok, data}}` where `window_id` is the
string ID of the window and `data` varies by query type.

<!-- test: commands_get_window_size_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.get_window_size(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, %{"width" => w, "height" => h}}}

Plushie.Command.get_window_position(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, %{"x" => x, "y" => y}}}
# (nil if position is unavailable)

Plushie.Command.get_mode(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, mode}}
# mode is "windowed", "fullscreen", or "hidden"

Plushie.Command.get_scale_factor(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, factor}}

Plushie.Command.is_maximized(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, boolean}}

Plushie.Command.is_minimized(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, boolean}}

Plushie.Command.raw_id(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, platform_id}}

Plushie.Command.monitor_size(window_id, tag)
# Result: %Effect{request_id: window_id, result: {:ok, %{"width" => w, "height" => h}}}
# (nil if monitor cannot be determined)
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "check_size"}) do
  {model, Plushie.Command.get_window_size("main", :got_size)}
end

def update(model, %Effect{request_id: "main", result: {:ok, %{"width" => w, "height" => h}}}) do
  %{model | window_width: w, window_height: h}
end
```

**Note:** Because the response is keyed by `window_id` rather than `tag`,
issuing multiple different queries against the same window will produce
results that share the same `window_id` key. Distinguish them by the shape
of the `data` map (e.g. `%{"width" => _, "height" => _}` for size vs.
`%{"x" => _, "y" => _}` for position).

##### System queries

System-level queries use a different transport path. Results arrive as
dedicated tuples where the **tag** (stringified) identifies the response.

<!-- test: commands_get_system_theme_construct_test, commands_system_theme_event_match_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.get_system_theme(tag)
# Result: {:system_theme, tag_string, mode}
# mode is "light", "dark", or "none"

Plushie.Command.get_system_info(tag)
# Result: {:system_info, tag_string, info_map}
# info_map keys: "system_name", "system_kernel", "system_version",
#   "system_short_version", "cpu_brand", "cpu_cores", "memory_total",
#   "memory_used", "graphics_backend", "graphics_adapter"
# Requires the renderer to be built with the `sysinfo` feature.
```

**Important:** The `tag` arrives as a **string** in `update/2`, even if you
pass an atom. `Plushie.Command.get_system_theme(:theme_detected)` produces
`%SystemEvent{type: :system_theme, tag: "theme_detected", data: mode}` -- match
on the string, not the atom.

```elixir
alias Plushie.Event.{WidgetEvent, SystemEvent}

def update(model, %WidgetEvent{type: :click, id: "detect_theme"}) do
  {model, Plushie.Command.get_system_theme(:theme_detected)}
end

def update(model, %SystemEvent{type: :system_theme, tag: "theme_detected", data: mode}) do
  %{model | os_theme: mode}
end
```

#### Image operations

In-memory images can be created, updated, and deleted at runtime. The
`Image` widget references them via `%{handle: "name"}` as its source.

<!-- test: commands_create_image_construct_test, commands_delete_image_construct_test, commands_clear_images_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.create_image(handle, data)                     # From PNG/JPEG bytes
Plushie.Command.create_image(handle, width, height, pixels)    # From raw RGBA pixels
Plushie.Command.update_image(handle, data)                     # Update with PNG/JPEG
Plushie.Command.update_image(handle, width, height, pixels)    # Update with raw RGBA
Plushie.Command.delete_image(handle)                           # Remove in-memory image
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "load_preview"}) do
  cmd = Plushie.Command.async(fn ->
    File.read!("preview.png")
  end, :preview_loaded)
  {model, cmd}
end

def update(model, {:preview_loaded, data}) do
  {model, Plushie.Command.create_image("preview", data)}
end
```

#### PaneGrid operations

Commands for manipulating panes in a `PaneGrid` widget.

<!-- test: commands_pane_split_construct_test, commands_pane_close_construct_test, commands_pane_restore_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.pane_split(widget_id, pane, axis, new_pane_id)  # Split a pane
Plushie.Command.pane_close(widget_id, pane)                     # Close a pane
Plushie.Command.pane_swap(widget_id, pane_a, pane_b)            # Swap two panes
Plushie.Command.pane_maximize(widget_id, pane)                  # Maximize a pane
Plushie.Command.pane_restore(widget_id)                         # Restore from maximized
```

Example:

```elixir
def update(model, %WidgetEvent{type: :click, id: "split_editor"}) do
  cmd = Plushie.Command.pane_split("pane_grid", "editor", :horizontal, "new_editor")
  {model, cmd}
end
```

#### Timers

<!-- test: commands_send_after_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.send_after(delay_ms, event)  # Send event after delay
```

```elixir
def update(model, %WidgetEvent{type: :click, id: "flash_message"}) do
  model = %{model | message: "Saved!"}
  cmd = Plushie.Command.send_after(3000, :clear_message)
  {model, cmd}
end

def update(model, :clear_message) do
  %{model | message: nil}
end
```

#### Batch

<!-- test: commands_batch_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Command.batch([
  Plushie.Command.focus("name_input"),
  Plushie.Command.send_after(5000, :auto_save)
])
```

Commands in a batch are dispatched sequentially. Async commands spawn
concurrent tasks, but the dispatch loop itself processes each command in
order (`Enum.reduce` in the runtime).

#### Extension commands

Push data directly to a native Rust extension widget without triggering the
view/diff/patch cycle. Used for high-frequency data like terminal output or
streaming log lines.

<!-- test: commands_extension_command_construct_test, commands_extension_commands_construct_test -- keep this code block in sync with the test -->
```elixir
# Single command
Plushie.Command.extension_command("term-1", "write", %{data: output})

# Batch (all processed before next view cycle)
Plushie.Command.extension_commands([
  {"term-1", "write", %{data: line1}},
  {"log-1", "append", %{line: entry}}
])
```

Extension commands are only meaningful for widgets backed by a
`WidgetExtension` Rust implementation. They are silently ignored for
widgets without an extension handler.

#### No-op

When `update` returns a bare model (not a tuple), the runtime treats it as
`{model, Plushie.Command.none()}`. You never need to write `Command.none()`
explicitly.

### Chaining commands

In iced, commands support `.then()` and `.chain()` for sequencing async
work. Plushie does not need dedicated chaining combinators because the Elm
update cycle provides this naturally: each `update/2` can return
`{model, commands}`, and the result of each command feeds back into
`update/2` as an event, which can return more commands.

The model is updated and `view/1` is re-rendered between each step. This
is actually more powerful than iced's chaining because you get full model
updates and UI refreshes at every link in the chain, not just at the end.

```elixir
# Step 1: user clicks "deploy" -- validate first
def update(model, %WidgetEvent{type: :click, id: "deploy"}) do
  cmd = Plushie.Command.async(fn -> validate_config(model.config) end, :validated)
  {%{model | status: :validating}, cmd}
end

# Step 2: validation result arrives -- if OK, start the build
def update(model, {:validated, :ok}) do
  cmd = Plushie.Command.async(fn -> build_release(model.config) end, :built)
  {%{model | status: :building}, cmd}
end

def update(model, {:validated, {:error, reason}}) do
  %{model | status: {:failed, reason}}
end

# Step 3: build result arrives -- if OK, push it
def update(model, {:built, {:ok, artifact}}) do
  cmd = Plushie.Command.async(fn -> push_artifact(artifact) end, :deployed)
  {%{model | status: :deploying}, cmd}
end

# Step 4: done
def update(model, {:deployed, :ok}) do
  %{model | status: :live}
end
```

Each step is a separate `update/2` clause with its own model state. The
UI reflects progress at every stage. No special chaining API needed --
the architecture is the API.

### DIY patterns

The `Command` module is convenience sugar, not a requirement. Elixir
already has all the concurrency primitives you need. Some users will
prefer the direct approach, and that is perfectly fine.

#### Streaming with bare processes

The runtime is a `GenServer`. You can send messages to it directly from
any process, and they arrive as events in `update/2`:

```elixir
def update(model, %WidgetEvent{type: :click, id: "import"}) do
  runtime = self()

  pid = spawn_link(fn ->
    "big.csv"
    |> File.stream!()
    |> Stream.with_index(1)
    |> Enum.each(fn {line, n} ->
      row = parse_row(line)
      send(runtime, {:import_progress, n, row})
    end)

    send(runtime, :import_done)
  end)

  {%{model | importing: true, import_pid: pid}, Plushie.Command.none()}
end

def update(model, {:import_progress, n, row}) do
  %{model | rows_imported: n, data: model.data ++ [row]}
end

def update(model, :import_done) do
  %{model | importing: false, import_pid: nil}
end
```

#### Cancellation with PIDs

If you track the PID yourself, cancellation is just `Process.exit/2`:

```elixir
def update(model, %WidgetEvent{type: :click, id: "cancel_import"}) do
  if model.import_pid, do: Process.exit(model.import_pid, :kill)
  %{model | importing: false, import_pid: nil}
end
```

#### When to use which

Use `Command.async/2` and `Command.stream/2` when you want the runtime
to manage task lifecycle and deliver results through the standard
`{tag, result}` convention. Use bare processes when you need more control
over message shapes, supervision, or when the command abstraction feels
like overhead for your use case.

### How commands work internally

Commands are data. They describe what should happen, not how. The runtime
interprets them:

- **Async commands** spawn an Elixir `Task` under the runtime's supervisor.
  When the task completes, the result is wrapped in the event tag and
  dispatched through `update/2`.
- **Widget operations** are encoded as wire messages and sent to the
  renderer.
- **Window commands** are encoded as wire messages to the renderer.
- **Window property queries** (get_size, get_position, etc.) are sent as
  `window_op` wire messages. The renderer responds with an `effect_response`
  keyed by `window_id`.
- **System ops** are sent as `system_op` wire messages.
- **System queries** (get_system_theme, get_system_info) are sent as
  `system_query` wire messages. The renderer responds with an
  `op_query_response` keyed by tag.
- **Image operations** are encoded as wire messages to the renderer.
- **PaneGrid operations** are encoded as widget ops sent to the renderer.
- **Timers** use `Process.send_after` under the hood.

Commands are not side effects in `update`. They are descriptions of side
effects that the runtime executes after `update` returns. This keeps
`update` testable:

```elixir
test "clicking fetch returns async command" do
  {model, cmd} = MyApp.update(%{loading: false}, %WidgetEvent{type: :click, id: "fetch"})
  assert model.loading == true
  assert %Plushie.Command{type: :async} = cmd
end
```

## Subscriptions

Subscriptions are ongoing event sources. Unlike commands (one-shot),
subscriptions produce events continuously as long as they are active.

**Important: tag semantics differ by subscription type.** For timer
subscriptions (`every/2`), the tag becomes the event wrapper -- `update/2`
receives `{tag, timestamp}`. For all renderer subscriptions (keyboard,
mouse, window, etc.), the tag is management-only and does NOT appear in
the event tuple. Renderer events arrive as fixed tuples like
`%Key{type: :press, ...}` regardless of what tag you chose.

### The subscribe callback

```elixir
use Plushie.App

# Optional callback. Default: no subscriptions.
def subscribe(model) do
  subs = []

  # Tick every second while the timer is running
  subs = if model.timer_running do
    [Plushie.Subscription.every(1000, :tick) | subs]
  else
    subs
  end

  # Always listen for keyboard shortcuts
  subs = [Plushie.Subscription.on_key_press(:key_event) | subs]

  subs
end
```

`subscribe/1` is called after every `update`. The runtime diffs the
returned subscription list against the previous one and starts/stops
subscriptions as needed. Subscriptions are identified by their
specification -- returning the same `Subscription.every(1000, :tick)` on
consecutive calls keeps the existing subscription alive; removing it stops
it.

### Available subscriptions

#### Time

<!-- test: subscriptions_every_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Subscription.every(interval_ms, event_tag)
# Delivers: {event_tag, timestamp} every interval_ms
```

#### Keyboard

<!-- test: subscriptions_on_key_press_construct_test -- keep this code block in sync with the test -->
```elixir
Plushie.Subscription.on_key_press(event_tag)
# Delivers: %Key{type: :press, ...}

Plushie.Subscription.on_key_release(event_tag)
# Delivers: %Key{type: :release, ...}

Plushie.Subscription.on_modifiers_changed(event_tag)
# Delivers: %Modifiers{shift: bool, ctrl: bool, ...}

# The event_tag is used by the runtime to register/unregister the
# subscription with the renderer. It is NOT included in the event
# tuple delivered to update/2. See docs/events.md for the full
# Key and KeyModifiers struct definitions.
```

#### Window lifecycle

```elixir
Plushie.Subscription.on_window_close(event_tag)
# Delivers: {event_tag, window_id}

Plushie.Subscription.on_window_open(event_tag)
# Delivers: %WindowEvent{type: :opened, window_id: wid, position: pos, width: w, height: h}

Plushie.Subscription.on_window_resize(event_tag)
# Delivers: %WindowEvent{type: :resized, window_id: wid, width: w, height: h}

Plushie.Subscription.on_window_focus(event_tag)
# Delivers: %WindowEvent{type: :focused, window_id: wid}

Plushie.Subscription.on_window_unfocus(event_tag)
# Delivers: %WindowEvent{type: :unfocused, window_id: wid}

Plushie.Subscription.on_window_move(event_tag)
# Delivers: %WindowEvent{type: :moved, window_id: wid, x: x, y: y}

Plushie.Subscription.on_window_event(event_tag)
# Delivers: various %WindowEvent{type: ..., ...} structs (catch-all for window events)
```

#### Mouse

```elixir
Plushie.Subscription.on_mouse_move(event_tag)
# Delivers: %Mouse{type: :moved, x: x, y: y}

Plushie.Subscription.on_mouse_button(event_tag)
# Delivers: %Mouse{type: :button_pressed, button: btn} or %Mouse{type: :button_released, button: btn}

Plushie.Subscription.on_mouse_scroll(event_tag)
# Delivers: {:wheel_scrolled, delta_x, delta_y, unit}
```

#### Touch

```elixir
Plushie.Subscription.on_touch(event_tag)
# Delivers: %Touch{type: :pressed, finger_id: fid, x: x, y: y}
#           %Touch{type: :moved, ...}
#           %Touch{type: :lifted, ...}
#           %Touch{type: :lost, ...}
```

#### IME (Input Method Editor)

```elixir
Plushie.Subscription.on_ime(event_tag)
# Delivers: %Ime{type: :opened}
#           %Ime{type: :preedit, text: text, cursor: {start, end_pos} | nil}
#           %Ime{type: :commit, text: text}
#           %Ime{type: :closed}
```

#### System

```elixir
Plushie.Subscription.on_theme_change(event_tag)
# Delivers: %SystemEvent{type: :theme_changed, data: mode}  (mode is "light" or "dark")

Plushie.Subscription.on_animation_frame(event_tag)
# Delivers: %SystemEvent{type: :animation_frame, data: timestamp}

Plushie.Subscription.on_file_drop(event_tag)
# Delivers: %WindowEvent{type: :file_dropped, window_id: wid, path: path}
#           %WindowEvent{type: :file_hovered, window_id: wid, path: path}
#           %WindowEvent{type: :files_hovered_left, window_id: wid}
```

#### Catch-all

```elixir
Plushie.Subscription.on_event(event_tag)
# Receives all renderer events. Tuple shape varies by event family.
```

#### Batch

```elixir
Plushie.Subscription.batch(subscriptions)
# Combines multiple subscriptions into a flat list. Identity function.
```

### Event rate limiting

The renderer supports rate limiting for high-frequency events (mouse moves,
scroll, animation frames, slider drags, etc.). This reduces wire traffic
and host CPU usage. Three configuration levels, in order of priority:

#### Per-widget `event_rate` prop

Widgets that emit high-frequency events accept an `event_rate` option:

```elixir
# Volume slider limited to 15 events/sec, seek bar at 60:
slider("volume", {0, 100}, model.volume, event_rate: 15)
slider("seek", {0, model.duration}, model.position, event_rate: 60)
```

Supported on: `Slider`, `VerticalSlider`, `Canvas`, `MouseArea`, `Sensor`,
`PaneGrid`, and all extension widgets.

#### Per-subscription `max_rate`

Renderer subscriptions accept a `max_rate` option:

<!-- test: subscriptions_set_max_rate_test, subscriptions_set_max_rate_zero_test, subscriptions_on_animation_frame_test -- keep this code block in sync with the test -->
```elixir
# Rate-limit mouse moves to 30 events per second:
Subscription.on_mouse_move(:mouse, max_rate: 30)

# Animation frames at 60fps:
Subscription.on_animation_frame(:frame, max_rate: 60)

# Subscribe but never emit (capture tracking only):
Subscription.on_mouse_move(:mouse, max_rate: 0)
```

Timer subscriptions (`every/2`) do not support `max_rate`.

#### Global `default_event_rate` setting

A global default applied to all coalescable event types:

```elixir
def settings do
  [default_event_rate: 60]
end
```

Set to 60 for most apps. Lower for dashboards or remote rendering.
Omit for unlimited (current default behavior).

### Subscription lifecycle

Subscriptions are declarative. You do not start or stop them imperatively.
You return a list from `subscribe/1`, and the runtime manages the rest:

```elixir
def subscribe(model) do
  if model.polling do
    [Plushie.Subscription.every(5000, :poll)]
  else
    []
  end
end

def update(model, %WidgetEvent{type: :click, id: "start_polling"}) do
  %{model | polling: true}
end

def update(model, %WidgetEvent{type: :click, id: "stop_polling"}) do
  %{model | polling: false}
end

def update(model, {:poll, _timestamp}) do
  {model, Plushie.Command.async(fn -> fetch_data() end, :data_received)}
end
```

When `polling` becomes true, the runtime starts the timer. When it becomes
false, the runtime stops it. No explicit cleanup needed.

### How subscriptions work internally

- **Time subscriptions** use Elixir's `:timer` or `Process.send_after`
  loop.
- **Keyboard, mouse, touch, and window subscriptions** are registered with
  the renderer via wire messages. The renderer sends events when they occur.
- **System subscriptions** (theme change, animation frame, file drop) are
  also renderer-side event sources.

Subscriptions that require the renderer (everything except timers) are
paused during renderer restart and resumed once the renderer is back.

## Application settings

The `settings/0` callback is documented in
[app-behaviour.md](app-behaviour.md). Notable settings relevant to
commands and rendering:

- `vsync` -- boolean (default `true`). Controls vertical sync. Set to
  `false` for uncapped frame rates (useful for benchmarks or animation-heavy
  apps at the cost of higher GPU usage).
- `scale_factor` -- number (default `1.0`). Global UI scale factor applied
  to all windows. Values greater than 1.0 make the UI larger; less than 1.0
  makes it smaller.
- `default_event_rate` -- integer. Maximum events per second for coalescable
  event types. Omit for unlimited (default). See [Event rate limiting](#event-rate-limiting).

<!-- test: commands_settings_scale_and_vsync_test -- keep this code block in sync with the test -->
```elixir
def settings do
  [
    antialiasing: true,
    vsync: false,
    scale_factor: 1.5,
    default_event_rate: 60
  ]
end
```

## Commands vs. effects

Commands are Elixir-side operations handled by the runtime. Effects are
native platform operations handled by the renderer (see [effects.md](effects.md)).

| | Commands | Effects |
|---|---|---|
| Handled by | Elixir runtime | Rust renderer |
| Examples | async work, timers, focus | file dialogs, clipboard, notifications |
| Transport | internal | wire protocol request/response |
| Return from | `update/2` | `update/2` (via `Plushie.Effects.request`) |

Widget operations and window commands are a hybrid -- they are initiated
from the Elixir side but executed by the renderer. They use the command
mechanism for the API but effect/effect_response for the transport.

## Next steps

- [Extensions](extensions.md) -- native widget extensions with custom commands
- [Effects](effects.md) -- platform requests (file dialogs, clipboard)
- [Gauge demo](https://github.com/plushie-ui/plushie-demos/tree/main/elixir/gauge-demo) -- extension commands (`set_value`, `animate_to`) with optimistic updates
