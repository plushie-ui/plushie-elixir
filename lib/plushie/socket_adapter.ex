defmodule Plushie.SocketAdapter do
  @moduledoc false

  # Bridges a Unix domain socket to the iostream transport protocol.
  #
  # When the renderer uses --exec, it creates a Unix socket and sets
  # PLUSHIE_SOCKET in the child's environment. This adapter connects
  # to that socket and translates between gen_tcp messages and the
  # iostream protocol that the Bridge already speaks.
  #
  # Protocol:
  #   Bridge sends {:iostream_bridge, pid} on init -> adapter stores it
  #   Bridge sends {:iostream_send, data} -> adapter writes to socket
  #   Socket sends {:tcp, socket, data} -> adapter forwards complete protocol messages
  #   Socket closes -> adapter sends {:iostream_closed, reason}

  use GenServer

  alias Plushie.Transport.Framing

  @max_buffer_size 64 * 1024 * 1024

  @doc """
  Connects to the renderer's socket and returns the adapter pid.

  The address is a Unix socket path (e.g., `/tmp/plushie.sock`),
  a TCP port (e.g., `:4567`), or a TCP host:port (e.g., `127.0.0.1:4567`).
  """
  @spec start_link(addr :: String.t(), format :: :msgpack | :json) ::
          GenServer.on_start()
  def start_link(addr, format \\ :msgpack) do
    GenServer.start_link(__MODULE__, {addr, format})
  end

  @impl true
  def init({addr, format}) do
    socket_opts =
      case format do
        :msgpack -> [:binary, {:packet, 4}, {:active, true}]
        :json -> [:binary, {:active, true}]
      end

    case connect(addr, socket_opts) do
      {:ok, socket} ->
        {:ok, %{socket: socket, bridge: nil, format: format, buffer: ""}}

      {:error, reason} ->
        {:stop, {:connect_failed, reason}}
    end
  end

  defp connect(addr, opts) do
    case parse_addr(addr) do
      {:unix, path} ->
        :gen_tcp.connect({:local, String.to_charlist(path)}, 0, opts)

      {:tcp, host, port} ->
        :gen_tcp.connect(String.to_charlist(host), port, opts)
    end
  end

  defp parse_addr(":" <> port_str) do
    {:tcp, "127.0.0.1", String.to_integer(port_str)}
  end

  defp parse_addr("/" <> _ = path), do: {:unix, path}

  defp parse_addr(addr) do
    case String.split(addr, ":", parts: 2) do
      [host, port_str] when host != "" ->
        {:tcp, host, String.to_integer(port_str)}

      _ ->
        {:unix, addr}
    end
  end

  @impl true
  # Bridge registers itself on init.
  def handle_info({:iostream_bridge, bridge_pid}, state) do
    {:noreply, %{state | bridge: bridge_pid}}
  end

  # Bridge sends protocol data to the renderer.
  def handle_info({:iostream_send, data}, state) do
    case :gen_tcp.send(state.socket, data) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        if state.bridge, do: send(state.bridge, {:iostream_closed, {:send_error, reason}})
        {:stop, {:send_error, reason}, state}
    end
  end

  # Socket received protocol data from the renderer.
  def handle_info({:tcp, socket, data}, %{socket: socket, format: :msgpack} = state) do
    if state.bridge, do: send(state.bridge, {:iostream_data, data})
    {:noreply, state}
  end

  def handle_info({:tcp, socket, data}, %{socket: socket, format: :json} = state) do
    new_buffer = state.buffer <> data

    if byte_size(new_buffer) > @max_buffer_size do
      if state.bridge, do: send(state.bridge, {:iostream_closed, :json_buffer_overflow})
      {:stop, :json_buffer_overflow, %{state | buffer: ""}}
    else
      {lines, buffer} = Framing.decode_lines(new_buffer)

      Enum.each(lines, fn line ->
        if state.bridge, do: send(state.bridge, {:iostream_data, line})
      end)

      {:noreply, %{state | buffer: buffer}}
    end
  end

  # Socket closed.
  def handle_info({:tcp_closed, socket}, %{socket: socket} = state) do
    if state.bridge, do: send(state.bridge, {:iostream_closed, :tcp_closed})
    {:stop, :normal, state}
  end

  # Socket error.
  def handle_info({:tcp_error, socket, reason}, %{socket: socket} = state) do
    if state.bridge, do: send(state.bridge, {:iostream_closed, reason})
    {:stop, {:tcp_error, reason}, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}
end
