defmodule Plushie.Transport.IOStream do
  @moduledoc """
  Transport implementation for iostream adapter connections.

  Communicates with an external process that owns the underlying I/O
  (SSH channel, TCP socket, WebSocket, etc.). The adapter process
  handles framing and delivers complete protocol messages.

  Protocol:
  1. Bridge sends `{:iostream_bridge, bridge_pid}` during init.
  2. Adapter sends `{:iostream_data, binary}` for incoming data.
  3. Bridge sends `{:iostream_send, iodata}` for outgoing data.
  4. Adapter sends `{:iostream_closed, reason}` on transport close.
  """

  @behaviour Plushie.Transport

  require Logger

  defstruct [:io_pid, :monitor_ref, alive: false]

  @impl true
  def init(opts) do
    io_pid = Keyword.fetch!(opts, :io_pid)
    ref = Process.monitor(io_pid)
    send(io_pid, {:iostream_bridge, self()})
    {:ok, %__MODULE__{io_pid: io_pid, monitor_ref: ref, alive: true}}
  end

  @impl true
  def send_data(%{io_pid: io_pid} = state, data) do
    send(io_pid, {:iostream_send, data})

    :telemetry.execute([:plushie, :bridge, :send], %{byte_size: IO.iodata_length(data)}, %{})

    {:ok, state}
  rescue
    ArgumentError ->
      Logger.warning("plushie bridge: iostream process unreachable during send")
      {:error, :unreachable}
  end

  @impl true
  def close(_state), do: :ok

  @impl true
  def handle_info({:iostream_data, data}, state) do
    {:data, data, state}
  end

  def handle_info({:iostream_closed, reason}, state) do
    {:closed, reason, %{state | alive: false}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{monitor_ref: ref} = state)
      when is_reference(ref) do
    {:closed, reason, %{state | alive: false}}
  end

  def handle_info(_msg, _state), do: :ignore

  @impl true
  def restartable?(_state), do: false

  @impl true
  def transport_ready?(%{alive: alive}), do: alive == true
end
