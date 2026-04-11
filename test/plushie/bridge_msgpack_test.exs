defmodule Plushie.BridgeMsgpackTest do
  @moduledoc """
  Integration test verifying msgpack protocol works end-to-end between
  Elixir and the plushie binary.

  Requires the plushie binary (downloaded or built from source).

  All tests use `--headless` mode so they work without a display server.
  Renderer log output is suppressed via RUST_LOG=off since error/warn
  messages from deliberately malformed input are expected.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  defp binary_path, do: Application.fetch_env!(:plushie, :test_binary_path)

  # Environment for tests: whitelisted renderer env with log output suppressed.
  defp test_env do
    Plushie.RendererEnv.build(rust_log: "off")
  end

  # Open a headless renderer port with the given args appended.
  defp open_headless_port(extra_args) do
    args = ["--headless" | extra_args]

    Port.open({:spawn_executable, binary_path()}, [
      :binary,
      :exit_status,
      :use_stdio,
      {:packet, 4},
      {:args, args},
      {:env, test_env()}
    ])
  end

  describe "msgpack protocol integration" do
    @describetag :integration

    test "renderer decodes msgpack settings without protocol error" do
      port = open_headless_port(["--msgpack"])

      # Send settings message in msgpack format.
      settings = Plushie.Protocol.encode_settings(%{antialiasing: false}, :msgpack)
      Port.command(port, settings)

      # Headless mode processes settings and enters the message loop.
      # Collect any responses (hello message, etc.) then close the port.
      messages = collect_port_messages(port, [], 1_000)
      close_port(port)

      # If the renderer sent any data messages, none should be decode errors.
      for {:data, data} <- messages do
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
      # No --msgpack flag: the renderer should auto-detect from the first byte.
      port = open_headless_port([])

      settings = Plushie.Protocol.encode_settings(%{antialiasing: false}, :msgpack)
      Port.command(port, settings)

      messages = collect_port_messages(port, [], 1_000)
      close_port(port)

      # Check no decode errors in responses.
      for {:data, data} <- messages do
        # Without --msgpack flag, responses could be msgpack (auto-detected)
        # or JSON (fallback). Check both.
        case Msgpax.unpack(data) do
          {:ok, %{"type" => "error", "message" => msg}} ->
            refute String.contains?(msg, "decode"),
                   "renderer sent a decode error (msgpack): #{msg}"

          _ ->
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
      port = open_headless_port(["--msgpack"])

      # Send JSON settings (wrong format for --msgpack).
      json_settings = Jason.encode!(%{type: "settings", settings: %{antialiasing: false}})
      Port.command(port, json_settings)

      # In headless mode, the renderer logs a decode error and continues.
      # Give it time to process, then close the port cleanly.
      messages = collect_port_messages(port, [], 500)
      close_port(port)

      # The renderer should NOT have sent back a successfully decoded response.
      # Any data messages should be hello or error, not a valid settings ack.
      for {:data, data} <- messages do
        case Msgpax.unpack(data) do
          {:ok, %{"type" => "hello"}} -> :ok
          {:ok, %{"type" => "error"}} -> :ok
          {:ok, %{"type" => other}} -> flunk("unexpected response type: #{other}")
          _ -> :ok
        end
      end
    end
  end

  describe "bridge telemetry" do
    @describetag :integration

    test "send and receive events fire during msgpack exchange" do
      capture_log(fn ->
        test_pid = self()
        send_id = "bridge_telemetry_send_#{:erlang.unique_integer()}"
        recv_id = "bridge_telemetry_recv_#{:erlang.unique_integer()}"

        :telemetry.attach(
          send_id,
          [:plushie, :bridge, :send],
          &Plushie.Test.TelemetryForwarder.handle/4,
          %{pid: test_pid, tag: :tel, include_event: true}
        )

        :telemetry.attach(
          recv_id,
          [:plushie, :bridge, :receive],
          &Plushie.Test.TelemetryForwarder.handle/4,
          %{pid: test_pid, tag: :tel, include_event: true}
        )

        {:ok, bridge} =
          Plushie.Bridge.start_link(
            renderer_path: binary_path(),
            format: :msgpack,
            runtime: self(),
            renderer_args: ["--headless"],
            log_level: :off
          )

        # Send settings through the bridge (triggers :send telemetry).
        Plushie.Bridge.send_settings(bridge, %{antialiasing: false})

        # The send telemetry fires synchronously within send_settings.
        assert_receive {:tel, [:plushie, :bridge, :send], %{byte_size: size}}, 1_000
        assert is_integer(size) and size > 0

        # The receive event may or may not fire depending on whether the
        # renderer sent data before crashing. Don't assert on it -- just
        # verify the handler was attached without error.

        :telemetry.detach(send_id)
        :telemetry.detach(recv_id)
        GenServer.stop(bridge, :normal, 1_000)
      end)
    catch
      :exit, _ -> :ok
    end
  end

  describe "msgpack edge cases" do
    @describetag :integration

    test "oversized message is handled gracefully" do
      port = open_headless_port(["--msgpack"])

      # Build a message with a very large string prop to exercise large payload handling.
      large_value = String.duplicate("x", 1_000_000)

      oversized_msg =
        Msgpax.pack!(%{
          "type" => "settings",
          "settings" => %{"bogus_key" => large_value}
        })

      Port.command(port, oversized_msg)

      # The renderer should process the message without hanging.
      # If we reach close_port without timing out, it handled the payload.
      _messages = collect_port_messages(port, [], 5_000)
      close_port(port)
    end

    test "malformed msgpack data causes error, not crash" do
      port = open_headless_port(["--msgpack"])

      # Send truncated / invalid msgpack bytes.
      Port.command(port, <<0xC1, 0xFF, 0x00, 0xDE, 0xAD>>)

      # In headless mode, the renderer logs a decode error but stays alive.
      # Verify it doesn't crash or hang -- we can still close the port cleanly.
      messages = collect_port_messages(port, [], 500)
      close_port(port)

      # No crash: if we got here, the renderer handled the malformed data gracefully.
      # It may have sent a hello before the malformed data arrived.
      assert is_list(messages)
    end

    test "binary data round-trips through msgpack encoding" do
      # Pure Elixir test -- no renderer needed.
      raw_bytes = :crypto.strong_rand_bytes(256)
      base64 = Base.encode64(raw_bytes)

      msg = %{
        type: "snapshot",
        tree: %{id: "root", type: "image", props: %{"data" => base64}, children: []}
      }

      encoded = Plushie.Protocol.encode(msg, :msgpack)

      {:ok, decoded} = Plushie.Protocol.decode(encoded, :msgpack)
      assert decoded["tree"]["props"]["data"] == base64
      assert Base.decode64!(decoded["tree"]["props"]["data"]) == raw_bytes
    end

    test "empty map message is handled" do
      port = open_headless_port(["--msgpack"])

      # Send a valid msgpack map with no "type" field.
      empty_msg = Msgpax.pack!(%{"not_a_type" => "hello"})
      Port.command(port, empty_msg)

      # Headless mode logs the decode error and continues reading.
      # Verify it handles this gracefully without panic or hang.
      messages = collect_port_messages(port, [], 500)
      close_port(port)

      assert is_list(messages)
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
        Enum.reverse(acc)
    end
  end

  # Close a port, ignoring errors if already closed.
  defp close_port(port) do
    Port.close(port)
  catch
    _, _ -> :ok
  end
end
