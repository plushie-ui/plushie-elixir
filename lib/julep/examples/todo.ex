defmodule Julep.Examples.Todo do
  @moduledoc """
  To-do list application with add, check off, delete, and filter.

  Demonstrates:
  - `text_input` with `on_submit` for keyboard-driven entry
  - Dynamic list rendering with scoped IDs (`todo:N`, `delete:N`)
  - `checkbox` toggle events with `value` payload
  - Filter buttons and conditional list filtering
  - `scrollable` for overflow content
  """

  use Julep.App

  alias Julep.Event.Widget

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{
      todos: [],
      input: "",
      next_id: 1,
      filter: :all
    }
  end

  # -- update ----------------------------------------------------------------

  def update(model, %Widget{type: :input, id: "todo_input", value: value}) do
    %{model | input: value}
  end

  def update(model, %Widget{type: :submit, id: "todo_input"}) do
    add_todo(model)
  end

  def update(model, %Widget{type: :click, id: "add_todo"}) do
    add_todo(model)
  end

  def update(model, %Widget{type: :toggle, id: "todo:" <> id_str, value: checked}) do
    id = String.to_integer(id_str)

    todos =
      Enum.map(model.todos, fn
        %{id: ^id} = todo -> %{todo | done: checked}
        todo -> todo
      end)

    %{model | todos: todos}
  end

  def update(model, %Widget{type: :click, id: "delete:" <> id_str}) do
    id = String.to_integer(id_str)
    todos = Enum.reject(model.todos, fn todo -> todo.id == id end)
    %{model | todos: todos}
  end

  def update(model, %Widget{type: :click, id: "filter_all"}), do: %{model | filter: :all}
  def update(model, %Widget{type: :click, id: "filter_active"}), do: %{model | filter: :active}

  def update(model, %Widget{type: :click, id: "filter_completed"}),
    do: %{model | filter: :completed}

  def update(model, %Widget{type: :click, id: "clear_completed"}) do
    todos = Enum.reject(model.todos, fn todo -> todo.done end)
    %{model | todos: todos}
  end

  def update(model, _event), do: model

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Julep.UI

    filtered_todos = filter_todos(model.todos, model.filter)
    active_count = Enum.count(model.todos, fn t -> not t.done end)

    window "main", title: "Todo" do
      column padding: 16, spacing: 12, width: :fill do
        text("title", "Todos", size: 24)

        row spacing: 8, width: :fill do
          text_input("todo_input", model.input,
            placeholder: "What needs to be done?",
            on_submit: true,
            width: :fill
          )

          button("add_todo", "Add")
        end

        scrollable "todo_list", height: :fill do
          column spacing: 4, width: :fill do
            for todo <- filtered_todos do
              row spacing: 8, width: :fill, id: "todo_row:#{todo.id}" do
                checkbox("todo:#{todo.id}", todo.done, label: todo.text)
                button("delete:#{todo.id}", "x")
              end
            end
          end
        end

        row spacing: 8 do
          text(
            "todo_count",
            "#{active_count} item#{if active_count != 1, do: "s", else: ""} left"
          )

          button("filter_all", "All")
          button("filter_active", "Active")
          button("filter_completed", "Completed")
          button("clear_completed", "Clear completed")
        end
      end
    end
  end

  # -- private ---------------------------------------------------------------

  defp add_todo(%{input: ""} = model), do: model

  defp add_todo(%{input: input} = model) do
    todo = %{id: model.next_id, text: String.trim(input), done: false}
    %{model | todos: model.todos ++ [todo], input: "", next_id: model.next_id + 1}
  end

  defp filter_todos(todos, :all), do: todos
  defp filter_todos(todos, :active), do: Enum.filter(todos, fn t -> not t.done end)
  defp filter_todos(todos, :completed), do: Enum.filter(todos, fn t -> t.done end)
end
