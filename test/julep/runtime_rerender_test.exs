defmodule Julep.RuntimeRerenderTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Julep.Event.Widget

  # ---------------------------------------------------------------------------
  # Test app: counter whose view text changes when the model changes.
  # ---------------------------------------------------------------------------

  defmodule CounterApp do
    use Julep.App

    def init(_opts), do: %{count: 0}
    def update(model, %Widget{type: :click, id: "inc"}), do: %{model | count: model.count + 1}
    def update(model, _event), do: model

    def view(model) do
      import Julep.UI

      column do
        text("count:#{model.count}")
        button("inc", "+")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test app: view that raises on demand.
  # ---------------------------------------------------------------------------

  defmodule CrashyViewApp do
    use Julep.App

    def init(_opts), do: %{explode: false}
    def update(model, :arm), do: %{model | explode: true}
    def update(model, :disarm), do: %{model | explode: false}
    def update(model, _event), do: model

    def view(%{explode: true}), do: raise("view went boom")

    def view(_model) do
      import Julep.UI

      column do
        text("all good")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp start_runtime(app) do
    tag = System.unique_integer([:positive])
    bridge_name = :"rerender_bridge_#{tag}"
    runtime_name = :"rerender_runtime_#{tag}"

    {:ok, _bridge} = Julep.Test.MockBridge.start_link(name: bridge_name)
    {:ok, runtime} = Julep.Runtime.start_link(app: app, bridge: bridge_name, name: runtime_name)
    :sys.get_state(runtime)

    {runtime, bridge_name}
  end

  defp dispatch_and_wait(runtime, event) do
    Julep.Runtime.dispatch(runtime, event)
    :sys.get_state(runtime)
  end

  defp force_rerender_and_wait(runtime) do
    send(runtime, :force_rerender)
    :sys.get_state(runtime)
  end

  defp find_by_type(%{type: type} = node, type), do: node

  defp find_by_type(%{children: children}, target) when is_list(children) do
    Enum.find_value(children, &find_by_type(&1, target))
  end

  defp find_by_type(_node, _target), do: nil

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "force_rerender" do
    test "re-renders view with existing model, no update/2 call" do
      capture_log(fn ->
        {runtime, bridge} = start_runtime(CounterApp)

        # Mutate model via normal event first.
        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})
        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})

        state = :sys.get_state(runtime)
        assert state.model.count == 2

        patches_before = length(Julep.Test.MockBridge.get_patches(bridge))

        # Force re-render -- model should not change (no update/2 called).
        force_rerender_and_wait(runtime)

        state = :sys.get_state(runtime)
        assert state.model.count == 2

        # Since the model didn't change and the module code is the same,
        # the tree is identical -- no new patch should be sent.
        patches_after = length(Julep.Test.MockBridge.get_patches(bridge))
        assert patches_after == patches_before
      end)
    end

    test "model is preserved across force_rerender" do
      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CounterApp)

        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})
        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})
        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})

        model_before = :sys.get_state(runtime).model

        force_rerender_and_wait(runtime)

        model_after = :sys.get_state(runtime).model
        assert model_before == model_after
      end)
    end

    test "runtime stays alive when view/1 raises during force_rerender" do
      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CrashyViewApp)

        # Arm the crash.
        dispatch_and_wait(runtime, :arm)

        # Force re-render with a crashing view -- should not kill the runtime.
        force_rerender_and_wait(runtime)
        assert Process.alive?(runtime)

        # Old tree should be preserved.
        state = :sys.get_state(runtime)
        text_node = find_by_type(state.tree, "text")
        assert text_node.props["content"] == "all good"

        # Disarm and verify the runtime recovers.
        dispatch_and_wait(runtime, :disarm)
        force_rerender_and_wait(runtime)

        state = :sys.get_state(runtime)
        text_node = find_by_type(state.tree, "text")
        assert text_node.props["content"] == "all good"
      end)
    end

    test "runtime continues processing events after force_rerender" do
      capture_log(fn ->
        {runtime, _bridge} = start_runtime(CounterApp)

        force_rerender_and_wait(runtime)

        dispatch_and_wait(runtime, %Widget{type: :click, id: "inc"})

        state = :sys.get_state(runtime)
        assert state.model.count == 1

        text_node = find_by_type(state.tree, "text")
        assert text_node.props["content"] == "count:1"
      end)
    end
  end
end
