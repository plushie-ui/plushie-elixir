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
