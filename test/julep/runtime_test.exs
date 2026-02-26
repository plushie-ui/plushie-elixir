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

    test "dispatching an event updates the model and sends a new snapshot" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "inc"})

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(snapshots) == 2

      [_initial, after_inc] = snapshots
      text_node = find_by_type(after_inc, "text")
      assert text_node.props["content"] == "Value: 1"
    end

    test "multiple events produce multiple snapshots" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "inc"})
      dispatch_and_wait(runtime, {:click, "inc"})
      dispatch_and_wait(runtime, {:click, "dec"})

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      # initial + 3 updates
      assert length(snapshots) == 4

      contents = snapshots |> Enum.map(&find_by_type(&1, "text")) |> Enum.map(& &1.props["content"])
      assert contents == ["Value: 0", "Value: 1", "Value: 2", "Value: 1"]
    end

    test "unknown events are handled and model remains unchanged" do
      {runtime, bridge} = start_runtime(SimpleApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "nope"})
      dispatch_and_wait(runtime, :mystery_event)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      # initial + 2 updates, all with value 0
      assert length(snapshots) == 3

      contents = snapshots |> Enum.map(&find_by_type(&1, "text")) |> Enum.map(& &1.props["content"])
      assert Enum.all?(contents, &(&1 == "Value: 0"))
    end
  end

  # ---------------------------------------------------------------------------
  # describe "commands"
  # ---------------------------------------------------------------------------

  describe "commands" do
    test "send_after delivers the event after the specified delay" do
      {runtime, bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # send_after(10, :timer_tick) is scheduled in init; wait long enough.
      Process.sleep(80)
      # Drain the runtime mailbox so the send_after_event is processed.
      :sys.get_state(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      # initial snapshot + snapshot after :timer_tick fires
      assert length(snapshots) >= 2

      last = List.last(snapshots)
      text_node = find_by_type(last, "text")
      assert text_node.props["content"] == "1"
    end

    test "async command delivers its result through update" do
      {runtime, bridge} = start_runtime(AsyncApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "async"})

      # Give the spawned Task time to complete and the runtime to process it.
      Process.sleep(50)
      :sys.get_state(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      last = List.last(snapshots)
      text_node = find_by_type(last, "text")
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

      {runtime, bridge} = start_runtime(BatchApp)
      await_initial_render(runtime)

      dispatch_and_wait(runtime, {:click, "batch"})

      # Wait for both delayed events to fire.
      Process.sleep(80)
      :sys.get_state(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      last = List.last(snapshots)
      text_node = find_by_type(last, "text")
      assert text_node.props["content"] == "ticks:2"
    end

    test "init with commands executes them" do
      {runtime, bridge} = start_runtime(CommandApp)
      await_initial_render(runtime)

      # The CommandApp init schedules send_after(10, :timer_tick).
      Process.sleep(80)
      :sys.get_state(runtime)

      snapshots = Julep.Test.MockBridge.get_snapshots(bridge)
      assert length(snapshots) >= 2

      last = List.last(snapshots)
      text_node = find_by_type(last, "text")
      assert text_node.props["content"] == "1"
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
  # Private helpers
  # ---------------------------------------------------------------------------

  # Depth-first search for the first node with the given type string.
  defp find_by_type(%{type: type} = node, type), do: node

  defp find_by_type(%{children: children}, target_type) when is_list(children) do
    Enum.find_value(children, &find_by_type(&1, target_type))
  end

  defp find_by_type(_node, _target_type), do: nil
end
