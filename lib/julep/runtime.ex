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
        app:          module,          # the Julep.App implementation
        model:        term(),          # current application model
        bridge:       pid() | atom(),  # Julep.Bridge pid or registered name
        tree:         map() | nil,     # last normalized tree (for re-send on restart)
        async_tasks:  map()            # %{tag => pid} for running async/stream tasks
      }

  ## Exit trapping

  The runtime traps exits so a bridge crash does not silently kill it.
  """

  use GenServer

  require Logger

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
    {model, commands} = unwrap_result(app.init(app_opts))

    state = %{
      app: app,
      model: model,
      bridge: bridge,
      tree: nil,
      init_commands: commands,
      subscriptions: %{},
      windows: MapSet.new(),
      async_tasks: %{}
    }

    # Defer rendering to handle_continue. Bridge is already started (it's
    # the first child in the supervisor tree), so it's safe to cast to it.
    {:ok, state, {:continue, :initial_render}}
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

    # The new renderer process expects Settings as the first message.
    send_settings(state.app, state.bridge)

    # Re-send the last known tree so the renderer can reconstruct its state.
    if state.tree do
      Julep.Bridge.send_snapshot(state.bridge, state.tree)
    end

    # Re-open all known windows (renderer lost its window map on restart).
    Enum.each(state.windows, fn window_id ->
      settings = state.app.window_config(state.model)
      Julep.Bridge.send_window_op(state.bridge, "open", window_id, settings)
    end)

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Async task completions
  # ---------------------------------------------------------------------------

  def handle_info({:async_result, tag, result}, state) do
    # Only remove the task from tracking if the process has exited (i.e. this
    # is the final result, not an intermediate stream emit).
    state =
      case Map.get(state.async_tasks, tag) do
        pid when is_pid(pid) ->
          if Process.alive?(pid) do
            state
          else
            %{state | async_tasks: Map.delete(state.async_tasks, tag)}
          end

        _ ->
          state
      end

    state = run_update(state, {tag, result})
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Timer-driven events
  # ---------------------------------------------------------------------------

  def handle_info({:send_after_event, event}, state) do
    state = run_update(state, event)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Exit trapping -- bridge or linked process crashes
  # ---------------------------------------------------------------------------

  def handle_info({:EXIT, pid, reason}, state) do
    Logger.warning("julep runtime: linked process #{inspect(pid)} exited: #{inspect(reason)}")
    # Don't crash; let the bridge restart machinery handle recovery.
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Subscription ticks
  # ---------------------------------------------------------------------------

  def handle_info({:subscription_tick, tag, interval}, state) do
    # Re-arm the timer
    ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
    state = put_in(state.subscriptions[{:every, interval, tag}], {:timer, ref})

    # Dispatch the event
    now = System.monotonic_time(:millisecond)
    state = run_update(state, {tag, now})
    {:noreply, state}
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
    Logger.debug("julep runtime: unhandled message: #{inspect(msg)}")
    {:noreply, state}
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
        cond do
          # First render or after restart -- send full snapshot.
          is_nil(old_tree) ->
            Julep.Bridge.send_snapshot(bridge, new_tree)

          # Trees identical -- skip send entirely.
          old_tree == new_tree ->
            :noop

          # Incremental update -- diff and send patch.
          true ->
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

  defp safe_view(app, model) do
    raw_tree = app.view(model)
    {:ok, Julep.Tree.normalize(raw_tree)}
  rescue
    e ->
      Logger.error("julep runtime: view/1 raised: #{Exception.message(e)}")
      :error
  end

  # Full update cycle: update model, execute commands, re-render, sync subs.
  # Wraps update/2 and view/1 in try/rescue so app exceptions do not crash
  # the runtime process.
  @spec run_update(map(), term()) :: map()
  defp run_update(%{app: app, model: model, bridge: bridge} = state, event) do
    case safe_update(app, model, event) do
      {:ok, new_model, commands} ->
        state = %{state | model: new_model}
        state = execute_commands(commands, state)
        new_tree = render_and_sync(app, new_model, bridge, state.tree)
        state = %{state | tree: new_tree}
        state = sync_subscriptions(state, new_model)
        sync_windows(state, new_tree)

      :error ->
        # Keep previous model and tree unchanged.
        state
    end
  end

  defp safe_update(app, model, event) do
    {new_model, commands} = unwrap_result(app.update(model, event))
    {:ok, new_model, commands}
  rescue
    e ->
      Logger.error("julep runtime: update/2 raised: #{Exception.message(e)}")
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
    runtime = self()

    {:ok, pid} =
      Task.start_link(fn ->
        result = fun.()
        send(runtime, {:async_result, tag, result})
      end)

    put_in(state.async_tasks[tag], pid)
  end

  defp execute_command(
         %Julep.Command{type: :stream, payload: %{fun: fun, tag: tag}},
         state
       ) do
    runtime = self()
    emit = fn value -> send(runtime, {:async_result, tag, value}) end

    {:ok, pid} =
      Task.start_link(fn ->
        result = fun.(emit)
        send(runtime, {:async_result, tag, result})
      end)

    put_in(state.async_tasks[tag], pid)
  end

  defp execute_command(%Julep.Command{type: :cancel, payload: %{tag: tag}}, state) do
    case Map.get(state.async_tasks, tag) do
      nil ->
        state

      pid ->
        Process.exit(pid, :kill)
        %{state | async_tasks: Map.delete(state.async_tasks, tag)}
    end
  end

  defp execute_command(
         %Julep.Command{type: :send_after, payload: %{delay: delay, event: event}},
         state
       ) do
    Process.send_after(self(), {:send_after_event, event}, delay)
    state
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

    state
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
    new_specs = state.app.subscribe(new_model)
    new_by_key = Map.new(new_specs, fn spec -> {Julep.Subscription.key(spec), spec} end)
    old_keys = Map.keys(state.subscriptions)
    new_keys = Map.keys(new_by_key)

    # Stop removed subscriptions
    to_stop = old_keys -- new_keys

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
    to_start = new_keys -- old_keys

    new_entries =
      Map.new(to_start, fn key ->
        spec = Map.fetch!(new_by_key, key)
        {key, start_subscription(spec, state.bridge)}
      end)

    # Keep existing (unchanged) subscriptions
    kept = Map.take(state.subscriptions, new_keys -- to_start)

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
              :on_event
            ] do
    if bridge do
      Julep.Bridge.send_subscription_register(bridge, Atom.to_string(type), Atom.to_string(tag))
    end

    {:renderer, type}
  end

  # ---------------------------------------------------------------------------
  # Window lifecycle
  # ---------------------------------------------------------------------------

  @spec detect_windows(map() | nil) :: MapSet.t()
  defp detect_windows(nil), do: MapSet.new()

  defp detect_windows(tree) do
    Julep.Tree.find_all(tree, fn node -> node.type == "window" end)
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  # Window setting keys that can be specified as node props on window elements.
  @window_prop_keys ~w(
    width height position min_size max_size maximized fullscreen visible
    resizable closeable minimizable decorations transparent blur level
    exit_on_close_request
  )

  @spec extract_window_props(tree :: map() | nil, window_id :: String.t()) :: map()
  defp extract_window_props(nil, _window_id), do: %{}

  defp extract_window_props(tree, window_id) do
    case Julep.Tree.find_all(tree, fn node ->
           node.type == "window" and node.id == window_id
         end) do
      [%{props: props} | _] when is_map(props) ->
        Map.take(props, @window_prop_keys)

      _ ->
        %{}
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

    %{state | windows: new_windows}
  end
end
