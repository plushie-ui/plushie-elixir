# App behaviour

`Plushie.App` is the only behaviour an app developer implements. It follows the
Elm architecture: model, update, view.

## Callbacks

```elixir
@callback init(opts :: keyword()) :: model | {model, Plushie.Command.t()} | {model, [Plushie.Command.t()]}
@callback update(model, event) :: model | {model, Plushie.Command.t()} | {model, [Plushie.Command.t()]}
@callback view(model) :: Plushie.Widget.ui_node()

# Optional:
@callback subscribe(model) :: [Plushie.Subscription.t()]
@callback handle_renderer_exit(model, exit_reason) :: model
@callback window_config(model) :: map()
@callback settings() :: keyword()
```

### init/1

Returns the initial model, optionally with commands. Called once when the
runtime starts.

<!-- test: app_behaviour_init_bare_model_test, app_behaviour_init_with_command_test -- keep this code block in sync with the test -->
```elixir
def init(_opts) do
  %{
    todos: [],
    input: "",
    filter: :all
  }
end

# Or with a command:
def init(_opts) do
  model = %{todos: [], loading: true}
  {model, Plushie.Command.async(fn -> load_todos_from_disk() end, :todos_loaded)}
end
```

The model can be any term, but plain maps work best. The runtime does not
inspect or modify the model -- it is fully owned by the app.

`opts` is a keyword list passed through from the runtime start call, so
apps can accept configuration at startup.

### update/2

Receives the current model and an event, returns the next model -- optionally
with commands.

<!-- test: app_behaviour_update_add_todo_test, app_behaviour_update_submit_returns_focus_test, app_behaviour_update_unknown_event_test -- keep this code block in sync with the test -->
```elixir
alias Plushie.Event.WidgetEvent

def update(model, %WidgetEvent{type: :click, id: "add_todo"}) do
  new_todo = %{id: System.unique_integer(), text: model.input, done: false}
  %{model | todos: [new_todo | model.todos], input: ""}
end

def update(model, %WidgetEvent{type: :input, id: "todo_field", value: value}) do
  %{model | input: value}
end

# Returning commands:
def update(model, %WidgetEvent{type: :submit, id: "todo_field"}) do
  new_todo = %{id: System.unique_integer(), text: model.input, done: false}
  model = %{model | todos: [new_todo | model.todos], input: ""}
  {model, Plushie.Command.focus("todo_field")}
end

def update(model, _event), do: model
```

Return a bare model when no side effects are needed. Return `{model, command}`
when you need async work, widget operations, window management, or timers.
See [commands.md](commands.md) for the full command API.

Events are structs under `Plushie.Event.*`. See [events.md](events.md) for
the full event taxonomy. Common families:

- `%WidgetEvent{type: :click, id: id}` -- button press
- `%WidgetEvent{type: :input, id: id, value: val}` -- text input change
- `%WidgetEvent{type: :select, id: id, value: val}` -- selection change
- `%WidgetEvent{type: :toggle, id: id, value: val}` -- checkbox/toggler change
- `%WidgetEvent{type: :submit, id: id, value: val}` -- form field submission
- `%Key{type: :press, ...}` -- keyboard event (via subscription)
- `%Key{type: :release, ...}` -- keyboard release (via subscription)
- `%WindowEvent{type: :close_requested, window_id: id}` -- window close requested
- `%WindowEvent{type: :resized, window_id: id, width: w, height: h}` -- window resized
- `%WidgetEvent{type: :canvas_press, id: id, data: %{x: x, y: y, button: btn}}` -- canvas interaction
- `%WidgetEvent{type: :sensor_resize, id: id, data: %{width: w, height: h}}` -- sensor size change
- `%WidgetEvent{type: :pane_clicked, id: id, data: %{pane: pane}}` -- pane grid click

### view/1

Receives the current model, returns a UI tree.

<!-- test: app_behaviour_view_basic_structure_test -- keep this code block in sync with the test -->
```elixir
def view(model) do
  import Plushie.UI

  window "main", title: "Todos" do
    column padding: 16, spacing: 8 do
      row spacing: 8 do
        text_input("todo_field", model.input, placeholder: "What needs doing?")
        button("add_todo", "Add")
      end

      for todo <- filtered_todos(model) do
        row id: todo.id, spacing: 8 do
          checkbox("toggle", todo.done)
          text(todo.text)
        end
      end
    end
  end
end
```

The view function is called after every update. It must be a pure function
of the model. The runtime diffs the returned tree against the previous one
and sends only the changes to the renderer.

UI trees are plain maps. The `Plushie.UI`
module provides builder functions and a `do` block syntax for composition,
but you can also build maps directly if preferred.

## Lifecycle

```
start_runtime(MyApp, opts)
  |
  v
init(opts) -> {model, commands}
  |
  v
subscribe(model) -> active subscriptions
  |
  v
view(model) -> initial tree -> send snapshot to renderer
  |
  v
[event from renderer / subscription / command result]
  |
  v
update(model, event) -> {model, commands}
  |
  v
subscribe(model) -> diff subscriptions (start/stop as needed)
  |
  v
view(model) -> next tree -> diff -> send patch to renderer
  |
  v
[repeat from event]
```

### subscribe/1 (optional)

Returns a list of active subscriptions based on the current model. Called
after every `update`. The runtime diffs the list and starts/stops
subscriptions automatically.

<!-- test: app_behaviour_subscribe_without_auto_refresh_test, app_behaviour_subscribe_with_auto_refresh_test -- keep this code block in sync with the test -->
```elixir
def subscribe(model) do
  subs = [Plushie.Subscription.on_key_press(:key_event)]

  if model.auto_refresh do
    [Plushie.Subscription.every(5000, :refresh) | subs]
  else
    subs
  end
end
```

Default: `[]` (no subscriptions). See [commands.md](commands.md) for the
full subscription API.

### handle_renderer_exit/2 (optional)

Called when the renderer process exits unexpectedly. Return the model to
use when the renderer restarts. Default: return model unchanged.

```elixir
def handle_renderer_exit(model, _reason) do
  %{model | status: :renderer_restarting}
end
```

### window_config/1 (optional)

Called when windows are opened, including at startup and after renderer
restart. Default: single window with app module name as title.

<!-- test: app_behaviour_window_config_returns_map_test -- keep this code block in sync with the test -->
```elixir
def window_config(_model) do
  %{
    title: "My App",
    width: 800,
    height: 600,
    min_size: %{width: 400, height: 300},
    resizable: true,
    theme: :dark
  }
end
```

### settings/0 (optional)

Called once at startup to provide application-level settings to the
renderer. Returns a keyword list.

<!-- test: app_behaviour_settings_test, app_behaviour_default_settings_test -- keep this code block in sync with the test -->
```elixir
def settings do
  [
    default_font: %{family: "monospace"},
    default_text_size: 16,
    antialiasing: true,
    fonts: ["priv/fonts/Inter.ttf"]
  ]
end
```

Supported keys:

- `default_font` -- a font specification map (same format as font props)
- `default_text_size` -- a number (pixels)
- `antialiasing` -- boolean
- `fonts` -- list of font file paths to load
- `vsync` -- boolean (default `true`). Controls vertical sync.
- `scale_factor` -- number (default `1.0`). Global UI scale factor applied
  to all windows.

To follow the OS light/dark preference automatically, set the window
`theme` prop to `:system`. The renderer detects the current OS theme
and applies the matching built-in light or dark theme.

Default: `[]` (renderer uses its own defaults).

## Starting the runtime

```elixir
# From IEx or application code:
{:ok, pid} = Plushie.start_link(MyApp)
{:ok, pid} = Plushie.start_link(MyApp, name: :my_app, binary: "/path/to/plushie")

# Under a supervisor:
children = [
  {Plushie, app: MyApp, name: :my_app}
]

# From mix:
# mix plushie.gui MyApp
# mix plushie.gui MyApp --release
```

## Testing

Apps can be tested without a renderer:

```elixir
test "adding a todo" do
  model = MyApp.init([])
  model = MyApp.update(model, %WidgetEvent{type: :input, id: "todo_field", value: "Buy milk"})
  model = MyApp.update(model, %WidgetEvent{type: :click, id: "add_todo"})

  assert [%{text: "Buy milk"}] = model.todos
  assert model.input == ""
end

test "view renders todo list" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  assert Plushie.Tree.find(tree, "todo:1")
end
```

Since `update` is a pure function and `view` returns plain maps, no special
test infrastructure is needed. The renderer is not involved.

## Configuration

Application-level configuration is set via `config :plushie, key, value` in
your `config.exs` (or per-environment config files).

| Key | Type | Default | Description |
|---|---|---|---|
| `:test_backend` | `:mock \| :headless \| :windowed` | `:mock` | Renderer mode used by `Plushie.Test.Case`. Controls which mode the binary runs in (mock/headless/windowed) through a unified Runtime backend. Override per-run with `PLUSHIE_TEST_BACKEND` env var. |
| `:test_format` | `:json \| :msgpack` | `:msgpack` | Wire format for test sessions. Set to `:json` for easier debugging. |
| `:widget_config` | `map()` | `%{}` | Configuration map passed to custom widgets at runtime, keyed by widget type. |

## Multi-window

Plushie supports multiple windows driven declaratively from `view/1`. Windows
are nodes in the tree -- if a window node is present, the window is open; if
it disappears, the window closes.

### Returning multiple windows

`view/1` returns explicit window nodes. Return a single window node for a
single-window app, or a list of window nodes for multiple windows:

```elixir
def view(model) do
  import Plushie.UI

  windows = [
    window "main", title: "My App" do
      main_content(model)
    end
  ]

  if model.inspector_open do
    inspector = window "inspector", title: "Inspector", size: {400, 600} do
      inspector_panel(model)
    end
    windows ++ [inspector]
  else
    windows
  end
end
```

Single-window apps return a single window node directly. Multi-window apps
return a list of window nodes. Returning arbitrary top-level widgets is not
supported.

### Window identity

Each window node has an `id` (like all nodes). The renderer uses this ID
to track which OS window corresponds to which tree node:

- **New ID appears** -- renderer opens a new OS window.
- **Existing ID present** -- renderer updates that window's content.
- **ID disappears** -- renderer closes that OS window.

Window IDs must be stable strings. Do not generate random IDs per render
or the renderer will close and reopen the window on every update.

### Window properties

```elixir
window "main",
  title: "My App",
  size: {800, 600},
  min_size: {400, 300},
  max_size: {1920, 1080},
  position: {100, 100},
  resizable: true,
  closeable: true,
  minimizable: true,
  decorations: true,
  transparent: false,
  visible: true,
  theme: :dark,        # or :system to follow OS preference
  level: :normal,      # :normal | :always_on_top | :always_on_bottom
  scale_factor: 1.5    # per-window UI scale (overrides global setting)
do
  content(model)
end
```

Properties are set when the window first appears. To change properties
after creation, use window commands:

<!-- test: app_behaviour_window_command_set_window_mode_test -- keep this code block in sync with the test -->
```elixir
def update(model, %WidgetEvent{type: :click, id: "go_fullscreen"}) do
  {model, Plushie.Command.set_window_mode("main", :fullscreen)}
end
```

### Window events

Window events include the window ID so your app knows which window they
came from:

<!-- test: app_behaviour_window_events_close_requested_test, app_behaviour_window_events_resized_test, app_behaviour_window_events_focused_test -- keep this code block in sync with the test -->
```elixir
def update(model, %WindowEvent{type: :close_requested, window_id: "inspector"}) do
  %{model | inspector_open: false}
end

def update(model, %WindowEvent{type: :close_requested, window_id: "main"}) do
  if model.unsaved_changes do
    %{model | confirm_exit: true}
  else
    {model, Plushie.Command.close_window("main")}
  end
end

def update(model, %WindowEvent{type: :resized, window_id: "main", width: width, height: height}) do
  %{model | window_size: {width, height}}
end

def update(model, %WindowEvent{type: :focused, window_id: window_id}) do
  %{model | active_window: window_id}
end
```

### Window close behaviour

By default, when the user clicks the close button on a window, the
renderer sends a `%WindowEvent{type: :close_requested, window_id: window_id}` event instead
of closing immediately. Your app decides what to do:

```elixir
# Let it close (remove it from view):
def update(model, %WindowEvent{type: :close_requested, window_id: "settings"}) do
  %{model | settings_open: false}
end

# Block the close:
def update(model, %WindowEvent{type: :close_requested, window_id: "main"}) do
  %{model | show_save_dialog: true}
end
```

If `close_requested` is not handled (falls through to the catch-all), the
window stays open. This prevents accidental closes. To close a window
programmatically, remove it from the tree (return `view/1` without it) or
use `Plushie.Command.close_window(id)`.

### Opening windows declaratively

Windows are opened by adding window nodes to the tree returned by
`view/1`. There is no `open_window` command. To open a new window, set a
flag in your model and include the window node conditionally:

```elixir
def update(model, %WidgetEvent{type: :click, id: "open_settings"}) do
  %{model | settings_open: true}
end

def view(model) do
  import Plushie.UI

  windows = [
    window "main", title: "My App" do
      main_content(model)
    end
  ]

  if model.settings_open do
    settings = window "settings", title: "Settings", size: {500, 400} do
      settings_panel(model)
    end
    windows ++ [settings]
  else
    windows
  end
end
```

### Primary window

The first window in the list returned by `view/1` is the primary window.
When the primary window is closed, the runtime exits (unless
`handle_renderer_exit/2` is overridden to prevent it).

Secondary windows can be opened and closed freely without affecting the
runtime lifecycle.

### Focus and active window

The renderer tracks which window has OS focus. Window focus/unfocus events
are delivered as:

```elixir
%WindowEvent{type: :focused, window_id: window_id}
%WindowEvent{type: :unfocused, window_id: window_id}
```

The app can use these to adjust behaviour (e.g., pause animations in
unfocused windows, track the active window for keyboard shortcuts).

### Example: dialog window

<!-- test: app_behaviour_dialog_window_test -- keep this code block in sync with the test -->
```elixir
def view(model) do
  import Plushie.UI

  main = window "main", title: "App" do
    main_content(model)
  end

  if model.confirm_dialog do
    dialog = window "confirm", title: "Confirm",
             size: {300, 150}, resizable: false,
             level: :always_on_top do
      column padding: 16, spacing: 12 do
        text("prompt", "Are you sure?")
        row spacing: 8 do
          button("confirm_yes", "Yes")
          button("confirm_no", "No")
        end
      end
    end
    [main, dialog]
  else
    main
  end
end
```


## How props reach the renderer

Values returned by `view/1` go through several transformation stages
before reaching the wire. Understanding this pipeline helps when
debugging unexpected behaviour or writing custom widgets.

1. **Widget builders** (`Plushie.UI` macros, `Plushie.Iced` functions)
   return structs with raw Elixir values -- atoms, tuples, structs.
   No encoding happens here.

2. **`Plushie.Widget` protocol** (`to_node/1`) converts typed widget
   structs into plain `%{id, type, props, children}` maps. Values
   remain as raw Elixir terms.

3. **`Plushie.Tree.normalize/1`** walks the tree and applies the
   `Plushie.Encode` protocol to each prop value. Atoms become strings
   (except `true`/`false`/`nil`), tuples become lists, and custom
   structs encode via their `Plushie.Encode` implementation. Scoped IDs
   are prefixed at this stage.

4. **Protocol encoding** stringifies atom keys to string keys, then
   serializes with Jason (JSON mode) or Msgpax (MessagePack mode) to
   produce wire bytes.

Each stage has a single responsibility. Widget builders don't worry
about wire encoding, the Encode protocol doesn't worry about
serialization format, and the Protocol layer doesn't know about widget
types.

See [running.md](running.md) for more detail on the encoding pipeline
and transport modes.

## Renderer limits

The renderer enforces hard limits on various resources. Exceeding them
results in rejection, truncation, or clamping (depending on the
resource). Design your app to stay within these bounds.

| Resource | Limit | Behavior when exceeded |
|---|---|---|
| Font data (`load_font`) | 16 MiB decoded | Rejected with warning |
| Runtime font loads | 256 per process | Rejected with warning |
| Image handles | 4096 | Error response |
| Total image bytes | 1 GiB | Error response |
| Markdown content | 1 MiB | Truncated at UTF-8 boundary with warning |
| Text editor content | 10 MiB | Truncated at UTF-8 boundary with warning |
| Window size | 1..16384 px | Clamped with warning |
| Window position | -32768..32768 | Clamped with warning |
| Tree depth | 256 levels | Rendering/caching stops descending |

Image and font limits are per-process and survive Reset. Content limits
truncate at a UTF-8 character boundary.
