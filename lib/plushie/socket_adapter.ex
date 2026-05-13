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

  require Logger

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

  @impl GenServer
  def init({addr, format}) do
    socket_opts =
      case format do
        :msgpack -> [:binary, {:packet, 4}, {:active, true}, {:nodelay, true}]
        :json -> [:binary, {:active, true}, {:nodelay, true}]
      end

    case connect(addr, socket_opts) do
      {:ok, socket} ->
        {:ok, %{socket: socket, bridge: nil, format: format, buffer: [], buffer_size: 0}}

      {:error, reason} ->
        {:stop, {:connect_failed, reason}}
    end
  end

  defp connect(addr, opts) do
    case parse_addr(addr) do
      {:ok, {:unix, path}} ->
        :gen_tcp.connect({:local, String.to_charlist(path)}, 0, opts)

      {:ok, {:tcp, host, port}} ->
        :gen_tcp.connect(String.to_charlist(host), port, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_addr(":" <> port_str) do
    with {:ok, port} <- parse_port(port_str) do
      {:ok, {:tcp, "127.0.0.1", port}}
    end
  end

  defp parse_addr("/" <> _ = path), do: {:ok, {:unix, path}}

  defp parse_addr(addr) do
    case String.split(addr, ":", parts: 2) do
      [host, port_str] when host != "" ->
        with {:ok, port} <- parse_port(port_str) do
          {:ok, {:tcp, host, port}}
        end

      _ ->
        {:ok, {:unix, addr}}
    end
  end

  defp parse_port(port_str) do
    case Integer.parse(port_str) do
      {port, ""} when port in 1..65_535 ->
        {:ok, port}

      _ ->
        {:error, {:invalid_tcp_port, port_str}}
    end
  end

  @impl GenServer
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
    new_size = state.buffer_size + byte_size(data)
    cap = Framing.max_message_size()

    if new_size > cap do
      # The iolist byte count is exact, so the adapter can enforce the
      # cap before materializing an oversized unterminated line.
      err = Plushie.Transport.BufferOverflowError.exception(size: new_size, limit: cap)
      if state.bridge, do: send(state.bridge, {:iostream_closed, {:buffer_overflow, err}})
      {:stop, {:buffer_overflow, err}, %{state | buffer: [], buffer_size: 0}}
    else
      # Append chunk to iolist. Only materialize the binary when there
      # are complete lines to decode.
      chunks = [state.buffer, data]

      if :binary.match(data, "\n") == :nomatch do
        {:noreply, %{state | buffer: chunks, buffer_size: new_size}}
      else
        binary = IO.iodata_to_binary(chunks)

        try do
          {lines, remaining} = Framing.decode_lines(binary)

          Enum.each(lines, fn line ->
            if state.bridge, do: send(state.bridge, {:iostream_data, line})
          end)

          {:noreply, %{state | buffer: remaining, buffer_size: byte_size(remaining)}}
        rescue
          err in Plushie.Transport.BufferOverflowError ->
            if state.bridge, do: send(state.bridge, {:iostream_closed, {:buffer_overflow, err}})
            {:stop, {:buffer_overflow, err}, %{state | buffer: [], buffer_size: 0}}
        end
      end
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

  def handle_info(msg, state) do
    :telemetry.execute([:plushie, :socket_adapter, :unhandled_message], %{count: 1}, %{
      message: msg
    })

    Logger.warning("plushie socket adapter: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
end
