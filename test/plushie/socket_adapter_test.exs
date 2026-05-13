defmodule Plushie.SocketAdapterTest do
  @moduledoc """
  Tests for the Unix socket adapter used by the stdio transport.

  Creates a temporary Unix socket, connects the adapter, and verifies
  that protocol messages flow correctly between the socket and the
  iostream protocol that the Bridge speaks.
  """
  use ExUnit.Case, async: true

  alias Plushie.SocketAdapter

  @moduletag :unix_socket

  describe "socket adapter" do
    test "connects to a unix socket and relays data" do
      {listener, path} = create_listener()

      # Start the adapter (connects to the socket).
      {:ok, adapter} = SocketAdapter.start_link(path, :msgpack)

      # Accept the connection on the listener side (simulating renderer).
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      # Register as the "bridge" to receive iostream messages.
      send(adapter, {:iostream_bridge, self()})
      Process.sleep(10)

      # Renderer sends a msgpack message to the adapter.
      payload = Msgpax.pack!(%{"type" => "hello"}) |> IO.iodata_to_binary()
      :gen_tcp.send(renderer_socket, payload)

      # We should receive it as an iostream_data message.
      assert_receive {:iostream_data, ^payload}, 1_000

      # Send data from the bridge side to the renderer.
      outgoing = Msgpax.pack!(%{"type" => "settings"}) |> IO.iodata_to_binary()
      send(adapter, {:iostream_send, outgoing})

      # Renderer should receive it (with {:packet, 4} framing handled by gen_tcp).
      assert_receive {:tcp, ^renderer_socket, ^outgoing}, 1_000

      :gen_tcp.close(renderer_socket)
      cleanup(path)
    end

    test "notifies bridge on socket close" do
      {listener, path} = create_listener()

      {:ok, adapter} = SocketAdapter.start_link(path, :msgpack)
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      send(adapter, {:iostream_bridge, self()})
      Process.sleep(10)

      # Close the renderer side.
      :gen_tcp.close(renderer_socket)

      assert_receive {:iostream_closed, _reason}, 1_000
      cleanup(path)
    end

    test "handles multiple messages" do
      {listener, path} = create_listener()

      {:ok, adapter} = SocketAdapter.start_link(path, :msgpack)
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      send(adapter, {:iostream_bridge, self()})
      Process.sleep(10)

      # Send several messages rapidly.
      for i <- 1..5 do
        payload = Msgpax.pack!(%{"n" => i}) |> IO.iodata_to_binary()
        :gen_tcp.send(renderer_socket, payload)
      end

      # All should arrive.
      for i <- 1..5 do
        expected = Msgpax.pack!(%{"n" => i}) |> IO.iodata_to_binary()
        assert_receive {:iostream_data, ^expected}, 1_000
      end

      :gen_tcp.close(renderer_socket)
      cleanup(path)
    end

    test "reassembles fragmented json lines before forwarding" do
      {listener, path} = create_listener(:json)

      {:ok, adapter} = SocketAdapter.start_link(path, :json)
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      send(adapter, {:iostream_bridge, self()})
      Process.sleep(10)

      line = Jason.encode!(%{"type" => "hello", "protocol" => 1})
      {first, second} = String.split_at(line <> "\n", div(byte_size(line), 2))

      :gen_tcp.send(renderer_socket, first)
      refute_receive {:iostream_data, _}, 50

      :gen_tcp.send(renderer_socket, second)
      assert_receive {:iostream_data, ^line}, 1_000

      :gen_tcp.close(renderer_socket)
      cleanup(path)
    end

    test "returns error when socket path does not exist" do
      Process.flag(:trap_exit, true)
      assert {:error, _} = SocketAdapter.start_link("/tmp/nonexistent.sock", :msgpack)
    end

    test "returns a descriptive error for invalid TCP ports" do
      Process.flag(:trap_exit, true)

      assert {:error, {:connect_failed, {:invalid_tcp_port, "abc"}}} =
               SocketAdapter.start_link("127.0.0.1:abc", :msgpack)
    end

    @tag capture_log: true
    test "reports unexpected messages" do
      {listener, path} = create_listener()

      {:ok, adapter} = SocketAdapter.start_link(path, :msgpack)
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      handler_id = "socket-adapter-unhandled-#{inspect(self())}"

      :telemetry.attach(
        handler_id,
        [:plushie, :socket_adapter, :unhandled_message],
        fn _event, _measurements, metadata, pid ->
          send(pid, {:socket_adapter_unhandled, metadata.message})
        end,
        self()
      )

      try do
        send(adapter, :unexpected)

        assert_receive {:socket_adapter_unhandled, :unexpected}

        :gen_tcp.close(renderer_socket)
        cleanup(path)
      after
        :telemetry.detach(handler_id)
      end
    end

    test "surfaces the typed BufferOverflowError when a json line exceeds the cap" do
      Process.flag(:trap_exit, true)
      {listener, path} = create_listener(:json)

      {:ok, adapter} = SocketAdapter.start_link(path, :json)
      {:ok, renderer_socket} = :gen_tcp.accept(listener, 5_000)
      :gen_tcp.close(listener)

      send(adapter, {:iostream_bridge, self()})
      Process.sleep(10)

      # Deliver an oversized unterminated buffer. The socket adapter
      # decodes through Plushie.Transport.Framing, which raises the
      # typed BufferOverflowError as soon as the accumulated tail
      # passes the cap; the adapter rescues, surfaces the error
      # through the iostream channel, and stops.
      #
      # We send the bytes in a background task because a 64 MiB write
      # on a Unix domain socket easily exceeds the kernel's send
      # buffer, so gen_tcp.send will block until the receiver drains;
      # the receiver will have already raised before the sender
      # finishes.
      cap = Plushie.Transport.Framing.max_message_size()
      oversize = :binary.copy("x", cap + 1)

      Task.start(fn ->
        :gen_tcp.send(renderer_socket, oversize)
      end)

      assert_receive {:iostream_closed, {:buffer_overflow, err}}, 15_000
      assert %Plushie.Transport.BufferOverflowError{size: size, limit: ^cap} = err
      assert size > cap

      :gen_tcp.close(renderer_socket)
      cleanup(path)
    end
  end

  # -- Helpers ----------------------------------------------------------------

  defp create_listener(format \\ :msgpack) do
    path = "/tmp/plushie_test_#{:erlang.unique_integer([:positive])}.sock"
    File.rm(path)

    socket_opts =
      case format do
        :msgpack -> [:binary, {:packet, 4}, {:active, true}, {:ifaddr, {:local, path}}]
        :json -> [:binary, {:active, true}, {:ifaddr, {:local, path}}]
      end

    {:ok, listener} = :gen_tcp.listen(0, socket_opts)

    {listener, path}
  end

  defp cleanup(path) do
    File.rm(path)
  end
end
