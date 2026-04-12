defmodule TodoTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent
  alias Todo

  describe "init/1" do
    test "returns empty todo list" do
      model = Todo.init([])
      assert model.todos == []
      assert model.input == ""
      assert model.next_id == 1
      assert model.filter == :all
    end
  end

  describe "adding todos" do
    test "submit adds todo and clears input" do
      model = %{todos: [], input: "Buy milk", next_id: 1, filter: :all}
      {model, _cmd} = Todo.update(model, %WidgetEvent{type: :submit, id: "new_todo"})

      assert [%{id: "todo_1", text: "Buy milk", done: false}] = model.todos
      assert model.input == ""
      assert model.next_id == 2
    end

    test "submit returns focus command" do
      model = %{todos: [], input: "Buy milk", next_id: 1, filter: :all}
      {_model, cmd} = Todo.update(model, %WidgetEvent{type: :submit, id: "new_todo"})

      assert %Plushie.Command{type: :focus} = cmd
    end

    test "empty input does nothing on submit" do
      model = %{todos: [], input: "", next_id: 1, filter: :all}
      result = Todo.update(model, %WidgetEvent{type: :submit, id: "new_todo"})
      assert result == model
    end

    test "whitespace-only input does nothing" do
      model = %{todos: [], input: "   ", next_id: 1, filter: :all}
      result = Todo.update(model, %WidgetEvent{type: :submit, id: "new_todo"})
      assert result == model
    end
  end

  describe "toggling" do
    test "toggle flips done state via scoped id" do
      model = %{
        todos: [%{id: "todo_1", text: "Buy milk", done: false}],
        input: "",
        next_id: 2,
        filter: :all
      }

      model =
        Todo.update(model, %WidgetEvent{
          type: :toggle,
          id: "toggle",
          scope: ["todo_1", "list", "app"]
        })

      assert [%{id: "todo_1", done: true}] = model.todos
    end

    test "toggle back to undone" do
      model = %{
        todos: [%{id: "todo_1", text: "Buy milk", done: true}],
        input: "",
        next_id: 2,
        filter: :all
      }

      model =
        Todo.update(model, %WidgetEvent{
          type: :toggle,
          id: "toggle",
          scope: ["todo_1"]
        })

      assert [%{id: "todo_1", done: false}] = model.todos
    end
  end

  describe "deleting" do
    test "delete removes todo via scoped id" do
      model = %{
        todos: [
          %{id: "todo_1", text: "A", done: false},
          %{id: "todo_2", text: "B", done: false}
        ],
        input: "",
        next_id: 3,
        filter: :all
      }

      model =
        Todo.update(model, %WidgetEvent{
          type: :click,
          id: "delete",
          scope: ["todo_1", "list", "app"]
        })

      assert [%{id: "todo_2", text: "B"}] = model.todos
    end
  end

  describe "filtering" do
    test "filter buttons update filter" do
      model = Todo.init([])

      model = Todo.update(model, %WidgetEvent{type: :click, id: "filter_active"})
      assert model.filter == :active

      model = Todo.update(model, %WidgetEvent{type: :click, id: "filter_done"})
      assert model.filter == :done

      model = Todo.update(model, %WidgetEvent{type: :click, id: "filter_all"})
      assert model.filter == :all
    end
  end

  describe "view/1" do
    test "contains expected structure" do
      model = Todo.init([])
      tree = Plushie.Tree.normalize(Todo.view(model))

      assert Plushie.Tree.exists?(tree, "main")
      assert Plushie.Tree.find(tree, "main#app/title")
      assert Plushie.Tree.find(tree, "main#app/new_todo")
      assert Plushie.Tree.find(tree, "main#app/filter_all")
      assert Plushie.Tree.find(tree, "main#app/filter_active")
      assert Plushie.Tree.find(tree, "main#app/filter_done")
    end

    test "renders todo items with scoped IDs" do
      model = %{
        todos: [%{id: "todo_1", text: "Buy milk", done: false}],
        input: "",
        next_id: 2,
        filter: :all
      }

      tree = Plushie.Tree.normalize(Todo.view(model))

      # The toggle checkbox is scoped under the todo row
      assert Plushie.Tree.find(tree, "main#app/list/todo_1/toggle")
      assert Plushie.Tree.find(tree, "main#app/list/todo_1/delete")
    end

    test "filters todos in view" do
      model = %{
        todos: [
          %{id: "todo_1", text: "Done", done: true},
          %{id: "todo_2", text: "Open", done: false}
        ],
        input: "",
        next_id: 3,
        filter: :active
      }

      tree = Plushie.Tree.normalize(Todo.view(model))

      # Only the active todo should be visible
      assert Plushie.Tree.exists?(tree, "main#app/list/todo_2/toggle")
      refute Plushie.Tree.exists?(tree, "main#app/list/todo_1/toggle")
    end
  end

  describe "unknown events" do
    test "returns model unchanged" do
      model = Todo.init([])
      assert Todo.update(model, %WidgetEvent{type: :click, id: "nonexistent"}) == model
    end
  end
end
