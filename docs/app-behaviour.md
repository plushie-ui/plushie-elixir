# App behaviour

`Julep.App` is the only behaviour an app developer implements. It follows the
Elm architecture: model, update, view.

## Callbacks

```elixir
@callback init(opts :: keyword()) :: model | {model, Julep.Command.t()}
@callback update(model, event) :: model | {model, Julep.Command.t()}
@callback view(model) :: Julep.UI.tree()

# Optional:
@callback subscribe(model) :: [Julep.Subscription.t()]
@callback handle_renderer_exit(model, exit_reason) :: model
@callback window_config(model) :: Julep.Window.config()
```

### init/1

Returns the initial model, optionally with commands. Called once when the
runtime starts.

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
  {model, Julep.Command.async(fn -> load_todos_from_disk() end, :todos_loaded)}
end
```

The model can be any term, but plain maps work best. The runtime does not
inspect or modify the model -- it is fully owned by the app.

`opts` is a keyword list passed through from the runtime start call, so
apps can accept configuration at startup.

### update/2

Receives the current model and an event, returns the next model -- optionally
with commands.

```elixir
def update(model, {:click, "add_todo"}) do
  new_todo = %{id: System.unique_integer(), text: model.input, done: false}
  %{model | todos: [new_todo | model.todos], input: ""}
end

def update(model, {:input, "todo_field", value}) do
  %{model | input: value}
end

# Returning commands:
def update(model, {:submit, "todo_field", _value}) do
  new_todo = %{id: System.unique_integer(), text: model.input, done: false}
  model = %{model | todos: [new_todo | model.todos], input: ""}
  {model, Julep.Command.focus("todo_field")}
end

def update(model, _event), do: model
```

Return a bare model when no side effects are needed. Return `{model, command}`
when you need async work, widget operations, window management, or timers.
See [commands.md](commands.md) for the full command API.

Events are tuples. The first element is the event family (atom), the rest
is event-specific data. See [events.md](events.md) for the full event
taxonomy. Common families:

- `{:click, button_id}` -- button press
- `{:input, field_id, value}` -- text input change
- `{:select, field_id, value}` -- selection change
- `{:toggle, field_id, value}` -- checkbox/toggler change
- `{:submit, field_id, value}` -- form field submission
- `{:key_press, key, modifiers}` -- keyboard event
- `{:window, action, window_id}` -- window lifecycle event

### view/1

Receives the current model, returns a UI tree.

```elixir
def view(model) do
  import Julep.UI

  window "main", title: "Todos" do
    column padding: 16, spacing: 8 do
      row spacing: 8 do
        text_input("todo_field", model.input, placeholder: "What needs doing?")
        button("add_todo", "Add")
      end

      for todo <- filtered_todos(model) do
        row id: "todo:#{todo.id}", spacing: 8 do
          checkbox("toggle:#{todo.id}", todo.done)
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

UI trees are plain maps (see [ui-trees.md](ui-trees.md)). The `Julep.UI`
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

```elixir
def subscribe(model) do
  subs = [Julep.Subscription.on_key_press(:key_event)]

  if model.auto_refresh do
    [Julep.Subscription.every(5000, :refresh) | subs]
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

Called on runtime startup to configure window properties. Default: single
window with app module name as title.

```elixir
def window_config(_model) do
  %{
    title: "My App",
    size: {800, 600},
    min_size: {400, 300},
    resizable: true,
    theme: "dark"
  }
end
```

## Starting the runtime

```elixir
# From IEx or application code:
{:ok, pid} = Julep.start(MyApp)
{:ok, pid} = Julep.start(MyApp, name: :my_app, renderer: "/path/to/julep_gui")

# Under a supervisor:
children = [
  {Julep, app: MyApp, name: :my_app}
]

# From mix:
# mix julep.gui MyApp
# mix julep.gui MyApp --release
```

## Testing

Apps can be tested without a renderer:

```elixir
test "adding a todo" do
  model = MyApp.init([])
  model = MyApp.update(model, {:input, "todo_field", "Buy milk"})
  model = MyApp.update(model, {:click, "add_todo"})

  assert [%{text: "Buy milk"}] = model.todos
  assert model.input == ""
end

test "view renders todo list" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  assert Julep.UI.find(tree, "todo:1")
end
```

Since `update` is a pure function and `view` returns plain maps, no special
test infrastructure is needed. The renderer is not involved.
