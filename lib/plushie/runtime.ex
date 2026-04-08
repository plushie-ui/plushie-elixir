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
        pending_effects:    %{String.t() => %{tag: atom(), timer_ref: reference()}},
        pending_timers:     %{term() => {reference(), integer()}},
        pending_coalesce:   %{term() => Plushie.Event.t()},
        pending_coalesce_order: [term()],
        coalesce_timer:     reference() | nil,
        consecutive_errors: non_neg_integer(),
        pending_interact:   {GenServer.from(), String.t(), reference(), reference(), String.t(), map()} | nil
      }

  ## Exit trapping

  The runtime traps exits so a bridge crash does not silently kill it.
  """

  use GenServer

  require Logger

  alias Plushie.Event.{AsyncEvent, EffectEvent, StreamEvent, TimerEvent, WidgetEvent}
  alias Plushie.Runtime.{Commands, Subscriptions, Windows}
  alias Plushie.Tree.NormalizeCtx

  # Fallback ctx for view_error paths where no normalization happened.
  @empty_nctx %NormalizeCtx{scope: "", window_id: nil}

  @enforce_keys [:app, :bridge]
  defstruct app: nil,
            model: nil,
            bridge: nil,
            task_supervisor: nil,
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
            pending_coalesce_order: [],
            coalesce_timer: nil,
            consecutive_errors: 0,
            consecutive_view_errors: 0,
            widget_handlers: %{},
            widget_events: %{},
            pending_stub_acks: %{},
            pending_interact: nil,
            pending_await_async: %{},
            widget_statuses: %{},
            focused_widget_id: nil,
            memo_cache: %{},
            widget_view_cache: %{},
            dev_overlay: nil,
            dev_overlay_timer: nil

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
           pending_effects: %{String.t() => %{tag: atom(), timer_ref: reference()}},
           pending_timers: %{term() => {reference(), integer()}},
           pending_coalesce: %{term() => Plushie.Event.t()},
           pending_coalesce_order: [term()],
           coalesce_timer: reference() | nil,
           consecutive_errors: non_neg_integer(),
           consecutive_view_errors: non_neg_integer(),
           pending_stub_acks: %{String.t() => GenServer.from()},
           widget_handlers: %{
             {String.t() | nil, String.t()} => %{
               module: module(),
               state: map(),
               window_id: String.t() | nil
             }
           },
           widget_events: %{
             {String.t() | nil, String.t()} => %{widget_type: atom(), events: MapSet.t(atom())}
           },
           pending_interact:
             {GenServer.from(), String.t(), reference(), reference(), String.t(), map()} | nil,
           pending_await_async: %{atom() => GenServer.from()},
           widget_statuses: %{String.t() => String.t()},
           focused_widget_id: String.t() | nil,
           memo_cache: map(),
           widget_view_cache: map(),
           dev_overlay: Plushie.Dev.RebuildingOverlay.t() | nil,
           dev_overlay_timer: reference() | nil
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
  Dispatches a message through `app.update/2`, then re-renders.

  Fire-and-forget from the caller's perspective. The runtime processes
  the message asynchronously. Use this to send results from spawned
  processes back to the runtime:

      runtime = self()  # inside update/2, self() is the runtime
      spawn(fn ->
        result = expensive_computation()
        Plushie.Runtime.dispatch(runtime, {:computation_done, result})
      end)

      # In update/2:
      def update(model, {:computation_done, result}), do: ...

  Prefer `Plushie.Command.async/2` for most async work. Use `dispatch/2`
  when you need direct control over the spawned process lifecycle.
  """
  @spec dispatch(GenServer.server(), term()) :: :ok
  def dispatch(runtime, event) do
    send(runtime, {:renderer_event, event})
    :ok
  end

  @doc """
  Waits for the runtime to finish processing all pending messages.

  Returns `:ok` once the runtime is idle, or `{:ok, :view_error}` if
  the most recent view/1 call failed. In the view error case, the model
  has been updated but the tree is stale (showing the last successful
  render). Use this to synchronize after dispatching events or starting
  the runtime, ensuring init/update cycles have completed before
  inspecting state.
  """
  @spec sync(runtime :: GenServer.server()) :: :ok | {:ok, :view_error}
  def sync(runtime) do
    GenServer.call(runtime, :sync)
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

  @doc "Returns the bridge pid for this runtime."
  @spec get_bridge(GenServer.server()) :: pid() | atom() | nil
  def get_bridge(runtime) do
    GenServer.call(runtime, :get_bridge)
  end

  @doc """
  Performs a synchronous interact via the renderer.

  Sends an interact request (e.g. click, type_text) to the renderer, which
  processes it against its widget tree and sends back events. The runtime
  processes those events through `update/2` and re-renders. Blocks until
  the renderer signals completion. Returns an error if another interact is
  already in flight, or if the renderer exits or restarts before the
  interaction finishes.
  """
  @spec interact(GenServer.server(), String.t(), map(), map(), timeout()) ::
          :ok
          | {:error,
             :interact_in_progress
             | :renderer_restarted
             | {:renderer_exit, term()}
             | {:timeout, String.t(), map()}}
  def interact(runtime, action, selector, payload \\ %{}, timeout \\ 10_000) do
    GenServer.call(runtime, {:interact, action, selector, payload}, timeout)
  end

  @doc """
  Waits for an async task with the given tag to complete.

  If the task has already completed, returns immediately. Otherwise
  blocks until the task finishes and its result has been processed
  through update/2.

  Returns `{:error, :await_in_progress}` if another caller is already
  waiting for the same tag.
  """
  @spec await_async(GenServer.server(), atom(), timeout()) :: :ok | {:error, :await_in_progress}
  def await_async(runtime, tag, timeout \\ 5000) do
    GenServer.call(runtime, {:await_async, tag}, timeout)
  end

  @doc "Finds a node in the current tree by exact scoped ID."
  @spec find_node(GenServer.server(), String.t()) :: map() | nil
  def find_node(runtime, id) do
    GenServer.call(runtime, {:find_node, id})
  end

  @doc "Finds a node in the current tree by exact scoped ID inside a specific window."
  @spec find_node(GenServer.server(), String.t(), String.t()) :: map() | nil
  def find_node(runtime, id, window_id) do
    GenServer.call(runtime, {:find_node, id, window_id})
  end

  @doc "Finds a node in the current tree using a predicate function."
  @spec find_node_by(GenServer.server(), (map() -> boolean())) :: map() | nil
  def find_node_by(runtime, fun) do
    GenServer.call(runtime, {:find_node_by, fun})
  end

  @doc """
  Registers an effect stub with the renderer.

  The renderer will return `response` immediately for any effect of
  the given `kind`, without executing the real effect. Blocks until
  the renderer confirms the stub is stored.

  The `kind` matches the effect function name as an atom (e.g.
  `:file_open`, `:clipboard_write`).

  Returns `{:error, :stub_ack_pending}` if a register or unregister
  for the same kind is already awaiting confirmation. Returns
  `{:error, :renderer_restarted}` if the renderer restarts while the
  registration is in flight (the stub must be re-registered).
  """
  @spec register_effect_stub(GenServer.server(), Plushie.Effect.kind(), term(), timeout()) ::
          :ok | {:error, :stub_ack_pending | :renderer_restarted}
  def register_effect_stub(runtime, kind, response, timeout \\ 5000) when is_atom(kind) do
    GenServer.call(runtime, {:register_effect_stub, Atom.to_string(kind), response}, timeout)
  end

  @doc """
  Removes a previously registered effect stub.

  Blocks until the renderer confirms the stub is removed.

  Returns `{:error, :stub_ack_pending}` if a register or unregister
  for the same kind is already awaiting confirmation. Returns
  `{:error, :renderer_restarted}` if the renderer restarts while the
  request is in flight.
  """
  @spec unregister_effect_stub(GenServer.server(), Plushie.Effect.kind(), timeout()) ::
          :ok | {:error, :stub_ack_pending | :renderer_restarted}
  def unregister_effect_stub(runtime, kind, timeout \\ 5000) when is_atom(kind) do
    GenServer.call(runtime, {:unregister_effect_stub, Atom.to_string(kind)}, timeout)
  end

  @doc """
  Returns the ID of the currently focused widget, or `nil`.

  Focus is tracked automatically from renderer status events.
  """
  @spec get_focused(GenServer.server()) :: String.t() | nil
  def get_focused(runtime) do
    GenServer.call(runtime, :get_focused)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    app = Keyword.fetch!(opts, :app)
    bridge = Keyword.fetch!(opts, :bridge)
    task_supervisor = Keyword.get(opts, :task_supervisor)
    daemon? = Keyword.get(opts, :daemon, false)
    token = Keyword.get(opts, :token)

    # App opts can be passed explicitly via :app_opts, or as remaining keys.
    app_opts =
      Keyword.get(
        opts,
        :app_opts,
        Keyword.drop(opts, [:app, :bridge, :name, :daemon, :token, :task_supervisor, :app_opts])
      )

    # 1. Initialize app model.
    case safe_init(app, app_opts) do
      {:ok, model, commands} ->
        state = %__MODULE__{
          app: app,
          model: model,
          bridge: bridge,
          task_supervisor: task_supervisor,
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
    {tree, nctx} =
      case render_and_sync(state.app, state.model, state.bridge, nil) do
        {:ok, tree, nctx} -> {tree, nctx}
        :view_error -> {nil, @empty_nctx}
      end

    # 5. Execute initial commands, then sync registries/subs/windows.
    state = %{state | tree: tree, memo_cache: nctx.memo, widget_view_cache: nctx.widget_view}
    state = Commands.execute_commands(state.init_commands, state)
    state = %{state | init_commands: []}
    state = sync_after_render(state, nctx)
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Synchronous queries
  # ---------------------------------------------------------------------------

  @impl true
  def handle_call(:sync, _from, state) do
    reply =
      if state.consecutive_view_errors > 0 do
        {:ok, :view_error}
      else
        :ok
      end

    {:reply, reply, state}
  end

  def handle_call(:get_model, _from, state) do
    {:reply, state.model, state}
  end

  def handle_call(:get_tree, _from, state) do
    {:reply, state.tree, state}
  end

  def handle_call(:get_bridge, _from, state) do
    {:reply, state.bridge, state}
  end

  def handle_call({:find_node, id}, _from, state) do
    {:reply, Plushie.Tree.find(state.tree, id), state}
  end

  def handle_call({:find_node, id, window_id}, _from, state) do
    {:reply, Plushie.Tree.find(state.tree, id, window_id), state}
  end

  def handle_call({:find_node_by, fun}, _from, state) do
    result = Plushie.Tree.find_all(state.tree, fun) |> List.first()
    {:reply, result, state}
  end

  def handle_call(:get_focused, _from, state) do
    {:reply, state.focused_widget_id, state}
  end

  def handle_call({:register_effect_stub, kind, response}, from, state) do
    if Map.has_key?(state.pending_stub_acks, kind) do
      {:reply, {:error, :stub_ack_pending}, state}
    else
      Plushie.Bridge.send_register_effect_stub(state.bridge, kind, response)
      {:noreply, %{state | pending_stub_acks: Map.put(state.pending_stub_acks, kind, from)}}
    end
  end

  def handle_call({:unregister_effect_stub, kind}, from, state) do
    if Map.has_key?(state.pending_stub_acks, kind) do
      {:reply, {:error, :stub_ack_pending}, state}
    else
      Plushie.Bridge.send_unregister_effect_stub(state.bridge, kind)
      {:noreply, %{state | pending_stub_acks: Map.put(state.pending_stub_acks, kind, from)}}
    end
  end

  # Internal timeout for pending_interact. Slightly exceeds the default
  # GenServer.call timeout (10s) to avoid racing with the caller's timeout.
  @interact_timeout 15_000

  def handle_call({:interact, action, selector, payload}, from, state) do
    case state.pending_interact do
      nil ->
        id = "interact_#{:erlang.unique_integer([:positive])}"
        {caller_pid, _} = from
        monitor_ref = Process.monitor(caller_pid)
        timer_ref = Process.send_after(self(), {:interact_timeout, id}, @interact_timeout)
        Plushie.Bridge.send_interact(state.bridge, id, action, selector, payload)

        {:noreply,
         %{state | pending_interact: {from, id, monitor_ref, timer_ref, action, selector}}}

      _ ->
        {:reply, {:error, :interact_in_progress}, state}
    end
  end

  def handle_call({:await_async, tag}, from, state) do
    cond do
      Map.has_key?(state.pending_await_async, tag) ->
        {:reply, {:error, :await_in_progress}, state}

      Map.has_key?(state.async_tasks, tag) ->
        # Task still running -- store caller and reply when it completes.
        {:noreply, %{state | pending_await_async: Map.put(state.pending_await_async, tag, from)}}

      true ->
        # Task already completed (or never existed).
        {:reply, :ok, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Renderer events (the main update loop)
  # ---------------------------------------------------------------------------

  @impl true
  # Status events are always intercepted to track widget interaction
  # state (focus, hover, etc.). The raw status event is absorbed by
  # the runtime. Derived events (focused, blurred) are dispatched to
  # update/2 for widgets that declared those event types.
  def handle_info(
        {:renderer_event, %WidgetEvent{type: :status, id: id, value: status} = event},
        state
      )
      when is_binary(status) do
    prev_status = Map.get(state.widget_statuses, id)
    state = %{state | widget_statuses: Map.put(state.widget_statuses, id, status)}

    state =
      cond do
        status == "focused" ->
          %{state | focused_widget_id: id}

        prev_status == "focused" and state.focused_widget_id == id ->
          %{state | focused_widget_id: nil}

        true ->
          state
      end

    # Derive focused/blurred events from status transitions.
    state =
      cond do
        prev_status != "focused" and status == "focused" ->
          run_update(state, %{event | type: :focused, value: nil})

        prev_status == "focused" and status != "focused" ->
          run_update(state, %{event | type: :blurred, value: nil})

        true ->
          state
      end

    {:noreply, state}
  end

  def handle_info(
        {:renderer_event, %Plushie.Event.SystemEvent{type: :diagnostic} = event},
        state
      ) do
    level = event.value[:level] || "warning"
    code = event.tag || "unknown"
    source = [event.window_id, event.id] |> Enum.reject(&is_nil/1) |> Enum.join("/")
    prefix = if source != "", do: " [#{source}]", else: ""
    msg = "plushie runtime:#{prefix} #{code}: #{event.value[:message] || inspect(event.value)}"

    case level do
      "error" -> Logger.error(msg)
      "info" -> Logger.info(msg)
      _ -> Logger.warning(msg)
    end

    :telemetry.execute([:plushie, :diagnostic], %{count: 1}, %{
      level: level,
      code: code,
      message: event.value[:message],
      id: event.id,
      window_id: event.window_id,
      element_id: event.value[:element_id],
      event: event
    })

    {:noreply, state}
  end

  def handle_info({:renderer_event, {:effect_stub_ack, kind}}, state) do
    case Map.pop(state.pending_stub_acks, kind) do
      {nil, _} ->
        {:noreply, state}

      {from, remaining} ->
        GenServer.reply(from, :ok)
        {:noreply, %{state | pending_stub_acks: remaining}}
    end
  end

  def handle_info({:renderer_event, {:effect_response, wire_id, result}}, state) do
    case pop_pending_effect(state, wire_id) do
      {:ok, tag, state} ->
        {:noreply, run_update(state, %EffectEvent{tag: tag, result: result})}

      :missing ->
        {:noreply, state}
    end
  end

  def handle_info({:renderer_event, {:hello, hello}}, state) do
    validate_renderer_widgets!(hello)
    check_renderer_version(hello)

    Logger.info(
      "plushie runtime: renderer connected -- #{hello.name} v#{hello.version} (#{hello.mode}, #{hello.backend}, #{hello.transport})"
    )

    {:noreply, state}
  end

  def handle_info(
        {:renderer_event, %Plushie.Event.SystemEvent{type: :all_windows_closed} = event},
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
  def handle_info({:renderer_event, %WidgetEvent{type: :move} = event}, state) do
    {:noreply,
     store_coalescable(
       state,
       {:move, event.window_id, Plushie.Event.target(event)},
       event
     )}
  end

  def handle_info({:renderer_event, %WidgetEvent{type: :scroll} = event}, state) do
    key = {:scroll, event.window_id, Plushie.Event.target(event)}

    existing = Map.get(state.pending_coalesce, key)

    accumulated =
      if existing do
        %{
          event
          | value: %{
              event.value
              | delta_x: existing.value.delta_x + event.value.delta_x,
                delta_y: existing.value.delta_y + event.value.delta_y
            }
        }
      else
        event
      end

    {:noreply, store_coalescable(state, key, accumulated)}
  end

  def handle_info({:renderer_event, %WidgetEvent{type: :scrolled} = event}, state) do
    {:noreply,
     store_coalescable(
       state,
       {:scrolled, event.window_id, Plushie.Event.target(event)},
       event
     )}
  end

  def handle_info({:renderer_event, %WidgetEvent{type: :resize} = event}, state) do
    {:noreply,
     store_coalescable(
       state,
       {:resize, event.window_id, Plushie.Event.target(event)},
       event
     )}
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
        event = decode_interact_event(event_map)
        run_update(acc, event)
      end)

    # Reply to the blocked caller.
    case state.pending_interact do
      {from, ^id, monitor_ref, timer_ref, _action, _selector} ->
        Process.demonitor(monitor_ref, [:flush])
        Process.cancel_timer(timer_ref)
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
    {:stop, :normal, fail_pending_interact(state, {:renderer_exit, :normal})}
  end

  def handle_info({:renderer_exit, :shutdown}, state) do
    {:stop, :normal, fail_pending_interact(state, {:renderer_exit, :shutdown})}
  end

  def handle_info({:renderer_exit, reason}, state) do
    state = fail_pending_interact(state, {:renderer_exit, reason})
    Logger.warning("plushie runtime: renderer exited: #{inspect(reason)}")

    exit = build_renderer_exit(reason)

    {new_model, recovery_error} =
      try do
        {state.app.handle_renderer_exit(state.model, exit), nil}
      catch
        catch_kind, catch_reason ->
          Logger.error(
            "plushie runtime: handle_renderer_exit #{catch_kind}: " <>
              Exception.format(catch_kind, catch_reason, __STACKTRACE__)
          )

          {state.model, {catch_kind, catch_reason}}
      end

    state = %{state | model: new_model}

    # If the recovery callback failed, dispatch a recovery_failed event
    # so the app can react (show an error, reset to safe state, etc.).
    state =
      if recovery_error do
        {kind, error} = recovery_error

        run_update(state, %Plushie.Event.SystemEvent{
          type: :recovery_failed,
          value: %{kind: kind, error: inspect(error), renderer_exit: exit}
        })
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:renderer_restarted, state) do
    Logger.info("plushie runtime: renderer restarted -- re-sending settings and snapshot")

    # Discard stale coalescable events from the old renderer.
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

    state = %{
      state
      | pending_coalesce: %{},
        pending_coalesce_order: [],
        coalesce_timer: nil,
        consecutive_errors: 0,
        consecutive_view_errors: 0
    }

    state = clear_frozen_ui_overlay(state)
    state = fail_pending_interact(state, :renderer_restarted)

    # Clear widget status tracking (old renderer state is stale).
    state = %{state | widget_statuses: %{}, focused_widget_id: nil}

    # Flush all pending effect requests -- the renderer that would have
    # responded is gone.
    state = flush_pending_effects(state, :renderer_restarted)

    # Flush pending stub acks with an error: the old renderer is gone
    # and its stub registry was lost. Callers must re-register.
    Enum.each(state.pending_stub_acks, fn {_kind, from} ->
      GenServer.reply(from, {:error, :renderer_restarted})
    end)

    state = %{state | pending_stub_acks: %{}}

    # The new renderer process expects Settings as the first message.
    send_settings(state)

    # Re-run view/1 to get a fresh tree rather than relying on a stale cache.
    # Pass widget handler states so widgets render with current internal state.
    # Preserve the dev overlay through the restart so the new renderer's
    # first frame shows the "Restarted" status bar.
    {tree, nctx} =
      case safe_view(
             state.app,
             state.model,
             state.widget_handlers,
             state.memo_cache,
             state.widget_view_cache
           ) do
        {:ok, new_tree, ctx} ->
          {maybe_inject_overlay(new_tree, state.dev_overlay), ctx}

        :error ->
          {state.tree, view_error_nctx(state)}
      end

    if tree do
      notify_bridge(state, &Plushie.Bridge.send_snapshot(&1, tree))
    end

    # Re-sync subscriptions with the new renderer.
    state =
      state
      |> reset_renderer_subscriptions()
      |> sync_runtime_subscriptions(state.model, nctx.widget_handlers)

    # Re-open all known windows with merged per-window props from the tree.
    # Reset tracked windows first so sync_windows sees them all as new.
    state = %{
      state
      | tree: tree,
        memo_cache: nctx.memo,
        widget_view_cache: nctx.widget_view,
        widget_handlers: nctx.widget_handlers,
        widget_events: nctx.widget_events,
        windows: MapSet.new()
    }

    state = Windows.sync_windows(state, tree, MapSet.new(nctx.window_ids))
    notify_bridge(state, &Plushie.Bridge.send_resync_complete/1)

    # If the overlay is showing a successful rebuild, schedule auto-dismiss
    # now that the renderer has restarted.
    state =
      case state.dev_overlay do
        %{status: :succeeded} -> schedule_overlay_dismiss(state)
        _ -> state
      end

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
        # Clean up before run_update so the tag is free for reuse in update/2.
        state = %{state | async_tasks: Map.delete(state.async_tasks, tag)}
        state = run_update(state, %AsyncEvent{tag: tag, result: result})
        # Notify after update so the caller sees the post-update model.
        state = notify_await_async(state, tag)
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
        state = run_update(state, %StreamEvent{tag: tag, value: value})
        {:noreply, state}

      _ ->
        # Stale or unknown -- discard.
        {:noreply, state}
    end
  end

  # Interact caller died (timeout or crash). Clean up pending_interact so
  # future interactions aren't blocked.
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state)
      when state.pending_interact != nil do
    case state.pending_interact do
      {_from, _id, ^ref, timer_ref, _action, _selector} ->
        Process.cancel_timer(timer_ref)
        Logger.debug("plushie runtime: interact caller exited, clearing pending interaction")
        {:noreply, %{state | pending_interact: nil}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:interact_timeout, id}, state) do
    case state.pending_interact do
      {from, ^id, monitor_ref, _timer_ref, action, selector} ->
        Process.demonitor(monitor_ref, [:flush])
        GenServer.reply(from, {:error, {:timeout, action, selector}})

        Logger.warning(
          "plushie runtime: interact #{id} timed out (action=#{action}, selector=#{inspect(selector)})"
        )

        {:noreply, %{state | pending_interact: nil}}

      _ ->
        # Stale timeout for an already-resolved interact.
        {:noreply, state}
    end
  end

  # Catch-all DOWN handler. Checks if the dead process is a monitored
  # async task before discarding.
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    case handle_async_task_exit(state, pid, reason) do
      {:handled, state} -> {:noreply, state}
      :not_a_task -> {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Timer-driven events
  # ---------------------------------------------------------------------------

  def handle_info({:send_after_event, event, nonce}, state) do
    case Map.get(state.pending_timers, event) do
      {_ref, ^nonce} ->
        state = %{state | pending_timers: Map.delete(state.pending_timers, event)}
        state = run_update(state, event)
        {:noreply, state}

      _ ->
        # Stale timer: the message was already in the mailbox when a
        # replacement timer was scheduled. Discard it.
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Effect request timeouts
  # ---------------------------------------------------------------------------

  def handle_info({:effect_timeout, id}, state) do
    case Map.pop(state.pending_effects, id) do
      {nil, _} ->
        # Already resolved or flushed -- ignore.
        {:noreply, state}

      {%{tag: tag}, pending_effects} ->
        :telemetry.execute([:plushie, :runtime, :effect_timeout], %{count: 1}, %{id: id})
        state = %{state | pending_effects: pending_effects}
        state = run_update(state, %EffectEvent{tag: tag, result: {:error, :timeout}})
        {:noreply, state}
    end
  end

  # ---------------------------------------------------------------------------
  # Exit trapping -- bridge or linked process crashes
  # ---------------------------------------------------------------------------

  # Task death via link (:EXIT from Task.start_link fallback or other
  # linked processes).
  def handle_info({:EXIT, pid, reason}, state) do
    case handle_async_task_exit(state, pid, reason) do
      {:handled, state} ->
        {:noreply, state}

      :not_a_task ->
        Logger.warning(
          "plushie runtime: linked process #{inspect(pid)} exited: #{inspect(reason)}"
        )

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

      # Route widget handler timer ticks to the widget's handle_event
      # instead of the app's update/2. Timer-triggered emits are
      # dispatched through the scope chain of parent widget_handlers.
      case Plushie.Runtime.WidgetHandlers.maybe_handle_timer(state.widget_handlers, tag) do
        {:handled, nil, new_registry} ->
          # Widget captured the timer (state update, re-render only).
          state = %{state | widget_handlers: new_registry}

          {new_tree, nctx, state} =
            case render_and_sync(
                   state.app,
                   state.model,
                   state.bridge,
                   state.tree,
                   state.widget_handlers,
                   state.memo_cache,
                   state.widget_view_cache,
                   state.dev_overlay
                 ) do
              {:ok, tree, nctx} ->
                {tree, nctx, clear_view_errors(state)}

              :view_error ->
                {state.tree, view_error_nctx(state), track_view_error(state)}
            end

          state = %{
            state
            | tree: new_tree,
              memo_cache: nctx.memo,
              widget_view_cache: nctx.widget_view
          }

          state = sync_after_render(state, nctx)

          {:noreply, state}

        {:handled, emitted_event, new_registry} ->
          # Widget emitted an event (possibly dispatched through
          # parent widget_handlers). Deliver to app's update/2.
          state = %{state | widget_handlers: new_registry}
          state = run_update(state, emitted_event)
          {:noreply, state}

        :not_routed ->
          # Standard app timer -- dispatch to update/2.
          now = System.monotonic_time(:millisecond)
          state = run_update(state, %TimerEvent{tag: tag, timestamp: now})
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
    state = %{state | consecutive_errors: 0, consecutive_view_errors: 0}
    state = clear_frozen_ui_overlay(state)

    {new_tree, nctx, state} =
      case render_and_sync(
             state.app,
             state.model,
             state.bridge,
             state.tree,
             state.widget_handlers,
             state.memo_cache,
             state.widget_view_cache,
             state.dev_overlay
           ) do
        {:ok, tree, nctx} ->
          {tree, nctx, clear_view_errors(state)}

        :view_error ->
          {state.tree, view_error_nctx(state), track_view_error(state)}
      end

    state = %{
      state
      | tree: new_tree,
        memo_cache: nctx.memo,
        widget_view_cache: nctx.widget_view
    }

    state = sync_after_render(state, nctx)
    {:noreply, state}
  end

  # -- Dev overlay messages ---------------------------------------------------

  def handle_info({:dev_overlay, overlay}, state) do
    state = cancel_overlay_timer(state)
    state = %{state | dev_overlay: overlay}
    state = dev_rerender(state)

    # Schedule auto-dismiss for success states (unless expanded).
    state =
      if overlay.status == :succeeded do
        schedule_overlay_dismiss(state)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:dev_overlay_auto_dismiss, state) do
    # Only auto-dismiss if the overlay is not expanded (user is reading).
    if state.dev_overlay && state.dev_overlay.expanded do
      {:noreply, state}
    else
      state = %{state | dev_overlay: nil, dev_overlay_timer: nil}
      {:noreply, dev_rerender(state)}
    end
  end

  # Catch-all: ignore unrecognised messages. Use Plushie.Runtime.dispatch/2
  # to formally send events from spawned processes.
  def handle_info(msg, state) do
    Logger.warning("plushie runtime: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # -- Dev overlay helpers ----------------------------------------------------

  @dev_overlay_dismiss_ms Plushie.Dev.RebuildingOverlay.dismiss_ms()

  defp maybe_handle_dev_overlay_event(state, %WidgetEvent{id: id})
       when is_binary(id) do
    if Plushie.Dev.RebuildingOverlay.overlay_event?(id) do
      {:handled, handle_dev_overlay_action(Plushie.Dev.RebuildingOverlay.action(id), state)}
    else
      :passthrough
    end
  end

  defp maybe_handle_dev_overlay_event(_state, _event), do: :passthrough

  defp handle_dev_overlay_action(_action, %{dev_overlay: nil} = state), do: state

  defp handle_dev_overlay_action(action, state) do
    case Plushie.Dev.RebuildingOverlay.handle_action(action, state.dev_overlay) do
      {:updated, overlay} ->
        state = %{state | dev_overlay: overlay}

        state =
          if not overlay.expanded and overlay.status == :succeeded do
            schedule_overlay_dismiss(state)
          else
            cancel_overlay_timer(state)
          end

        dev_rerender(state)

      :dismissed ->
        state = cancel_overlay_timer(state)
        dev_rerender(%{state | dev_overlay: nil})

      :noop ->
        state
    end
  catch
    kind, reason ->
      Logger.warning(
        "plushie runtime: dev overlay action #{kind}: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      state
  end

  defp dev_rerender(state) do
    {new_tree, nctx, state} =
      case render_and_sync(
             state.app,
             state.model,
             state.bridge,
             state.tree,
             state.widget_handlers,
             state.memo_cache,
             state.widget_view_cache,
             state.dev_overlay
           ) do
        {:ok, tree, nctx} ->
          {tree, nctx, clear_view_errors(state)}

        :view_error ->
          {state.tree, view_error_nctx(state), track_view_error(state)}
      end

    state = %{
      state
      | tree: new_tree,
        memo_cache: nctx.memo,
        widget_view_cache: nctx.widget_view
    }

    sync_after_render(state, nctx)
  end

  defp schedule_overlay_dismiss(state) do
    state = cancel_overlay_timer(state)
    ref = Process.send_after(self(), :dev_overlay_auto_dismiss, @dev_overlay_dismiss_ms)
    %{state | dev_overlay_timer: ref}
  end

  defp cancel_overlay_timer(%{dev_overlay_timer: nil} = state), do: state

  defp cancel_overlay_timer(state) do
    Process.cancel_timer(state.dev_overlay_timer)
    %{state | dev_overlay_timer: nil}
  end

  @impl true
  def terminate(_reason, state) do
    # Cancel coalesce timer if pending.
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

    # Cancel all pending send_after timers so they don't fire into the void.
    Enum.each(state.pending_timers, fn {_event, {ref, _nonce}} ->
      Process.cancel_timer(ref)
    end)

    # Cancel subscription timers.
    Enum.each(state.subscriptions, fn
      {_key, {:timer, ref}} -> Process.cancel_timer(ref)
      _ -> :ok
    end)

    # Cancel effect timeout timers.
    Enum.each(state.pending_effects, fn {_id, %{timer_ref: ref}} ->
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

  defp fail_pending_interact(%{pending_interact: nil} = state, _reason), do: state

  defp fail_pending_interact(
         %{pending_interact: {from, _id, monitor_ref, timer_ref, _action, _selector}} = state,
         reason
       ) do
    Process.demonitor(monitor_ref, [:flush])
    Process.cancel_timer(timer_ref)
    GenServer.reply(from, {:error, reason})
    %{state | pending_interact: nil}
  end

  # Sends app-level settings to the bridge. The renderer expects a Settings
  # message as the very first message on stdin (before any snapshot), so this
  # must always send something, even if the app doesn't define settings/0.
  defp send_settings(state) do
    settings =
      if function_exported?(state.app, :settings, 0) do
        try do
          case state.app.settings() do
            s when is_map(s) and s != %{} -> s
            s when is_list(s) and s != [] -> Map.new(s)
            _ -> %{}
          end
        catch
          kind, reason ->
            Logger.warning(
              "plushie runtime: settings/0 #{kind}: " <>
                Exception.format(kind, reason, __STACKTRACE__)
            )

            %{}
        end
      else
        %{}
      end

    widget_config = Application.get_env(:plushie, :widget_config, %{})

    settings =
      if widget_config != %{} do
        Map.put(settings, :widget_config, widget_config)
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

    # Enable renderer-side prop validation when configured.
    settings =
      if Application.get_env(:plushie, :validate_props) do
        Map.put(settings, :validate_props, true)
      else
        settings
      end

    notify_bridge(state, &Plushie.Bridge.send_settings(&1, settings))
  end

  # Converts a raw renderer exit reason into a structured %RendererExit{}.
  @spec build_renderer_exit(term()) :: Plushie.RendererExit.t()
  defp build_renderer_exit(:normal),
    do: %Plushie.RendererExit{type: :shutdown, message: "renderer shut down normally"}

  defp build_renderer_exit(:shutdown),
    do: %Plushie.RendererExit{type: :shutdown, message: "renderer shut down"}

  defp build_renderer_exit(:heartbeat_timeout),
    do: %Plushie.RendererExit{
      type: :heartbeat_timeout,
      message: "renderer unresponsive (heartbeat timeout)"
    }

  defp build_renderer_exit({:exit_status, status}),
    do: %Plushie.RendererExit{
      type: :crash,
      message: "renderer crashed with exit status #{status}",
      details: status
    }

  defp build_renderer_exit(reason),
    do: %Plushie.RendererExit{
      type: :crash,
      message: "renderer exited unexpectedly: #{inspect(reason)}",
      details: reason
    }

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
  # Returns {:ok, tree, nctx} on success, :view_error on failure
  # (old_tree is preserved by the caller).
  @spec render_and_sync(
          app :: module(),
          model :: term(),
          bridge :: pid() | atom(),
          old_tree :: map() | nil,
          widget_handlers :: map(),
          memo_cache :: map(),
          widget_view_cache :: map(),
          dev_overlay :: Plushie.Dev.RebuildingOverlay.t() | nil
        ) :: {:ok, map(), Plushie.Tree.NormalizeCtx.t()} | :view_error
  defp render_and_sync(
         app,
         model,
         bridge,
         old_tree,
         widget_handlers \\ %{},
         memo_cache \\ %{},
         widget_view_cache \\ %{},
         dev_overlay \\ nil
       ) do
    case safe_view(app, model, widget_handlers, memo_cache, widget_view_cache) do
      {:ok, new_tree, nctx} ->
        new_tree = maybe_inject_overlay(new_tree, dev_overlay)

        if is_nil(old_tree) do
          notify_bridge(%{bridge: bridge}, &Plushie.Bridge.send_snapshot(&1, new_tree))
        else
          ops =
            :telemetry.span([:plushie, :diff], %{app: app}, fn ->
              {Plushie.Tree.diff(old_tree, new_tree), %{}}
            end)

          if ops != [] do
            notify_bridge(%{bridge: bridge}, &Plushie.Bridge.send_patch(&1, ops))
          end
        end

        {:ok, new_tree, nctx}

      :error ->
        :view_error
    end
  end

  @view_error_warn_threshold 5

  defp track_view_error(state) do
    count = state.consecutive_view_errors + 1

    if count == @view_error_warn_threshold do
      Logger.warning(
        "plushie runtime: view/1 has failed #{count} consecutive times, " <>
          "the UI is stale. Check the error log for details."
      )
    end

    state = %{state | consecutive_view_errors: count}

    if count == @view_error_warn_threshold && is_nil(state.dev_overlay) && state.tree do
      overlay = %Plushie.Dev.RebuildingOverlay{status: :frozen_ui}
      new_tree = maybe_inject_overlay(state.tree, overlay)
      ops = Plushie.Tree.diff(state.tree, new_tree)

      if ops != [] do
        notify_bridge(state, &Plushie.Bridge.send_patch(&1, ops))
      end

      %{state | dev_overlay: overlay, tree: new_tree}
    else
      state
    end
  end

  defp clear_view_errors(state) do
    state = %{state | consecutive_view_errors: 0}
    clear_frozen_ui_overlay(state)
  end

  defp clear_frozen_ui_overlay(state) do
    case state.dev_overlay do
      %Plushie.Dev.RebuildingOverlay{status: :frozen_ui} ->
        %{state | dev_overlay: nil}

      _ ->
        state
    end
  end

  defp maybe_inject_overlay(tree, overlay) do
    Plushie.Dev.RebuildingOverlay.maybe_inject(tree, overlay)
  end

  defp safe_init(app, app_opts) do
    {model, commands} = unwrap_result(app.init(app_opts))
    {:ok, model, commands}
  catch
    kind, reason ->
      Logger.error("""
      plushie runtime: app.init/1 #{kind}: #{Exception.format(kind, reason, __STACKTRACE__)}
      """)

      {:error, {:init_crashed, reason}}
  end

  # Renders the view and normalizes the tree. Canvas widget stored state
  # is injected during normalization via the context map -- the
  # normalizer detects stateful widget nodes and re-renders them with
  # stored state before normalizing the output. This eliminates the need
  # for post-processing (the old apply_widget_handler_state approach).
  @spec safe_view(module(), term(), map(), map(), map()) ::
          {:ok, map(), Plushie.Tree.NormalizeCtx.t()} | :error
  defp safe_view(app, model, widget_handler_states, memo_cache, widget_view_cache) do
    raw_tree =
      :telemetry.span([:plushie, :view], %{app: app}, fn ->
        {app.view(model), %{}}
      end)

    validate_root_windows!(raw_tree)

    ctx = %Plushie.Tree.NormalizeCtx{
      scope: "",
      window_id: nil,
      widget_states: widget_handler_states,
      memo_prev: memo_cache,
      widget_view_prev: widget_view_cache
    }

    {normalized, result_ctx} =
      :telemetry.span([:plushie, :normalize], %{app: app}, fn ->
        {Plushie.Tree.normalize_with_caches(raw_tree, ctx), %{}}
      end)

    {:ok, normalized, result_ctx}
  catch
    kind, reason ->
      :telemetry.execute([:plushie, :runtime, :view_error], %{count: 1}, %{
        app: app,
        kind: kind,
        reason: reason
      })

      Logger.error("""
      plushie runtime: view/1 #{kind}: #{Exception.format(kind, reason, __STACKTRACE__)}
      """)

      :error
  end

  defp validate_root_windows!(nil), do: :ok
  defp validate_root_windows!([]), do: :ok

  defp validate_root_windows!(%{type: "window"}), do: :ok

  defp validate_root_windows!(%{} = node) do
    raise ArgumentError,
          "view/1 must return a window node or a list of window nodes at the top level, " <>
            "got #{inspect(Map.get(node, :type) || Map.get(node, "type") || :unknown)}"
  end

  defp validate_root_windows!(nodes) when is_list(nodes) do
    Enum.each(nodes, fn
      %{type: "window"} ->
        :ok

      %{} = node ->
        raise ArgumentError,
              "view/1 must return only window nodes at the top level, " <>
                "got #{inspect(Map.get(node, :type) || Map.get(node, "type") || :unknown)}"

      other ->
        raise ArgumentError,
              "view/1 must return window nodes at the top level, got #{inspect(other)}"
    end)
  end

  defp validate_root_windows!(other) do
    raise ArgumentError,
          "view/1 must return a window node or a list of window nodes, got #{inspect(other)}"
  end

  # ---------------------------------------------------------------------------
  # Event pipeline
  #
  # Every inbound event flows through two stages:
  #
  # 1. **Dispatch through widget_handlers**: walk the scope chain of
  #    widget handlers (innermost to outermost) following iced's
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

  # Dispatch an event through the widget handler chain. Returns
  # `{event_or_nil, updated_state}` where event_or_nil is the event
  # to deliver to app.update/2 (nil if captured by a widget).
  @spec route_through_widgets(state(), term()) :: {term() | nil, state()}
  defp route_through_widgets(state, event) do
    event = Plushie.Runtime.WidgetHandlers.normalize_widget_event!(state.widget_events, event)

    {result_event, new_registry} =
      Plushie.Runtime.WidgetHandlers.dispatch_event(state.widget_handlers, event)

    {result_event, %{state | widget_handlers: new_registry}}
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
    # Intercept dev overlay events before they reach the app.
    case maybe_handle_dev_overlay_event(state, event) do
      {:handled, state} ->
        state

      :passthrough ->
        try do
          handlers_before = state.widget_handlers
          {resolved_event, state} = route_through_widgets(state, event)

          if is_nil(resolved_event) do
            if state.widget_handlers != handlers_before do
              rerender_after_widget_state_change(state, handlers_before)
            else
              state
            end
          else
            dispatch_update(state, resolved_event)
          end
        catch
          kind, reason ->
            Logger.warning(
              "plushie runtime: widget event routing #{kind}: " <>
                Exception.format(kind, reason, __STACKTRACE__)
            )

            state
        end
    end
  end

  defp check_renderer_version(hello) do
    expected = Plushie.Binary.binary_version()

    if hello.version != expected do
      Logger.warning(
        "plushie runtime: renderer version mismatch, " <>
          "got #{hello.version}, expected #{expected}. " <>
          "The renderer binary may be stale. " <>
          "Run `mix plushie.build` or `mix plushie.download` to update."
      )
    end
  end

  defp validate_renderer_widgets!(hello) do
    expected = configured_widget_keys()
    missing = expected -- hello.native_widgets

    if missing != [] do
      raise ArgumentError,
            "renderer is missing required native widgets #{inspect(missing)}. " <>
              "Renderer reported #{inspect(hello.native_widgets)}"
    end
  end

  defp configured_widget_keys do
    Plushie.WidgetRegistry.native_widgets()
    |> Enum.map(&native_widget_type/1)
    |> Enum.uniq()
  end

  defp native_widget_type(module) do
    case module.type_names() do
      [type | _] ->
        Atom.to_string(type)

      [] ->
        raise ArgumentError, "native widget #{inspect(module)} does not declare a widget type"
    end
  end

  # Update + commands + re-render (the core dispatch path).
  @spec dispatch_update(state(), term()) :: state()
  defp dispatch_update(%{app: app, model: model, bridge: bridge} = state, event) do
    case safe_update(app, model, event, state.consecutive_errors) do
      {:ok, new_model, commands} ->
        state = %{state | model: new_model, consecutive_errors: 0}
        state = Commands.execute_commands(commands, state)

        {new_tree, nctx, state} =
          case render_and_sync(
                 app,
                 new_model,
                 bridge,
                 state.tree,
                 state.widget_handlers,
                 state.memo_cache,
                 state.widget_view_cache,
                 state.dev_overlay
               ) do
            {:ok, tree, nctx} ->
              {tree, nctx, clear_view_errors(state)}

            :view_error ->
              {state.tree, view_error_nctx(state), track_view_error(state)}
          end

        state = %{
          state
          | tree: new_tree,
            memo_cache: nctx.memo,
            widget_view_cache: nctx.widget_view
        }

        sync_after_render(state, nctx)

      :error ->
        %{state | consecutive_errors: state.consecutive_errors + 1}
    end
  end

  # Re-render after a widget's handle_event returned {:update_state, ...}
  # without emitting an event. The widget state changed but the app's
  # update/2 was never called, so we need to re-render to pick up
  # any view changes driven by the new widget state.
  #
  # `handlers_before` is the widget_handlers state prior to the update.
  # On view error we revert to this to avoid a state-tree desync where
  # the handler registry reflects an update the tree never rendered.
  @spec rerender_after_widget_state_change(state(), map()) :: state()
  defp rerender_after_widget_state_change(
         %{app: app, model: model, bridge: bridge} = state,
         handlers_before
       ) do
    {new_tree, nctx, state} =
      case render_and_sync(
             app,
             model,
             bridge,
             state.tree,
             state.widget_handlers,
             state.memo_cache,
             state.widget_view_cache,
             state.dev_overlay
           ) do
        {:ok, tree, nctx} ->
          {tree, nctx, clear_view_errors(state)}

        :view_error ->
          fallback = %{
            view_error_nctx(state)
            | widget_handlers: handlers_before
          }

          {state.tree, fallback, %{track_view_error(state) | widget_handlers: handlers_before}}
      end

    state = %{
      state
      | tree: new_tree,
        memo_cache: nctx.memo,
        widget_view_cache: nctx.widget_view
    }

    sync_after_render(state, nctx)
  end

  defp safe_update(app, model, event, consecutive_errors) do
    {new_model, commands} =
      :telemetry.span([:plushie, :update], %{app: app, event: event}, fn ->
        {unwrap_result(app.update(model, event)), %{}}
      end)

    {:ok, new_model, commands}
  catch
    kind, reason ->
      :telemetry.execute([:plushie, :runtime, :update_error], %{count: 1}, %{
        app: app,
        event: event,
        kind: kind,
        reason: reason
      })

      # Rate-limit logging: normal up to 10, debug up to 100, suppress with
      # periodic reminders every 1000 errors thereafter. Note: consecutive_errors
      # is the pre-increment count (before this error), so thresholds are offset
      # by one (e.g., < 9 means the first 10 errors log at :error level).
      count = consecutive_errors + 1
      formatted = Exception.format(kind, reason, __STACKTRACE__)

      cond do
        count <= 10 ->
          Logger.error("plushie runtime: update/2 #{kind}: #{formatted}")

        count <= 100 ->
          Logger.debug("plushie runtime: update/2 #{kind} (repeated): #{formatted}")

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

  # Cancels the timeout timer for a resolved effect request and returns the tag.
  @spec pop_pending_effect(state(), String.t()) :: {:ok, atom(), state()} | :missing
  defp pop_pending_effect(state, id) do
    case Map.pop(state.pending_effects, id) do
      {nil, _} ->
        :missing

      {%{tag: tag, timer_ref: timer_ref}, pending_effects} ->
        Process.cancel_timer(timer_ref)
        {:ok, tag, %{state | pending_effects: pending_effects}}
    end
  end

  # Flushes all pending effect requests, dispatching error results through
  # update/2 and cancelling their timers.
  # Flushes all pending effects by cancelling their timers and delivering
  # error events. Each effect is removed individually before its error event
  # is dispatched so that new effects started during the flush survive.
  @spec flush_pending_effects(state(), atom()) :: state()
  defp flush_pending_effects(state, reason) do
    ids = Map.keys(state.pending_effects)

    Enum.reduce(ids, state, fn id, acc ->
      case Map.get(acc.pending_effects, id) do
        %{tag: tag, timer_ref: timer_ref} ->
          if timer_ref, do: Process.cancel_timer(timer_ref)
          acc = %{acc | pending_effects: Map.delete(acc.pending_effects, id)}
          run_update(acc, %EffectEvent{tag: tag, result: {:error, reason}})

        nil ->
          # Already removed (e.g. by a run_update side effect).
          acc
      end
    end)
  end

  # Drains queued subscription ticks for the same tag/interval from the
  # mailbox. This coalesces rapid-fire animation or timer ticks so the
  # runtime only processes the latest one, avoiding redundant update cycles.
  @spec drain_matching_ticks(term(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp drain_matching_ticks(tag, interval, count \\ 0) do
    receive do
      {:subscription_tick, ^tag, ^interval} -> drain_matching_ticks(tag, interval, count + 1)
    after
      0 ->
        if count > 0 do
          :telemetry.execute(
            [:plushie, :runtime, :ticks_drained],
            %{count: count},
            %{tag: tag}
          )
        end

        count
    end
  end

  # ---------------------------------------------------------------------------
  # Interact protocol helpers
  # ---------------------------------------------------------------------------

  # Processes an interact_step batch: decode each event, run through update/2
  # without sending intermediate patches, then send a single full snapshot.
  # The renderer expects exactly one snapshot per interact_step.
  defp run_interact_step(state, events) do
    {state, deferred_commands} =
      Enum.reduce(events, {state, []}, fn event_map, {acc, commands_acc} ->
        event = decode_interact_event(event_map)
        {next_state, commands} = apply_event_deferred(acc, event)
        {next_state, commands_acc ++ commands}
      end)

    # Execute commands before re-rendering, consistent with dispatch_update.
    # Commands are the result of update/2, not the view. They must execute
    # regardless of whether the re-render succeeds.
    state = Commands.execute_commands(deferred_commands, state)

    # Re-render and send a full snapshot (not a patch).
    case safe_view(
           state.app,
           state.model,
           state.widget_handlers,
           state.memo_cache,
           state.widget_view_cache
         ) do
      {:ok, new_tree, nctx} ->
        notify_bridge(state, &Plushie.Bridge.send_snapshot(&1, new_tree))

        state = %{
          state
          | tree: new_tree,
            memo_cache: nctx.memo,
            widget_view_cache: nctx.widget_view
        }

        sync_after_render(state, nctx)

      :error ->
        Logger.warning(
          "plushie runtime: view/1 failed during interact step, keeping previous tree"
        )

        state
    end
  end

  @spec apply_event_deferred(state(), term()) :: {state(), [Plushie.Command.t()]}
  defp apply_event_deferred(state, event) do
    {resolved_event, state} = route_through_widgets(state, event)

    if is_nil(resolved_event) do
      {state, []}
    else
      case safe_update(state.app, state.model, resolved_event, state.consecutive_errors) do
        {:ok, new_model, commands} ->
          {%{state | model: new_model, consecutive_errors: 0}, List.wrap(commands)}

        :error ->
          {%{state | consecutive_errors: state.consecutive_errors + 1}, []}
      end
    end
  end

  # Decodes a renderer event map from interact_step/interact_response using
  # the shared protocol decoder so scripted interactions and normal runtime
  # event delivery stay on the same path.
  defp decode_interact_event(%{} = event_map), do: Plushie.Protocol.decode_event(event_map)

  defp decode_interact_event(other) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, "interact", :event, other, :expected_map, %{}},
      format: :msgpack,
      data: <<>>
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

    # Prepend to avoid O(n) list append; reversed before flushing.
    pending_coalesce_order =
      if Map.has_key?(state.pending_coalesce, key) do
        state.pending_coalesce_order
      else
        [key | state.pending_coalesce_order]
      end

    %{
      state
      | pending_coalesce: Map.put(state.pending_coalesce, key, event),
        pending_coalesce_order: pending_coalesce_order
    }
  end

  @spec flush_coalescables(state()) :: state()
  defp flush_coalescables(%{pending_coalesce: pending} = state)
       when map_size(pending) == 0 do
    state
  end

  defp flush_coalescables(state) do
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

    state =
      state.pending_coalesce_order
      |> Enum.reverse()
      |> Enum.reduce(state, fn key, acc ->
        event = Map.fetch!(acc.pending_coalesce, key)
        run_update(acc, event)
      end)

    %{state | pending_coalesce: %{}, pending_coalesce_order: [], coalesce_timer: nil}
  end

  # Builds a NormalizeCtx from the current runtime state for view_error
  # fallback paths where normalization did not produce a ctx.
  @spec view_error_nctx(state()) :: NormalizeCtx.t()
  defp view_error_nctx(state) do
    %NormalizeCtx{
      scope: "",
      window_id: nil,
      memo: state.memo_cache,
      widget_view: state.widget_view_cache,
      widget_handlers: state.widget_handlers,
      widget_events: state.widget_events,
      window_ids: MapSet.to_list(state.windows)
    }
  end

  # Syncs pre-computed widget registries, subscriptions, and windows.
  # Called after every render cycle once tree/memo_cache/widget_view_cache
  # are already on state.
  @spec sync_after_render(state(), NormalizeCtx.t()) :: state()
  defp sync_after_render(state, %NormalizeCtx{} = nctx) do
    state = %{
      state
      | widget_handlers: nctx.widget_handlers,
        widget_events: nctx.widget_events
    }

    state = sync_runtime_subscriptions(state, state.model, nctx.widget_handlers)
    Windows.sync_windows(state, state.tree, MapSet.new(nctx.window_ids))
  end

  defp sync_runtime_subscriptions(state, model, widget_handlers) do
    widget_subs = Plushie.Runtime.WidgetHandlers.collect_subscriptions(widget_handlers)
    Subscriptions.sync_subscriptions(state, model, widget_subs)
  end

  defp reset_renderer_subscriptions(state) do
    subscriptions =
      Enum.reduce(state.subscriptions, %{}, fn
        {key, {:timer, _ref} = entry}, acc -> Map.put(acc, key, entry)
        {_key, _entry}, acc -> acc
      end)

    subscription_keys = subscriptions |> Map.keys() |> Enum.sort()
    %{state | subscriptions: subscriptions, subscription_keys: subscription_keys}
  end

  # Shared handler for async task exits (both :EXIT and :DOWN paths).
  # Returns {:handled, state} if the pid was an async task, :not_a_task otherwise.
  @spec handle_async_task_exit(state(), pid(), term()) :: {:handled, state()} | :not_a_task
  defp handle_async_task_exit(state, pid, reason) do
    {tag, entry} =
      Enum.find_value(state.async_tasks, {nil, nil}, fn
        {tag, {^pid, nonce}} -> {tag, nonce}
        _ -> nil
      end)

    case entry do
      nil ->
        :not_a_task

      :cancelled ->
        state = %{state | async_tasks: Map.delete(state.async_tasks, tag)}
        state = notify_await_async(state, tag)
        {:handled, state}

      _nonce when reason == :normal ->
        state = %{state | async_tasks: Map.delete(state.async_tasks, tag)}
        state = notify_await_async(state, tag)
        {:handled, state}

      _nonce ->
        Logger.warning("plushie runtime: async task #{inspect(tag)} crashed: #{inspect(reason)}")
        state = %{state | async_tasks: Map.delete(state.async_tasks, tag)}
        state = run_update(state, %AsyncEvent{tag: tag, result: {:error, {:crashed, reason}}})
        state = notify_await_async(state, tag)
        {:handled, state}
    end
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
