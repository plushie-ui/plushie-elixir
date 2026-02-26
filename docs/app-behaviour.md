# App behaviour

`Julep.App` is the only behaviour an app developer implements. It follows the
Elm architecture: model, update, view.

## Callbacks

```elixir
@callback init(opts :: keyword()) :: model
@callback update(model, event) :: model
@callback view(model) :: Julep.UI.tree()
```

### init/1

Returns the initial model. Called once when the runtime starts.

```elixir
def init(_opts) do
  %{
    todos: [],
    input: "",
    filter: :all
  }
end
```

The model can be any term, but plain maps work best. The runtime does not
inspect or modify the model -- it is fully owned by the app.

`opts` is a keyword list passed through from the runtime start call, so
apps can accept configuration at startup.

### update/2

Receives the current model and an event, returns the next model.

```elixir
def update(model, {:click, "add_todo"}) do
  new_todo = %{id: System.unique_integer(), text: model.input, done: false}
  %{model | todos: [new_todo | model.todos], input: ""}
end

def update(model, {:input, "todo_field", value}) do
  %{model | input: value}
end

def update(model, _event), do: model
```

Events are tuples. The first element is the event family (atom), the rest
is event-specific data. Common families:

- `{:click, button_id}` -- button press
- `{:input, field_id, value}` -- text input change
- `{:select, field_id, value}` -- selection change
- `{:toggle, field_id, value}` -- checkbox/toggler change
- `{:submit, field_id, value}` -- form field submission
- `{:key, key_event}` -- keyboard event
- `{:window, window_event}` -- window lifecycle event

Update must be a pure function of its inputs. Side effects (file I/O, HTTP,
timers) are handled through the effects system (see [effects.md](effects.md)).

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
init(opts) -> initial model
  |
  v
view(model) -> initial tree -> send snapshot to renderer
  |
  v
[event received from renderer]
  |
  v
update(model, event) -> next model
  |
  v
view(next model) -> next tree -> diff -> send patch to renderer
  |
  v
[repeat from event received]
```

## Optional callbacks

These callbacks have sensible defaults but can be overridden:

```elixir
# Called when the renderer process exits unexpectedly. Return the model
# to use when the renderer restarts. Default: return model unchanged.
@callback handle_renderer_exit(model, exit_reason) :: model

# Called on runtime startup to configure window properties.
# Default: single window with app module name as title.
@callback window_config(model) :: Julep.Window.config()
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
