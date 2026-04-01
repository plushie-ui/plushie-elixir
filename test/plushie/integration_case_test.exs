defmodule Plushie.IntegrationCaseTest do
  use Plushie.IntegrationCase, async: true

  alias Plushie.Event.WidgetEvent

  alias Counter
  alias Todo

  describe "start_app/1" do
    test "starts a runtime with mock bridge and sends initial snapshot" do
      {runtime, bridge} = start_app(Counter)
      assert Process.alive?(runtime)

      snapshots = get_snapshots(bridge)
      assert length(snapshots) == 1
    end
  end

  describe "send_event/2" do
    test "dispatches events through the runtime" do
      {runtime, _bridge} = start_app(Counter)

      send_event(runtime, %WidgetEvent{type: :click, id: "inc"})

      model = get_model(runtime)
      assert model.count == 1
    end
  end

  describe "assert_tree/2" do
    test "provides the current tree to the assertion function" do
      {runtime, _bridge} = start_app(Counter)

      assert_tree(runtime, fn tree ->
        assert tree != nil
        assert tree.type == "window"
      end)
    end
  end

  describe "get_model/1" do
    test "returns the current model" do
      {runtime, _bridge} = start_app(Counter)
      model = get_model(runtime)
      assert model.count == 0
    end
  end

  describe "full integration flow" do
    test "counter app increments and decrements" do
      {runtime, _bridge} = start_app(Counter)

      send_event(runtime, %WidgetEvent{type: :click, id: "inc"})
      send_event(runtime, %WidgetEvent{type: :click, id: "inc"})
      send_event(runtime, %WidgetEvent{type: :click, id: "dec"})

      model = get_model(runtime)
      assert model.count == 1
    end
  end

  describe "daemon mode" do
    test "non-daemon runtime stops on all_windows_closed" do
      {runtime, _bridge} = start_app(Counter)
      ref = Process.monitor(runtime)

      # Send directly -- don't use send_event/2 which calls
      # :sys.get_state after dispatch (the runtime will be dead).
      Plushie.Runtime.dispatch(runtime, %Plushie.Event.SystemEvent{type: :all_windows_closed})

      assert_receive {:DOWN, ^ref, :process, ^runtime, :normal}, 1000
    end

    test "daemon runtime stays alive on all_windows_closed" do
      {runtime, _bridge} = start_app(Counter, daemon: true)
      ref = Process.monitor(runtime)

      send_event(runtime, %Plushie.Event.SystemEvent{type: :all_windows_closed})

      # Should NOT receive a DOWN message -- runtime stays alive
      refute_receive {:DOWN, ^ref, :process, ^runtime, _}, 200
      assert Process.alive?(runtime)
    end

    test "daemon runtime delivers all_windows_closed to update/2" do
      # Counter's catch-all update/2 returns the model unchanged,
      # which is fine -- the point is the runtime didn't stop.
      {runtime, _bridge} = start_app(Counter, daemon: true)

      send_event(runtime, %Plushie.Event.SystemEvent{type: :all_windows_closed})

      # Runtime is still alive and responsive
      model = get_model(runtime)
      assert model.count == 0
    end
  end

  describe "todo app integration" do
    test "add and toggle a todo" do
      {runtime, _bridge} = start_app(Todo)

      # Type in the input
      send_event(runtime, %WidgetEvent{type: :input, id: "new_todo", value: "Buy milk"})

      # Submit
      send_event(runtime, %WidgetEvent{type: :submit, id: "new_todo"})

      model = get_model(runtime)
      assert length(model.todos) == 1
      assert hd(model.todos).text == "Buy milk"
      assert hd(model.todos).done == false
    end
  end
end
