# Async and Effects

The pad saves experiments to the local filesystem, but so far it uses
synchronous file I/O directly in `update/2`. In this chapter we add
asynchronous commands for background work, platform effects for native
dialogs, and multi-window support. By the end, the pad will have
import/export via file dialogs, clipboard integration, and the ability to
detach an experiment into its own window.

## Async commands

`Plushie.Command.task/2` runs a function in a separate process and delivers
the result as an event:

```elixir
alias Plushie.Command

def update(model, %WidgetEvent{type: :click, id: "fetch"}) do
  cmd = Command.task(fn ->
    # This runs in a Task, not in the runtime process
    {:ok, fetch_data_from_api()}
  end, :data_loaded)

  {%{model | status: :loading}, cmd}
end
```

The second argument, `:data_loaded`, is a **tag** that identifies this task.
The result arrives as a `Plushie.Event.AsyncEvent` struct with the same tag:

```elixir
alias Plushie.Event.AsyncEvent

def update(model, %AsyncEvent{tag: :data_loaded, result: {:ok, data}}) do
  %{model | status: :done, data: data}
end

def update(model, %AsyncEvent{tag: :data_loaded, result: {:error, reason}}) do
  %{model | status: :error, error: inspect(reason)}
end
```

A few things to know about async:

- **One task per tag.** Starting a new async with the same tag kills the
  previous one. This prevents stale results from a superseded request.
- **Results are nonce-checked.** If a task is killed and its result arrives
  late, the runtime discards it silently.
- **The function runs in a linked Task.** Exceptions in the function become
  `{:error, reason}` results, where `reason` is the exception struct.

## Platform effects

Effects are asynchronous requests to the renderer for platform operations:
file dialogs, clipboard access, and notifications. Unlike async commands
(which run Elixir code), effects are handled by the renderer binary.

### File dialogs

Every effect takes an atom tag as its first argument. The tag identifies the
effect in result matching, so there is no need to store request IDs in your model.

```elixir
alias Plushie.Effect

def update(model, %WidgetEvent{type: :click, id: "import"}) do
  {model, Effect.file_open(:import, title: "Import Experiment", filters: [{"Elixir", "*.ex"}])}
end
```

The result arrives as a `Plushie.Event.EffectEvent` struct. Match on the tag:

```elixir
alias Plushie.Event.EffectEvent
alias Plushie.Effect.Result

def update(model, %EffectEvent{tag: :import, result: %Result.FileOpened{path: path}}) do
  source = File.read!(path)
  # ... load the experiment
end

def update(model, %EffectEvent{tag: :import, result: %Result.Cancelled{}}) do
  model  # user closed the dialog
end

def update(model, %EffectEvent{tag: :import, result: %Result.Error{message: message}}) do
  %{model | error: message}
end
```

Available file dialogs:

- `Effect.file_open/2` - single file selection
- `Effect.file_open_multiple/2` - multiple file selection
- `Effect.file_save/2` - save dialog
- `Effect.directory_select/2` - directory selection
- `Effect.directory_select_multiple/2` - multiple directories

### Clipboard

```elixir
# Copy text to clipboard
{model, Effect.clipboard_write(:copy, model.source)}

# Read from clipboard
{model, Effect.clipboard_read(:paste)}
# Result: %EffectEvent{tag: :paste, result: %Result.ClipboardText{text: content}}
```

Also available: `clipboard_read_html/1`, `clipboard_write_html/3`,
`clipboard_clear/1`. On Linux, `clipboard_read_primary/1` and
`clipboard_write_primary/2` access the middle-click selection buffer.

### Notifications

```elixir
{model, Effect.notification(:exported, "Exported", "Experiment saved to #{path}")}
```

Pass options as the fourth argument. Options include `:icon`, `:timeout`,
and `:urgency` (`:low`, `:normal`, `:critical`).

### Effect timeouts

Effects have default timeouts: 120 seconds for file dialogs (the user may
browse for a while), 5 seconds for clipboard and notifications. If the
renderer does not respond in time, you get `%Plushie.Effect.Result.Timeout{}`.

### Applying it: import and export

Add import and export buttons to the pad toolbar:

```elixir
row padding: {4, 8}, spacing: 8 do
  button("save", "Save", style: :primary)
  button("import", "Import")
  button("export", "Export")
  checkbox("auto-save", model.auto_save)
  text("auto-label", "Auto-save")
end
```

Handle the events. Each effect gets a distinct tag, so matching the
result is straightforward:

```elixir
alias Plushie.Effect.Result

def update(model, %WidgetEvent{type: :click, id: "import"}) do
  {model, Effect.file_open(:import, title: "Import Experiment")}
end

def update(model, %WidgetEvent{type: :click, id: "export"}) do
  {model, Effect.file_save(:export, title: "Export Experiment")}
end

def update(model, %EffectEvent{tag: :import, result: %Result.FileOpened{path: path}}) do
  source = File.read!(path)
  %{model | source: source}
end

def update(model, %EffectEvent{tag: :export, result: %Result.FileSaved{path: path}}) do
  File.write!(path, model.source)
  model
end

def update(model, %EffectEvent{tag: tag, result: %Result.Cancelled{}})
    when tag in [:import, :export] do
  model
end
```

### Applying it: copy code

Add a "Copy" button that copies the current experiment source to the
clipboard:

```elixir
def update(model, %WidgetEvent{type: :click, id: "copy"}) do
  {model, Effect.clipboard_write(:copy, model.source)}
end
```

## Streaming and cancellation

For long-running work that produces intermediate results:

```elixir
cmd = Command.stream(fn emit ->
  for {line, n} <- Enum.with_index(File.stream!("large.csv"), 1) do
    emit.(%{line: n, data: parse(line)})
  end
  :done
end, :csv_import)
```

Each `emit.()` call delivers a `Plushie.Event.StreamEvent` struct. The final
return value arrives as a `Plushie.Event.AsyncEvent` struct, same as regular async.

To cancel a running async or stream:

```elixir
{model, Command.cancel(:csv_import)}
```

For one-shot delayed events (not recurring like subscriptions):

```elixir
{model, Command.send_after(3000, {:clear_status})}
```

See the [Commands reference](../reference/commands.md) for details.

## Batching

Combine multiple commands from a single update:

```elixir
{model, Command.batch([
  Effect.clipboard_write(:copy, model.source),
  Effect.notification(:copied, "Copied", "Source copied to clipboard"),
  Command.focus("editor")
])}
```

Commands in a batch execute in order.

## Multi-window

A Plushie app can have multiple windows. Return a list of `window` nodes
from `view/1`:

```elixir
def view(model) do
  windows = [
    window "main", title: "Plushie Pad" do
      # ... main pad UI
    end
  ]

  if model.detached do
    windows ++ [
      window "experiment", title: "Experiment: #{model.active_file}" do
        container "detached-preview", padding: 16 do
          model.preview
        end
      end
    ]
  else
    windows
  end
end
```

A few important things about multi-window:

**Window IDs must be stable strings.** If a window ID changes between
renders, the renderer closes the old window and opens a new one. Use
consistent, predictable IDs.

**`exit_on_close_request`** is a per-window prop that controls whether
closing the window triggers app exit. There is no "primary window" concept --
each window independently decides its close behaviour:

```elixir
window "main", title: "App", exit_on_close_request: true do
  # Closing this window exits the app
end

window "settings", title: "Settings", exit_on_close_request: false do
  # Closing this window just closes the window
end
```

**`close_requested` vs `closed`:** When the user clicks the window's close
button, the renderer sends a `:close_requested` event, not a `:closed` event.
Your app decides whether to actually close. If `exit_on_close_request` is
true (the default), the runtime exits. Otherwise, the event arrives in
`update/2` and you handle it:

```elixir
alias Plushie.Event.WindowEvent

def update(model, %WindowEvent{type: :close_requested, window_id: "experiment"}) do
  %{model | detached: false}
end
```

**Daemon mode** keeps the app running after the last window closes. Set
`:daemon` in `Plushie.start_link/2` options. When all windows close, you
receive `%SystemEvent{type: :all_windows_closed}` in `update/2`.

### Applying it: detach experiment

Add a "Detach" button that opens the experiment in its own window:

```elixir
def update(model, %WidgetEvent{type: :click, id: "detach"}) do
  %{model | detached: true}
end

def update(model, %WindowEvent{type: :close_requested, window_id: "experiment"}) do
  %{model | detached: false}
end
```

The view conditionally adds a second window when `model.detached` is true.
Closing the experiment window sets the flag back to false, and the experiment
returns to the preview pane.

## Error handling patterns

Always handle both success and failure for async and effects:

```elixir
alias Plushie.Effect.Result

def update(model, %AsyncEvent{tag: :export, result: {:ok, _}}) do
  %{model | status: "Exported"}
end

def update(model, %AsyncEvent{tag: :export, result: {:error, reason}}) do
  %{model | error: "Export failed: #{inspect(reason)}"}
end

def update(model, %EffectEvent{tag: _tag, result: %Result.Cancelled{}}) do
  model  # user cancelled the dialog, not an error
end
```

The `%Result.Cancelled{}` result is distinct from `%Result.Error{}`. A
user cancelling a file dialog is expected behaviour, not a failure.

## Verify it

Effect stubs let you control what the renderer returns for platform
operations. Register a stub before triggering the effect, and the renderer
responds with your stub instead of executing the real operation:

```elixir
test "import loads experiment from file" do
  register_effect_stub(:file_open, {:ok, %{path: "/tmp/test.ex"}})
  click("#import")
  # The stub responds with the path; verify the source was loaded
  assert model().source != ""
end

test "detach button opens second window" do
  click("#detach")
  assert model().detached == true
end
```

The full effect stubbing API is covered in [chapter 15](15-testing.md).

## Try it

Write experiments to try these concepts:

- Build a button that triggers `Command.task` with a simulated slow
  operation (`Process.sleep(2000)`). Show a loading indicator while the
  task runs, then display the result.
- Try `Command.stream` to deliver progress updates. Show a progress bar
  that fills as chunks arrive.
- Try `Command.batch` to combine a clipboard write with a notification.
- Build a two-window experiment: a main window and a secondary window
  that opens conditionally. Close the secondary window and see it disappear
  from the view.

In the next chapter, we will explore the canvas system for custom 2D drawing.

---

Next: [Canvas](12-canvas.md)
