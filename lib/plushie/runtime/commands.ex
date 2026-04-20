defmodule Plushie.Runtime.Commands do
  @moduledoc """
  Command execution engine for the Plushie runtime.

  Handles all `%Plushie.Command{}` types returned by `app.update/2` and
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
  @spec execute_commands([Plushie.Command.t()] | Plushie.Command.t(), map()) :: map()
  def execute_commands(commands, state) when is_list(commands) do
    :telemetry.span([:plushie, :commands], %{count: length(commands)}, fn ->
      {Enum.reduce(commands, state, &execute_command/2), %{}}
    end)
  end

  def execute_commands(%Plushie.Command{} = cmd, state) do
    :telemetry.span([:plushie, :commands], %{count: 1}, fn ->
      {execute_command(cmd, state), %{}}
    end)
  end

  # -- Private command handlers -----------------------------------------------

  @spec execute_command(Plushie.Command.t(), map()) :: map()
  defp execute_command(%Plushie.Command{type: :none}, state), do: state

  defp execute_command(
         %Plushie.Command{type: :dispatch, payload: %{value: value, mapper: mapper}},
         state
       ) do
    try do
      event = mapper.(value)
      send(self(), {:renderer_event, event})
    catch
      kind, reason ->
        Logger.warning(
          "plushie runtime: Command.dispatch mapper #{kind}: " <>
            Exception.format(kind, reason, __STACKTRACE__)
        )
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :task, payload: %{fun: fun, tag: tag}}, state) do
    # Kill any existing task with the same tag before starting a new one.
    state = cancel_existing_task(state, tag)

    runtime = self()
    nonce = make_ref()

    {:ok, pid} =
      start_task(state, fn ->
        result = fun.()
        send(runtime, {:async_result, tag, nonce, result})
      end)

    Process.monitor(pid)
    put_in(state.async_tasks[tag], {pid, nonce})
  end

  defp execute_command(
         %Plushie.Command{type: :stream, payload: %{fun: fun, tag: tag}},
         state
       ) do
    # Kill any existing task with the same tag before starting a new one.
    state = cancel_existing_task(state, tag)

    runtime = self()
    nonce = make_ref()
    emit = fn value -> send(runtime, {:stream_value, tag, nonce, value}) end

    {:ok, pid} =
      start_task(state, fn ->
        result = fun.(emit)
        send(runtime, {:async_result, tag, nonce, result})
      end)

    Process.monitor(pid)
    put_in(state.async_tasks[tag], {pid, nonce})
  end

  defp execute_command(%Plushie.Command{type: :cancel, payload: %{tag: tag}}, state) do
    case Map.get(state.async_tasks, tag) do
      {pid, _nonce} when is_pid(pid) ->
        Process.exit(pid, :kill)
        # Mark as cancelled; the EXIT handler owns entry cleanup.
        %{state | async_tasks: Map.put(state.async_tasks, tag, {pid, :cancelled})}

      _ ->
        state
    end
  end

  defp execute_command(
         %Plushie.Command{type: :send_after, payload: %{delay: delay, event: event}},
         state
       ) do
    # Cancel any existing timer for the same event key to prevent duplicates.
    case Map.get(state.pending_timers, event) do
      nil -> :ok
      {old_ref, _nonce} -> Process.cancel_timer(old_ref)
    end

    # Tag the message with a nonce so the handler can discard stale deliveries.
    # Process.cancel_timer is best-effort: if the old timer already fired and
    # the message is in the mailbox, the nonce lets us distinguish it from the
    # current timer.
    nonce = System.unique_integer([:monotonic])
    ref = Process.send_after(self(), {:send_after_event, event, nonce}, delay)
    pending_timers = Map.put(state.pending_timers, event, {ref, nonce})
    %{state | pending_timers: pending_timers}
  end

  defp execute_command(
         %Plushie.Command{type: :effect, payload: %{id: id, tag: tag, kind: kind, opts: opts}},
         state
       ) do
    # Cancel any existing effect with the same tag (one-per-tag enforcement).
    state = cancel_pending_effect_by_tag(state, tag)

    bridge = state.bridge

    if bridge do
      Plushie.Bridge.send_effect(bridge, id, kind, opts)
    else
      Logger.warning("plushie runtime: effect #{kind} (#{id}) without bridge")
    end

    # Start a timeout timer for this effect request, using a per-effect default
    # if one is configured.
    timeout = Plushie.Effect.default_timeout(kind) || @effect_timeout_ms
    ref = Process.send_after(self(), {:effect_timeout, id}, timeout)
    put_in(state.pending_effects[id], %{tag: tag, kind: kind, timer_ref: ref})
  end

  defp execute_command(
         %Plushie.Command{type: :command, payload: %{id: id, family: family, value: value}},
         state
       ) do
    if state.bridge do
      Plushie.Bridge.send_command(state.bridge, id, family, value)
    end

    state
  end

  defp execute_command(
         %Plushie.Command{type: :commands, payload: %{commands: commands}},
         state
       ) do
    if state.bridge do
      Plushie.Bridge.send_commands(state.bridge, commands)
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :widget_op, payload: %{op: op} = payload}, state) do
    if state.bridge do
      Plushie.Bridge.send_widget_op(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :exit, payload: _payload}, state) do
    Logger.info("plushie runtime: exit command received, stopping")
    send(self(), {:renderer_exit, :normal})
    state
  end

  defp execute_command(
         %Plushie.Command{type: :window_op, payload: %{op: op, window_id: window_id} = payload},
         state
       ) do
    if state.bridge do
      settings = Map.drop(payload, [:op, :window_id])
      Plushie.Bridge.send_window_op(state.bridge, op, window_id, settings)
    end

    state
  end

  defp execute_command(
         %Plushie.Command{
           type: :window_query,
           payload: %{op: op, window_id: window_id} = payload
         },
         state
       ) do
    if state.bridge do
      settings = Map.drop(payload, [:op, :window_id])
      Plushie.Bridge.send_window_op(state.bridge, op, window_id, settings)
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :system_op, payload: %{op: op} = payload}, state) do
    if state.bridge do
      Plushie.Bridge.send_system_op(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(
         %Plushie.Command{type: :system_query, payload: %{op: op} = payload},
         state
       ) do
    if state.bridge do
      Plushie.Bridge.send_system_query(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :image_op, payload: %{op: op} = payload}, state) do
    if state.bridge do
      Plushie.Bridge.send_image_op(state.bridge, op, Map.delete(payload, :op))
    end

    state
  end

  defp execute_command(
         %Plushie.Command{type: :advance_frame, payload: %{timestamp: timestamp}},
         state
       ) do
    if state.bridge do
      Plushie.Bridge.send_advance_frame(state.bridge, timestamp)
    end

    state
  end

  defp execute_command(%Plushie.Command{type: :batch, payload: %{commands: cmds}}, state) do
    execute_commands(cmds, state)
  end

  defp execute_command(cmd, state) do
    Logger.warning("plushie runtime: unknown command: #{inspect(cmd)}")
    state
  end

  # Kills an existing async task with the given tag, if one is running.
  # Used before starting a replacement task to avoid orphaned processes.
  #
  # Uses `:kill` for immediate, guaranteed cancellation. The task process
  # terminates unconditionally regardless of what it's doing. The trade-off
  # is that `:kill` bypasses both normal cleanup logic and trapped exits in
  # the user's async function, so external resources (HTTP connections, DB
  # handles, file descriptors) won't be released gracefully.
  #
  # If cleanup is needed, users should handle it outside the async function
  # (e.g. in update/2 when receiving the cancellation event). Note that
  # trapping exits does NOT help here; `:kill` cannot be trapped.
  #
  # The alternative `:shutdown` signal would allow cleanup via trapped exits,
  # but isn't guaranteed to terminate misbehaving or blocked tasks, which
  # could leave orphaned processes and leak the nonce/tag mapping.
  @spec cancel_existing_task(map(), term()) :: map()
  defp cancel_existing_task(state, tag) do
    case Map.get(state.async_tasks, tag) do
      {old_pid, _nonce} when is_pid(old_pid) ->
        Process.exit(old_pid, :kill)
        # Mark as cancelled; the EXIT handler owns entry cleanup.
        %{state | async_tasks: Map.put(state.async_tasks, tag, {old_pid, :cancelled})}

      _ ->
        state
    end
  end

  # Cancels a pending effect with the given tag (one-per-tag enforcement).
  # Finds the wire ID by scanning pending_effects for the matching tag,
  # cancels its timer, and removes it.
  @spec cancel_pending_effect_by_tag(map(), atom()) :: map()
  defp cancel_pending_effect_by_tag(state, tag) do
    case Enum.find(state.pending_effects, fn {_id, entry} -> entry.tag == tag end) do
      {id, %{timer_ref: ref}} ->
        Process.cancel_timer(ref)
        %{state | pending_effects: Map.delete(state.pending_effects, id)}

      nil ->
        state
    end
  end

  # Starts a task under the Task.Supervisor if available, otherwise
  # falls back to Task.start_link (for tests that start Runtime without
  # the full supervisor tree).
  @spec start_task(map(), (-> any())) :: {:ok, pid()}
  defp start_task(%{task_supervisor: nil}, fun), do: Task.start_link(fun)
  defp start_task(%{task_supervisor: sup}, fun), do: Task.Supervisor.start_child(sup, fun)
end
