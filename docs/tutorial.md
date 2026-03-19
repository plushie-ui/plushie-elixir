# Tutorial: building a todo app

This tutorial walks through building a complete todo app, introducing
one concept per step. By the end you'll understand text inputs,
dynamic lists, scoped IDs, commands, and conditional rendering.

## Step 1: the model

Start with a model that tracks a list of todos and the current input
text.

```elixir
defmodule MyApp.Todo do
  use Toddy.App

  import Toddy.UI

  alias Toddy.Event.Widget

  def init(_opts) do
    %{
      todos: [],
      input: "",
      filter: :all,
      next_id: 1
    }
  end

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Todos" do
      column id: "app", padding: 20, spacing: 12, width: :fill do
        text("title", "My Todos", size: 24)
        text("empty", "No todos yet")
      end
    end
  end
end
```

Run it with `mix toddy.gui MyApp.Todo`. You'll see a title and a
placeholder message. Not much yet, but the structure is in place:
`init` sets up state, `view` renders it.

## Step 2: adding a text input

Add a text input that updates the model on every keystroke, and a
submit handler that creates a todo when the user presses Enter.

```elixir
def update(model, %Widget{type: :input, id: "new_todo", value: val}) do
  %{model | input: val}
end

def update(model, %Widget{type: :submit, id: "new_todo"}) do
  if String.trim(model.input) != "" do
    todo = %{id: "todo_#{model.next_id}", text: model.input, done: false}
    %{model | todos: [todo | model.todos], input: "", next_id: model.next_id + 1}
  else
    model
  end
end

def update(model, _event), do: model
```

And the view:

```elixir
def view(model) do
  window "main", title: "Todos" do
    column id: "app", padding: 20, spacing: 12, width: :fill do
      text("title", "My Todos", size: 24)

      text_input("new_todo", model.input,
        placeholder: "What needs doing?",
        on_submit: true
      )
    end
  end
end
```

Type something and press Enter. The input clears (the model's
`input` resets to `""`), but you can't see the todos yet. Let's
fix that.

## Step 3: rendering the list with scoped IDs

Each todo needs its own row with a checkbox and a delete button.
We wrap each item in a named row using the todo's ID. This creates
a **scope** -- children get unique IDs automatically without manual
prefixing.

```elixir
def view(model) do
  window "main", title: "Todos" do
    column id: "app", padding: 20, spacing: 12, width: :fill do
      text("title", "My Todos", size: 24)

      text_input("new_todo", model.input,
        placeholder: "What needs doing?",
        on_submit: true
      )

      column id: "list", spacing: 4 do
        for todo <- model.todos do
          container todo.id do
            row spacing: 8 do
              checkbox("toggle", todo.done)
              text(todo.text)
              button("delete", "x")
            end
          end
        end
      end
    end
  end
end
```

Each todo row has `id: todo.id` (e.g., `"todo_1"`). Inside it,
the checkbox has local id `"toggle"` and the button has `"delete"`.
On the wire, these become `"list/todo_1/toggle"` and
`"list/todo_1/delete"` -- unique across all items.

## Step 4: handling toggle and delete with scope

When the checkbox or delete button is clicked, the event carries the
local `id` and a `scope` list with the todo's row ID as the
immediate parent. Pattern match on both:

```elixir
def update(model, %Widget{type: :toggle, id: "toggle", scope: [todo_id | _]}) do
  todos = Enum.map(model.todos, fn
    %{id: ^todo_id} = t -> %{t | done: !t.done}
    t -> t
  end)
  %{model | todos: todos}
end

def update(model, %Widget{type: :click, id: "delete", scope: [todo_id | _]}) do
  %{model | todos: Enum.reject(model.todos, &(&1.id == todo_id))}
end
```

The `scope: [todo_id | _]` pattern binds the immediate parent's ID
(e.g., `"todo_1"`) regardless of how deep the row is nested. If you
later move the list into a sidebar or tab, the pattern still works.

## Step 5: refocusing with a command

After submitting a todo, the text input loses focus. Let's refocus
it automatically using `Toddy.Command.focus/1`:

```elixir
alias Toddy.Command

def update(model, %Widget{type: :submit, id: "new_todo"}) do
  if String.trim(model.input) != "" do
    todo = %{id: "todo_#{model.next_id}", text: model.input, done: false}
    model = %{model | todos: [todo | model.todos], input: "", next_id: model.next_id + 1}
    {model, Command.focus("app/new_todo")}
  else
    model
  end
end
```

Note the scoped path `"app/new_todo"` -- the text input is inside
the `"app"` column, so its full ID is `"app/new_todo"`. Commands
always use the full scoped path.

## Step 6: filtering

Add filter buttons that toggle between all, active, and completed
todos.

```elixir
def update(model, %Widget{type: :click, id: "filter_all"}),
  do: %{model | filter: :all}

def update(model, %Widget{type: :click, id: "filter_active"}),
  do: %{model | filter: :active}

def update(model, %Widget{type: :click, id: "filter_done"}),
  do: %{model | filter: :done}
```

Add the filter buttons and apply the filter in the view:

```elixir
def view(model) do
  window "main", title: "Todos" do
    column id: "app", padding: 20, spacing: 12, width: :fill do
      text("title", "My Todos", size: 24)

      text_input("new_todo", model.input,
        placeholder: "What needs doing?",
        on_submit: true
      )

      row spacing: 8 do
        button("filter_all", "All")
        button("filter_active", "Active")
        button("filter_done", "Done")
      end

      column id: "list", spacing: 4 do
        for todo <- filtered(model) do
          todo_row(todo)
        end
      end
    end
  end
end

defp filtered(%{filter: :all, todos: todos}), do: todos
defp filtered(%{filter: :active, todos: todos}), do: Enum.reject(todos, & &1.done)
defp filtered(%{filter: :done, todos: todos}), do: Enum.filter(todos, & &1.done)

defp todo_row(todo) do
  container todo.id do
    row spacing: 8 do
      checkbox("toggle", todo.done)
      text(todo.text)
      button("delete", "x")
    end
  end
end
```

Notice `todo_row/1` is extracted as a view helper. Each helper
imports `Toddy.UI` independently (the import is lexically scoped).

## The complete app

The full source is in
[`examples/todo.ex`](https://github.com/toddy-ui/toddy-elixir/blob/main/examples/todo.ex)
with tests in
[`test/toddy/examples/todo_test.exs`](https://github.com/toddy-ui/toddy-elixir/blob/main/test/toddy/examples/todo_test.exs).

```elixir
defmodule MyApp.Todo do
  use Toddy.App

  import Toddy.UI

  alias Toddy.Command
  alias Toddy.Event.Widget

  # -- Init -----------------------------------------------------------------

  def init(_opts) do
    %{todos: [], input: "", filter: :all, next_id: 1}
  end

  # -- Update ---------------------------------------------------------------

  def update(model, %Widget{type: :input, id: "new_todo", value: val}) do
    %{model | input: val}
  end

  def update(model, %Widget{type: :submit, id: "new_todo"}) do
    if String.trim(model.input) != "" do
      todo = %{id: "todo_#{model.next_id}", text: model.input, done: false}
      model = %{model | todos: [todo | model.todos], input: "", next_id: model.next_id + 1}
      {model, Command.focus("app/new_todo")}
    else
      model
    end
  end

  def update(model, %Widget{type: :toggle, id: "toggle", scope: [todo_id | _]}) do
    todos = Enum.map(model.todos, fn
      %{id: ^todo_id} = t -> %{t | done: !t.done}
      t -> t
    end)
    %{model | todos: todos}
  end

  def update(model, %Widget{type: :click, id: "delete", scope: [todo_id | _]}) do
    %{model | todos: Enum.reject(model.todos, &(&1.id == todo_id))}
  end

  def update(model, %Widget{type: :click, id: "filter_all"}), do: %{model | filter: :all}
  def update(model, %Widget{type: :click, id: "filter_active"}), do: %{model | filter: :active}
  def update(model, %Widget{type: :click, id: "filter_done"}), do: %{model | filter: :done}

  def update(model, _event), do: model

  # -- View -----------------------------------------------------------------

  def view(model) do
    window "main", title: "Todos" do
      column id: "app", padding: 20, spacing: 12, width: :fill do
        text("title", "My Todos", size: 24)

        text_input("new_todo", model.input,
          placeholder: "What needs doing?",
          on_submit: true
        )

        row spacing: 8 do
          button("filter_all", "All")
          button("filter_active", "Active")
          button("filter_done", "Done")
        end

        column id: "list", spacing: 4 do
          for todo <- filtered(model) do
            todo_row(todo)
          end
        end
      end
    end
  end

  defp filtered(%{filter: :all, todos: todos}), do: todos
  defp filtered(%{filter: :active, todos: todos}), do: Enum.reject(todos, & &1.done)
  defp filtered(%{filter: :done, todos: todos}), do: Enum.filter(todos, & &1.done)

  defp todo_row(todo) do
    container todo.id do
      row spacing: 8 do
        checkbox("toggle", todo.done)
        text(todo.text)
        button("delete", "x")
      end
    end
  end
end
```

## What you've learned

- **Text inputs** with `on_submit: true` for form-like behavior
- **Scoped IDs** via named containers (`container todo.id do`)
- **Scope binding** in update (`scope: [todo_id | _]`)
- **Commands** for side effects (`Command.focus/1` with scoped paths)
- **Conditional rendering** with filter functions
- **View helpers** extracted as private functions

## Next steps

- [Commands](commands.md) -- async work, file dialogs, timers
- [Scoped IDs](scoped-ids.md) -- full scoping reference
- [Composition patterns](composition-patterns.md) -- scaling beyond
  a single module
- [Testing](testing.md) -- unit and integration testing
