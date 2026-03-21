defmodule Plushie.Runtime do
  @moduledoc """
  Core lifecycle GenServer for Plushie applications.

  The runtime is the heartbeat of a Plushie app. It owns the Elm-style
  update loop: event in -> model out -> view out -> snapshot to bridge.

  ## Startup

  On `init/1` the runtime:
    1. Calls `app.init(app_opts)` to get the initial model (and optional commands).
    2. Calls `app.view(model)` to produce the initial UI tree.
    3. Normalizes the tree via `Plushie.Tree.normalize/1`.
    4. Sends a full snapshot to the bridge via `Plushie.Bridge.send_snapshot/2`.
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
        app:                module(),
        model:              term(),
        bridge:             pid() | atom(),
        daemon:             boolean(),
        tree:               map() | nil,
        subscriptions:      %{term() => {:timer, reference()} | {:renderer, atom(), non_neg_integer() | nil}},
        subscription_keys:  [term()],
        windows:            MapSet.t(),
        async_tasks:        %{atom() => {pid(), reference()}},
        pending_effects:    %{String.t() => reference()},
        pending_timers:     %{term() => reference()},
        pending_coalesce:   %{term() => Plushie.Event.t()},
        coalesce_timer:     reference() | nil,
        consecutive_errors: non_neg_integer()
      }

  ## Exit trapping

  The runtime traps exits so a bridge crash does not silently kill it.
  """

  use GenServer

  require Logger

  alias Plushie.Event.{Async, Effect, Mouse, Sensor, Stream, Timer}
  alias Plushie.Runtime.{Commands, Subscriptions, Windows}

  @typep state :: %{
           app: module(),
           model: term(),
           bridge: pid() | atom(),
           daemon: boolean(),
           tree: map() | nil,
           subscriptions: %{
             term() => {:timer, reference()} | {:renderer, atom(), non_neg_integer() | nil}
           },
           subscription_keys: [term()],
           windows: MapSet.t(),
           async_tasks: %{atom() => {pid(), reference()}},
           pending_effects: %{String.t() => reference()},
           pending_timers: %{term() => reference()},
           pending_coalesce: %{term() => Plushie.Event.t()},
           coalesce_timer: reference() | nil,
           consecutive_errors: non_neg_integer()
         }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the runtime linked to the calling process.

  Required opts:
    - `:app`    - module implementing `Plushie.App`
    - `:bridge` - pid or registered name of the `Plushie.Bridge` GenServer

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
    daemon? = Keyword.get(opts, :daemon, false)

    # App opts can be passed explicitly via :app_opts, or as remaining keys.
    app_opts =
      Keyword.get(opts, :app_opts, Keyword.drop(opts, [:app, :bridge, :name, :daemon, :app_opts]))

    # 1. Initialize app model.
    case safe_init(app, app_opts) do
      {:ok, model, commands} ->
        state = %{
          app: app,
          model: model,
          bridge: bridge,
          daemon: daemon?,
          tree: nil,
          init_commands: commands,
          subscriptions: %{},
          subscription_keys: [],
          windows: MapSet.new(),
          async_tasks: %{},
          pending_effects: %{},
          pending_timers: %{},
          pending_coalesce: %{},
          coalesce_timer: nil,
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
    state = Commands.execute_commands(Map.get(state, :init_commands, []), state)
    state = Map.delete(state, :init_commands)
    state = Subscriptions.sync_subscriptions(state, state.model)
    state = Windows.sync_windows(state, tree)
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

  def handle_info({:renderer_event, {:hello, hello}}, state) do
    Logger.info(
      "plushie runtime: renderer connected -- #{hello.name} v#{hello.version} (#{hello.backend}, #{hello.transport})"
    )

    {:noreply, state}
  end

  def handle_info(
        {:renderer_event, %Plushie.Event.System{type: :all_windows_closed} = event},
        %{daemon: false} = state
      ) do
    # Non-daemon mode: dispatch through update/2 so the app can perform
    # cleanup (save drafts, persist state, etc.), then shut down. Commands
    # from update are executed synchronously; async tasks may not complete
    # since the process is stopping.
    state = run_update(state, event)
    {:stop, :normal, state}
  end

  # Coalescable events -- high-frequency events (mouse moves, sensor resizes)
  # are stored and deferred until the next message boundary. A zero-delay timer
  # ensures they flush before the GenServer processes non-coalescable messages,
  # while consecutive coalescable events for the same source collapse into the
  # latest value. This preserves ordering relative to other event types (a
  # non-coalescable event always flushes pending coalescables first) and avoids
  # redundant update cycles during bursts.
  def handle_info({:renderer_event, %Mouse{type: :moved} = event}, state) do
    {:noreply, store_coalescable(state, :mouse_move, event)}
  end

  def handle_info({:renderer_event, %Sensor{type: :resize} = event}, state) do
    {:noreply, store_coalescable(state, {:sensor_resize, event.id}, event)}
  end

  def handle_info({:renderer_event, event}, state) do
    state = flush_coalescables(state)
    state = run_update(state, event)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Renderer lifecycle
  # ---------------------------------------------------------------------------

  def handle_info({:renderer_exit, :normal}, state) do
    # Clean exit (renderer process ended). Shut down the runtime.
    Logger.info("plushie runtime: renderer exited normally -- shutting down")
    {:stop, :normal, state}
  end

  def handle_info({:renderer_exit, reason}, state) do
    Logger.warning("plushie runtime: renderer exited: #{inspect(reason)}")

    new_model =
      try do
        state.app.handle_renderer_exit(state.model, reason)
      rescue
        e ->
          Logger.error("""
          plushie runtime: handle_renderer_exit raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

          state.model
      end

    {:noreply, %{state | model: new_model}}
  end

  def handle_info(:renderer_restarted, state) do
    Logger.info("plushie runtime: renderer restarted -- re-sending settings and snapshot")

    # Discard stale coalescable events from the old renderer.
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)
    state = %{state | pending_coalesce: %{}, coalesce_timer: nil}

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
      notify_bridge(state, &Plushie.Bridge.send_snapshot(&1, tree))
    end

    # Re-sync subscriptions with the new renderer.
    state = Subscriptions.sync_subscriptions(state, state.model)

    # Re-open all known windows with merged per-window props from the tree.
    # Reset tracked windows first so sync_windows sees them all as new.
    state = %{state | tree: tree, windows: MapSet.new()}
    state = Windows.sync_windows(state, tree)

    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Coalescable event flush
  # ---------------------------------------------------------------------------

  def handle_info(:flush_coalescables, state) do
    {:noreply, flush_coalescables(%{state | coalesce_timer: nil})}
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
        :telemetry.execute([:plushie, :runtime, :effect_timeout], %{count: 1}, %{id: id})
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
      state = %{state | async_tasks: Map.delete(state.async_tasks, tag)}

      if reason != :normal do
        Logger.warning("plushie runtime: async task #{inspect(tag)} crashed: #{inspect(reason)}")

        state = run_update(state, %Async{tag: tag, result: {:error, {:crashed, reason}}})
        {:noreply, state}
      else
        {:noreply, state}
      end
    else
      Logger.warning("plushie runtime: linked process #{inspect(pid)} exited: #{inspect(reason)}")
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
    Logger.info("plushie runtime: force re-render (code reload)")
    new_tree = render_and_sync(state.app, state.model, state.bridge, state.tree)
    state = %{state | tree: new_tree}
    state = Subscriptions.sync_subscriptions(state, state.model)
    state = Windows.sync_windows(state, new_tree)
    {:noreply, state}
  end

  # Ignore anything else -- stray messages, etc.
  def handle_info(msg, state) do
    Logger.warning("plushie runtime: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel coalesce timer if pending.
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

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

  # Send to the active bridge. In a future multi-renderer mode, this will
  # fan out to all connected bridges. Commands.ex, subscriptions.ex, and
  # windows.ex still access state.bridge directly -- they'll be updated
  # when multi-renderer support is actually needed.
  defp notify_bridge(%{bridge: nil}, _fun), do: :ok
  defp notify_bridge(%{bridge: bridge}, fun), do: fun.(bridge)

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

    extension_config = Application.get_env(:plushie, :extension_config, %{})

    settings =
      if extension_config != %{} do
        Map.put(settings, :extension_config, extension_config)
      else
        settings
      end

    notify_bridge(%{bridge: bridge}, &Plushie.Bridge.send_settings(&1, settings))
  end

  # Unwraps `app.init/1` or `app.update/2` return values into a
  # `{model, commands}` tuple. Commands are always a flat list of
  # `%Plushie.Command{}` structs.
  #
  # Raises on structurally invalid returns (e.g. `{model, :not_a_command}`)
  # so the error surfaces immediately rather than silently corrupting
  # the model.
  @spec unwrap_result(term()) :: {term(), [Plushie.Command.t()]}
  defp unwrap_result({model, commands}) when is_list(commands) do
    Enum.each(commands, fn
      %Plushie.Command{} ->
        :ok

      invalid ->
        raise ArgumentError,
              "init/1 or update/2 returned {model, commands} but the command " <>
                "list contains #{inspect(invalid)}, expected %Plushie.Command{}"
    end)

    {model, commands}
  end

  defp unwrap_result({model, %Plushie.Command{} = cmd}) do
    {model, [cmd]}
  end

  defp unwrap_result({_model, invalid}) do
    raise ArgumentError,
          "init/1 or update/2 returned {model, commands} but commands is " <>
            "#{inspect(invalid)}, expected a %Plushie.Command{} or a list of them"
  end

  defp unwrap_result(model) when is_tuple(model) do
    raise ArgumentError,
          "init/1 or update/2 returned a #{tuple_size(model)}-element tuple, " <>
            "expected a bare model or {model, command}"
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
          notify_bridge(%{bridge: bridge}, &Plushie.Bridge.send_snapshot(&1, new_tree))
        else
          # Incremental update -- diff produces an empty list for identical
          # trees, so the previous O(n) equality pre-check is unnecessary.
          ops = Plushie.Tree.diff(old_tree, new_tree)

          if ops != [] do
            notify_bridge(%{bridge: bridge}, &Plushie.Bridge.send_patch(&1, ops))
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
      plushie runtime: app.init/1 raised: #{Exception.message(e)}
      #{Exception.format_stacktrace(__STACKTRACE__)}
      """)

      {:error, {:init_crashed, e}}
  end

  defp safe_view(app, model) do
    raw_tree =
      :telemetry.span([:plushie, :view], %{app: app}, fn ->
        {app.view(model), %{}}
      end)

    {:ok, Plushie.Tree.normalize(raw_tree)}
  rescue
    e ->
      :telemetry.execute([:plushie, :runtime, :view_error], %{count: 1}, %{app: app})

      Logger.error("""
      plushie runtime: view/1 raised: #{Exception.message(e)}
      #{Exception.format_stacktrace(__STACKTRACE__)}
      """)

      :error
  end

  # Full update cycle: update -> commands -> view -> diff -> patch.
  #
  # Note on sequencing: commands execute BEFORE view/1 is called. This means
  # a fast async completion would queue its result for the NEXT cycle, not
  # the current one. This is intentional -- commands are side effects that
  # happen between the model update and the re-render. Their results arrive
  # as separate events in subsequent cycles.
  #
  # Wraps update/2 and view/1 in try/rescue so app exceptions do not crash
  # the runtime process.
  @spec run_update(state(), term()) :: state()
  defp run_update(%{app: app, model: model, bridge: bridge} = state, event) do
    case safe_update(app, model, event, state.consecutive_errors) do
      {:ok, new_model, commands} ->
        state = %{state | model: new_model, consecutive_errors: 0}
        state = Commands.execute_commands(commands, state)
        new_tree = render_and_sync(app, new_model, bridge, state.tree)
        state = %{state | tree: new_tree}
        state = Subscriptions.sync_subscriptions(state, new_model)
        Windows.sync_windows(state, new_tree)

      :error ->
        %{state | consecutive_errors: state.consecutive_errors + 1}
    end
  end

  defp safe_update(app, model, event, consecutive_errors) do
    {new_model, commands} =
      :telemetry.span([:plushie, :update], %{app: app, event: event}, fn ->
        {unwrap_result(app.update(model, event)), %{}}
      end)

    {:ok, new_model, commands}
  rescue
    e ->
      :telemetry.execute([:plushie, :runtime, :update_error], %{count: 1}, %{
        app: app,
        event: event
      })

      # Rate-limit logging: normal up to 10, debug up to 100, suppress with
      # periodic reminders every 1000 errors thereafter. Note: consecutive_errors
      # is the pre-increment count (before this error), so thresholds are offset
      # by one (e.g., < 9 means the first 10 errors log at :error level).
      count = consecutive_errors + 1

      cond do
        count <= 10 ->
          Logger.error("""
          plushie runtime: update/2 raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

        count <= 100 ->
          Logger.debug("""
          plushie runtime: update/2 raised (repeated): #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

        count == 101 ->
          Logger.warning(
            "plushie runtime: 100 consecutive update errors -- suppressing further logs"
          )

        rem(count, 1000) == 0 ->
          Logger.warning("plushie runtime: #{count} consecutive errors")

        true ->
          :ok
      end

      :error
  end

  # ---------------------------------------------------------------------------
  # Effect request tracking
  # ---------------------------------------------------------------------------

  # Cancels the timeout timer for a resolved effect request.
  @spec cancel_pending_effect(state(), String.t()) :: state()
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
  @spec flush_pending_effects(state(), atom()) :: state()
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

  # ---------------------------------------------------------------------------
  # Coalescable event helpers
  # ---------------------------------------------------------------------------

  # Stores a high-frequency event for deferred processing. A zero-delay timer
  # ensures the flush fires at the next message boundary -- consecutive
  # coalescable events for the same key overwrite each other so only the
  # latest survives.
  @spec store_coalescable(state(), term(), Plushie.Event.t()) :: state()
  defp store_coalescable(state, key, event) do
    state =
      if state.coalesce_timer == nil do
        ref = Process.send_after(self(), :flush_coalescables, 0)
        %{state | coalesce_timer: ref}
      else
        state
      end

    %{state | pending_coalesce: Map.put(state.pending_coalesce, key, event)}
  end

  @spec flush_coalescables(state()) :: state()
  defp flush_coalescables(%{pending_coalesce: pending} = state)
       when map_size(pending) == 0 do
    state
  end

  defp flush_coalescables(state) do
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

    state =
      Enum.reduce(state.pending_coalesce, state, fn {_key, event}, acc ->
        run_update(acc, event)
      end)

    %{state | pending_coalesce: %{}, coalesce_timer: nil}
  end
end
