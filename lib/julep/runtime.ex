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
        app:    module,          # the Julep.App implementation
        model:  term(),          # current application model
        bridge: pid() | atom(),  # Julep.Bridge pid or registered name
        tree:   map() | nil      # last normalized tree (for re-send on restart)
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

    app    = Keyword.fetch!(opts, :app)
    bridge = Keyword.fetch!(opts, :bridge)

    # App opts can be passed explicitly via :app_opts, or as remaining keys.
    app_opts = Keyword.get(opts, :app_opts, Keyword.drop(opts, [:app, :bridge, :name, :app_opts]))

    # 1. Initialize app model.
    {model, commands} = unwrap_result(app.init(app_opts))

    state = %{app: app, model: model, bridge: bridge, tree: nil, init_commands: commands, subscriptions: %{}}

    # Defer snapshot send to handle_continue so the supervisor can start
    # Bridge before we try to send to it.
    {:ok, state, {:continue, :initial_render}}
  end

  @impl true
  def handle_continue(:initial_render, state) do
    # 2-4. Render initial tree and push snapshot (old_tree is nil -> full snapshot).
    tree = render_and_sync(state.app, state.model, state.bridge, nil)

    # 5. Execute initial commands.
    execute_commands(Map.get(state, :init_commands, []))

    state = %{state | tree: tree} |> Map.delete(:init_commands)
    state = sync_subscriptions(state, state.model)
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
    Logger.info("julep runtime: renderer restarted -- re-sending current snapshot")

    # Re-send the last known tree so the renderer can reconstruct its state.
    if state.tree do
      Julep.Bridge.send_snapshot(state.bridge, state.tree)
    end

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Async task completions
  # ---------------------------------------------------------------------------

  def handle_info({:async_result, tag, result}, state) do
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

  # Ignore anything else -- stray messages, etc.
  def handle_info(msg, state) do
    Logger.debug("julep runtime: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

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
  @spec render_and_sync(module(), term(), pid() | atom(), map() | nil) :: map()
  defp render_and_sync(app, model, bridge, old_tree) do
    raw_tree = app.view(model)
    new_tree = Julep.Tree.normalize(raw_tree)

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
  end

  # Full update cycle: update model, execute commands, re-render, sync subs.
  @spec run_update(map(), term()) :: map()
  defp run_update(%{app: app, model: model, bridge: bridge} = state, event) do
    {new_model, commands} = unwrap_result(app.update(model, event))

    execute_commands(commands)

    new_tree = render_and_sync(app, new_model, bridge, state.tree)

    state = %{state | model: new_model, tree: new_tree}
    sync_subscriptions(state, new_model)
  end

  # Executes a list of commands. Batch commands are flattened recursively.
  @spec execute_commands([Julep.Command.t()]) :: :ok
  defp execute_commands(commands) when is_list(commands) do
    Enum.each(commands, &execute_command/1)
  end

  defp execute_commands(%Julep.Command{} = cmd) do
    execute_command(cmd)
  end

  defp execute_commands(_), do: :ok

  @spec execute_command(Julep.Command.t()) :: :ok
  defp execute_command(%Julep.Command{type: :none}), do: :ok

  defp execute_command(%Julep.Command{type: :async, payload: %{fun: fun, tag: tag}}) do
    runtime = self()

    Task.start(fn ->
      result = fun.()
      send(runtime, {:async_result, tag, result})
    end)

    :ok
  end

  defp execute_command(%Julep.Command{type: :send_after, payload: %{delay: delay, event: event}}) do
    Process.send_after(self(), {:send_after_event, event}, delay)
    :ok
  end

  # Widget ops -- bridge messages. Phase 0: log and skip.
  defp execute_command(%Julep.Command{type: type} = cmd)
       when type in [:focus, :focus_next, :focus_previous, :select_all, :scroll_to] do
    Logger.debug("julep runtime: widget op #{type} stubbed for Phase 0: #{inspect(cmd.payload)}")
    :ok
  end

  # Window commands -- Phase 2. Skip for now.
  defp execute_command(%Julep.Command{type: :close_window} = cmd) do
    Logger.debug("julep runtime: close_window stubbed for Phase 2: #{inspect(cmd.payload)}")
    :ok
  end

  defp execute_command(%Julep.Command{type: :batch, payload: %{commands: cmds}}) do
    execute_commands(cmds)
  end

  defp execute_command(cmd) do
    Logger.warning("julep runtime: unknown command: #{inspect(cmd)}")
    :ok
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
        {:timer, ref} -> Process.cancel_timer(ref)
        _ -> :ok
      end
    end)

    # Start new subscriptions
    to_start = new_keys -- old_keys

    new_entries =
      Map.new(to_start, fn key ->
        spec = Map.fetch!(new_by_key, key)
        {key, start_subscription(spec)}
      end)

    # Keep existing (unchanged) subscriptions
    kept = Map.take(state.subscriptions, new_keys -- to_start)

    %{state | subscriptions: Map.merge(kept, new_entries)}
  end

  defp start_subscription(%{type: :every, interval: interval, tag: tag}) do
    ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
    {:timer, ref}
  end

  defp start_subscription(%{type: type, tag: _tag})
       when type in [:on_key_press, :on_key_release, :on_window_close, :on_window_event] do
    # Renderer-side subscriptions -- Phase 2 will send registration messages to bridge.
    # For now, just track that they're active.
    {:renderer, type}
  end
end
