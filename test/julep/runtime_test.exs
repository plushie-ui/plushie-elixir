defmodule Julep.RuntimeTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Test app: simple counter driven by button click events.
  # ---------------------------------------------------------------------------

  defmodule SimpleApp do
    use Julep.App

    def init(_opts), do: %{value: 0}

    def update(model, {:click, "inc"}), do: %{model | value: model.value + 1}
    def update(model, {:click, "dec"}), do: %{model | value: model.value - 1}
    def update(model, _event), do: model

    def view(model) do
      import Julep.UI
      column do
        text("Value: #{model.value}")
        button("inc", "+")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test app: exercises send_after (schedules a timer in init).
  # ---------------------------------------------------------------------------

  defmodule CommandApp do
    use Julep.App

    def init(_opts) do
      {%{value: 0}, Julep.Command.send_after(10, :timer_tick)}
    end

    def update(model, :timer_tick), do: %{model | value: model.value + 1}
    def update(model, _event), do: model

    def view(model) do
      import Julep.UI
      column do
        text("#{model.value}")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Test app: exercises the async command (no timer in init to avoid races).
  # ---------------------------------------------------------------------------

  defmodule AsyncApp do
    use Julep.App

    def init(_opts), do: %{value: 0}

    def update(model, {:click, "async"}) do
      cmd = Julep.Command.async(fn -> 42 end, :async_result)
      {model, cmd}
    end

    def update(model, {:async_result, result}), do: %{model | value: result}
    def update(model, _event), do: model

    def view(model) do
      import Julep.UI
      column do
        text("#{model.value}")
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Starts a uniquely-named MockBridge and Runtime pair for a single test.
  # Returns {runtime_pid, bridge_name}.
  defp start_runtime(app, extra_opts \\ []) do
    # Use the test PID to ensure unique names per test (async: true safe).
    tag = System.unique_integer([:positive])
    bridge_name = :"mock_bridge_#{tag}"
    runtime_name = :"runtime_#{tag}"

    {:ok, _bridge} = Julep.Test.MockBridge.start_link(name: bridge_name)

    opts =
      [app: app, bridge: bridge_name, name: runtime_name]
      |> Keyword.merge(extra_opts)

    {:ok, runtime} = Julep.Runtime.start_link(opts)

    {runtime, bridge_name}
  end

  # Waits for handle_continue/:initial_render to complete.
  # :sys.get_state/1 is synchronous and processes all pending messages first.
  defp await_initial_render(runtime) do
    :sys.get_state(runtime)
  end

  # Dispatches an event and waits for the runtime to process it.
  defp dispatch_and_wait(runtime, event) do
    Julep.Runtime.dispatch(runtime, event)
    :sys.get_state(runtime)
  end

  # ---------------------------------------------------------------------------
  # describe "init/update/view cycle"
  # ---------------------------------------------------------------------------

  describe "init/update/view cycle" do
    test "Runtime starts and sends initial snapshot to bridge" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(snapshots) == 1

      [snapshot] = snapshots
      assert snapshot.type == "column"

      # The text child should reflect the initial model value of 0.
      text_node = find_by_type(snapshot, "text")
      assert text_node != nil
      assert text_node.props["content"] == "Value: 0"
    end

    test "dispatching an event updates the model and sends a patch" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "inc"})

      # Initial render sends a snapshot; subsequent updates send patches.
      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(snapshots) == 1

      patches = Julep.Test.MockBridge.get_patches(bridge)
      assert length(patches) == 1

      # Verify the runtime's current tree reflects the update.
      state = :sys.get_state(runtime)
      text_node = find_by_type(state.tree, "text")
      assert text_node.props["content"] == "Value: 1"
    end

    test "multiple events produce patches and update model correctly" do
      {runtime, _bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "inc"})
      dispatch_and_wait(runtime, {:click, "inc"})
      dispatch_and_wait(runtime, {:click, "dec"})

      state = :sys.get_state(runtime)
      assert state.model.value == 1

      text_node = find_by_type(state.tree, "text")
      assert text_node.props["content"] == "Value: 1"
    end

    test "unknown events are handled and model remains unchanged" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "nope"})
      dispatch_and_wait(runtime, :mystery_event)

      # Unknown events don't change the tree, so no patches are sent.
      patches = Julep.Test.MockBridge.get_patches(bridge)
      assert patches == []

      state = :sys.get_state(runtime)
      assert state.model.value == 0
    end
  end

  # ---------------------------------------------------------------------------
  # describe "commands"
  # ---------------------------------------------------------------------------

  describe "commands" do
    test "send_after delivers the event after the specified delay" do
      {runtime, _bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # send_after(10, :timer_tick) is scheduled in init; wait long enough.
      Process.sleep(80)
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.value == 1

      text_node = find_by_type(state.tree, "text")
      assert text_node.props["content"] == "1"
    end

    test "async command delivers its result through update" do
      {runtime, _bridge} = start_runtime(AsyncApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "async"})

      # Give the spawned Task time to complete and the runtime to process it.
      Process.sleep(50)
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.value == 42

      text_node = find_by_type(state.tree, "text")
      assert text_node.props["content"] == "42"
    end

    test "batch commands are all executed" do
      # Build an app whose update returns a batch of two send_after commands.
      defmodule BatchApp do
        use Julep.App

        def init(_opts), do: %{ticks: 0}

        def update(model, :tick), do: %{model | ticks: model.ticks + 1}

        def update(model, {:click, "batch"}) do
          cmd =
            Julep.Command.batch([
              Julep.Command.send_after(10, :tick),
              Julep.Command.send_after(10, :tick)
            ])

          {model, cmd}
        end

        def update(model, _event), do: model

        def view(model) do
          import Julep.UI
          column do
            text("ticks:#{model.ticks}")
            button("batch", "Go")
          end
        end
      end

      {runtime, _bridge} = start_runtime(BatchApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "batch"})

      # Wait for both delayed events to fire.
      Process.sleep(80)
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.ticks == 2

      text_node = find_by_type(state.tree, "text")
      assert text_node.props["content"] == "ticks:2"
    end

    test "init with commands executes them" do
      {runtime, _bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # The CommandApp init schedules send_after(10, :timer_tick).
      Process.sleep(80)
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.value == 1
    end
  end

  # ---------------------------------------------------------------------------
  # describe "renderer lifecycle"
  # ---------------------------------------------------------------------------

  describe "renderer lifecycle" do
    test "{:renderer_exit, reason} calls handle_renderer_exit and model is updated" do
      # An app that marks itself as :crashed on renderer exit.
      defmodule ExitApp do
        use Julep.App

        def init(_opts), do: %{status: :ok}
        def update(model, _event), do: model

        def view(model) do
          import Julep.UI
          column do
            text(inspect(model.status))
          end
        end

        def handle_renderer_exit(model, _reason), do: %{model | status: :crashed}
      end

      {runtime, bridge} = start_runtime(ExitApp)
      await_initial_render(runtime)

      send(runtime, {:renderer_exit, :port_closed})
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.status == :crashed

      # renderer_exit does NOT produce a new snapshot -- it only updates the model
      # so it is ready when the renderer restarts.
      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(snapshots) == 1
    end

    test ":renderer_restarted re-sends the current tree to the bridge" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      initial_snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(initial_snapshots) == 1

      send(runtime, :renderer_restarted)
      :sys.get_state(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      # Should have sent the same tree a second time.
      assert length(snapshots) == 2

      [first, second] = snapshots
      assert first == second
    end
  end

  # ---------------------------------------------------------------------------
  # describe "subscriptions"
  # ---------------------------------------------------------------------------

  describe "subscriptions" do
    test "app with every subscription receives periodic tick events" do
      defmodule TickApp do
        use Julep.App

        def init(_opts), do: %{ticks: 0}

        def update(model, {:tick, _timestamp}), do: %{model | ticks: model.ticks + 1}
        def update(model, _event), do: model

        def subscribe(_model), do: [Julep.Subscription.every(20, :tick)]

        def view(model) do
          import Julep.UI
          column do
            text("ticks:#{model.ticks}")
          end
        end
      end

      {runtime, _bridge} = start_runtime(TickApp)
      await_initial_render(runtime)

      # Wait long enough for at least 2 ticks (20ms interval).
      Process.sleep(80)
      :sys.get_state(runtime)

      state = :sys.get_state(runtime)
      assert state.model.ticks >= 2
    end

    test "subscription removed when subscribe/1 stops returning it" do
      defmodule ToggleSubApp do
        use Julep.App

        def init(_opts), do: %{timer_on: true, ticks: 0}

        def update(model, {:tick, _ts}), do: %{model | ticks: model.ticks + 1}
        def update(model, :stop_timer), do: %{model | timer_on: false}
        def update(model, _event), do: model

        def subscribe(model) do
          if model.timer_on do
            [Julep.Subscription.every(15, :tick)]
          else
            []
          end
        end

        def view(model) do
          import Julep.UI
          column do
            text("ticks:#{model.ticks}")
          end
        end
      end

      {runtime, _bridge} = start_runtime(ToggleSubApp)
      await_initial_render(runtime)

      # Let some ticks accumulate.
      Process.sleep(60)
      :sys.get_state(runtime)

      ticks_before = :sys.get_state(runtime).model.ticks
      assert ticks_before >= 2

      # Stop the timer subscription.
      dispatch_and_wait(runtime, :stop_timer)

      # Wait and confirm no more ticks arrive.
      Process.sleep(60)
      :sys.get_state(runtime)

      ticks_after = :sys.get_state(runtime).model.ticks
      # Ticks should not have increased after stopping.
      assert ticks_after == ticks_before
    end

    test "multiple subscriptions can coexist" do
      defmodule MultiSubApp do
        use Julep.App

        def init(_opts), do: %{fast: 0, slow: 0}

        def update(model, {:fast_tick, _ts}), do: %{model | fast: model.fast + 1}
        def update(model, {:slow_tick, _ts}), do: %{model | slow: model.slow + 1}
        def update(model, _event), do: model

        def subscribe(_model) do
          [
            Julep.Subscription.every(15, :fast_tick),
            Julep.Subscription.every(40, :slow_tick)
          ]
        end

        def view(model) do
          import Julep.UI
          column do
            text("fast:#{model.fast}")
            text("slow:#{model.slow}")
          end
        end
      end

      {runtime, _bridge} = start_runtime(MultiSubApp)
      await_initial_render(runtime)

      Process.sleep(100)
      state = :sys.get_state(runtime)

      # Both subscriptions should have fired at least once.
      assert state.model.fast >= 2
      assert state.model.slow >= 1
      # Fast should tick more than slow.
      assert state.model.fast > state.model.slow
    end
  end

  # ---------------------------------------------------------------------------
  # describe "error recovery"
  # ---------------------------------------------------------------------------

  describe "error recovery" do
    test "update/2 exception does not crash the runtime" do
      defmodule CrashUpdateApp do
        use Julep.App

        def init(_opts), do: %{value: 0}
        def update(_model, :crash), do: raise("boom")
        def update(model, {:click, "inc"}), do: %{model | value: model.value + 1}
        def update(model, _event), do: model

        def view(model) do
          import Julep.UI

          column do
            text("#{model.value}")
          end
        end
      end

      {runtime, _bridge} = start_runtime(CrashUpdateApp)
      await_initial_render(runtime)

      # This should not crash the runtime.
      dispatch_and_wait(runtime, :crash)

      # Runtime is still alive and model unchanged.
      assert Process.alive?(runtime)
      state = :sys.get_state(runtime)
      assert state.model.value == 0

      # Can still process normal events after the crash.
      dispatch_and_wait(runtime, {:click, "inc"})
      state = :sys.get_state(runtime)
      assert state.model.value == 1
    end

    test "view/1 exception does not crash the runtime" do
      defmodule CrashViewApp do
        use Julep.App

        def init(_opts), do: %{crash_view: false}
        def update(model, :crash_view), do: %{model | crash_view: true}
        def update(model, :fix_view), do: %{model | crash_view: false}
        def update(model, _event), do: model

        def view(%{crash_view: true}), do: raise("view boom")

        def view(_model) do
          import Julep.UI

          column do
            text("ok")
          end
        end
      end

      {runtime, _bridge} = start_runtime(CrashViewApp)
      await_initial_render(runtime)

      # Trigger the crashing view -- runtime should survive.
      dispatch_and_wait(runtime, :crash_view)
      assert Process.alive?(runtime)

      # Fix the view and confirm the runtime continues normally.
      dispatch_and_wait(runtime, :fix_view)
      state = :sys.get_state(runtime)
      assert state.model.crash_view == false
    end
  end

  # ---------------------------------------------------------------------------
  # describe "effects"
  # ---------------------------------------------------------------------------

  describe "effects" do
    test "effect_request command is forwarded to the bridge" do
      defmodule EffectApp do
        use Julep.App

        def init(_opts), do: %{result: nil}

        def update(model, {:click, "open"}) do
          {cmd, _id} = Julep.Effects.file_open(title: "Pick a file")
          {model, cmd}
        end

        def update(model, {:effect_result, _id, {:ok, result}}) do
          %{model | result: result}
        end

        def update(model, _event), do: model

        def view(model) do
          import Julep.UI

          column do
            text(inspect(model.result))
          end
        end
      end

      {runtime, bridge} = start_runtime(EffectApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "open"})

      effect_requests = Julep.Test.MockBridge.get_effect_requests(bridge)
      assert length(effect_requests) == 1

      [req] = effect_requests
      assert req.kind == "file_open"
      assert req.payload == %{title: "Pick a file"}
    end

    test "effect_result event is dispatched through update" do
      defmodule EffectResultApp do
        use Julep.App

        def init(_opts), do: %{path: nil}

        def update(model, {:effect_result, _id, {:ok, %{"path" => path}}}) do
          %{model | path: path}
        end

        def update(model, _event), do: model

        def view(model) do
          import Julep.UI

          column do
            text(inspect(model.path))
          end
        end
      end

      {runtime, _bridge} = start_runtime(EffectResultApp)
      await_initial_render(runtime)

      # Simulate the renderer sending back an effect result.
      dispatch_and_wait(runtime, {:effect_result, "ef_42", {:ok, %{"path" => "/tmp/test.txt"}}})

      state = :sys.get_state(runtime)
      assert state.model.path == "/tmp/test.txt"
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Depth-first search for the first node with the given type string.
  defp find_by_type(%{type: type} = node, type), do: node

  defp find_by_type(%{children: children}, target_type) when is_list(children) do
    Enum.find_value(children, &find_by_type(&1, target_type))
  end

  defp find_by_type(_node, _target_type), do: nil
end
