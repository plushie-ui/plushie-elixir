defmodule Plushie.Docs.TutorialTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Event.WidgetEvent

  # -- Todo app reproduced from tutorial doc --

  defmodule TodoApp do
    use Plushie.App

    alias Plushie.Command
    alias Plushie.Event.WidgetEvent

    def init(_opts) do
      %{todos: [], input: "", filter: :all, next_id: 1}
    end

    def update(model, %WidgetEvent{type: :input, id: "new_todo", value: val}) do
      %{model | input: val}
    end

    def update(model, %WidgetEvent{type: :submit, id: "new_todo"}) do
      if String.trim(model.input) != "" do
        todo = %{id: "todo_#{model.next_id}", text: model.input, done: false}
        model = %{model | todos: [todo | model.todos], input: "", next_id: model.next_id + 1}
        {model, Command.focus("app/new_todo")}
      else
        model
      end
    end

    def update(model, %WidgetEvent{type: :toggle, id: "toggle", scope: [todo_id | _]}) do
      todos =
        Enum.map(model.todos, fn
          %{id: ^todo_id} = t -> %{t | done: !t.done}
          t -> t
        end)

      %{model | todos: todos}
    end

    def update(model, %WidgetEvent{type: :click, id: "delete", scope: [todo_id | _]}) do
      %{model | todos: Enum.reject(model.todos, &(&1.id == todo_id))}
    end

    def update(model, %WidgetEvent{type: :click, id: "filter_all"}), do: %{model | filter: :all}

    def update(model, %WidgetEvent{type: :click, id: "filter_active"}),
      do: %{model | filter: :active}

    def update(model, %WidgetEvent{type: :click, id: "filter_done"}), do: %{model | filter: :done}

    def update(model, _event), do: model

    # Step 1 view (no input, just title + placeholder)
    def step1_view(_model) do
      import Plushie.UI

      window "main", title: "Todos" do
        column id: "app", padding: 20, spacing: 12, width: :fill do
          text("title", "My Todos", size: 24)
          text("empty", "No todos yet")
        end
      end
    end

    # Step 3 view (input + todo list, no filters)
    def step3_view(model) do
      import Plushie.UI

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

    # Full view (step 6 -- filters + extracted helpers)
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

    def filtered(%{filter: :all, todos: todos}), do: todos
    def filtered(%{filter: :active, todos: todos}), do: Enum.reject(todos, & &1.done)
    def filtered(%{filter: :done, todos: todos}), do: Enum.filter(todos, & &1.done)

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

  # -- Step 1: init and initial view --

  test "tutorial_step1_init_test" do
    model = TodoApp.init([])
    assert model.todos == []
    assert model.input == ""
    assert model.filter == :all
    assert model.next_id == 1
  end

  test "tutorial_step1_view_test" do
    model = TodoApp.init([])
    tree = Plushie.Tree.normalize(TodoApp.step1_view(model))

    assert tree.type == "window"
    assert tree.id == "main"
    assert tree.props[:title] == "Todos"

    assert [column] = tree.children
    assert column.type == "column"
    assert column.id == "main#app"
    assert column.props[:spacing] == 12
    assert column.props[:width] == "fill"

    assert [title, empty] = column.children
    assert title.type == "text"
    assert title.props[:content] == "My Todos"
    assert title.props[:size] == 24
    assert empty.type == "text"
    assert empty.props[:content] == "No todos yet"
  end

  # -- Step 2: input handling --

  test "tutorial_step2_input_updates_model_test" do
    model = TodoApp.init([])
    model = TodoApp.update(model, %WidgetEvent{type: :input, id: "new_todo", value: "Buy milk"})
    assert model.input == "Buy milk"
  end

  test "tutorial_step2_submit_creates_todo_test" do
    model = TodoApp.init([])
    model = TodoApp.update(model, %WidgetEvent{type: :input, id: "new_todo", value: "Buy milk"})
    {model, cmd} = TodoApp.update(model, %WidgetEvent{type: :submit, id: "new_todo"})

    assert model.input == ""
    assert model.next_id == 2
    assert [item] = model.todos
    assert item.text == "Buy milk"
    assert item.id == "todo_1"
    assert item.done == false
    assert %Command{type: :focus} = cmd
  end

  test "tutorial_step2_empty_submit_does_nothing_test" do
    model = TodoApp.init([])
    model = TodoApp.update(model, %WidgetEvent{type: :input, id: "new_todo", value: "   "})
    result = TodoApp.update(model, %WidgetEvent{type: :submit, id: "new_todo"})
    assert result == model
    assert result.todos == []
  end

  test "tutorial_step2_view_has_text_input_test" do
    model = %{todos: [], input: "Hello", filter: :all, next_id: 1}
    tree = Plushie.Tree.normalize(TodoApp.step3_view(model))

    assert [column] = tree.children
    assert [_title, input | _] = column.children
    assert input.type == "text_input"
    assert input.id == "main#app/new_todo"
    assert input.props[:value] == "Hello"
    assert input.props[:placeholder] == "What needs doing?"
    assert input.props[:on_submit] == true
  end

  # -- Step 3: rendering the list with scoped IDs --

  test "tutorial_step3_view_renders_todo_list_test" do
    model = %{
      todos: [
        %{id: "todo_1", text: "Buy milk", done: false},
        %{id: "todo_2", text: "Walk dog", done: true}
      ],
      input: "",
      filter: :all,
      next_id: 3
    }

    tree = Plushie.Tree.normalize(TodoApp.step3_view(model))

    list_col = Plushie.Tree.find(tree, "main#app/list")
    assert list_col.type == "column"
    assert list_col.props[:spacing] == 4

    assert [row1, row2] = list_col.children
    assert row1.id == "main#app/list/todo_1"
    assert row1.type == "container"
    assert row2.id == "main#app/list/todo_2"
  end

  test "tutorial_step3_todo_row_structure_test" do
    model = %{
      todos: [%{id: "todo_1", text: "Buy milk", done: false}],
      input: "",
      filter: :all,
      next_id: 2
    }

    tree = Plushie.Tree.normalize(TodoApp.step3_view(model))

    # Find the container for todo_1
    container = Plushie.Tree.find(tree, "main#app/list/todo_1")
    assert container.type == "container"

    assert [inner_row] = container.children
    assert inner_row.type == "row"
    assert inner_row.props[:spacing] == 8

    assert [cb, text_node, btn] = inner_row.children
    assert cb.type == "checkbox"
    assert cb.id == "main#app/list/todo_1/toggle"
    assert cb.props[:checked] == false
    assert text_node.type == "text"
    assert text_node.props[:content] == "Buy milk"
    assert btn.type == "button"
    assert btn.id == "main#app/list/todo_1/delete"
    assert btn.props[:label] == "x"
  end

  # -- Step 4: toggle and delete --

  test "tutorial_step4_toggle_test" do
    model = %{
      todos: [%{id: "todo_1", text: "Buy milk", done: false}],
      input: "",
      filter: :all,
      next_id: 2
    }

    model =
      TodoApp.update(model, %WidgetEvent{
        type: :toggle,
        id: "toggle",
        scope: ["todo_1", "list", "app"]
      })

    assert [%{id: "todo_1", done: true}] = model.todos
  end

  test "tutorial_step4_delete_test" do
    model = %{
      todos: [%{id: "todo_1", text: "Buy milk", done: false}],
      input: "",
      filter: :all,
      next_id: 2
    }

    model =
      TodoApp.update(model, %WidgetEvent{
        type: :click,
        id: "delete",
        scope: ["todo_1", "list", "app"]
      })

    assert model.todos == []
  end

  # -- Step 5: submit returns focus command --

  test "tutorial_step5_submit_returns_focus_command_test" do
    model = %{todos: [], input: "Buy milk", filter: :all, next_id: 1}
    {_model, cmd} = TodoApp.update(model, %WidgetEvent{type: :submit, id: "new_todo"})

    assert %Command{type: :focus, payload: %{target: "app/new_todo"}} = cmd
  end

  # -- Step 6: filtering --

  test "tutorial_step6_filter_all_test" do
    model = TodoApp.init([])
    model = TodoApp.update(model, %WidgetEvent{type: :click, id: "filter_active"})
    assert model.filter == :active
    model = TodoApp.update(model, %WidgetEvent{type: :click, id: "filter_all"})
    assert model.filter == :all
  end

  test "tutorial_step6_filter_done_test" do
    model = TodoApp.init([])
    model = TodoApp.update(model, %WidgetEvent{type: :click, id: "filter_done"})
    assert model.filter == :done
  end

  test "tutorial_step6_view_has_filter_buttons_test" do
    model = TodoApp.init([])
    tree = Plushie.Tree.normalize(TodoApp.view(model))

    assert [column] = tree.children
    assert [_title, _input, filters, _list] = column.children
    assert filters.type == "row"

    assert [all_btn, active_btn, done_btn] = filters.children
    assert all_btn.id == "main#app/filter_all"
    assert all_btn.props[:label] == "All"
    assert active_btn.id == "main#app/filter_active"
    assert done_btn.id == "main#app/filter_done"
  end

  test "tutorial_step6_view_filters_todos_test" do
    model = %{
      todos: [
        %{id: "todo_1", text: "Buy milk", done: false},
        %{id: "todo_2", text: "Walk dog", done: true}
      ],
      input: "",
      filter: :active,
      next_id: 3
    }

    tree = Plushie.Tree.normalize(TodoApp.view(model))

    # Only the active todo should appear
    assert Plushie.Tree.exists?(tree, "main#app/list/todo_1/toggle")
    refute Plushie.Tree.exists?(tree, "main#app/list/todo_2/toggle")
  end

  test "tutorial_step6_filtered_helper_test" do
    model = %{
      todos: [
        %{id: "todo_1", text: "Buy milk", done: false},
        %{id: "todo_2", text: "Walk dog", done: true},
        %{id: "todo_3", text: "Read book", done: false}
      ],
      input: "",
      filter: :all,
      next_id: 4
    }

    assert length(TodoApp.filtered(model)) == 3
    assert length(TodoApp.filtered(%{model | filter: :active})) == 2
    assert length(TodoApp.filtered(%{model | filter: :done})) == 1
  end
end
