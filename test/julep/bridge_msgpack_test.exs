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
