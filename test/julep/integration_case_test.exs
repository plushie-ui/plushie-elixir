defmodule Julep.IntegrationCaseTest do
  use Julep.IntegrationCase, async: true

  alias Julep.Event.Widget

  alias Julep.Examples.Counter
  alias Julep.Examples.Todo

  # ---------------------------------------------------------------------------
  # start_app/1
  # ---------------------------------------------------------------------------

  describe "start_app/1" do
    test "starts a runtime with mock bridge and sends initial snapshot" do
      {runtime, bridge} = start_app(Counter)
      assert Process.alive?(runtime)

      snapshots = get_snapshots(bridge)
      assert length(snapshots) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # send_event/2
  # ---------------------------------------------------------------------------

  describe "send_event/2" do
    test "dispatches events through the runtime" do
      {runtime, _bridge} = start_app(Counter)

      send_event(runtime, %Widget{type: :click, id: "increment"})

      model = get_model(runtime)
      assert model.count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # assert_tree/2
  # ---------------------------------------------------------------------------

  describe "assert_tree/2" do
    test "provides the current tree to the assertion function" do
      {runtime, _bridge} = start_app(Counter)

      assert_tree(runtime, fn tree ->
        assert tree != nil
        assert tree.type == "window"
      end)
    end
  end

  # ---------------------------------------------------------------------------
  # get_model/1
  # ---------------------------------------------------------------------------

  describe "get_model/1" do
    test "returns the current model" do
      {runtime, _bridge} = start_app(Counter)
      model = get_model(runtime)
      assert model.count == 0
    end
  end

  # ---------------------------------------------------------------------------
  # full integration flow
  # ---------------------------------------------------------------------------

  describe "full integration flow" do
    test "counter app increments and decrements" do
      {runtime, _bridge} = start_app(Counter)

      send_event(runtime, %Widget{type: :click, id: "increment"})
      send_event(runtime, %Widget{type: :click, id: "increment"})
      send_event(runtime, %Widget{type: :click, id: "decrement"})

      model = get_model(runtime)
      assert model.count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # to-do app integration
  # ---------------------------------------------------------------------------

  describe "todo app integration" do
    test "add and toggle a todo" do
      {runtime, _bridge} = start_app(Todo)

      # Type in the input
      send_event(runtime, %Widget{type: :input, id: "new_todo", value: "Buy milk"})

      # Submit
      send_event(runtime, %Widget{type: :submit, id: "new_todo"})

      model = get_model(runtime)
      assert length(model.todos) == 1
      assert hd(model.todos).text == "Buy milk"
      assert hd(model.todos).done == false
    end
  end
end
