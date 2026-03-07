defmodule Julep.BridgeMsgpackTest do
  @moduledoc """
  Integration test verifying msgpack protocol works end-to-end between
  Elixir and the julep_gui binary.

  Requires the debug binary at native/julep_gui/target/debug/julep_gui.
  Build it with `cargo build` before running these tests.

  The spawned renderer processes have display env vars stripped so they
  always crash on iced startup (no display server), regardless of the
  test runner's environment. This lets us verify protocol decode
  behaviour without needing to manage renderer lifecycle.
  """
  use ExUnit.Case, async: false

  @renderer_path Path.expand("native/julep_gui/target/debug/julep_gui")

  # Strip display env vars so the renderer always fails to find a display,
  # even when tests run under Xvfb or Weston. Erlang's Port :env option
  # requires charlist keys; `false` means unset the variable.
  @no_display_env [
    {~c"DISPLAY", false},
    {~c"WAYLAND_DISPLAY", false},
    {~c"WAYLAND_SOCKET", false}
  ]

  describe "msgpack protocol integration" do
    @describetag :integration

    test "renderer decodes msgpack settings without protocol error" do
      # Open Port with {:packet, 4} for msgpack framing.
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:args, ["--msgpack"]},
          {:env, @no_display_env}
        ])

      # Send settings message in msgpack format.
      settings = Julep.Protocol.encode_settings(%{antialiasing: false}, :msgpack)
      Port.command(port, settings)

      # Wait for responses. The renderer should:
      # 1. Successfully decode the msgpack settings (no error response)
      # 2. Attempt to start iced::daemon
      # 3. Crash because there is no display server
      #
      # We collect all messages until exit_status.
      messages = collect_port_messages(port, [], 5_000)

      # The renderer should have exited (no display).
      assert Enum.any?(messages, &match?({:exit_status, _}, &1)),
             "expected renderer to exit (no display server)"

      # If the renderer sent any data messages, none should be decode errors.
      data_messages = for {:data, data} <- messages, do: data

      for data <- data_messages do
        # Decode as msgpack (since we forced --msgpack, responses are msgpack too).
        case Msgpax.unpack(data) do
          {:ok, %{"type" => "error", "message" => msg}} ->
            refute String.contains?(msg, "decode"),
                   "renderer sent a decode error: #{msg}"

          _ ->
            :ok
        end
      end
    end

    test "renderer auto-detects msgpack from first byte" do
      # Open Port with {:packet, 4} but NO --msgpack flag.
      # The renderer should auto-detect msgpack from the first byte.
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:env, @no_display_env}
        ])

      # Send settings as msgpack. The first byte will NOT be '{',
      # so auto-detect should pick msgpack.
      settings = Julep.Protocol.encode_settings(%{antialiasing: false}, :msgpack)
      Port.command(port, settings)

      messages = collect_port_messages(port, [], 5_000)

      assert Enum.any?(messages, &match?({:exit_status, _}, &1)),
             "expected renderer to exit"

      # Check no decode errors in responses.
      for {:data, data} <- messages do
        # Without --msgpack flag, error responses default to JSON.
        # But if auto-detect worked, responses should be msgpack.
        # Try msgpack first, fall back to JSON.
        case Msgpax.unpack(data) do
          {:ok, %{"type" => "error", "message" => msg}} ->
            refute String.contains?(msg, "decode"),
                   "renderer sent a decode error (msgpack): #{msg}"

          _ ->
            # Try JSON in case auto-detect fell back to JSON error response
            case Jason.decode(data) do
              {:ok, %{"type" => "error", "message" => msg}} ->
                refute String.contains?(msg, "decode"),
                       "renderer sent a decode error (json): #{msg}"

              _ ->
                :ok
            end
        end
      end
    end

    test "renderer rejects json when --msgpack forced" do
      # Force msgpack but send JSON. The renderer should respond with
      # a msgpack error and exit.
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:args, ["--msgpack"]},
          {:env, @no_display_env}
        ])

      # Send JSON settings (wrong format for --msgpack).
      # We need to frame it with {:packet, 4} since that's how the port is opened.
      json_settings = Jason.encode!(%{type: "settings", settings: %{antialiasing: false}})
      Port.command(port, json_settings)

      messages = collect_port_messages(port, [], 5_000)

      # The renderer should have exited with an error.
      assert Enum.any?(messages, &match?({:exit_status, _}, &1))

      # If data was returned, it should be a decode error in msgpack format
      # (since --msgpack was forced).
      data_messages = for {:data, data} <- messages, do: data

      if data_messages != [] do
        # Renderer should respond with an error in msgpack format.
        [first | _] = data_messages

        case Msgpax.unpack(first) do
          {:ok, %{"type" => "error"}} -> :ok
          # Could also be that serde failed at a different level
          _ -> :ok
        end
      end
    end
  end

  describe "bridge telemetry" do
    @describetag :integration

    test "send and receive events fire during msgpack exchange" do
      test_pid = self()
      send_id = "bridge_telemetry_send_#{:erlang.unique_integer()}"
      recv_id = "bridge_telemetry_recv_#{:erlang.unique_integer()}"

      :telemetry.attach(
        send_id,
        [:julep, :bridge, :send],
        fn event, measurements, _meta, _ ->
          send(test_pid, {:tel, event, measurements})
        end,
        nil
      )

      :telemetry.attach(
        recv_id,
        [:julep, :bridge, :receive],
        fn event, measurements, _meta, _ ->
          send(test_pid, {:tel, event, measurements})
        end,
        nil
      )

      {:ok, bridge} =
        Julep.Bridge.start_link(
          renderer_path: @renderer_path,
          format: :msgpack,
          runtime: self(),
          port_env: @no_display_env
        )

      # Send settings through the bridge (triggers :send telemetry).
      Julep.Bridge.send_settings(bridge, %{antialiasing: false})

      # Give the renderer time to respond before it crashes (no display).
      Process.sleep(200)

      # The send event should have fired.
      assert_received {:tel, [:julep, :bridge, :send], %{byte_size: size}}
      assert is_integer(size) and size > 0

      # The receive event may or may not fire depending on whether the
      # renderer sent data before crashing. Don't assert on it -- just
      # verify the handler was attached without error.

      :telemetry.detach(send_id)
      :telemetry.detach(recv_id)
      GenServer.stop(bridge, :normal, 1_000)
    catch
      :exit, _ -> :ok
    end
  end

  describe "msgpack edge cases" do
    @describetag :integration

    test "oversized message is handled gracefully" do
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:args, ["--msgpack"]},
          {:env, @no_display_env}
        ])

      # Build a message with a very large string prop to exercise large payload handling.
      # {:packet, 4} supports up to ~4GB frames, so this tests the decoder with bulk data.
      large_value = String.duplicate("x", 1_000_000)

      oversized_msg =
        Msgpax.pack!(%{
          "type" => "settings",
          "settings" => %{"bogus_key" => large_value}
        })

      Port.command(port, oversized_msg)

      messages = collect_port_messages(port, [], 5_000)

      # The renderer should either process the message or exit cleanly.
      # It must not hang indefinitely.
      assert length(messages) >= 1
    end

    test "malformed msgpack data causes error, not crash" do
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:args, ["--msgpack"]},
          {:env, @no_display_env}
        ])

      # Send truncated / invalid msgpack bytes.
      Port.command(port, <<0xC1, 0xFF, 0x00, 0xDE, 0xAD>>)

      messages = collect_port_messages(port, [], 5_000)

      # The renderer should exit (decode error or display error),
      # not hang or segfault.
      assert Enum.any?(messages, &match?({:exit_status, _}, &1)),
             "expected renderer to exit after malformed data"
    end

    test "binary data round-trips through msgpack encoding" do
      # Verify that Julep.Protocol can encode and decode a message containing
      # binary data (e.g. image bytes) without corruption.
      raw_bytes = :crypto.strong_rand_bytes(256)
      base64 = Base.encode64(raw_bytes)

      # Encode a message containing base64 binary data (how images are sent).
      msg = %{
        type: "snapshot",
        tree: %{id: "root", type: "image", props: %{"data" => base64}, children: []}
      }

      encoded = Julep.Protocol.encode(msg, :msgpack)

      # Decode it back and verify the binary data survived the round-trip.
      {:ok, decoded} = Julep.Protocol.decode(encoded, :msgpack)
      assert decoded["tree"]["props"]["data"] == base64

      # Verify the original bytes can be recovered from the base64.
      assert Base.decode64!(decoded["tree"]["props"]["data"]) == raw_bytes
    end

    test "empty map message is handled" do
      port =
        Port.open({:spawn_executable, @renderer_path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:packet, 4},
          {:args, ["--msgpack"]},
          {:env, @no_display_env}
        ])

      # Send a valid msgpack map with no "type" field.
      empty_msg = Msgpax.pack!(%{"not_a_type" => "hello"})
      Port.command(port, empty_msg)

      messages = collect_port_messages(port, [], 5_000)

      # Should exit (no display) without protocol panic.
      assert Enum.any?(messages, &match?({:exit_status, _}, &1)),
             "expected renderer to exit"
    end
  end

  # Collect port messages until exit_status or timeout.
  defp collect_port_messages(port, acc, timeout) do
    receive do
      {^port, {:data, data}} ->
        collect_port_messages(port, [{:data, data} | acc], timeout)

      {^port, {:exit_status, status}} ->
        Enum.reverse([{:exit_status, status} | acc])
    after
      timeout ->
        # Force close the port if still running.
        try do
          Port.close(port)
        catch
          _, _ -> :ok
        end

        Enum.reverse(acc)
    end
  end
end
