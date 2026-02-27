defmodule Julep.Examples.TodoTest do
  use ExUnit.Case, async: true

  alias Julep.Examples.Todo

  # ---------------------------------------------------------------------------
  # init/1
  # ---------------------------------------------------------------------------

  describe "init/1" do
    test "returns empty todo list" do
      model = Todo.init([])
      assert model.todos == []
      assert model.input == ""
      assert model.next_id == 1
      assert model.filter == :all
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- adding todos
  # ---------------------------------------------------------------------------

  describe "update/2 -- adding todos" do
    test "submit adds todo and clears input" do
      model = %{todos: [], input: "Buy milk", next_id: 1, filter: :all}
      model = Todo.update(model, {:submit, "todo_input", "Buy milk"})

      assert [%{id: 1, text: "Buy milk", done: false}] = model.todos
      assert model.input == ""
      assert model.next_id == 2
    end

    test "click add_todo adds todo" do
      model = %{todos: [], input: "Buy milk", next_id: 1, filter: :all}
      model = Todo.update(model, {:click, "add_todo"})

      assert [%{id: 1, text: "Buy milk", done: false}] = model.todos
    end

    test "empty input does nothing" do
      model = %{todos: [], input: "", next_id: 1, filter: :all}
      model = Todo.update(model, {:click, "add_todo"})
      assert model.todos == []
    end

    test "increments next_id" do
      model = %{todos: [], input: "First", next_id: 1, filter: :all}
      model = Todo.update(model, {:click, "add_todo"})
      model = %{model | input: "Second"}
      model = Todo.update(model, {:click, "add_todo"})
      assert [%{id: 1}, %{id: 2}] = model.todos
      assert model.next_id == 3
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- toggling
  # ---------------------------------------------------------------------------

  describe "update/2 -- toggling" do
    test "toggle marks todo done" do
      model = %{
        todos: [%{id: 1, text: "Buy milk", done: false}],
        input: "",
        next_id: 2,
        filter: :all
      }

      model = Todo.update(model, {:toggle, "todo:1", true})
      assert [%{id: 1, done: true}] = model.todos
    end

    test "toggle marks todo undone" do
      model = %{
        todos: [%{id: 1, text: "Buy milk", done: true}],
        input: "",
        next_id: 2,
        filter: :all
      }

      model = Todo.update(model, {:toggle, "todo:1", false})
      assert [%{id: 1, done: false}] = model.todos
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- deleting
  # ---------------------------------------------------------------------------

  describe "update/2 -- deleting" do
    test "delete removes todo" do
      model = %{
        todos: [%{id: 1, text: "A", done: false}, %{id: 2, text: "B", done: false}],
        input: "",
        next_id: 3,
        filter: :all
      }

      model = Todo.update(model, {:click, "delete:1"})
      assert [%{id: 2, text: "B"}] = model.todos
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- filtering
  # ---------------------------------------------------------------------------

  describe "update/2 -- filtering" do
    test "filter_all sets filter to :all" do
      model = %{todos: [], input: "", next_id: 1, filter: :active}
      model = Todo.update(model, {:click, "filter_all"})
      assert model.filter == :all
    end

    test "filter_active sets filter to :active" do
      model = %{todos: [], input: "", next_id: 1, filter: :all}
      model = Todo.update(model, {:click, "filter_active"})
      assert model.filter == :active
    end

    test "filter_completed sets filter to :completed" do
      model = %{todos: [], input: "", next_id: 1, filter: :all}
      model = Todo.update(model, {:click, "filter_completed"})
      assert model.filter == :completed
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- clear completed
  # ---------------------------------------------------------------------------

  describe "update/2 -- clear completed" do
    test "removes all done todos" do
      model = %{
        todos: [
          %{id: 1, text: "Done", done: true},
          %{id: 2, text: "Open", done: false},
          %{id: 3, text: "Also done", done: true}
        ],
        input: "",
        next_id: 4,
        filter: :all
      }

      model = Todo.update(model, {:click, "clear_completed"})
      assert [%{id: 2, text: "Open"}] = model.todos
    end
  end

  # ---------------------------------------------------------------------------
  # update/2 -- unknown events
  # ---------------------------------------------------------------------------

  describe "update/2 -- unknown events" do
    test "returns model unchanged" do
      model = Todo.init([])
      assert Todo.update(model, {:click, "nonexistent"}) == model
    end
  end

  # ---------------------------------------------------------------------------
  # view/1 -- tree structure
  # ---------------------------------------------------------------------------

  describe "view/1" do
    test "contains expected structure" do
      model = Todo.init([])
      tree = Julep.Tree.normalize(Todo.view(model))

      assert Julep.Tree.exists?(tree, "main")
      assert Julep.Tree.exists?(tree, "title")
      assert Julep.Tree.exists?(tree, "todo_input")
      assert Julep.Tree.exists?(tree, "add_todo")
      assert Julep.Tree.exists?(tree, "todo_count")
      assert Julep.Tree.exists?(tree, "filter_all")
      assert Julep.Tree.exists?(tree, "filter_active")
      assert Julep.Tree.exists?(tree, "filter_completed")
    end

    test "shows correct active count" do
      model = %{
        todos: [
          %{id: 1, text: "Done", done: true},
          %{id: 2, text: "Open", done: false}
        ],
        input: "",
        next_id: 3,
        filter: :all
      }

      tree = Julep.Tree.normalize(Todo.view(model))
      count_node = Julep.Tree.find(tree, "todo_count")
      assert count_node
      assert count_node.props["content"] =~ "1 item left"
    end

    test "filters todos in view" do
      model = %{
        todos: [
          %{id: 1, text: "Done", done: true},
          %{id: 2, text: "Open", done: false}
        ],
        input: "",
        next_id: 3,
        filter: :active
      }

      tree = Julep.Tree.normalize(Todo.view(model))

      assert Julep.Tree.exists?(tree, "todo:2")
      refute Julep.Tree.exists?(tree, "todo:1")
    end
  end

  # ---------------------------------------------------------------------------
  # Full scenario
  # ---------------------------------------------------------------------------

  describe "full scenario" do
    test "add, toggle, filter cycle" do
      model = Todo.init([])

      # Add a todo via input + submit
      model = Todo.update(model, {:input, "todo_input", "Buy milk"})
      model = Todo.update(model, {:submit, "todo_input", "Buy milk"})
      assert length(model.todos) == 1

      # Add another via click
      model = %{model | input: "Walk dog"}
      model = Todo.update(model, {:click, "add_todo"})
      assert length(model.todos) == 2

      # Toggle first
      model = Todo.update(model, {:toggle, "todo:1", true})
      assert hd(model.todos).done == true

      # Filter to active
      model = Todo.update(model, {:click, "filter_active"})
      tree = Julep.Tree.normalize(Todo.view(model))

      # Only "Walk dog" should be visible
      refute Julep.Tree.exists?(tree, "todo:1")
      assert Julep.Tree.exists?(tree, "todo:2")

      # Clear completed
      model = Todo.update(model, {:click, "clear_completed"})
      assert length(model.todos) == 1
      assert hd(model.todos).text == "Walk dog"
    end
  end
end
