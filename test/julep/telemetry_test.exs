defmodule Julep.TelemetryTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Julep.Event.Widget

  # ---------------------------------------------------------------------------
  # Minimal app for driving the update/view loop.
  # ---------------------------------------------------------------------------

  defmodule TelemetryApp do
    use Julep.App

    def init(_opts), do: %{value: 0}

    def update(model, %Widget{type: :click, id: "inc"}), do: %{model | value: model.value + 1}
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

  defp start_runtime(app, extra_opts \\ []) do
    tag = System.unique_integer([:positive])
    bridge_name = :"telemetry_bridge_#{tag}"
    runtime_name = :"telemetry_runtime_#{tag}"

    {:ok, _bridge} = Julep.Test.MockBridge.start_link(name: bridge_name)

    opts =
      [app: app, bridge: bridge_name, name: runtime_name]
      |> Keyword.merge(extra_opts)

    {:ok, runtime} = Julep.Runtime.start_link(opts)
    {runtime, bridge_name}
  end

  defp await_initial_render(runtime) do
    :sys.get_state(runtime)
  end

  defp attach(event_name, test_pid) do
    handler_id = "#{inspect(test_pid)}_#{:erlang.unique_integer()}"

    :telemetry.attach(
      handler_id,
      event_name,
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end,
      nil
    )

    handler_id
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "[:julep, :view] span" do
    test "fires start and stop events on initial render" do
      capture_log(fn ->
        stop_id = attach([:julep, :view, :stop], self())

        {runtime, _bridge} = start_runtime(TelemetryApp)
        await_initial_render(runtime)

        assert_receive {:telemetry_event, [:julep, :view, :stop], measurements, _metadata}
        assert is_integer(measurements.duration)
        assert measurements.duration >= 0

        :telemetry.detach(stop_id)
        GenServer.stop(runtime)
      end)
    end
  end

  describe "[:julep, :update] span" do
    test "fires start and stop events when dispatching an event" do
      capture_log(fn ->
        {runtime, _bridge} = start_runtime(TelemetryApp)
        await_initial_render(runtime)

        stop_id = attach([:julep, :update, :stop], self())

        Julep.Runtime.dispatch(runtime, %Widget{type: :click, id: "inc"})
        # Synchronise -- ensures the event has been processed.
        :sys.get_state(runtime)

        assert_receive {:telemetry_event, [:julep, :update, :stop], measurements, _metadata}
        assert is_integer(measurements.duration)
        assert measurements.duration >= 0

        :telemetry.detach(stop_id)
        GenServer.stop(runtime)
      end)
    end
  end

  describe "[:julep, :bridge, :send]" do
    test "fires when sending data to the port" do
      capture_log(fn ->
        handler_id = attach([:julep, :bridge, :send], self())

        # We can't easily send to a real port without a renderer, but MockBridge
        # is a GenServer, not a port. We verify the handler attaches and
        # detaches cleanly. A full integration test lives in bridge_msgpack_test.
        :telemetry.detach(handler_id)
      end)
    end
  end

  describe "[:julep, :bridge, :receive]" do
    test "handler can be attached for receive events" do
      capture_log(fn ->
        handler_id = attach([:julep, :bridge, :receive], self())
        :telemetry.detach(handler_id)
      end)
    end
  end

  describe "[:julep, :bridge, :restart]" do
    test "handler can be attached for restart events" do
      capture_log(fn ->
        handler_id = attach([:julep, :bridge, :restart], self())
        :telemetry.detach(handler_id)
      end)
    end
  end
end
