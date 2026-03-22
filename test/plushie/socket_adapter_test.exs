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

    test "returns error when socket path does not exist" do
      Process.flag(:trap_exit, true)
      assert {:error, _} = SocketAdapter.start_link("/tmp/nonexistent.sock", :msgpack)
    end
  end

  # -- Helpers ----------------------------------------------------------------

  defp create_listener do
    path = "/tmp/plushie_test_#{:erlang.unique_integer([:positive])}.sock"
    File.rm(path)

    {:ok, listener} =
      :gen_tcp.listen(0, [:binary, {:packet, 4}, {:active, true}, {:ifaddr, {:local, path}}])

    {listener, path}
  end

  defp cleanup(path) do
    File.rm(path)
  end
end
