defmodule Plushie.Test.SessionPool do
  @moduledoc """
  Session manager for concurrent test renderer sessions.

  For `:mock` and `:headless`, owns a single renderer Port and multiplexes
  multiple logical sessions over it. For `:windowed`, each logical session
  gets its own renderer process because the real iced renderer only supports
  one live app session per process.

  ## Usage

  Start the pool once (typically in `test_helper.exs` or `setup_all`):

      {:ok, pool} = SessionPool.start_link(mode: :mock, max_sessions: 8)

  The Runtime test backend connects to the pool via a PoolAdapter:

      session = Session.start(MyApp, backend: Backend.Runtime, pool: pool)

  The pool assigns session IDs, sends messages to the right renderer,
  and forwards replies back to the caller.
  """

  use GenServer

  alias __MODULE__.{Multiplexed, Transport, Windowed}

  require Logger

  @type mode :: :mock | :headless | :windowed
  @type session_id :: String.t()
  @typedoc """
  Pool state for the test renderer session manager.

  The top-level struct keeps only pool-wide configuration and counters. Mode-
  specific runtime state lives in `Multiplexed` or `Windowed` structs.
  """
  @type t :: %__MODULE__{
          mode: mode(),
          renderer: String.t(),
          env: [{String.t(), String.t()}],
          format: Transport.format(),
          max_sessions: pos_integer(),
          multiplexed: Multiplexed.t() | nil,
          sessions: %{session_id() => Windowed.t()},
          closing_windowed: %{session_id() => {Windowed.close_kind(), port()}},
          next_id: pos_integer(),
          next_session: pos_integer()
        }

  defstruct [
    :mode,
    :renderer,
    :env,
    :format,
    :max_sessions,
    # multiplexed mode only
    multiplexed: nil,
    # windowed mode only: session_id -> %Windowed{}
    sessions: %{},
    # windowed mode only: session_id -> {{:sync, from} | :async, port}
    closing_windowed: %{},
    next_id: 1,
    next_session: 1
  ]

  # -- Public API ------------------------------------------------------------

  @doc """
  Start the pool, spawning a renderer process.

  ## Options

  - `:renderer` -- path to the plushie binary (required)
  - `:mode` -- `:mock` (default), `:headless`, or `:windowed`
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
    case GenServer.call(pool, :register, :infinity) do
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
  Unregister a session without waiting for the renderer reset.

  The session is removed from the active map immediately. The reset
  is still sent to the renderer, but the caller doesn't block on the
  response. Used by terminate/2 to avoid blocking on slow renderers.
  """
  @spec unregister_async(pool :: GenServer.server(), session_id()) :: :ok
  def unregister_async(pool, session_id) do
    GenServer.cast(pool, {:unregister_async, session_id})
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
    case GenServer.call(pool, {:send_interact, session_id, msg}) do
      req_id when is_binary(req_id) ->
        req_id

      {:error, reason} ->
        raise "failed to send interact for #{inspect(session_id)}: #{inspect(reason)}"
    end
  end

  # -- GenServer Implementation -----------------------------------------------

  @impl GenServer
  def init(opts) do
    mode = Keyword.get(opts, :mode, :mock)
    format = Keyword.get(opts, :format, :msgpack)
    max_sessions = max_sessions(Keyword.get(opts, :max_sessions))

    renderer_path = Keyword.fetch!(opts, :renderer)

    env_opts =
      case Keyword.fetch(opts, :rust_log) do
        {:ok, level} -> [rust_log: level]
        :error -> []
      end

    env = Plushie.RendererEnv.build(env_opts)

    state = %__MODULE__{
      mode: mode,
      renderer: renderer_path,
      env: env,
      format: format,
      max_sessions: max_sessions
    }

    case mode do
      mode when mode in [:mock, :headless] ->
        args = Transport.multiplexed_args(mode, format, max_sessions)
        port = Transport.open_renderer_port(renderer_path, env, format, args)

        Transport.send_initial_settings(port, format, "")
        {:ok, %{state | multiplexed: %Multiplexed{port: port, buffer: ""}}}

      :windowed ->
        {:ok, state}
    end
  end

  @doc false
  @spec renderer_mode_flag(:mock | :headless) :: String.t()
  defdelegate renderer_mode_flag(mode), to: Transport

  @impl GenServer
  def handle_call(:register, {caller_pid, _}, state) do
    session_count =
      case state.mode do
        mode when mode in [:mock, :headless] -> Multiplexed.session_count(state.multiplexed)
        :windowed -> map_size(state.sessions)
      end

    if session_count >= state.max_sessions do
      {:reply, {:error, {:max_sessions_reached, state.max_sessions}}, state}
    else
      session_id = "pool_#{state.next_session}"
      monitor_ref = Process.monitor(caller_pid)

      case state.mode do
        mode when mode in [:mock, :headless] ->
          multiplexed =
            Multiplexed.register(state.multiplexed, session_id, caller_pid, monitor_ref)

          {:reply, session_id,
           %{state | multiplexed: multiplexed, next_session: state.next_session + 1}}

        :windowed ->
          state = Windowed.register_session(state, caller_pid, monitor_ref, session_id)
          {:reply, session_id, state}
      end
    end
  end

  def handle_call({:unregister, session_id}, from, state) do
    case state.mode do
      mode when mode in [:mock, :headless] ->
        case Map.get(state.multiplexed.sessions, session_id) do
          {_pid, monitor_ref} -> Process.demonitor(monitor_ref, [:flush])
          _ -> :ok
        end

        req_id = "unreg_#{state.next_id}"

        multiplexed =
          Multiplexed.unregister(state.multiplexed, session_id, req_id, from, state.format)

        {:noreply,
         %{
           state
           | multiplexed: multiplexed,
             next_id: state.next_id + 1
         }}

      :windowed ->
        case Map.get(state.sessions, session_id) do
          %Windowed{owner_ref: monitor_ref, port: port} ->
            Process.demonitor(monitor_ref, [:flush])
            state = Windowed.request_exit(state, session_id, port, {:sync, from})

            {:noreply, state}

          nil ->
            {:reply, :ok, state}
        end
    end
  end

  def handle_call({:send, session_id, msg, response_type}, from, state) do
    req_id = "req_#{state.next_id}"

    case state.mode do
      mode when mode in [:mock, :headless] ->
        case Multiplexed.send_sync(
               state.multiplexed,
               session_id,
               msg,
               req_id,
               response_type,
               from,
               state.format
             ) do
          {:ok, multiplexed} ->
            {:noreply, %{state | multiplexed: multiplexed, next_id: state.next_id + 1}}

          :error ->
            GenServer.reply(from, {:error, :unknown_session})
            {:noreply, state}
        end

      :windowed ->
        case Map.fetch(state.sessions, session_id) do
          {:ok, %Windowed{} = session} ->
            session = Windowed.send_sync(session, msg, req_id, response_type, from, state.format)

            {:noreply,
             %{
               state
               | sessions: Map.put(state.sessions, session_id, session),
                 next_id: state.next_id + 1
             }}

          :error ->
            GenServer.reply(from, {:error, :unknown_session})
            {:noreply, state}
        end
    end
  end

  def handle_call({:send_interact, session_id, msg}, _from, state) do
    req_id = "req_#{state.next_id}"

    case state.mode do
      mode when mode in [:mock, :headless] ->
        case Multiplexed.send_interact(state.multiplexed, session_id, msg, req_id, state.format) do
          {:ok, multiplexed} ->
            {:reply, req_id, %{state | multiplexed: multiplexed, next_id: state.next_id + 1}}

          :error ->
            {:reply, {:error, :unknown_session}, state}
        end

      :windowed ->
        case Map.fetch(state.sessions, session_id) do
          {:ok, %Windowed{} = session} ->
            session = Windowed.send_interact(session, msg, req_id, state.format)

            {:reply, req_id,
             %{
               state
               | sessions: Map.put(state.sessions, session_id, session),
                 next_id: state.next_id + 1
             }}

          :error ->
            {:reply, {:error, :unknown_session}, state}
        end
    end
  end

  @impl GenServer
  def handle_cast({:unregister_async, session_id}, state) do
    case state.mode do
      mode when mode in [:mock, :headless] ->
        case Map.get(state.multiplexed.sessions, session_id) do
          {_pid, monitor_ref} ->
            Process.demonitor(monitor_ref, [:flush])
            req_id = "rel_#{state.next_id}"

            multiplexed =
              Multiplexed.release_session(state.multiplexed, session_id, req_id, state.format)

            {:noreply, %{state | multiplexed: multiplexed, next_id: state.next_id + 1}}

          nil ->
            {:noreply, state}
        end

      :windowed ->
        case Map.get(state.sessions, session_id) do
          %Windowed{owner_ref: monitor_ref, port: port} ->
            Process.demonitor(monitor_ref, [:flush])
            state = Windowed.request_exit(state, session_id, port, :async)

            {:noreply, state}

          nil ->
            {:noreply, state}
        end
    end
  end

  def handle_cast({:send, session_id, msg}, state) do
    case state.mode do
      mode when mode in [:mock, :headless] ->
        {:noreply,
         %{
           state
           | multiplexed: Multiplexed.send_async(state.multiplexed, session_id, msg, state.format)
         }}

      :windowed ->
        case Map.get(state.sessions, session_id) do
          %Windowed{} = session ->
            session = Windowed.send_async(session, msg, state.format)
            {:noreply, %{state | sessions: Map.put(state.sessions, session_id, session)}}

          nil ->
            {:noreply, state}
        end
    end
  end

  @impl GenServer
  def handle_info(
        {port, {:data, data}},
        %{mode: mode, multiplexed: %Multiplexed{port: port}} = state
      )
      when mode in [:mock, :headless] do
    multiplexed = Multiplexed.handle_port_data(data, state.multiplexed, state.format)
    {:noreply, %{state | multiplexed: multiplexed}}
  end

  def handle_info(
        {port, {:exit_status, code}},
        %{mode: mode, multiplexed: %Multiplexed{port: port}} = state
      )
      when mode in [:mock, :headless] do
    Logger.error("SessionPool: renderer exited with status #{code}")

    multiplexed = Multiplexed.handle_renderer_exit(state.multiplexed)
    {:stop, {:renderer_exited, code}, %{state | multiplexed: multiplexed}}
  end

  def handle_info({port, {:data, data}}, %{mode: :windowed} = state) do
    case Windowed.find_session_by_port(state.sessions, port) do
      {session_id, %Windowed{} = session} ->
        session = Windowed.handle_port_data(data, session_id, session, state.format)
        {:noreply, %{state | sessions: Map.put(state.sessions, session_id, session)}}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info({port, {:exit_status, code}}, %{mode: :windowed} = state) do
    case Windowed.find_session_by_port(state.sessions, port) ||
           Windowed.find_close_by_port(state.sessions, state.closing_windowed, port) do
      {session_id, %Windowed{} = session} ->
        state = Windowed.finish_exit(state, session_id, session, code)
        {:noreply, state}

      nil ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case state.mode do
      mode when mode in [:mock, :headless] ->
        case Multiplexed.find_session_by_owner(state.multiplexed, pid, ref) do
          {session_id, _} ->
            req_id = "rel_#{state.next_id}"

            multiplexed =
              Multiplexed.release_session(state.multiplexed, session_id, req_id, state.format)

            {:noreply, %{state | multiplexed: multiplexed, next_id: state.next_id + 1}}

          nil ->
            {:noreply, state}
        end

      :windowed ->
        case Enum.find(state.sessions, fn {_id, s} ->
               Windowed.matches_owner?(s, pid, ref)
             end) do
          {session_id, %Windowed{port: port}} ->
            state = Windowed.request_exit(state, session_id, port, :async)

            {:noreply, state}

          nil ->
            {:noreply, state}
        end
    end
  end

  def handle_info({:force_close_windowed, session_id, port}, state) do
    case Map.fetch(state.closing_windowed, session_id) do
      {:ok, _close_kind} ->
        Port.close(port)
        {:noreply, state}

      :error ->
        {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp max_sessions(nil), do: 8
  defp max_sessions(requested) when is_integer(requested) and requested > 0, do: requested
end
