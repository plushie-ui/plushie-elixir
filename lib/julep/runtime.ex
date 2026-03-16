defmodule Julep.Runtime do
  @moduledoc """
  Core lifecycle GenServer for Julep applications.

  The runtime is the heartbeat of a Julep app. It owns the Elm-style
  update loop: event in -> model out -> view out -> snapshot to bridge.

  ## Startup

  On `init/1` the runtime:
    1. Calls `app.init(app_opts)` to get the initial model (and optional commands).
    2. Calls `app.view(model)` to produce the initial UI tree.
    3. Normalizes the tree via `Julep.Tree.normalize/1`.
    4. Sends a full snapshot to the bridge via `Julep.Bridge.send_snapshot/2`.
    5. Executes any commands returned from `init/1`.

  ## Event loop

  On every `{:renderer_event, event}`:
    1. Calls `app.update(model, event)`.
    2. Executes returned commands.
    3. Calls `app.view(model)` on the new model.
    4. Diffs against the previous tree; sends a patch if changed, or a
       full snapshot on first render / after renderer restart.

  ## State shape

      %{
        app:             module,          # the Julep.App implementation
        model:           term(),          # current application model
        bridge:          pid() | atom(),  # Julep.Bridge pid or registered name
        tree:            map() | nil,     # last normalized tree (for re-send on restart)
        async_tasks:     map(),           # %{tag => {pid, nonce}} for running async/stream tasks
        pending_effects: map(),           # %{id => timer_ref} for in-flight effect requests
        pending_timers:  map()            # %{event => timer_ref} for send_after dedup/cancel
      }

  ## Exit trapping

  The runtime traps exits so a bridge crash does not silently kill it.
  """

  use GenServer

  require Logger

  alias Julep.Event.{Async, Effect, Stream, Timer}

  @typep state :: %{
           app: module(),
           model: term(),
           bridge: pid() | atom(),
           tree: map() | nil,
           subscriptions: map(),
           windows: MapSet.t(),
           async_tasks: map(),
           pending_effects: map(),
           pending_timers: map(),
           consecutive_errors: non_neg_integer()
         }

  # Default timeout for effect requests (30 seconds).
  @effect_timeout_ms 30_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the runtime linked to the calling process.

  Required opts:
    - `:app`    - module implementing `Julep.App`
    - `:bridge` - pid or registered name of the `Julep.Bridge` GenServer

  Optional opts:
    - `:name` - registration name passed to `GenServer.start_link/3`

  Any other opts are forwarded to `app.init/1` as the app opts keyword list.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Dispatches `event` through `app.update/2`, then re-renders and snapshots.

  Fire-and-forget from the caller's perspective. The runtime processes the
  event asynchronously from its mailbox.
  """
  @spec dispatch(GenServer.server(), term()) :: :ok
  def dispatch(runtime, event) do
    send(runtime, {:renderer_event, event})
    :ok
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    app = Keyword.fetch!(opts, :app)
    bridge = Keyword.fetch!(opts, :bridge)

    # App opts can be passed explicitly via :app_opts, or as remaining keys.
    app_opts = Keyword.get(opts, :app_opts, Keyword.drop(opts, [:app, :bridge, :name, :app_opts]))

    # 1. Initialize app model.
    case safe_init(app, app_opts) do
      {:ok, model, commands} ->
        state = %{
          app: app,
          model: model,
          bridge: bridge,
          tree: nil,
          init_commands: commands,
          subscriptions: %{},
          windows: MapSet.new(),
          async_tasks: %{},
          pending_effects: %{},
          pending_timers: %{},
          consecutive_errors: 0
        }

        # Defer rendering to handle_continue. Bridge is already started (it's
        # the first child in the supervisor tree), so it's safe to cast to it.
        {:ok, state, {:continue, :initial_render}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:initial_render, state) do
    # Send app-level settings to the renderer before the first snapshot.
    send_settings(state.app, state.bridge)

    # 2-4. Render initial tree and push snapshot (old_tree is nil -> full snapshot).
    tree = render_and_sync(state.app, state.model, state.bridge, nil)

    # 5. Execute initial commands.
    state = %{state | tree: tree}
    state = execute_commands(Map.get(state, :init_commands, []), state)
    state = Map.delete(state, :init_commands)
    state = sync_subscriptions(state, state.model)
    state = sync_windows(state, tree)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Renderer events (the main update loop)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:renderer_event, %Effect{request_id: id} = event}, state) do
    state = cancel_pending_effect(state, id)
    state = run_update(state, event)
    {:noreply, state}
  end

  def handle_info({:renderer_event, {:hello, _protocol, version, name}}, state) do
    Logger.info("julep runtime: renderer connected -- #{name} v#{version}")
    {:noreply, state}
  end

  def handle_info({:renderer_event, event}, state) do
    state = run_update(state, event)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Renderer lifecycle
  # ---------------------------------------------------------------------------

  def handle_info({:renderer_exit, :normal}, state) do
    # Clean exit (user closed window). Shut down the runtime.
    Logger.info("julep runtime: renderer exited normally -- shutting down")
    {:stop, :normal, state}
  end

  def handle_info({:renderer_exit, reason}, state) do
    Logger.warning("julep runtime: renderer exited: #{inspect(reason)}")

    model = state.app.handle_renderer_exit(state.model, reason)
    {:noreply, %{state | model: model}}
  end

  def handle_info(:renderer_restarted, state) do
    Logger.info("julep runtime: renderer restarted -- re-sending settings and snapshot")

    # Flush all pending effect requests -- the renderer that would have
    # responded is gone.
    state = flush_pending_effects(state, :renderer_restarted)

    # The new renderer process expects Settings as the first message.
    send_settings(state.app, state.bridge)

    # Re-run view/1 to get a fresh tree rather than relying on a stale cache.
    tree =
      case safe_view(state.app, state.model) do
        {:ok, new_tree} -> new_tree
        :error -> state.tree
      end

    if tree do
      Julep.Bridge.send_snapshot(state.bridge, tree)
    end

    # Re-sync subscriptions with the new renderer.
    state = sync_subscriptions(state, state.model)

    # Re-open all known windows (renderer lost its window map on restart).
    Enum.each(state.windows, fn window_id ->
      settings = state.app.window_config(state.model)
      Julep.Bridge.send_window_op(state.bridge, "open", window_id, settings)
    end)

    {:noreply, %{state | tree: tree}}
  end

  # ---------------------------------------------------------------------------
  # Async task completions
  # ---------------------------------------------------------------------------

  def handle_info({:async_result, tag, nonce, result}, state) do
    case Map.get(state.async_tasks, tag) do
      {_pid, ^nonce} ->
        # Nonce matches -- this is from the current task.
        state = run_update(state, %Async{tag: tag, result: result})
        {:noreply, state}

      _ ->
        # Stale or unknown -- discard.
        {:noreply, state}
    end
  end

  def handle_info({:stream_value, tag, nonce, value}, state) do
    case Map.get(state.async_tasks, tag) do
      {_pid, ^nonce} ->
        # Nonce matches -- this is from the current stream task.
        state = run_update(state, %Stream{tag: tag, value: value})
        {:noreply, state}

      _ ->
        # Stale or unknown -- discard.
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Safety net -- monitors are no longer placed on async tasks, but handle
    # gracefully in case external code monitors something linked to us.
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Timer-driven events
  # ---------------------------------------------------------------------------

  def handle_info({:send_after_event, event}, state) do
    state = %{state | pending_timers: Map.delete(state.pending_timers, event)}
    state = run_update(state, event)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Effect request timeouts
  # ---------------------------------------------------------------------------

  def handle_info({:effect_timeout, id}, state) do
    case Map.pop(state.pending_effects, id) do
      {nil, _} ->
        # Already resolved or flushed -- ignore.
        {:noreply, state}

      {_timer_ref, pending_effects} ->
        :telemetry.execute([:julep, :runtime, :effect_timeout], %{count: 1}, %{id: id})
        state = %{state | pending_effects: pending_effects}
        state = run_update(state, %Effect{request_id: id, result: {:error, :timeout}})
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Exit trapping -- bridge or linked process crashes
  # ---------------------------------------------------------------------------

  def handle_info({:EXIT, pid, reason}, state) do
    # Clean up async_tasks entry if this was an async task process.
    tag =
      Enum.find_value(state.async_tasks, fn
        {tag, {^pid, _nonce}} -> tag
        _ -> nil
      end)

    if tag do
      {:noreply, %{state | async_tasks: Map.delete(state.async_tasks, tag)}}
    else
      Logger.warning("julep runtime: linked process #{inspect(pid)} exited: #{inspect(reason)}")
      {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Subscription ticks
  # ---------------------------------------------------------------------------

  def handle_info({:subscription_tick, tag, interval}, state) do
    key = {:every, interval, tag}

    if Map.has_key?(state.subscriptions, key) do
      # Drain any queued ticks for the same key to coalesce frames.
      drain_matching_ticks(tag, interval)

      # Re-arm the timer.
      ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
      state = put_in(state.subscriptions[key], {:timer, ref})

      # Dispatch the event.
      now = System.monotonic_time(:millisecond)
      state = run_update(state, %Timer{tag: tag, timestamp: now})
      {:noreply, state}
    else
      # Subscription was cancelled -- discard stale tick.
      {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Dev-mode live reload
  # ---------------------------------------------------------------------------

  def handle_info(:force_rerender, state) do
    Logger.info("julep runtime: force re-render (code reload)")
    new_tree = render_and_sync(state.app, state.model, state.bridge, state.tree)
    state = %{state | tree: new_tree}
    state = sync_subscriptions(state, state.model)
    state = sync_windows(state, new_tree)
    {:noreply, state}
  end

  # Ignore anything else -- stray messages, etc.
  def handle_info(msg, state) do
    Logger.warning("julep runtime: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel all pending send_after timers so they don't fire into the void.
    Enum.each(state.pending_timers, fn {_event, ref} ->
      Process.cancel_timer(ref)
    end)

    # Cancel subscription timers.
    Enum.each(state.subscriptions, fn
      {_key, {:timer, ref}} -> Process.cancel_timer(ref)
      _ -> :ok
    end)

    # Cancel effect timeout timers.
    Enum.each(state.pending_effects, fn {_id, ref} ->
      Process.cancel_timer(ref)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Sends app-level settings to the bridge. The renderer expects a Settings
  # message as the very first message on stdin (before any snapshot), so this
  # must always send something, even if the app doesn't define settings/0.
  defp send_settings(app, bridge) do
    settings =
      if function_exported?(app, :settings, 0) do
        case app.settings() do
          s when is_list(s) and s != [] -> Map.new(s)
          _ -> %{}
        end
      else
        %{}
      end

    extension_config = Application.get_env(:julep, :extension_config, %{})

    settings =
      if extension_config != %{} do
        Map.put(settings, "extension_config", extension_config)
      else
        settings
      end

    if bridge, do: Julep.Bridge.send_settings(bridge, settings)
  end

  # Unwraps `app.init/1` or `app.update/2` return values into a
  # `{model, commands}` tuple. Commands are always a flat list of
  # `%Julep.Command{}` structs.
  @spec unwrap_result(term()) :: {term(), [Julep.Command.t()]}
  defp unwrap_result({model, commands}) when is_list(commands) do
    {model, commands}
  end

  defp unwrap_result({model, %Julep.Command{} = cmd}) do
    {model, [cmd]}
  end

  defp unwrap_result(model) do
    {model, []}
  end

  # Renders the view and sends either a full snapshot (first render or after
  # restart) or a patch (incremental diff) to the bridge.
  # If view/1 raises, returns old_tree unchanged.
  @spec render_and_sync(module(), term(), pid() | atom(), map() | nil) :: map() | nil
  defp render_and_sync(app, model, bridge, old_tree) do
    case safe_view(app, model) do
      {:ok, new_tree} ->
        if is_nil(old_tree) do
          # First render or after restart -- send full snapshot.
          Julep.Bridge.send_snapshot(bridge, new_tree)
        else
          # Incremental update -- diff produces an empty list for identical
          # trees, so the previous O(n) equality pre-check is unnecessary.
          ops = Julep.Tree.diff(old_tree, new_tree)

          if ops != [] do
            Julep.Bridge.send_patch(bridge, ops)
          end
        end

        new_tree

      :error ->
        # Return old tree unchanged.
        old_tree
    end
  end

  defp safe_init(app, app_opts) do
    {model, commands} = unwrap_result(app.init(app_opts))
    {:ok, model, commands}
  rescue
    e ->
      Logger.error("""
      julep runtime: app.init/1 raised: #{Exception.message(e)}
      #{Exception.format_stacktrace(__STACKTRACE__)}
      """)

      {:error, {:init_crashed, e}}
  end

  defp safe_view(app, model) do
    raw_tree =
      :telemetry.span([:julep, :view], %{app: app}, fn ->
        {app.view(model), %{}}
      end)

    {:ok, Julep.Tree.normalize(raw_tree)}
  rescue
    e ->
      :telemetry.execute([:julep, :runtime, :view_error], %{count: 1}, %{app: app})

      Logger.error("""
      julep runtime: view/1 raised: #{Exception.message(e)}
      #{Exception.format_stacktrace(__STACKTRACE__)}
      """)

      :error
  end

  # Full update cycle: update model, execute commands, re-render, sync subs.
  # Wraps update/2 and view/1 in try/rescue so app exceptions do not crash
  # the runtime process.
  @spec run_update(state(), term()) :: state()
  defp run_update(%{app: app, model: model, bridge: bridge} = state, event) do
    case safe_update(app, model, event, state.consecutive_errors) do
      {:ok, new_model, commands} ->
        state = %{state | model: new_model, consecutive_errors: 0}
        state = execute_commands(commands, state)
        new_tree = render_and_sync(app, new_model, bridge, state.tree)
        state = %{state | tree: new_tree}
        state = sync_subscriptions(state, new_model)
        sync_windows(state, new_tree)

      :error ->
        count = state.consecutive_errors + 1

        if count == 100 do
          Logger.warning(
            "julep runtime: 100 consecutive update errors -- suppressing further logs"
          )
        end

        %{state | consecutive_errors: count}
    end
  end

  defp safe_update(app, model, event, consecutive_errors) do
    {new_model, commands} =
      :telemetry.span([:julep, :update], %{app: app, event: event}, fn ->
        {unwrap_result(app.update(model, event)), %{}}
      end)

    {:ok, new_model, commands}
  rescue
    e ->
      :telemetry.execute([:julep, :runtime, :update_error], %{count: 1}, %{
        app: app,
        event: event
      })

      # Rate-limit logging: normal up to 10, debug up to 100, then suppress.
      cond do
        consecutive_errors < 10 ->
          Logger.error("""
          julep runtime: update/2 raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

        consecutive_errors < 100 ->
          Logger.debug("""
          julep runtime: update/2 raised (repeated): #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

        true ->
          :ok
      end

      :error
  end

  # Executes a list of commands. Batch commands are flattened recursively.
  # State is threaded through so commands can read/write async_tasks and bridge.
  @spec execute_commands([Julep.Command.t()] | Julep.Command.t() | term(), map()) :: map()
  defp execute_commands(commands, state) when is_list(commands) do
    Enum.reduce(commands, state, &execute_command/2)
  end

  defp execute_commands(%Julep.Command{} = cmd, state) do
    execute_command(cmd, state)
  end

  defp execute_commands(_, state), do: state

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
         %Julep.Command{type: :effect_request, payload: %{id: id, kind: kind, opts: opts}},
         state
       ) do
    bridge = state.bridge

    if bridge do
      Julep.Bridge.send_effect_request(bridge, id, kind, opts)
    else
      Logger.warning("julep runtime: effect_request #{kind} (#{id}) without bridge")
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

  defp execute_command(%Julep.Command{type: :widget_op, payload: %{op: op} = payload}, state)
       when op in ["pane_split", "pane_close", "pane_swap", "pane_maximize", "pane_restore"] do
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

  # ---------------------------------------------------------------------------
  # Subscription lifecycle
  # ---------------------------------------------------------------------------

  @spec sync_subscriptions(map(), term()) :: map()
  defp sync_subscriptions(state, new_model) do
    new_specs =
      try do
        state.app.subscribe(new_model)
      rescue
        e ->
          Logger.error("""
          julep runtime: subscribe/1 raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

          []
      end
    new_by_key = Map.new(new_specs, fn spec -> {Julep.Subscription.key(spec), spec} end)
    old_key_set = state.subscriptions |> Map.keys() |> MapSet.new()
    new_key_set = new_by_key |> Map.keys() |> MapSet.new()

    # Stop removed subscriptions
    to_stop = MapSet.difference(old_key_set, new_key_set)

    Enum.each(to_stop, fn key ->
      case Map.get(state.subscriptions, key) do
        {:timer, ref} ->
          Process.cancel_timer(ref)

        {:renderer, type} ->
          if state.bridge do
            Julep.Bridge.send_subscription_unregister(state.bridge, Atom.to_string(type))
          end

        _ ->
          :ok
      end
    end)

    # Start new subscriptions
    to_start = MapSet.difference(new_key_set, old_key_set)

    new_entries =
      Map.new(to_start, fn key ->
        spec = Map.fetch!(new_by_key, key)
        {key, start_subscription(spec, state.bridge)}
      end)

    # Keep existing (unchanged) subscriptions
    kept_keys = MapSet.difference(new_key_set, to_start) |> MapSet.to_list()
    kept = Map.take(state.subscriptions, kept_keys)

    %{state | subscriptions: Map.merge(kept, new_entries)}
  end

  defp start_subscription(%{type: :every, interval: interval, tag: tag}, _bridge) do
    ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
    {:timer, ref}
  end

  defp start_subscription(%{type: type, tag: tag}, bridge)
       when type in [
              :on_key_press,
              :on_key_release,
              :on_window_close,
              :on_window_event,
              :on_window_open,
              :on_window_resize,
              :on_window_focus,
              :on_window_unfocus,
              :on_window_move,
              :on_mouse_move,
              :on_mouse_button,
              :on_mouse_scroll,
              :on_touch,
              :on_ime,
              :on_theme_change,
              :on_animation_frame,
              :on_file_drop,
              :on_event,
              :on_modifiers_changed
            ] do
    if bridge do
      Julep.Bridge.send_subscription_register(bridge, Atom.to_string(type), Atom.to_string(tag))
    end

    {:renderer, type}
  end

  # ---------------------------------------------------------------------------
  # Window lifecycle
  # ---------------------------------------------------------------------------

  # Window nodes are only recognized at root level or as direct children of
  # the root node. This matches the Rust renderer's find_window_nodes / window_ids
  # which also only checks root + direct children. Deeply nested window nodes
  # are not supported and will be ignored by both sides.
  @spec detect_windows(map() | nil) :: MapSet.t()
  defp detect_windows(nil), do: MapSet.new()

  defp detect_windows(%{type: "window", id: id}) do
    MapSet.new([id])
  end

  defp detect_windows(%{children: children}) when is_list(children) do
    children
    |> Enum.filter(fn node -> node.type == "window" end)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp detect_windows(_), do: MapSet.new()

  # Window setting keys that can be specified as node props on window elements.
  @window_prop_keys ~w(
    size width height position min_size max_size maximized fullscreen
    visible resizable closeable minimizable decorations transparent blur level
    exit_on_close_request
  )

  @spec extract_window_props(tree :: map() | nil, window_id :: String.t()) :: map()
  defp extract_window_props(nil, _window_id), do: %{}

  defp extract_window_props(tree, window_id) do
    props =
      case find_window_node(tree, window_id) do
        %{props: props} when is_map(props) ->
          Map.take(props, @window_prop_keys)

        _ ->
          %{}
      end

    decompose_size_tuples(props)
  end

  # Find a window node at root level or as a direct child (matching Rust depth).
  defp find_window_node(%{type: "window", id: id} = node, id), do: node

  defp find_window_node(%{children: children}, window_id) when is_list(children) do
    Enum.find(children, fn node -> node.type == "window" and node.id == window_id end)
  end

  defp find_window_node(_, _), do: nil

  # Decompose size tuples into separate width/height keys that Rust expects.
  # size: {w, h}     -> width: w, height: h  (and remove size key)
  # min_size: {w, h} -> min_size: %{"width" => w, "height" => h}
  # max_size: {w, h} -> max_size: %{"width" => w, "height" => h}
  # Also handles lists (which is what the Encode protocol produces from tuples).
  @spec decompose_size_tuples(map()) :: map()
  defp decompose_size_tuples(props) do
    props
    |> decompose_size()
    |> decompose_nested_size("min_size")
    |> decompose_nested_size("max_size")
  end

  defp decompose_size(props) do
    case Map.get(props, "size") do
      {w, h} ->
        props
        |> Map.delete("size")
        |> Map.put_new("width", w)
        |> Map.put_new("height", h)

      [w, h] ->
        props
        |> Map.delete("size")
        |> Map.put_new("width", w)
        |> Map.put_new("height", h)

      _ ->
        props
    end
  end

  defp decompose_nested_size(props, key) do
    case Map.get(props, key) do
      {w, h} -> Map.put(props, key, %{"width" => w, "height" => h})
      [w, h] -> Map.put(props, key, %{"width" => w, "height" => h})
      _ -> props
    end
  end

  @spec sync_windows(map(), map() | nil) :: map()
  defp sync_windows(state, tree) do
    new_windows = detect_windows(tree)
    current_windows = state.windows

    # Open new windows
    opened = MapSet.difference(new_windows, current_windows)

    Enum.each(opened, fn window_id ->
      base_settings = state.app.window_config(state.model)
      per_window_props = extract_window_props(tree, window_id)
      settings = Map.merge(base_settings, per_window_props)

      if state.bridge do
        Julep.Bridge.send_window_op(state.bridge, "open", window_id, settings)
      end
    end)

    # Close removed windows
    closed = MapSet.difference(current_windows, new_windows)

    Enum.each(closed, fn window_id ->
      if state.bridge do
        Julep.Bridge.send_window_op(state.bridge, "close", window_id)
      end
    end)

    # Diff window props for windows that are still open -- send update ops
    # for any changed props (title, size, position, etc.).
    surviving = MapSet.intersection(current_windows, new_windows)

    Enum.each(surviving, fn window_id ->
      old_props = extract_window_props(state.tree, window_id)
      new_props = extract_window_props(tree, window_id)

      if old_props != new_props and state.bridge do
        Julep.Bridge.send_window_op(state.bridge, "update", window_id, new_props)
      end
    end)

    %{state | windows: new_windows}
  end

  # ---------------------------------------------------------------------------
  # Effect request tracking
  # ---------------------------------------------------------------------------

  # Cancels the timeout timer for a resolved effect request.
  @spec cancel_pending_effect(map(), String.t()) :: map()
  defp cancel_pending_effect(state, id) do
    case Map.pop(state.pending_effects, id) do
      {nil, _} ->
        state

      {timer_ref, pending_effects} ->
        Process.cancel_timer(timer_ref)
        %{state | pending_effects: pending_effects}
    end
  end

  # Flushes all pending effect requests, dispatching error results through
  # update/2 and cancelling their timers.
  @spec flush_pending_effects(map(), atom()) :: map()
  defp flush_pending_effects(state, reason) do
    state =
      Enum.reduce(state.pending_effects, state, fn {id, timer_ref}, acc ->
        # Cancel the timer first to prevent double dispatch (the timeout
        # handler checks pending_effects, but better safe than racy).
        if timer_ref, do: Process.cancel_timer(timer_ref)
        run_update(acc, %Effect{request_id: id, result: {:error, reason}})
      end)

    %{state | pending_effects: %{}}
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

  # Drains queued subscription ticks for the same tag/interval from the
  # mailbox. This coalesces rapid-fire animation or timer ticks so the
  # runtime only processes the latest one, avoiding redundant update cycles.
  @spec drain_matching_ticks(term(), non_neg_integer()) :: :ok
  defp drain_matching_ticks(tag, interval) do
    receive do
      {:subscription_tick, ^tag, ^interval} -> drain_matching_ticks(tag, interval)
    after
      0 -> :ok
    end
  end
end
