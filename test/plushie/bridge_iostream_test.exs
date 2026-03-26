defmodule Plushie.BridgeIostreamTest do
  @moduledoc """
  Tests the iostream transport mode in Bridge.

  Uses the test process as both the iostream adapter and the runtime,
  verifying the message flow without needing a real transport or renderer.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  def forward_telemetry(event, measurements, metadata, test_pid) do
    send(test_pid, {:telemetry_event, event, measurements, metadata})
  end

  defp attach(event_name, test_pid) do
    handler_id = "#{inspect(test_pid)}_#{:erlang.unique_integer()}"

    :telemetry.attach(
      handler_id,
      event_name,
      &__MODULE__.forward_telemetry/4,
      test_pid
    )

    handler_id
  end

  describe "iostream transport init" do
    test "sends {:iostream_bridge, pid} to the iostream adapter on start" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}
      GenServer.stop(bridge)
    end

    test "monitors the iostream adapter process" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      # Bridge is alive and monitoring us. Verify it's running.
      assert Process.alive?(bridge)
      GenServer.stop(bridge)
    end
  end

  describe "iostream data flow" do
    test "forwards decoded messages to the runtime" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      # Simulate a hello message from the renderer through the iostream adapter.
      hello_data =
        Plushie.Protocol.encode(
          %{
            type: "hello",
            name: "plushie",
            version: "0.1.0",
            protocol: Plushie.Protocol.protocol_version(),
            backend: "test"
          },
          :msgpack
        )

      send(bridge, {:iostream_data, IO.iodata_to_binary(hello_data)})

      assert_receive {:renderer_event, {:hello, hello}}, 1_000
      assert hello.name == "plushie"
      assert hello.version == "0.1.0"
      assert hello.backend == "test"

      GenServer.stop(bridge)
    end

    test "sends data to iostream adapter via {:iostream_send, iodata}" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      Plushie.Bridge.send_settings(bridge, %{antialiasing: false})

      assert_receive {:iostream_send, data}
      assert is_list(data) or is_binary(data)
      assert IO.iodata_length(data) > 0

      GenServer.stop(bridge)
    end

    test "json format works over iostream" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :json,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      Plushie.Bridge.send_settings(bridge, %{antialiasing: false})

      assert_receive {:iostream_send, data}
      json = IO.iodata_to_binary(data)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["type"] == "settings"

      GenServer.stop(bridge)
    end

    test "ignores blank json lines" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :json,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      send(bridge, {:iostream_data, "\n"})

      refute_receive {:renderer_event, _}, 100

      GenServer.stop(bridge)
    end

    test "crashes on protocol violations instead of leaking decode errors" do
      Process.flag(:trap_exit, true)
      handler_id = attach([:plushie, :bridge, :protocol_error], self())

      try do
        {:ok, bridge} =
          Plushie.Bridge.start_link(
            transport: {:iostream, self()},
            format: :json,
            runtime: self()
          )

        assert_receive {:iostream_bridge, ^bridge}

        bad_json =
          Jason.encode!(%{
            type: "event",
            family: "wheel_scrolled",
            data: %{delta_x: 1, delta_y: 2, unit: "page"}
          })

        log =
          capture_log(fn ->
            send(bridge, {:iostream_data, bad_json})

            assert_receive {:telemetry_event, [:plushie, :bridge, :protocol_error], %{},
                            metadata},
                           1_000

            assert match?(
                     {:invalid_event_field, "wheel_scrolled", :unit, "page", :unknown, _},
                     metadata.reason
                   )

            assert metadata.format == :json

            assert_receive {:EXIT, ^bridge, reason}, 1_000
            assert inspect(reason) =~ "Plushie.Protocol.Error"
            refute_receive {:renderer_event, _}, 100
          end)

        assert log =~ "invalid wheel_scrolled event field unit"
      after
        :telemetry.detach(handler_id)
        Process.flag(:trap_exit, false)
      end
    end
  end

  describe "iostream lifecycle" do
    test "stops when iostream adapter sends {:iostream_closed, reason}" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}
      ref = Process.monitor(bridge)

      capture_log(fn ->
        send(bridge, {:iostream_closed, :peer_closed})
        assert_receive {:DOWN, ^ref, :process, ^bridge, :normal}
      end)

      assert_receive {:renderer_exit, :peer_closed}
    end

    test "stops when iostream adapter process exits" do
      adapter =
        spawn(fn ->
          receive do
            {:iostream_bridge, _bridge} -> :ok
          end

          # Stay alive until told to exit
          receive do
            :stop -> :ok
          end
        end)

      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, adapter},
          format: :msgpack,
          runtime: self()
        )

      bridge_ref = Process.monitor(bridge)

      capture_log(fn ->
        Process.exit(adapter, :shutdown)
        assert_receive {:DOWN, ^bridge_ref, :process, ^bridge, :normal}, 1_000
      end)

      assert_receive {:renderer_exit, :shutdown}
    end

    test "does not attempt restart on iostream transport close" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self(),
          max_restarts: 5
        )

      assert_receive {:iostream_bridge, ^bridge}
      ref = Process.monitor(bridge)

      capture_log(fn ->
        send(bridge, {:iostream_closed, :normal})
        assert_receive {:DOWN, ^ref, :process, ^bridge, :normal}
      end)

      # Should NOT receive a :renderer_restarted message
      refute_receive :renderer_restarted, 200
    end
  end
end
