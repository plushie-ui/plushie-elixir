defmodule Plushie.BridgeIostreamTest do
  @moduledoc """
  Tests the iostream transport mode in Bridge.

  Uses the test process as both the iostream adapter and the runtime,
  verifying the message flow without needing a real transport or renderer.
  """
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  require Logger

  @hello_msg %{
    type: "hello",
    name: "plushie",
    version: "0.1.0",
    protocol: Plushie.Protocol.protocol_version(),
    mode: "mock",
    backend: "test",
    transport: "stdio",
    native_widgets: [],
    widgets: []
  }

  def forward_telemetry(event, measurements, metadata, %{test_pid: test_pid, bridge: bridge}) do
    # The telemetry handler registry is global, so events from other
    # bridges running in parallel tests would reach this handler. Filter
    # to the caller's bridge by the `:bridge` metadata tag emitted by
    # every bridge telemetry call. When `bridge` is `nil`, pass through
    # (used for tests that do not bind to a specific bridge).
    if bridge == nil or metadata[:bridge] == bridge do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  defp attach(event_name, test_pid, bridge \\ nil) do
    handler_id = "#{inspect(test_pid)}_#{:erlang.unique_integer()}"

    :telemetry.attach(
      handler_id,
      event_name,
      &__MODULE__.forward_telemetry/4,
      %{test_pid: test_pid, bridge: bridge}
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
      hello_data = Plushie.Protocol.encode(@hello_msg, :msgpack)

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

      assert_receive {:iostream_send, data}, 1_000
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

      assert_receive {:iostream_send, data}, 1_000
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

    test "does not forward hello when the protocol version is wrong" do
      Process.flag(:trap_exit, true)

      try do
        {:ok, bridge} =
          Plushie.Bridge.start_link(
            transport: {:iostream, self()},
            format: :json,
            runtime: self()
          )

        assert_receive {:iostream_bridge, ^bridge}

        bad_hello =
          Jason.encode!(%{@hello_msg | protocol: Plushie.Protocol.protocol_version() + 1})

        log =
          capture_log(fn ->
            send(bridge, {:iostream_data, bad_hello})

            refute_receive {:renderer_event, {:hello, _}}, 100
            # Under heavy parallel-test load the scheduler gap between
            # the bridge's `{:stop, {:protocol_mismatch, ...}, state}`
            # return and the VM-generated `:EXIT` on the linked test
            # process can exceed the default 1s window. The bridge
            # already stops inline in a single `handle_info` invocation
            # (see `dispatch_message/3`), so the only remaining delay
            # is scheduler latency.
            assert_receive {:EXIT, ^bridge, {:protocol_mismatch, _, _}}, 5_000
          end)

        assert log =~ "protocol version mismatch"
      after
        Process.flag(:trap_exit, false)
      end
    end

    test "surfaces typed BufferOverflow diagnostic when a msgpack message exceeds the cap" do
      Process.flag(:trap_exit, true)

      try do
        {:ok, bridge} =
          Plushie.Bridge.start_link(
            transport: {:iostream, self()},
            format: :msgpack,
            runtime: self()
          )

        assert_receive {:iostream_bridge, ^bridge}

        # A `{:packet, 4}` transport can legitimately deliver up to 4
        # GiB per packet; the bridge backstop enforces the protocol's
        # 64 MiB cap for the port-based path (Framing is not on this
        # path). Hand the bridge a complete msgpack-shaped binary
        # larger than the cap and assert the typed diagnostic lands
        # on the renderer_event channel and the bridge stops.
        cap = Plushie.Transport.Framing.max_message_size()
        expected_size = cap + 1
        oversize = :binary.copy("x", expected_size)

        capture_log(fn ->
          send(bridge, {:iostream_data, oversize})

          assert_receive {:renderer_event,
                          %Plushie.Event.DiagnosticMessage{
                            level: :error,
                            diagnostic: %Plushie.Event.Diagnostic.BufferOverflow{
                              size: ^expected_size,
                              limit: ^cap
                            }
                          }},
                         2_000

          assert_receive {:EXIT, ^bridge, {:buffer_overflow, ^expected_size, ^cap}}, 2_000
        end)
      after
        Process.flag(:trap_exit, false)
      end
    end

    test "logs and drops protocol violations instead of crashing" do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :json,
          runtime: self()
        )

      assert_receive {:iostream_bridge, ^bridge}

      # Attach the telemetry handler AFTER the bridge pid is known so
      # the forwarder can filter events from parallel bridges out of the
      # test mailbox. Without this filter, events from other bridges
      # running in async tests would be observed here and matched
      # against our expected reason, producing a cross-test flake.
      handler_id = attach([:plushie, :bridge, :protocol_error], self(), bridge)

      try do
        bad_json =
          Jason.encode!(%{
            type: "event",
            family: "wheel_scrolled",
            value: %{delta_x: 1, delta_y: 2, unit: "page"}
          })

        send(bridge, {:iostream_data, bad_json})

        # The telemetry event carries the structured reason. That is
        # the load-bearing assertion: the bridge observed the violation
        # and classified it correctly. Capturing the human-readable
        # log line via `capture_log` is unreliable under heavy parallel
        # test load because the capture sink's flush order is not
        # synchronised with the bridge process.
        assert_receive {:telemetry_event, [:plushie, :bridge, :protocol_error], %{}, metadata},
                       1_000

        assert match?(
                 {:invalid_event_field, "wheel_scrolled", :unit, "page", :unknown, _},
                 metadata.reason
               )

        assert metadata.format == :json

        # Bridge should survive the protocol error (log + drop).
        refute_receive {:renderer_event, _}, 100
        assert Process.alive?(bridge)
      after
        :telemetry.detach(handler_id)
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

      # The bridge sends `{:renderer_exit, reason}` before returning
      # `{:stop, :normal, state}`, so the runtime observes the exit
      # notification first and the `:DOWN` from the monitor only after
      # the VM has run the bridge's `terminate/2` and reaped the
      # process. Assert in that natural order, and give both a generous
      # timeout: under heavy parallel-test load the gap between the two
      # messages can exceed the default 100ms window.
      capture_log(fn ->
        send(bridge, {:iostream_closed, :peer_closed})
        assert_receive {:renderer_exit, :peer_closed}, 5_000
        assert_receive {:DOWN, ^ref, :process, ^bridge, :normal}, 5_000
      end)
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

    test "holds transient outbound messages until resync completes" do
      # The awaiting_resync queuing mechanism is triggered by renderer restarts
      # on spawn-mode bridges. Iostream transport doesn't support restarts
      # natively, but the queuing code path is shared. We test this with a
      # spawn-mode bridge using a shell script that crashes once (triggering
      # the restart + awaiting_resync state), then stays alive on the second
      # launch so we can verify queued messages are flushed.

      tag = System.unique_integer([:positive])
      state_file = Path.join(System.tmp_dir!(), "plushie_resync_#{tag}")
      script = Path.join(System.tmp_dir!(), "plushie_resync_#{tag}.sh")

      # First invocation: exit with error (triggers restart).
      # Second invocation: stay alive (simulates successful restart).
      File.write!(script, """
      #!/bin/sh
      if [ ! -f "#{state_file}" ]; then
        touch "#{state_file}"
        exit 1
      fi
      sleep 60
      """)

      File.chmod!(script, 0o755)

      log =
        capture_log(fn ->
          {:ok, bridge} =
            Plushie.Bridge.start_link(
              transport: :spawn,
              format: :json,
              runtime: self(),
              renderer_path: script,
              max_restarts: 1,
              restart_delay: 10
            )

          # The first launch exits immediately with status 1. The bridge
          # detects this and enters awaiting_resync + schedules restart.
          assert_receive {:renderer_exit, _}, 1_000

          # While awaiting resync, queue a widget_op.
          Plushie.Bridge.send_widget_op(bridge, "focus", %{id: "save"})

          # The restart fires after restart_delay (10ms). The script stays
          # alive on second invocation.
          assert_receive :renderer_restarted, 1_000

          # Complete the resync; this flushes queued messages.
          Plushie.Bridge.send_resync_complete(bridge)

          # The bridge should still be alive and functioning.
          assert Process.alive?(bridge)

          GenServer.stop(bridge)
        end)

      assert log =~ "queued widget_op while renderer is unavailable"

      File.rm(state_file)
      File.rm(script)
    end
  end

  describe "heartbeat watchdog" do
    defp start_bridge_with_heartbeat(interval) do
      {:ok, bridge} =
        Plushie.Bridge.start_link(
          transport: {:iostream, self()},
          format: :msgpack,
          runtime: self(),
          heartbeat_interval: interval
        )

      assert_receive {:iostream_bridge, ^bridge}
      bridge
    end

    defp send_hello(bridge) do
      hello_data = Plushie.Protocol.encode(@hello_msg, :msgpack)

      send(bridge, {:iostream_data, IO.iodata_to_binary(hello_data)})
      assert_receive {:renderer_event, {:hello, _}}, 1_000
    end

    test "triggers restart when no messages arrive within the interval" do
      # `capture_log` only observes log messages that fire while its
      # lambda is executing. Wrap the entire bridge lifetime so the
      # `"renderer unresponsive"` warning is captured regardless of
      # when the scheduler runs the heartbeat handler relative to the
      # test process's progress.
      log =
        capture_log(fn ->
          bridge = start_bridge_with_heartbeat(50)
          ref = Process.monitor(bridge)

          send_hello(bridge)

          # No further messages. The watchdog should fire after ~50ms
          # and the bridge should stop (iostream transport does not
          # restart, it just shuts down). Use a generous timeout to
          # absorb scheduler latency between the timer firing and the
          # runtime observing the `:renderer_exit` + `:DOWN` messages
          # under heavy parallel-test load.
          assert_receive {:renderer_exit, :heartbeat_timeout}, 5_000
          assert_receive {:DOWN, ^ref, :process, ^bridge, :normal}, 5_000
        end)

      assert log =~ "renderer unresponsive"
    end

    test "resets timer on each received message" do
      # Use a long interval to absorb scheduler jitter under heavy
      # parallel-test load. The invariant under test is "an intervening
      # message resets the timer", not tight wall-clock timing.
      #
      # Schedule:
      #   t = 0     hello processed, timer armed for t = interval
      #   t = 500   send click, timer re-armed for t = 2500
      #   t = 2200  alive check: past the original timer, well before
      #             the reset timer
      interval = 2_000
      bridge = start_bridge_with_heartbeat(interval)
      send_hello(bridge)

      event_data =
        Plushie.Protocol.encode(
          %{type: "event", family: "click", id: "btn", window_id: "main"},
          :msgpack
        )

      Process.sleep(500)
      send(bridge, {:iostream_data, IO.iodata_to_binary(event_data)})
      assert_receive {:renderer_event, _}, 1_000

      # Wait past the original window but before the reset window.
      Process.sleep(1_700)
      assert Process.alive?(bridge)

      GenServer.stop(bridge)
    end

    test "does not fire during awaiting_resync" do
      Process.flag(:trap_exit, true)

      try do
        # Use spawn transport with a script to trigger the resync state.
        tag = System.unique_integer([:positive])
        script = Path.join(System.tmp_dir!(), "plushie_hb_resync_#{tag}.sh")

        File.write!(script, """
        #!/bin/sh
        exit 1
        """)

        File.chmod!(script, 0o755)

        log =
          capture_log(fn ->
            {:ok, bridge} =
              Plushie.Bridge.start_link(
                transport: :spawn,
                format: :json,
                runtime: self(),
                renderer_path: script,
                max_restarts: 0,
                restart_delay: 10,
                heartbeat_interval: 50
              )

            ref = Process.monitor(bridge)

            # The renderer exits immediately. Bridge hits max_restarts
            # and stops. Under heavy parallel-test load the gap between
            # `{:renderer_exit, ...}` and the monitor `:DOWN` can exceed
            # the default 100ms, so use a generous timeout.
            assert_receive {:DOWN, ^ref, :process, ^bridge, _}, 5_000
          end)

        # Should NOT see heartbeat timeout in the logs.
        refute log =~ "renderer unresponsive"

        File.rm(script)
      after
        Process.flag(:trap_exit, false)
      end
    end

    test "disabled when heartbeat_interval is nil" do
      bridge = start_bridge_with_heartbeat(nil)

      send_hello(bridge)

      # Wait longer than any reasonable interval. No timeout should fire.
      Process.sleep(100)
      assert Process.alive?(bridge)

      GenServer.stop(bridge)
    end
  end
end
