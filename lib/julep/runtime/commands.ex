defmodule Julep.Runtime.Commands do
  @moduledoc """
  Command execution engine for the Julep runtime.

  Handles all `%Julep.Command{}` types returned by `app.update/2` and
  `app.init/1`. The single public entry point is `execute_commands/2`,
  which threads state through each command and returns the updated state.
  """

  require Logger

  # Default timeout for effect requests (30 seconds).
  @effect_timeout_ms 30_000

  @doc """
  Executes a list of commands (or a single command), threading the runtime
  state through each one. Batch commands are flattened recursively.
  """
  @spec execute_commands([Julep.Command.t()] | Julep.Command.t(), map()) :: map()
  def execute_commands(commands, state) when is_list(commands) do
    Enum.reduce(commands, state, &execute_command/2)
  end

  def execute_commands(%Julep.Command{} = cmd, state) do
    execute_command(cmd, state)
  end

  # -- Private command handlers -----------------------------------------------

  @spec execute_command(Julep.Command.t(), map()) :: map()
  defp execute_command(%Julep.Command{type: :none}, state), do: state

  defp execute_command(
         %Julep.Command{type: :done, payload: %{value: value, mapper: mapper}},
         state
       ) do
    event = mapper.(value)
    send(self(), {:renderer_event, event})
    state
  end

  defp execute_command(%Julep.Command{type: :async, payload: %{fun: fun, tag: tag}}, state) do
    # Kill any existing task with the same tag before starting a new one.
    state = cancel_existing_task(state, tag)

    runtime = self()
    nonce = make_ref()

    {:ok, pid} =
      Task.start_link(fn ->
        result = fun.()
        send(runtime, {:async_result, tag, nonce, result})
      end)

    put_in(state.async_tasks[tag], {pid, nonce})
  end

  defp execute_command(
         %Julep.Command{type: :stream, payload: %{fun: fun, tag: tag}},
         state
       ) do
    # Kill any existing task with the same tag before starting a new one.
    state = cancel_existing_task(state, tag)

    runtime = self()
    nonce = make_ref()
    emit = fn value -> send(runtime, {:stream_value, tag, nonce, value}) end

    {:ok, pid} =
      Task.start_link(fn ->
        result = fun.(emit)
        send(runtime, {:async_result, tag, nonce, result})
      end)

    put_in(state.async_tasks[tag], {pid, nonce})
  end

  defp execute_command(%Julep.Command{type: :cancel, payload: %{tag: tag}}, state) do
    case Map.get(state.async_tasks, tag) do
      {pid, _nonce} when is_pid(pid) ->
        Process.exit(pid, :kill)
        %{state | async_tasks: Map.delete(state.async_tasks, tag)}

      nil ->
        state
    end
  end

  defp execute_command(
         %Julep.Command{type: :send_after, payload: %{delay: delay, event: event}},
         state
       ) do
    # Cancel any existing timer for the same event key to prevent duplicates.
    case Map.get(state.pending_timers, event) do
      nil -> :ok
      old_ref -> Process.cancel_timer(old_ref)
    end

    ref = Process.send_after(self(), {:send_after_event, event}, delay)
    pending_timers = Map.put(state.pending_timers, event, ref)
    %{state | pending_timers: pending_timers}
  end

  defp execute_command(
         %Julep.Command{type: :effect, payload: %{id: id, kind: kind, opts: opts}},
         state
       ) do
    bridge = state.bridge

    if bridge do
      Julep.Bridge.send_effect(bridge, id, kind, opts)
    else
      Logger.warning("julep runtime: effect #{kind} (#{id}) without bridge")
    end

    # Start a timeout timer for this effect request, using a per-effect default
    # if one is configured.
    timeout = Julep.Effects.default_timeout(kind) || @effect_timeout_ms
    ref = Process.send_after(self(), {:effect_timeout, id}, timeout)
    put_in(state.pending_effects[id], ref)
  end

  defp execute_command(%Julep.Command{type: type, payload: payload}, state)
       when type in [
              :focus,
              :focus_next,
              :focus_previous,
              :select_all,
              :scroll_to,
              :snap_to,
              :snap_to_end,
              :scroll_by,
              :move_cursor_to_front,
              :move_cursor_to_end,
              :move_cursor_to,
              :select_range
            ] do
    if state.bridge do
      Julep.Bridge.send_widget_op(state.bridge, Atom.to_string(type), payload)
    end

    state
  end

  defp execute_command(%Julep.Command{type: :close_window, payload: payload}, state) do
    if state.bridge do
      Julep.Bridge.send_widget_op(state.bridge, "close_window", payload)
    end

    state
  end

  defp execute_command(%Julep.Command{type: :widget_op, payload: %{op: op} = payload}, state) do
    if state.bridge do
      Julep.Bridge.send_widget_op(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(%Julep.Command{type: :exit, payload: _payload}, state) do
    Logger.info("julep runtime: exit command received -- stopping")
    send(self(), {:renderer_exit, :normal})
    state
  end

  defp execute_command(
         %Julep.Command{type: :window_op, payload: %{op: op, window_id: window_id} = payload},
         state
       ) do
    if state.bridge do
      settings = Map.drop(payload, [:op, :window_id])
      Julep.Bridge.send_window_op(state.bridge, op, window_id, settings)
    end

    state
  end

  defp execute_command(
         %Julep.Command{type: :window_query, payload: %{op: op, window_id: window_id} = payload},
         state
       ) do
    if state.bridge do
      settings = Map.drop(payload, [:op, :window_id])
      Julep.Bridge.send_window_op(state.bridge, op, window_id, settings)
    end

    state
  end

  defp execute_command(%Julep.Command{type: :image_op, payload: %{op: op} = payload}, state) do
    if state.bridge do
      Julep.Bridge.send_image_op(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(
         %Julep.Command{
           type: :extension_command,
           payload: %{node_id: node_id, op: op, payload: payload}
         },
         state
       ) do
    if state.bridge do
      Julep.Bridge.send_extension_command(state.bridge, node_id, op, payload)
    end

    state
  end

  defp execute_command(
         %Julep.Command{type: :extension_commands, payload: %{commands: commands}},
         state
       ) do
    if state.bridge do
      Julep.Bridge.send_extension_commands(state.bridge, commands)
    end

    state
  end

  defp execute_command(
         %Julep.Command{type: :advance_frame, payload: %{timestamp: timestamp}},
         state
       ) do
    if state.bridge do
      Julep.Bridge.send_advance_frame(state.bridge, timestamp)
    end

    state
  end

  defp execute_command(%Julep.Command{type: :batch, payload: %{commands: cmds}}, state) do
    execute_commands(cmds, state)
  end

  defp execute_command(cmd, state) do
    Logger.warning("julep runtime: unknown command: #{inspect(cmd)}")
    state
  end

  # Kills an existing async task with the given tag, if one is running.
  # Used before starting a replacement task to avoid orphaned processes.
  @spec cancel_existing_task(map(), term()) :: map()
  defp cancel_existing_task(state, tag) do
    case Map.get(state.async_tasks, tag) do
      {old_pid, _nonce} ->
        Process.exit(old_pid, :kill)
        %{state | async_tasks: Map.delete(state.async_tasks, tag)}

      nil ->
        state
    end
  end
end
