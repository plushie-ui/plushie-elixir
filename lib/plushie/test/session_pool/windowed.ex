defmodule Plushie.Test.SessionPool.Windowed do
  @moduledoc """
  State and business logic for the `:windowed` session pool mode.

  Windowed tests run one renderer process per logical session. This module owns
  per-session state, request tracking, response dispatch, and exit handling for
  those renderer processes.
  """

  alias Plushie.Test.SessionPool.Transport

  require Logger

  @typedoc "Internal session identifier assigned by `SessionPool`."
  @type session_id :: String.t()
  @typedoc "Request identifier attached to a message sent to the renderer."
  @type request_id :: String.t()
  @typedoc "How the pool is waiting for a windowed renderer to exit."
  @type close_kind :: {:sync, GenServer.from()} | :async
  @typedoc "Per-session state for a windowed renderer process."
  @type t :: %__MODULE__{
          owner_pid: pid(),
          owner_ref: reference(),
          port: port(),
          pending: %{request_id() => {String.t(), GenServer.from()}},
          buffer: binary()
        }

  defstruct [:owner_pid, :owner_ref, :port, pending: %{}, buffer: ""]

  @spec new(pid(), reference(), port()) :: t()
  def new(owner_pid, owner_ref, port) do
    %__MODULE__{owner_pid: owner_pid, owner_ref: owner_ref, port: port}
  end

  @spec register_session(Plushie.Test.SessionPool.t(), pid(), reference(), session_id()) ::
          Plushie.Test.SessionPool.t()
  def register_session(state, caller_pid, monitor_ref, session_id) do
    port =
      Transport.open_renderer_port(
        state.renderer,
        state.env,
        state.format,
        Transport.windowed_args(state.format)
      )

    Transport.send_initial_settings(port, state.format, session_id)

    session = new(caller_pid, monitor_ref, port)

    %{
      state
      | sessions: Map.put(state.sessions, session_id, session),
        next_session: state.next_session + 1
    }
  end

  @spec send_sync(t(), map(), request_id(), String.t(), GenServer.from(), Transport.format()) ::
          t()
  def send_sync(%__MODULE__{} = session, msg, req_id, response_type, from, format) do
    msg = Map.put(msg, :id, req_id)
    Transport.send_to_port(session.port, format, msg)
    %{session | pending: Map.put(session.pending, req_id, {response_type, from})}
  end

  @spec send_interact(t(), map(), request_id(), Transport.format()) :: t()
  def send_interact(%__MODULE__{} = session, msg, req_id, format) do
    msg = Map.put(msg, :id, req_id)
    Transport.send_to_port(session.port, format, msg)
    session
  end

  @spec send_async(t(), map(), Transport.format()) :: t()
  def send_async(%__MODULE__{} = session, msg, format) do
    Transport.send_to_port(session.port, format, msg)
    session
  end

  @spec request_exit(Plushie.Test.SessionPool.t(), session_id(), port(), close_kind()) ::
          Plushie.Test.SessionPool.t()
  def request_exit(state, session_id, port, close_kind) do
    case Map.has_key?(state.closing_windowed, session_id) do
      true ->
        state

      false ->
        Transport.send_to_port(port, state.format, %{type: "widget_op", op: "exit", payload: %{}})
        Process.send_after(self(), {:force_close_windowed, session_id, port}, 1_000)
        put_in(state.closing_windowed[session_id], {close_kind, port})
    end
  end

  @spec finish_exit(Plushie.Test.SessionPool.t(), session_id(), t(), integer()) ::
          Plushie.Test.SessionPool.t()
  def finish_exit(state, session_id, %__MODULE__{} = session, code) do
    case Map.pop(state.closing_windowed, session_id) do
      {{{:sync, from}, _port}, closing_windowed} ->
        GenServer.reply(from, :ok)

        %{
          state
          | sessions: Map.delete(state.sessions, session_id),
            closing_windowed: closing_windowed
        }

      {{:async, _port}, closing_windowed} ->
        %{
          state
          | sessions: Map.delete(state.sessions, session_id),
            closing_windowed: closing_windowed
        }

      {nil, _closing_windowed} ->
        Logger.error(
          "SessionPool: windowed renderer exited with status #{code} for #{session_id}"
        )

        for {_req_id, {_type, from}} <- session.pending do
          GenServer.reply(from, {:error, :renderer_exited})
        end

        if Process.alive?(session.owner_pid) do
          send(session.owner_pid, {:plushie_pool_renderer_exited, session_id, code})
        end

        %{state | sessions: Map.delete(state.sessions, session_id)}
    end
  end

  @spec find_session_by_port(%{session_id() => t()}, port()) :: {session_id(), t()} | nil
  def find_session_by_port(sessions, port) do
    Enum.find(sessions, fn {_session_id, entry} ->
      match?(%__MODULE__{port: ^port}, entry)
    end)
  end

  @spec find_close_by_port(%{session_id() => t()}, map(), port()) :: {session_id(), t()} | nil
  def find_close_by_port(sessions, closing_windowed, port) do
    Enum.find(closing_windowed, fn {session_id, _close_kind} ->
      case Map.get(closing_windowed, session_id) do
        {_close_kind, ^port} -> true
        _ -> false
      end
    end)
    |> case do
      {session_id, {_close_kind, ^port}} ->
        case Map.get(sessions, session_id) do
          %__MODULE__{} = session -> {session_id, session}
          _ -> nil
        end

      nil ->
        nil
    end
  end

  @spec matches_owner?(t(), pid(), reference()) :: boolean()
  def matches_owner?(%__MODULE__{} = session, pid, ref) do
    session.owner_pid == pid and session.owner_ref == ref
  end

  @spec handle_port_data(binary() | {:eol, binary()}, session_id(), t(), Transport.format()) ::
          t()
  def handle_port_data(raw_data, session_id, %__MODULE__{} = session, format) do
    case decode_message(raw_data, session.buffer, format) do
      {:ok, msg, buffer} ->
        dispatch_response(session_id, msg, %{session | buffer: buffer})

      {:cont, buffer} ->
        %{session | buffer: buffer}
    end
  end

  defp decode_message(raw_data, buffer, :json) do
    line =
      case raw_data do
        {:eol, l} -> l
        l when is_binary(l) -> l
      end

    buffer = buffer <> line

    case Jason.decode(buffer) do
      {:ok, msg} -> {:ok, msg, ""}
      {:error, _} -> {:cont, buffer}
    end
  end

  defp decode_message(data, _buffer, :msgpack) do
    case Msgpax.unpack(data) do
      {:ok, msg} -> {:ok, msg, ""}
      {:error, _} -> {:cont, ""}
    end
  end

  defp dispatch_response(_session_id, %{"type" => "hello"}, session), do: session

  defp dispatch_response(session_id, %{"type" => "interact_step"} = msg, session) do
    send(session.owner_pid, {:plushie_pool_event, session_id, msg})
    session
  end

  defp dispatch_response(session_id, %{"type" => "interact_response"} = msg, session) do
    send(session.owner_pid, {:plushie_pool_event, session_id, msg})
    session
  end

  defp dispatch_response(session_id, %{"type" => "event"} = msg, session) do
    send(session.owner_pid, {:plushie_pool_event, session_id, msg})
    session
  end

  defp dispatch_response(session_id, %{"type" => type} = msg, session)
       when type in ["effect_stub_registered", "effect_stub_unregistered"] do
    send(session.owner_pid, {:plushie_pool_event, session_id, msg})
    session
  end

  defp dispatch_response(_session_id, %{"id" => req_id} = msg, session) do
    case Map.pop(session.pending, req_id) do
      {nil, pending} ->
        %{session | pending: pending}

      {{_expected_type, from}, pending} ->
        GenServer.reply(from, {:ok, msg})
        %{session | pending: pending}
    end
  end

  defp dispatch_response(_session_id, _msg, session), do: session
end
