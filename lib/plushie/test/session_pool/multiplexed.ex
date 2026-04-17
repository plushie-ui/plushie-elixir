defmodule Plushie.Test.SessionPool.Multiplexed do
  @moduledoc """
  State and business logic for the shared-renderer session pool modes.

  `:mock` and `:headless` run one renderer process that hosts many logical
  sessions. This module owns the registrations, pending replies, teardown
  tracking, and dispatch of replies back to the correct test process.
  """

  alias Plushie.Test.SessionPool.Transport

  @typedoc "Internal session identifier assigned by `SessionPool`."
  @type session_id :: String.t()
  @typedoc "Request identifier attached to a message sent to the renderer."
  @type request_id :: String.t()
  @typedoc "Shared-renderer state for multiplexed test sessions."
  @type t :: %__MODULE__{
          port: port(),
          buffer: binary(),
          sessions: %{session_id() => {pid(), reference()}},
          pending: %{{session_id(), request_id()} => {String.t(), GenServer.from()}},
          pending_close: %{session_id() => :awaiting}
        }

  defstruct [
    :port,
    :buffer,
    # session_id -> {owner_pid, monitor_ref}
    sessions: %{},
    # {session_id, request_id} -> {response_type, from}
    pending: %{},
    # session_id -> :awaiting while reset is in flight
    pending_close: %{}
  ]

  @spec session_count(t()) :: non_neg_integer()
  def session_count(%__MODULE__{} = state), do: map_size(state.sessions)

  @spec register(t(), session_id(), pid(), reference()) :: t()
  def register(%__MODULE__{} = state, session_id, caller_pid, monitor_ref) do
    %{state | sessions: Map.put(state.sessions, session_id, {caller_pid, monitor_ref})}
  end

  @spec find_session_by_owner(t(), pid(), reference()) ::
          {session_id(), {pid(), reference()}} | nil
  def find_session_by_owner(%__MODULE__{} = state, pid, ref) do
    Enum.find(state.sessions, fn {_id, {p, r}} -> p == pid and r == ref end)
  end

  @spec unregister(t(), session_id(), request_id(), GenServer.from(), Transport.format()) :: t()
  def unregister(%__MODULE__{} = state, session_id, req_id, from, format) do
    Transport.send_to_port(state.port, format, %{session: session_id, type: "reset", id: req_id})

    %{
      state
      | pending: Map.put(state.pending, {session_id, req_id}, {"reset_response", from}),
        sessions: Map.delete(state.sessions, session_id),
        pending_close: Map.put(state.pending_close, session_id, :awaiting)
    }
  end

  @spec release_session(t(), session_id(), request_id(), Transport.format()) :: t()
  def release_session(%__MODULE__{} = state, session_id, req_id, format) do
    Transport.send_to_port(state.port, format, %{session: session_id, type: "reset", id: req_id})

    %{
      state
      | sessions: Map.delete(state.sessions, session_id),
        pending_close: Map.put(state.pending_close, session_id, :awaiting)
    }
  end

  @spec send_sync(
          t(),
          session_id(),
          map(),
          request_id(),
          String.t(),
          GenServer.from(),
          Transport.format()
        ) ::
          {:ok, t()} | :error
  def send_sync(%__MODULE__{} = state, session_id, msg, req_id, response_type, from, format) do
    case Map.has_key?(state.sessions, session_id) do
      true ->
        msg = msg |> Map.put(:session, session_id) |> Map.put(:id, req_id)
        Transport.send_to_port(state.port, format, msg)

        {:ok,
         %{state | pending: Map.put(state.pending, {session_id, req_id}, {response_type, from})}}

      false ->
        :error
    end
  end

  @spec send_interact(t(), session_id(), map(), request_id(), Transport.format()) ::
          {:ok, t()} | :error
  def send_interact(%__MODULE__{} = state, session_id, msg, req_id, format) do
    case Map.has_key?(state.sessions, session_id) do
      true ->
        msg = msg |> Map.put(:session, session_id) |> Map.put(:id, req_id)
        Transport.send_to_port(state.port, format, msg)
        {:ok, state}

      false ->
        :error
    end
  end

  @spec send_async(t(), session_id(), map(), Transport.format()) :: t()
  def send_async(%__MODULE__{} = state, session_id, msg, format) do
    Transport.send_to_port(state.port, format, Map.put(msg, :session, session_id))
    state
  end

  @spec handle_renderer_exit(t()) :: t()
  def handle_renderer_exit(%__MODULE__{} = state) do
    for {_key, {_type, from}} <- state.pending do
      GenServer.reply(from, {:error, :renderer_exited})
    end

    %{state | pending: %{}, pending_close: %{}}
  end

  @spec handle_port_data(binary() | {:eol, binary()}, t(), Transport.format()) :: t()
  def handle_port_data(raw_data, %__MODULE__{} = state, :json) do
    line =
      case raw_data do
        {:eol, l} -> l
        l when is_binary(l) -> l
      end

    buffer = state.buffer <> line

    case Jason.decode(buffer) do
      {:ok, msg} ->
        dispatch_response(msg, %{state | buffer: ""})

      {:error, _} ->
        %{state | buffer: buffer}
    end
  end

  def handle_port_data(data, %__MODULE__{} = state, :msgpack) do
    case Msgpax.unpack(data) do
      {:ok, msg} -> dispatch_response(msg, state)
      {:error, _} -> state
    end
  end

  defp dispatch_response(%{"type" => "hello"}, state), do: state

  defp dispatch_response(
         %{"type" => "event", "family" => "session_closed", "session" => session_id},
         state
       ) do
    case Map.pop(state.pending_close, session_id) do
      {nil, _} ->
        forward_to_session(state, session_id, %{
          "type" => "session_closed",
          "session" => session_id
        })

      {:awaiting, pending_close} ->
        %{state | pending_close: pending_close}
    end
  end

  defp dispatch_response(
         %{"type" => "event", "family" => "session_error", "session" => session_id} = msg,
         state
       ) do
    forward_to_session(state, session_id, msg)
  end

  defp dispatch_response(%{"type" => "interact_step", "session" => session_id} = msg, state) do
    forward_to_session(state, session_id, msg)
  end

  defp dispatch_response(%{"type" => _type, "session" => session_id, "id" => req_id} = msg, state) do
    key = {session_id, req_id}

    case Map.fetch(state.pending, key) do
      {:ok, {_expected_type, from}} ->
        GenServer.reply(from, {:ok, msg})
        %{state | pending: Map.delete(state.pending, key)}

      :error ->
        forward_to_session(state, session_id, msg)
    end
  end

  defp dispatch_response(%{"type" => "event", "session" => session_id} = msg, state) do
    forward_to_session(state, session_id, msg)
  end

  defp dispatch_response(%{"type" => type, "session" => session_id} = msg, state)
       when type in ["effect_stub_register_ack", "effect_stub_unregister_ack"] do
    forward_to_session(state, session_id, msg)
  end

  defp dispatch_response(_msg, state), do: state

  defp forward_to_session(%__MODULE__{} = state, session_id, msg) do
    case Map.get(state.sessions, session_id) do
      {pid, _ref} -> send(pid, {:plushie_pool_event, session_id, msg})
      nil -> :ok
    end

    state
  end
end
