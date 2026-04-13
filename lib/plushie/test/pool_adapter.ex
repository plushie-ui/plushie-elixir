defmodule Plushie.Test.PoolAdapter do
  @moduledoc """
  Iostream adapter that connects a Bridge to one SessionPool session.

  Acts as a thin relay between the Bridge's iostream protocol and the
  SessionPool's multiplexed port. The Bridge handles session_id injection
  via its `:session_id` option, so this adapter only needs to forward raw
  bytes in both directions.

  The adapter registers a session with the pool and monitors the pool
  for crashes. Incoming pool events are re-encoded and forwarded to the
  Bridge as iostream data.
  """

  use GenServer

  require Logger

  alias Plushie.Test.SessionPool

  defstruct [:pool, :session_id, :bridge, :format]

  @doc """
  Starts a pool adapter and returns `{:ok, pid, session_id}`.

  ## Options

  - `:pool` - the SessionPool server (required)
  - `:format` - wire format, `:msgpack` (default) or `:json`
  """
  @spec start_link(keyword()) :: {:ok, pid(), String.t()} | {:error, term()}
  def start_link(opts) do
    case GenServer.start_link(__MODULE__, opts) do
      {:ok, pid} ->
        session_id = GenServer.call(pid, :get_session_id)
        {:ok, pid, session_id}

      error ->
        error
    end
  end

  @impl GenServer
  def init(opts) do
    pool = Keyword.fetch!(opts, :pool)
    format = Keyword.get(opts, :format, :msgpack)

    Process.monitor(pool)
    session_id = SessionPool.register(pool)

    {:ok, %__MODULE__{pool: pool, session_id: session_id, bridge: nil, format: format}}
  end

  @impl GenServer
  def handle_call(:get_session_id, _from, state) do
    {:reply, state.session_id, state}
  end

  @impl GenServer
  def handle_info({:iostream_bridge, bridge_pid}, state) do
    {:noreply, %{state | bridge: bridge_pid}}
  end

  # Bridge sends encoded protocol data. The Bridge already injected
  # the session_id (via its session_id option), so we just need to
  # forward the raw message to the pool.
  def handle_info({:iostream_send, iodata}, state) do
    binary = IO.iodata_to_binary(iodata)

    case decode(binary, state.format) do
      {:ok, msg} ->
        # Forward to pool. The session field is already set by Bridge.
        SessionPool.send_message(state.pool, state.session_id, msg)

      {:error, _} ->
        Logger.error(
          "plushie pool_adapter: failed to decode outgoing message (#{byte_size(binary)} bytes)"
        )
    end

    {:noreply, state}
  end

  # Pool forwards renderer responses for our session.
  def handle_info({:plushie_pool_event, _session_id, msg}, state) do
    if state.bridge do
      data = encode(msg, state.format)
      send(state.bridge, {:iostream_data, data})
    end

    {:noreply, state}
  end

  def handle_info({:plushie_pool_renderer_exited, _session_id, code}, state) do
    if state.bridge do
      send(state.bridge, {:iostream_closed, {:renderer_exited, code}})
    end

    {:stop, {:renderer_exited, code}, state}
  end

  # Pool process died.
  def handle_info({:DOWN, _ref, :process, pool, reason}, %{pool: pool} = state) do
    if state.bridge do
      send(state.bridge, {:iostream_closed, reason})
    end

    stop_reason =
      if reason in [:normal, :shutdown], do: :normal, else: {:pool_exited, reason}

    {:stop, stop_reason, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, state) do
    if state.pool && state.session_id do
      SessionPool.unregister_async(state.pool, state.session_id)
    end

    :ok
  end

  defp decode(data, :msgpack), do: Msgpax.unpack(data)
  defp decode(data, :json), do: Jason.decode(data)

  defp encode(msg, :msgpack), do: Msgpax.pack!(msg) |> IO.iodata_to_binary()
  defp encode(msg, :json), do: Jason.encode!(msg) <> "\n"
end
