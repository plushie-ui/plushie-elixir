# Commands and subscriptions

Iced has two mechanisms beyond the basic update/view cycle: `Task` (async
commands from update) and `Subscription` (ongoing event sources). Julep
provides Elixir equivalents for both.

## Commands

Sometimes `update/2` needs to do more than return a new model. It might
need to focus a text input, start an HTTP request, open a new window, or
schedule a delayed event. These are commands.

### Returning commands from update

`update/2` can return either a bare model or a `{model, commands}` tuple:

```elixir
# No commands -- just return the model:
def update(model, {:click, "simple"}), do: model

# With commands -- return a tuple:
def update(model, {:click, "save"}) do
  {model, Julep.Command.async(fn -> save_to_disk(model) end, :save_result)}
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

```elixir
# Run a function asynchronously. Result is delivered as an event.
Julep.Command.async(fun, event_tag)

# The function runs in a Task. When it returns, the runtime calls:
#   update(model, {event_tag, result})
```

```elixir
def update(model, {:click, "fetch"}) do
  cmd = Julep.Command.async(fn ->
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

```elixir
Julep.Command.stream(fun, event_tag)

# fun receives an emit callback: fn value -> sends {:async_result, tag, value}
# Each emit call dispatches {event_tag, value} through update/2.
# The function's final return value is dispatched the same way.
```

```elixir
def update(model, {:click, "import"}) do
  cmd = Julep.Command.stream(fn emit ->
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

```elixir
Julep.Command.cancel(event_tag)
```

```elixir
def update(model, {:click, "cancel_import"}) do
  {%{model | importing: false}, Julep.Command.cancel(:file_import)}
end
```

#### Widget operations

These send operation requests to the renderer:

```elixir
Julep.Command.focus(widget_id)           # Focus a text input
Julep.Command.focus_next()               # Focus next focusable widget
Julep.Command.focus_previous()           # Focus previous focusable widget
Julep.Command.select_all(widget_id)      # Select all text in input
Julep.Command.move_cursor(widget_id, pos) # Move cursor to position
Julep.Command.scroll_to(widget_id, offset) # Scroll to position
Julep.Command.snap_to(widget_id, offset)   # Snap scroll position
```

Example:

```elixir
def update(model, {:click, "new_todo"}) do
  {%{model | input: ""}, Julep.Command.focus("todo_input")}
end
```

#### Window management

```elixir
Julep.Command.open_window(window_id, opts)    # Open a new window
Julep.Command.close_window(window_id)         # Close a window
Julep.Command.resize_window(window_id, {w, h}) # Resize
Julep.Command.move_window(window_id, {x, y})   # Move
Julep.Command.maximize_window(window_id)       # Maximize
Julep.Command.minimize_window(window_id)       # Minimize
Julep.Command.fullscreen_window(window_id)     # Fullscreen
```

> **Not supported: `set_icon`.** iced's `window::set_icon` requires raw RGBA
> pixel data, which is impractical to serialize over JSONL. Set your
> application icon at the OS/desktop level instead (`.desktop` file on Linux,
> `Info.plist` on macOS, resource embedding on Windows).

#### Timers

```elixir
Julep.Command.send_after(delay_ms, event)  # Send event after delay
```

```elixir
def update(model, {:click, "flash_message"}) do
  model = %{model | message: "Saved!"}
  cmd = Julep.Command.send_after(3000, :clear_message)
  {model, cmd}
end

def update(model, :clear_message) do
  %{model | message: nil}
end
```

#### Batch

```elixir
Julep.Command.batch([
  Julep.Command.focus("name_input"),
  Julep.Command.send_after(5000, :auto_save)
])
```

Commands in a batch execute concurrently.

#### No-op

When `update` returns a bare model (not a tuple), the runtime treats it as
`{model, Julep.Command.none()}`. You never need to write `Command.none()`
explicitly.

### Chaining commands

In iced, commands support `.then()` and `.chain()` for sequencing async
work. Julep does not need dedicated chaining combinators because the Elm
update cycle provides this naturally: each `update/2` can return
`{model, commands}`, and the result of each command feeds back into
`update/2` as an event, which can return more commands.

The model is updated and `view/1` is re-rendered between each step. This
is actually more powerful than iced's chaining because you get full model
updates and UI refreshes at every link in the chain, not just at the end.

```elixir
# Step 1: user clicks "deploy" -- validate first
def update(model, {:click, "deploy"}) do
  cmd = Julep.Command.async(fn -> validate_config(model.config) end, :validated)
  {%{model | status: :validating}, cmd}
end

# Step 2: validation result arrives -- if OK, start the build
def update(model, {:validated, :ok}) do
  cmd = Julep.Command.async(fn -> build_release(model.config) end, :built)
  {%{model | status: :building}, cmd}
end

def update(model, {:validated, {:error, reason}}) do
  %{model | status: {:failed, reason}}
end

# Step 3: build result arrives -- if OK, push it
def update(model, {:built, {:ok, artifact}}) do
  cmd = Julep.Command.async(fn -> push_artifact(artifact) end, :deployed)
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
def update(model, {:click, "import"}) do
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

  {%{model | importing: true, import_pid: pid}, Julep.Command.none()}
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
def update(model, {:click, "cancel_import"}) do
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
- **Widget operations** are encoded as JSONL messages and sent to the
  renderer.
- **Window commands** are encoded as JSONL messages to the renderer.
- **Timers** use `Process.send_after` under the hood.

Commands are not side effects in `update`. They are descriptions of side
effects that the runtime executes after `update` returns. This keeps
`update` testable:

```elixir
test "clicking fetch returns async command" do
  {model, cmd} = MyApp.update(%{loading: false}, {:click, "fetch"})
  assert model.loading == true
  assert %Julep.Command{type: :async} = cmd
end
```

## Subscriptions

Subscriptions are ongoing event sources. Unlike commands (one-shot),
subscriptions produce events continuously as long as they are active.

### The subscribe callback

```elixir
@behaviour Julep.App

# Optional callback. Default: no subscriptions.
def subscribe(model) do
  subs = []

  # Tick every second while the timer is running
  subs = if model.timer_running do
    [Julep.Subscription.every(1000, :tick) | subs]
  else
    subs
  end

  # Always listen for keyboard shortcuts
  subs = [Julep.Subscription.on_key_press(:key_event) | subs]

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

```elixir
# Time
Julep.Subscription.every(interval_ms, event_tag)
# Delivers: {event_tag, timestamp} every interval_ms

# Keyboard
Julep.Subscription.on_key_press(event_tag)
# Delivers: {event_tag, key, modifiers}

Julep.Subscription.on_key_release(event_tag)
# Delivers: {event_tag, key, modifiers}

# Window events
Julep.Subscription.on_window_close(event_tag)
# Delivers: {event_tag, window_id}

Julep.Subscription.on_window_event(event_tag)
# Delivers: {event_tag, window_id, event}
```

### Subscription lifecycle

Subscriptions are declarative. You do not start or stop them imperatively.
You return a list from `subscribe/1`, and the runtime manages the rest:

```elixir
def subscribe(model) do
  if model.polling do
    [Julep.Subscription.every(5000, :poll)]
  else
    []
  end
end

def update(model, {:click, "start_polling"}) do
  %{model | polling: true}
end

def update(model, {:click, "stop_polling"}) do
  %{model | polling: false}
end

def update(model, {:poll, _timestamp}) do
  {model, Julep.Command.async(fn -> fetch_data() end, :data_received)}
end
```

When `polling` becomes true, the runtime starts the timer. When it becomes
false, the runtime stops it. No explicit cleanup needed.

### How subscriptions work internally

- **Time subscriptions** use Elixir's `:timer` or `Process.send_after`
  loop.
- **Keyboard and window subscriptions** are registered with the renderer
  via JSONL messages. The renderer sends events when they occur.

Subscriptions that require the renderer (keyboard, window) are paused
during renderer restart and resumed once the renderer is back.

## Commands vs. effects

Commands are Elixir-side operations handled by the runtime. Effects are
native platform operations handled by the renderer (see [effects.md](effects.md)).

| | Commands | Effects |
|---|---|---|
| Handled by | Elixir runtime | Rust renderer |
| Examples | async work, timers, focus | file dialogs, clipboard, notifications |
| Transport | internal (no JSONL) | JSONL request/response |
| Return from | `update/2` | `update/2` (via `Julep.Effects.request`) |

Widget operations and window commands are a hybrid -- they are initiated
from the Elixir side but executed by the renderer. They use the command
mechanism for the API but effect_request/response for the transport.
