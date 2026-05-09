defmodule Plushie.RuntimeRerenderTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent

  # ---------------------------------------------------------------------------
  # Test app: counter whose view text changes when the model changes.
  # ---------------------------------------------------------------------------

  defmodule CounterApp do
    use Plushie.App

    def init(_opts), do: %{count: 0}

    def update(model, %WidgetEvent{type: :click, id: "inc"}),
      do: %{model | count: model.count + 1}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main" do
        column do
          text("count:#{model.count}")
          button("inc", "+")
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test app: view that raises on demand.
  # ---------------------------------------------------------------------------

  defmodule CrashyViewApp do
    use Plushie.App

    def init(_opts), do: %{explode: false}
    def update(model, :arm), do: %{model | explode: true}
    def update(model, :disarm), do: %{model | explode: false}
    def update(model, _event), do: model

    def view(%{explode: true}), do: raise("view went boom")

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          text("all good")
        end
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

    {:ok, _bridge} = Plushie.Test.InternalMockBridge.start_link(name: bridge_name)
    {:ok, runtime} = Plushie.Runtime.start_link(app: app, bridge: bridge_name, name: runtime_name)
    Plushie.Runtime.sync(runtime)

    {runtime, bridge_name}
  end

  defp dispatch_and_wait(runtime, event) do
    Plushie.Runtime.dispatch(runtime, event)
    Plushie.Runtime.sync(runtime)
  end

  defp force_rerender_and_wait(runtime) do
    send(runtime, :force_rerender)
    Plushie.Runtime.sync(runtime)
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
    @describetag capture_log: true

    test "re-renders view with existing model, no update/2 call" do
      {runtime, bridge} = start_runtime(CounterApp)

      # Mutate model via normal event first.
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})

      assert Plushie.Runtime.get_model(runtime).count == 2

      patches_before = length(Plushie.Test.InternalMockBridge.get_patches(bridge))

      # Force re-render; model should not change (no update/2 called).
      force_rerender_and_wait(runtime)

      assert Plushie.Runtime.get_model(runtime).count == 2

      # Since the model didn't change and the module code is the same,
      # the tree is identical; no new patch should be sent.
      patches_after = length(Plushie.Test.InternalMockBridge.get_patches(bridge))
      assert patches_after == patches_before
    end

    test "model is preserved across force_rerender" do
      {runtime, _bridge} = start_runtime(CounterApp)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})
      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})

      model_before = Plushie.Runtime.get_model(runtime)

      force_rerender_and_wait(runtime)

      model_after = Plushie.Runtime.get_model(runtime)
      assert model_before == model_after
    end

    test "runtime stays alive when view/1 raises during force_rerender" do
      {runtime, _bridge} = start_runtime(CrashyViewApp)

      # Arm the crash.
      dispatch_and_wait(runtime, :arm)

      # Force re-render with a crashing view; should not kill the runtime.
      force_rerender_and_wait(runtime)
      assert Process.alive?(runtime)

      # Old tree should be preserved.
      tree = Plushie.Runtime.get_tree(runtime)
      text_node = find_by_type(tree, "text")
      assert text_node.props[:content] == "all good"

      # Disarm and verify the runtime recovers.
      dispatch_and_wait(runtime, :disarm)
      force_rerender_and_wait(runtime)

      tree = Plushie.Runtime.get_tree(runtime)
      text_node = find_by_type(tree, "text")
      assert text_node.props[:content] == "all good"
    end

    test "runtime continues processing events after force_rerender" do
      {runtime, _bridge} = start_runtime(CounterApp)

      force_rerender_and_wait(runtime)

      dispatch_and_wait(runtime, %WidgetEvent{type: :click, id: "inc"})

      assert Plushie.Runtime.get_model(runtime).count == 1

      text_node = find_by_type(Plushie.Runtime.get_tree(runtime), "text")
      assert text_node.props[:content] == "count:1"
    end
  end

  # ---------------------------------------------------------------------------
  # Widget :update_state re-render
  # ---------------------------------------------------------------------------

  defmodule ClickCounterWidget do
    @moduledoc false
    use Plushie.Widget
    widget(:click_counter_widget)
    state(clicks: 0)

    @impl true
    def handle_event(%{type: :click}, state) do
      {:update_state, %{state | clicks: state.clicks + 1}}
    end

    def handle_event(_event, _state), do: :ignored

    @impl true
    def view(id, _props, state) do
      import Plushie.UI

      container id do
        text("clicks:#{state.clicks}")
      end
    end
  end

  defmodule WidgetStateApp do
    use Plushie.App

    def init(_opts), do: %{}
    def update(model, _event), do: model

    def view(_model) do
      import Plushie.UI

      window "main" do
        column do
          ClickCounterWidget.new("counter")
        end
      end
    end
  end

  describe "widget :update_state re-render" do
    test "re-renders tree immediately when handle_event returns {:update_state, ...}" do
      {runtime, _bridge} = start_runtime(WidgetStateApp)

      # Before any click the widget renders "clicks:0".
      tree = Plushie.Runtime.get_tree(runtime)
      text_node = find_by_type(tree, "text")
      assert text_node.props[:content] == "clicks:0"

      # Dispatch a click scoped to the widget. The widget's
      # handle_event returns {:update_state, ...} (no emit),
      # so the event is consumed and update/2 is never called.
      dispatch_and_wait(
        runtime,
        %WidgetEvent{type: :click, id: "counter", scope: [], window_id: "main"}
      )

      # The tree should reflect the updated widget state immediately.
      tree = Plushie.Runtime.get_tree(runtime)
      text_node = find_by_type(tree, "text")
      assert text_node.props[:content] == "clicks:1"

      # A second click should also re-render.
      dispatch_and_wait(
        runtime,
        %WidgetEvent{type: :click, id: "counter", scope: [], window_id: "main"}
      )

      tree = Plushie.Runtime.get_tree(runtime)
      text_node = find_by_type(tree, "text")
      assert text_node.props[:content] == "clicks:2"
    end
  end
end
