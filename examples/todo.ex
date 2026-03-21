defmodule Todo do
  @moduledoc """
  To-do list with add, toggle, delete, and filter.

  Demonstrates:
  - `text_input` with `on_submit` for keyboard-driven entry
  - Scoped IDs via named rows for dynamic list items
  - Scope binding in `update/2` for item-level events
  - `Command.focus/1` with scoped paths for refocusing
  - Filter buttons with conditional list rendering
  - View helper extraction (`todo_row/1`, `filtered/1`)
  """

  use Plushie.App

  alias Plushie.Command
  alias Plushie.Event.Widget

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
    todos =
      Enum.map(model.todos, fn
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
    import Plushie.UI

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
    import Plushie.UI

    container todo.id do
      row spacing: 8 do
        checkbox("toggle", todo.done)
        text(todo.text)
        button("delete", "x")
      end
    end
  end
end
