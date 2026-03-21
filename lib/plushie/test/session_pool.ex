defmodule Plushie.Test.SessionPool do
  @moduledoc """
  Shared renderer process for concurrent test sessions.

  Owns a single `plushie --headless --max-sessions N` (or `--mock`)
  Port and multiplexes messages from multiple test sessions over it.
  Each session gets a unique session ID; responses are demuxed by the
  `session` field and forwarded to the owning process.

  ## Usage

  Start the pool once (typically in `test_helper.exs` or `setup_all`):

      {:ok, pool} = SessionPool.start_link(mode: :mock, max_sessions: 8)

  Then use `Plushie.Test.Backend.Pooled` as the backend, passing the pool:

      session = Session.start(MyApp, backend: Backend.Pooled, pool: pool)

  ## Architecture

  The pool is a GenServer that:

  1. Spawns the renderer as a Port with `--max-sessions N`.
  2. Assigns unique session IDs to each registered caller.
  3. Injects the `session` field into outgoing messages.
  4. Demuxes incoming responses by the `session` field and forwards
     them to the registered owner process.
  """

  use GenServer

  require Logger

  @type session_id :: String.t()

  # -- Public API ------------------------------------------------------------

  @doc """
  Start the pool, spawning a renderer process.

  ## Options

  - `:renderer` -- path to the plushie binary (required)
  - `:mode` -- `:mock` (default) or `:headless`
  - `:format` -- `:msgpack` (default) or `:json`
  - `:max_sessions` -- maximum concurrent sessions (default 8)
  - `:name` -- optional registered name for the pool
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {gen_opts, pool_opts} = Keyword.split(opts, [:name])
    GenServer.start_link(__MODULE__, pool_opts, gen_opts)
  end

  @doc "Register a new session. Returns a unique session ID."
  @spec register(pool :: GenServer.server()) :: session_id()
  def register(pool) do
    case GenServer.call(pool, :register) do
      {:error, {:max_sessions_reached, max}} ->
        raise """
        Session pool is full (#{max} sessions).

        This usually means tests are creating sessions faster than they're
        being released. Increase :max_sessions in your SessionPool config
        or check for tests that don't properly stop their sessions.
        """

      session_id when is_binary(session_id) ->
        session_id
    end
  end

  @doc "Unregister a session. Sends Reset to the renderer to free resources."
  @spec unregister(pool :: GenServer.server(), session_id()) :: :ok
  def unregister(pool, session_id) do
    # The call blocks until the renderer's reset_response arrives.
    _response = GenServer.call(pool, {:unregister, session_id})
    :ok
  end

  @doc """
  Send a message to the renderer for the given session.

  The `session` field is injected automatically. Synchronous -- waits
  for the matching response if `expect_response` is a response type
  string (e.g. `"query_response"`). For fire-and-forget messages
  (snapshot, patch, subscription), pass `nil`.
  """
  @spec send_message(
          pool :: GenServer.server(),
          session_id(),
          msg :: map(),
          expect_response :: String.t() | nil
        ) :: {:ok, map()} | {:error, term()} | :ok
  def send_message(pool, session_id, msg, expect_response \\ nil) do
    if expect_response do
      GenServer.call(pool, {:send, session_id, msg, expect_response}, 30_000)
    else
      GenServer.cast(pool, {:send, session_id, msg})
    end
  end

  @doc """
  Send an interact message that may produce intermediate steps.

  Unlike `send_message/4`, this does NOT block for the response.
  Instead, `interact_step` and `interact_response` messages are
  forwarded to the session owner via `{:plushie_pool_event, ...}`.
  The caller is responsible for handling them in `handle_info`.

  Returns the request ID assigned to this interact.
  """
  @spec send_interact(
          pool :: GenServer.server(),
          session_id(),
          msg :: map()
        ) :: String.t()
  def send_interact(pool, session_id, msg) do
    GenServer.call(pool, {:send_interact, session_id, msg})
  end

  # -- GenServer Implementation -----------------------------------------------

  defmodule State do
    @moduledoc false
    defstruct [
      :port,
      :format,
      :max_sessions,
      # session_id -> {owner_pid, monitor_ref}
      sessions: %{},
      # {session_id, request_id} -> {response_type, from}
      pending: %{},
      # session_id -> from (callers waiting for session_closed after reset)
      pending_close: %{},
      next_id: 1,
      next_session: 1,
      buffer: ""
    ]
  end

  @impl GenServer
  def init(opts) do
    mode = Keyword.get(opts, :mode, :mock)
    format = Keyword.get(opts, :format, :msgpack)
    max_sessions = Keyword.get(opts, :max_sessions, 8)

    renderer_path = Keyword.fetch!(opts, :renderer)

    env_opts =
      case Keyword.fetch(opts, :rust_log) do
        {:ok, level} -> [rust_log: level]
        :error -> []
      end

    env = Plushie.RendererEnv.build(env_opts)

    mode_flag = if mode == :headless, do: "--headless", else: "--mock"

    args =
      [mode_flag, "--max-sessions", to_string(max_sessions)] ++
        if(format == :json, do: ["--json"], else: [])

    port_opts =
      [:binary, :exit_status, :use_stdio] ++
        if(format == :json, do: [{:line, 65_536}], else: [{:packet, 4}])

    port =
      Port.open(
        {:spawn_executable, renderer_path},
        port_opts ++ [{:args, args}, {:env, env}]
      )

    # Send initial settings to trigger the hello handshake.
    settings = %{protocol_version: Plushie.Protocol.protocol_version()}
    send_to_port(port, format, %{session: "", type: "settings", settings: settings})

    {:ok, %State{port: port, format: format, max_sessions: max_sessions}}
  end

  @impl GenServer
  def handle_call(:register, {caller_pid, _}, state) do
    if map_size(state.sessions) >= state.max_sessions do
      {:reply, {:error, {:max_sessions_reached, state.max_sessions}}, state}
    else
      session_id = "pool_#{state.next_session}"
      monitor_ref = Process.monitor(caller_pid)
      sessions = Map.put(state.sessions, session_id, {caller_pid, monitor_ref})
      {:reply, session_id, %{state | sessions: sessions, next_session: state.next_session + 1}}
    end
  end

  def handle_call({:unregister, session_id}, from, state) do
    # Demonitor the session owner -- we're cleaning up explicitly.
    case Map.get(state.sessions, session_id) do
      {_pid, monitor_ref} -> Process.demonitor(monitor_ref, [:flush])
      _ -> :ok
    end

    # Send Reset to free renderer resources. We block on reset_response
    # for backward compatibility with older renderers. If the renderer
    # also sends session_closed (v0.3.2+), we handle it gracefully.
    req_id = "unreg_#{state.next_id}"
    msg = %{session: session_id, type: "reset", id: req_id}
    send_to_port(state.port, state.format, msg)

    pending = Map.put(state.pending, {session_id, req_id}, {"reset_response", from})
    sessions = Map.delete(state.sessions, session_id)
    # Track session_id so we can absorb the session_closed event if it arrives.
    pending_close = Map.put(state.pending_close, session_id, :awaiting)

    {:noreply,
     %{
       state
       | pending: pending,
         sessions: sessions,
         pending_close: pending_close,
         next_id: state.next_id + 1
     }}
  end

  def handle_call({:send, session_id, msg, response_type}, from, state) do
    req_id = "req_#{state.next_id}"
    msg = msg |> Map.put(:session, session_id) |> Map.put(:id, req_id)
    send_to_port(state.port, state.format, msg)

    pending = Map.put(state.pending, {session_id, req_id}, {response_type, from})
    {:noreply, %{state | pending: pending, next_id: state.next_id + 1}}
  end

  def handle_call({:send_interact, session_id, msg}, _from, state) do
    req_id = "req_#{state.next_id}"
    msg = msg |> Map.put(:session, session_id) |> Map.put(:id, req_id)
    send_to_port(state.port, state.format, msg)

    # Don't add to pending -- interact_step and interact_response
    # will be forwarded to the session owner via forward_to_session.
    {:reply, req_id, %{state | next_id: state.next_id + 1}}
  end

  @impl GenServer
  def handle_cast({:send, session_id, msg}, state) do
    msg = Map.put(msg, :session, session_id)
    send_to_port(state.port, state.format, msg)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    state = handle_port_data(data, state)
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    Logger.error("SessionPool: renderer exited with status #{code}")
    # Reply to all pending callers with an error.
    for {_key, {_type, from}} <- state.pending do
      GenServer.reply(from, {:error, :renderer_exited})
    end

    {:stop, {:renderer_exited, code}, %{state | pending: %{}, pending_close: %{}}}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    # Session owner died -- clean up without sending a reset to the renderer
    # (the test process is gone, no point waiting for a response).
    case Enum.find(state.sessions, fn {_id, {p, r}} -> p == pid and r == ref end) do
      {session_id, _} ->
        sessions = Map.delete(state.sessions, session_id)
        {:noreply, %{state | sessions: sessions}}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # -- Port I/O ---------------------------------------------------------------

  defp send_to_port(port, format, msg) do
    data = Plushie.Protocol.encode(msg, format)
    Port.command(port, data)
  end

  defp handle_port_data(raw_data, %{format: :json} = state) do
    # JSON mode: Port sends {:line, data} tuples via {:data, {:eol, line}}.
    line =
      case raw_data do
        {:eol, l} -> l
        l when is_binary(l) -> l
      end

    buffer = state.buffer <> line

    case Jason.decode(buffer) do
      {:ok, msg} ->
        state = %{state | buffer: ""}
        dispatch_response(msg, state)

      {:error, _} ->
        %{state | buffer: buffer}
    end
  end

  defp handle_port_data(data, %{format: :msgpack} = state) do
    case Msgpax.unpack(data) do
      {:ok, msg} -> dispatch_response(msg, state)
      {:error, _} -> state
    end
  end

  defp dispatch_response(%{"type" => "hello"}, state), do: state

  # Session closed: absorb if we're tracking this session's teardown,
  # otherwise forward to the session owner.
  defp dispatch_response(
         %{"type" => "event", "family" => "session_closed", "session" => session_id},
         state
       ) do
    case Map.pop(state.pending_close, session_id) do
      {nil, _} ->
        forward_to_session(
          session_id,
          %{"type" => "session_closed", "session" => session_id},
          state
        )

      {:awaiting, pending_close} ->
        # Reset already replied via reset_response; just clean up.
        %{state | pending_close: pending_close}
    end
  end

  # Session error: forward to session owner if registered, otherwise log.
  defp dispatch_response(
         %{"type" => "event", "family" => "session_error", "session" => session_id} = msg,
         state
       ) do
    forward_to_session(session_id, msg, state)
  end

  # Interact step: an intermediate event batch during iterative
  # interact. Forward to the session owner for processing (the owner
  # will send back a snapshot). Do NOT consume the pending entry --
  # more steps or the final interact_response may follow.
  defp dispatch_response(
         %{"type" => "interact_step", "session" => session_id} = msg,
         state
       ) do
    forward_to_session(session_id, msg, state)
  end

  defp dispatch_response(%{"type" => _type, "session" => session_id, "id" => req_id} = msg, state) do
    key = {session_id, req_id}

    case Map.fetch(state.pending, key) do
      {:ok, {_expected_type, from}} ->
        GenServer.reply(from, {:ok, msg})
        %{state | pending: Map.delete(state.pending, key)}

      :error ->
        # Not a pending response -- might be an event. Forward to session owner.
        forward_to_session(session_id, msg, state)
    end
  end

  defp dispatch_response(%{"type" => "event", "session" => session_id} = msg, state) do
    forward_to_session(session_id, msg, state)
  end

  defp dispatch_response(_msg, state), do: state

  defp forward_to_session(session_id, msg, state) do
    case Map.get(state.sessions, session_id) do
      nil -> state
      {pid, _ref} -> send(pid, {:plushie_pool_event, session_id, msg})
    end

    state
  end
end
