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
        consecutive_errors: non_neg_integer(),
        pending_interact:   {GenServer.from(), String.t()} | nil
      }

  ## Exit trapping

  The runtime traps exits so a bridge crash does not silently kill it.
  """

  use GenServer

  require Logger

  alias Plushie.Event.{Async, Effect, Mouse, Sensor, Stream, Timer}
  alias Plushie.Runtime.{Commands, Subscriptions, Windows}

  @enforce_keys [:app, :bridge]
  defstruct app: nil,
            model: nil,
            bridge: nil,
            daemon: false,
            token: nil,
            tree: nil,
            init_commands: [],
            subscriptions: %{},
            subscription_keys: [],
            windows: MapSet.new(),
            async_tasks: %{},
            pending_effects: %{},
            pending_timers: %{},
            pending_coalesce: %{},
            coalesce_timer: nil,
            consecutive_errors: 0,
            canvas_widgets: %{},
            pending_interact: nil,
            pending_await_async: %{}

  @typep state :: %__MODULE__{
           app: module(),
           model: term(),
           bridge: pid() | atom(),
           daemon: boolean(),
           token: term(),
           tree: map() | nil,
           init_commands: [Plushie.Command.t()],
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
           consecutive_errors: non_neg_integer(),
           canvas_widgets: %{
             String.t() => %{module: module(), state: map()}
           },
           pending_interact: {GenServer.from(), String.t()} | nil,
           pending_await_async: %{atom() => GenServer.from()}
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

  @doc "Returns the current app model synchronously."
  @spec get_model(GenServer.server()) :: term()
  def get_model(runtime) do
    GenServer.call(runtime, :get_model)
  end

  @doc "Returns the current normalized UI tree synchronously."
  @spec get_tree(GenServer.server()) :: map() | nil
  def get_tree(runtime) do
    GenServer.call(runtime, :get_tree)
  end

  @doc """
  Performs a synchronous interact via the renderer.

  Sends an interact request (e.g. click, type_text) to the renderer, which
  processes it against its widget tree and sends back events. The runtime
  processes those events through `update/2` and re-renders. Blocks until
  the renderer signals completion.
  """
  @spec interact(GenServer.server(), String.t(), map(), map(), timeout()) :: :ok
  def interact(runtime, action, selector, payload \\ %{}, timeout \\ 10_000) do
    GenServer.call(runtime, {:interact, action, selector, payload}, timeout)
  end

  @doc """
  Waits for an async task with the given tag to complete.

  If the task has already completed, returns immediately. Otherwise
  blocks until the task finishes and its result has been processed
  through update/2.
  """
  @spec await_async(GenServer.server(), atom(), timeout()) :: :ok
  def await_async(runtime, tag, timeout \\ 5000) do
    GenServer.call(runtime, {:await_async, tag}, timeout)
  end

  @doc "Finds a node in the current tree by ID."
  @spec find_node(GenServer.server(), String.t()) :: map() | nil
  def find_node(runtime, id) do
    GenServer.call(runtime, {:find_node, id})
  end

  @doc "Finds a node in the current tree using a predicate function."
  @spec find_node_by(GenServer.server(), (map() -> boolean())) :: map() | nil
  def find_node_by(runtime, fun) do
    GenServer.call(runtime, {:find_node_by, fun})
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
    token = Keyword.get(opts, :token)

    # App opts can be passed explicitly via :app_opts, or as remaining keys.
    app_opts =
      Keyword.get(
        opts,
        :app_opts,
        Keyword.drop(opts, [:app, :bridge, :name, :daemon, :token, :app_opts])
      )

    # 1. Initialize app model.
    case safe_init(app, app_opts) do
      {:ok, model, commands} ->
        state = %__MODULE__{
          app: app,
          model: model,
          bridge: bridge,
          daemon: daemon?,
          token: token,
          init_commands: commands
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
    send_settings(state)

    # 2-4. Render initial tree and push snapshot (old_tree is nil -> full snapshot).
    tree = render_and_sync(state.app, state.model, state.bridge, nil)

    # 5. Sync canvas_widget registry so widgets are available for
    # event interception from the very first interaction.
    canvas_widgets =
      Plushie.Runtime.CanvasWidgets.derive_registry(tree)

    # 6. Execute initial commands.
    state = %{state | tree: tree, canvas_widgets: canvas_widgets}
    state = Commands.execute_commands(state.init_commands, state)
    state = %{state | init_commands: []}
    state = Subscriptions.sync_subscriptions(state, state.model)
    state = Windows.sync_windows(state, tree)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Synchronous queries
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call(:get_model, _from, state) do
    {:reply, state.model, state}
  end

  def handle_call(:get_tree, _from, state) do
    {:reply, state.tree, state}
  end

  def handle_call({:find_node, id}, _from, state) do
    {:reply, Plushie.Tree.find(state.tree, id), state}
  end

  def handle_call({:find_node_by, fun}, _from, state) do
    result = Plushie.Tree.find_all(state.tree, fun) |> List.first()
    {:reply, result, state}
  end

  def handle_call({:interact, action, selector, payload}, from, state) do
    id = "interact_#{:erlang.unique_integer([:positive])}"
    Plushie.Bridge.send_interact(state.bridge, id, action, selector, payload)
    {:noreply, %{state | pending_interact: {from, id}}}
  end

  def handle_call({:await_async, tag}, from, state) do
    if Map.has_key?(state.async_tasks, tag) do
      # Task still running -- store caller and reply when it completes.
      pending = Map.put(state.pending_await_async, tag, from)
      {:noreply, %{state | pending_await_async: pending}}
    else
      # Task already completed (or never existed).
      {:reply, :ok, state}
    end
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

  # Interact protocol: the renderer sends intermediate event batches during
  # an interact request. All events in a step came from one atomic iced event
  # and the renderer expects exactly one snapshot back.
  def handle_info({:renderer_event, {:interact_step, _id, events}}, state) do
    state = flush_coalescables(state)
    state = run_interact_step(state, events)
    {:noreply, state}
  end

  def handle_info({:renderer_event, {:interact_response, id, events}}, state) do
    state = flush_coalescables(state)

    # Process any final events from the response. Each event gets a
    # full update cycle (intercept + update + re-render).
    state =
      Enum.reduce(events, state, fn event_map, acc ->
        case decode_interact_event(event_map) do
          nil -> acc
          event -> run_update(acc, event)
        end
      end)

    # Reply to the blocked caller.
    case state.pending_interact do
      {from, ^id} ->
        GenServer.reply(from, :ok)
        {:noreply, %{state | pending_interact: nil}}

      _ ->
        {:noreply, state}
    end
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
    send_settings(state)

    # Re-run view/1 to get a fresh tree rather than relying on a stale cache.
    # Pass canvas_widget states so widgets render with current internal state.
    tree =
      case safe_view(state.app, state.model, state.canvas_widgets) do
        {:ok, new_tree} -> new_tree
        :error -> state.tree
      end

    if tree do
      notify_bridge(state, &Plushie.Bridge.send_snapshot(&1, tree))
    end

    canvas_widgets = Plushie.Runtime.CanvasWidgets.derive_registry(tree)

    # Re-sync subscriptions with the new renderer.
    state = Subscriptions.sync_subscriptions(state, state.model)

    # Re-open all known windows with merged per-window props from the tree.
    # Reset tracked windows first so sync_windows sees them all as new.
    state = %{state | tree: tree, canvas_widgets: canvas_widgets, windows: MapSet.new()}
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
      state = notify_await_async(state, tag)

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

      # Route canvas_widget timer ticks to the widget's handle_event
      # instead of the app's update/2. Timer-triggered emits are
      # dispatched through the scope chain of parent canvas_widgets.
      case Plushie.Runtime.CanvasWidgets.maybe_handle_timer(state.canvas_widgets, tag) do
        {:handled, nil, new_registry} ->
          # Widget captured the timer (state update, re-render only).
          state = %{state | canvas_widgets: new_registry}

          new_tree =
            render_and_sync(
              state.app,
              state.model,
              state.bridge,
              state.tree,
              state.canvas_widgets
            )

          canvas_widgets =
            Plushie.Runtime.CanvasWidgets.derive_registry(new_tree)

          {:noreply, %{state | tree: new_tree, canvas_widgets: canvas_widgets}}

        {:handled, emitted_event, new_registry} ->
          # Widget emitted an event (possibly dispatched through
          # parent canvas_widgets). Deliver to app's update/2.
          state = %{state | canvas_widgets: new_registry}
          state = run_update(state, emitted_event)
          {:noreply, state}

        :not_routed ->
          # Standard app timer -- dispatch to update/2.
          now = System.monotonic_time(:millisecond)
          state = run_update(state, %Timer{tag: tag, timestamp: now})
          {:noreply, state}
      end
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

    new_tree =
      render_and_sync(state.app, state.model, state.bridge, state.tree, state.canvas_widgets)

    canvas_widgets =
      Plushie.Runtime.CanvasWidgets.derive_registry(new_tree)

    state = %{state | tree: new_tree, canvas_widgets: canvas_widgets}
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
  defp send_settings(state) do
    settings =
      if function_exported?(state.app, :settings, 0) do
        case state.app.settings() do
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

    # Include token if one was provided (for --listen socket auth).
    settings =
      if state.token do
        Map.put(settings, :token, state.token)
      else
        settings
      end

    notify_bridge(state, &Plushie.Bridge.send_settings(&1, settings))
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
  # Canvas widget state is injected during normalization (inside safe_view).
  # If view/1 raises, returns old_tree unchanged.
  @spec render_and_sync(module(), term(), pid() | atom(), map() | nil, map()) :: map() | nil
  defp render_and_sync(app, model, bridge, old_tree, canvas_widgets \\ %{}) do
    case safe_view(app, model, canvas_widgets) do
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

  # Renders the view and normalizes the tree. Canvas widget stored state
  # is injected during normalization via the process dictionary -- the
  # normalizer detects canvas_widget nodes and re-renders them with
  # stored state before normalizing the output. This eliminates the need
  # for post-processing (the old apply_canvas_widget_state approach).
  @spec safe_view(module(), term(), map()) :: {:ok, map()} | :error
  defp safe_view(app, model, canvas_widget_states) do
    # Stash widget states for Tree.normalize to pick up during the
    # normalization pass. Cleaned up in the after block.
    if canvas_widget_states != %{} do
      Process.put(:__plushie_canvas_widget_states__, canvas_widget_states)
    end

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
  after
    Process.delete(:__plushie_canvas_widget_states__)
  end

  # ---------------------------------------------------------------------------
  # Event pipeline
  #
  # Every inbound event flows through two stages:
  #
  # 1. **Dispatch through canvas_widgets**: walk the scope chain of
  #    canvas_widget handlers (innermost to outermost) following iced's
  #    captured/ignored model. Returns the (possibly transformed) event
  #    to deliver, or nil if captured with no output.
  #
  # 2. **App update**: model update via app.update/2, command execution,
  #    and optionally re-rendering + tree sync.
  #
  # Two app update modes:
  # - `run_update`: full cycle (update + commands + view + diff + patch).
  #   Used by the normal event loop and interact_response.
  # - `apply_event`: update + commands only, no re-render. Used by
  #   interact_step where events are batched and a single snapshot
  #   is sent after all events are processed.
  # ---------------------------------------------------------------------------

  # Dispatch an event through the canvas_widget handler chain. Returns
  # `{event_or_nil, updated_state}` where event_or_nil is the event
  # to deliver to app.update/2 (nil if captured by a widget).
  @spec route_through_widgets(state(), term()) :: {term() | nil, state()}
  defp route_through_widgets(state, event) do
    {result_event, new_registry} =
      Plushie.Runtime.CanvasWidgets.dispatch_event(state.canvas_widgets, event)

    {result_event, %{state | canvas_widgets: new_registry}}
  end

  # Full update cycle: intercept -> update -> commands -> view -> diff -> patch.
  #
  # Note on sequencing: commands execute BEFORE view/1 is called. This means
  # a fast async completion would queue its result for the NEXT cycle, not
  # the current one. This is intentional -- commands are side effects that
  # happen between the model update and the re-render. Their results arrive
  # as separate events in subsequent cycles.
  @spec run_update(state(), term()) :: state()
  defp run_update(state, event) do
    {resolved_event, state} = route_through_widgets(state, event)

    if is_nil(resolved_event) do
      state
    else
      dispatch_update(state, resolved_event)
    end
  end

  # Update + commands + re-render (the core dispatch path).
  @spec dispatch_update(state(), term()) :: state()
  defp dispatch_update(%{app: app, model: model, bridge: bridge} = state, event) do
    case safe_update(app, model, event, state.consecutive_errors) do
      {:ok, new_model, commands} ->
        state = %{state | model: new_model, consecutive_errors: 0}
        state = Commands.execute_commands(commands, state)
        new_tree = render_and_sync(app, new_model, bridge, state.tree, state.canvas_widgets)
        state = %{state | tree: new_tree}

        canvas_widgets =
          Plushie.Runtime.CanvasWidgets.derive_registry(new_tree)

        state = %{state | canvas_widgets: canvas_widgets}

        widget_subs =
          Plushie.Runtime.CanvasWidgets.collect_subscriptions(canvas_widgets)

        state = Subscriptions.sync_subscriptions(state, new_model, widget_subs)
        Windows.sync_windows(state, new_tree)

      :error ->
        %{state | consecutive_errors: state.consecutive_errors + 1}
    end
  end

  # Intercept + update + commands, no re-render. Used by interact_step
  # where events are batched and a single snapshot follows.
  @spec apply_event(state(), term()) :: state()
  defp apply_event(state, event) do
    {resolved_event, state} = route_through_widgets(state, event)

    if is_nil(resolved_event) do
      state
    else
      case safe_update(state.app, state.model, resolved_event, state.consecutive_errors) do
        {:ok, new_model, commands} ->
          state = %{state | model: new_model, consecutive_errors: 0}
          Commands.execute_commands(commands, state)

        :error ->
          %{state | consecutive_errors: state.consecutive_errors + 1}
      end
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
  # Interact protocol helpers
  # ---------------------------------------------------------------------------

  # Processes an interact_step batch: decode each event, run through update/2
  # without sending intermediate patches, then send a single full snapshot.
  # The renderer expects exactly one snapshot per interact_step.
  defp run_interact_step(state, events) do
    state =
      Enum.reduce(events, state, fn event_map, acc ->
        case decode_interact_event(event_map) do
          nil -> acc
          event -> apply_event(acc, event)
        end
      end)

    # Re-render and send a full snapshot (not a patch).
    # Pass canvas_widget states so normalization injects stored state.
    case safe_view(state.app, state.model, state.canvas_widgets) do
      {:ok, new_tree} ->
        notify_bridge(state, &Plushie.Bridge.send_snapshot(&1, new_tree))

        canvas_widgets =
          Plushie.Runtime.CanvasWidgets.derive_registry(new_tree)

        state = %{state | tree: new_tree, canvas_widgets: canvas_widgets}
        state = Subscriptions.sync_subscriptions(state, state.model)
        Windows.sync_windows(state, new_tree)

      :error ->
        state
    end
  end

  # Decodes a wire-format event map from an interact_step/interact_response
  # into an Elixir event struct. Uses the test backend's EventDecoder which
  # handles the same wire format.
  defp decode_interact_event(%{"family" => family, "id" => id} = event_map) do
    Plushie.Test.Backend.EventDecoder.decode(family, id, event_map)
  end

  defp decode_interact_event(_), do: nil

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

  defp notify_await_async(state, tag) do
    case Map.pop(state.pending_await_async, tag) do
      {nil, _} ->
        state

      {from, remaining} ->
        GenServer.reply(from, :ok)
        %{state | pending_await_async: remaining}
    end
  end
end
