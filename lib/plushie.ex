defmodule Plushie do
  @moduledoc """
  Native desktop GUIs from Elixir, powered by iced.

  ## Quick start

      {:ok, pid} = Plushie.start_link(MyApp)

  ## Dev mode (live code reloading)

      # In config/dev.exs:
      config :plushie, code_reloader: true

      # Or as a start_link option:
      {:ok, pid} = Plushie.start_link(MyApp, code_reloader: true)

  ## Under a supervisor

      children = [
        {Plushie, app: MyApp}
      ]

  ## Options

  - `:app`        -- (required) the app module implementing `Plushie.App`
  - `:app_opts`   -- opts forwarded to `app.init/1` (default: `[]`)
  - `:binary`     -- path to the plushie binary (default: auto-resolved)
  - `:name`       -- supervisor registration name (default: `Plushie`)
  - `:daemon`     -- if `true`, keep running after the last window closes
                      (default: `false`). In daemon mode, `all_windows_closed`
                      is delivered to `update/2` instead of triggering shutdown.
  - `:code_reloader` -- enable dev-mode live reloading. `false` (default),
                      `true`, or a keyword list of reloader options
                      (`:debounce_ms`, `:rebuild_artifacts`). Can also be set
                      via `config :plushie, code_reloader: true`.
  - `:transport`   -- `:spawn` (default, spawns the renderer as a child
                      process), `:stdio` (reads/writes the BEAM's own
                      stdin/stdout, for use with `plushie --exec`), or
                      `{:iostream, pid}` (custom transport via iostream
                      adapter -- see `Plushie.Bridge` for the protocol)
  - `:format`      -- wire format, `:msgpack` (default) or `:json`
  - `:log_level`   -- plushie binary log level (`:off`, `:error`, `:warning`, `:info`, `:debug`).
                      Default: `:error`.
  - `:renderer_args` -- extra CLI args passed to the renderer process
  - `:heartbeat_interval` -- maximum time (ms) between renderer messages
                      before the bridge considers it unresponsive and restarts
                      the renderer. `nil` disables the watchdog. Default: `30_000`.

  When `:transport` is `:stdio` or `{:iostream, pid}`, the `:binary`
  option is ignored (no renderer subprocess is spawned).

  ## Telemetry

  Plushie emits `:telemetry` events for observability. Spans include
  both `start` and `stop` (or `exception`) suffixes automatically.

  ### Spans

  Spans are emitted via `:telemetry.span/3`. Each produces
  `[:plushie, <name>, :start]` and `[:plushie, <name>, :stop]`
  events (or `:exception` on failure).

  - `[:plushie, :view]` - calls `app.view(model)`.
    Metadata: `%{app: module()}`.
  - `[:plushie, :normalize]` - normalizes the raw view tree into
    canonical wire format, including widget rendering and memo caching.
    Metadata: `%{app: module()}`.
  - `[:plushie, :diff]` - diffs old and new trees to produce patch
    operations. Metadata: `%{app: module()}`.
  - `[:plushie, :update]` - calls `app.update(model, event)`.
    Metadata: `%{app: module(), event: Plushie.Event.t()}`.
  - `[:plushie, :commands]` - executes commands returned by
    `update/2` or `init/1`. Metadata: `%{count: non_neg_integer()}`.
  - `[:plushie, :subscriptions, :sync]` - diffs and synchronizes
    active subscriptions. Metadata: `%{}`.

  ### Single events

  Single events are emitted via `:telemetry.execute/3`.

  #### Runtime

  - `[:plushie, :runtime, :view_error]` - `view/1` raised or threw.
    Measurements: `%{count: 1}`. Metadata: `%{app: module()}`.
  - `[:plushie, :runtime, :update_error]` - `update/2` raised or threw.
    Measurements: `%{count: 1}`. Metadata: `%{app: module(), event: term()}`.
  - `[:plushie, :runtime, :effect_timeout]` - a pending effect
    request timed out. Measurements: `%{count: 1}`.
    Metadata: `%{id: term()}`.
  - `[:plushie, :runtime, :ticks_drained]` - coalesced multiple
    pending ticks into one cycle. Measurements: `%{count: integer()}`.
    Metadata: `%{tag: atom()}`.

  #### Tree

  - `[:plushie, :memo, :hit]` - memo cache hit during normalization.
    Measurements: `%{count: 1}`. Metadata: `%{id: String.t()}`.
  - `[:plushie, :memo, :miss]` - memo cache miss during normalization.
    Measurements: `%{count: 1}`. Metadata: `%{id: String.t()}`.
  - `[:plushie, :widget_cache, :hit]` - widget view cache hit.
    Measurements: `%{count: 1}`.
    Metadata: `%{id: String.t(), module: module()}`.
  - `[:plushie, :widget_cache, :miss]` - widget view cache miss.
    Measurements: `%{count: 1}`.
    Metadata: `%{id: String.t(), module: module()}`.

  #### Bridge

  - `[:plushie, :bridge, :send]` - frame sent to the renderer.
    Measurements: `%{byte_size: non_neg_integer()}`.
  - `[:plushie, :bridge, :receive]` - frame received from the renderer.
    Measurements: `%{byte_size: non_neg_integer()}`.
  - `[:plushie, :bridge, :restart]` - renderer process restarted.
    Measurements: `%{count: pos_integer()}` (cumulative restart count).
  - `[:plushie, :bridge, :protocol_error]` - failed to decode a
    renderer frame. Metadata: `%{reason: term(), format: atom()}`.
  - `[:plushie, :bridge, :max_restarts_reached]` - renderer exceeded
    the maximum restart limit. Metadata: `%{reason: term(), max_restarts: integer()}`.
  """

  use Supervisor

  @default_binary_path :auto

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts a Plushie application under a supervisor linked to the calling process.

  Returns `{:ok, pid}` on success.
  """
  @spec start_link(module(), keyword()) :: Supervisor.on_start()
  def start_link(app_module, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:app, app_module)
      |> Keyword.put_new(:name, __MODULE__)

    Supervisor.start_link(__MODULE__, opts, name: sup_name(opts[:name]))
  end

  @doc """
  Stops a running Plushie supervisor.

  Accepts a pid or the instance name passed as `:name` to `start_link/2`
  (defaults to `Plushie`, matching the default registration).
  """
  @spec stop(pid() | atom()) :: :ok
  def stop(pid_or_name \\ __MODULE__)
  def stop(pid) when is_pid(pid), do: Supervisor.stop(pid)
  def stop(name) when is_atom(name), do: Supervisor.stop(sup_name(name))

  @doc """
  Child spec for embedding Plushie under an existing supervisor.

  ## Example

      children = [
        {Plushie, app: MyApp, name: :my_app_gui}
      ]
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    name = opts[:name]

    %{
      id: name,
      start: {__MODULE__, :start_link, [opts[:app], opts]},
      type: :supervisor
    }
  end

  # ---------------------------------------------------------------------------
  # Supervisor callbacks
  # ---------------------------------------------------------------------------

  @doc false
  @impl Supervisor
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    app = Keyword.fetch!(opts, :app)
    validate_app!(app)
    transport = Keyword.get(opts, :transport, :spawn)
    validate_transport!(transport)

    binary_path =
      if transport == :stdio or match?({:iostream, _}, transport) do
        nil
      else
        case Keyword.get(opts, :binary, @default_binary_path) do
          :auto -> Plushie.Binary.path!()
          path -> path
        end
      end

    daemon? = Keyword.get(opts, :daemon, false)
    code_reloader? = resolve_code_reloader(opts)
    format = Keyword.get(opts, :format, :msgpack)
    log_level = Keyword.get(opts, :log_level, :error)

    session_id = Keyword.get(opts, :session_id, "")

    heartbeat_interval = Keyword.get(opts, :heartbeat_interval, 30_000)

    bridge_opts =
      [
        runtime: runtime_name(name),
        name: bridge_name(name),
        transport: transport,
        format: format,
        log_level: log_level,
        renderer_args: Keyword.get(opts, :renderer_args, []),
        heartbeat_interval: heartbeat_interval,
        session_id: session_id
      ]
      |> then(fn opts ->
        if binary_path do
          Keyword.put(opts, :renderer_path, Path.expand(binary_path))
        else
          opts
        end
      end)

    # Task.Supervisor MUST start before Bridge and Runtime so async
    # tasks have a supervisor when the Runtime starts processing commands.
    # Bridge MUST start before Runtime. Runtime's handle_continue(:initial_render)
    # fires immediately and casts Settings + Snapshot to Bridge. If Bridge hasn't
    # started yet, those casts are lost and the renderer hangs.
    children = [
      # Task supervisor for async/stream commands. Started first so it is
      # available when Runtime begins executing commands.
      {Task.Supervisor, name: task_supervisor_name(name)},
      # Bridge opens the Port and spawns the renderer process (spawn mode)
      # or attaches to stdin/stdout (stdio mode). In spawn mode the renderer
      # blocks on stdin waiting for a Settings message.
      Supervisor.child_spec(
        {Plushie.Bridge, bridge_opts},
        restart: :transient,
        significant: true
      ),
      # Runtime sends Settings then Snapshot to the already-registered Bridge.
      # Bridge forwards renderer events back to Runtime.
      Supervisor.child_spec(
        {Plushie.Runtime,
         [
           app: app,
           bridge: bridge_name(name),
           name: runtime_name(name),
           task_supervisor: task_supervisor_name(name),
           daemon: daemon?,
           token: Keyword.get(opts, :token),
           app_opts: Keyword.get(opts, :app_opts, [])
         ]},
        restart: :transient,
        significant: true
      )
    ]

    children =
      if code_reloader? do
        reloader_opts = resolve_reloader_opts(opts)

        dev_opts =
          reloader_opts
          |> Keyword.put(:runtime, runtime_name(name))
          |> Keyword.put(:bridge, bridge_name(name))
          |> Keyword.put_new(:name, dev_server_name(name))

        children ++
          [
            Supervisor.child_spec(
              {Plushie.Dev.DevServer, dev_opts},
              restart: :transient
            )
          ]
      else
        children
      end

    # :rest_for_one -- if Bridge crashes, Runtime restarts too (fresh start).
    # If Runtime crashes alone, only Runtime restarts; it re-sends settings
    # and snapshot to the still-running Bridge/renderer.
    # :transient -- don't restart children that exit normally (clean window close).
    # :auto_shutdown -- when any significant child exits normally, tear down the tree.
    Supervisor.init(children,
      strategy: :rest_for_one,
      auto_shutdown: :any_significant
    )
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec validate_app!(module()) :: :ok
  defp validate_app!(app) do
    unless is_atom(app) and Code.ensure_loaded?(app) do
      raise ArgumentError,
            "expected :app to be a loaded module, got: #{inspect(app)}"
    end

    unless function_exported?(app, :init, 1) and function_exported?(app, :update, 2) and
             function_exported?(app, :view, 1) do
      raise ArgumentError,
            "#{inspect(app)} does not implement the Plushie.App behaviour " <>
              "(missing init/1, update/2, or view/1)"
    end

    :ok
  end

  @type transport :: :spawn | :stdio | {:iostream, pid()}

  @spec validate_transport!(transport()) :: :ok
  @valid_transports [:spawn, :stdio]
  defp validate_transport!(transport) when transport in @valid_transports, do: :ok
  defp validate_transport!({:iostream, pid}) when is_pid(pid), do: :ok

  defp validate_transport!(other) do
    raise ArgumentError,
          "expected :transport to be :spawn, :stdio, or {:iostream, pid}, got: #{inspect(other)}"
  end

  @doc "Returns the registered name of the runtime for the given instance."
  @spec runtime_for(name :: atom()) :: atom()
  def runtime_for(name \\ __MODULE__), do: runtime_name(name)

  @doc "Returns the registered name of the bridge for the given instance."
  @spec bridge_for(name :: atom()) :: atom()
  def bridge_for(name \\ __MODULE__), do: bridge_name(name)

  defp sup_name(name), do: :"#{name}.Supervisor"
  defp task_supervisor_name(name), do: :"#{name}.TaskSupervisor"
  defp runtime_name(name), do: :"#{name}.Runtime"
  defp bridge_name(name), do: :"#{name}.Bridge"
  defp dev_server_name(name), do: :"#{name}.DevServer"

  @spec resolve_code_reloader(opts :: keyword()) :: boolean()
  defp resolve_code_reloader(opts) do
    case Keyword.get(opts, :code_reloader) do
      nil -> Application.get_env(:plushie, :code_reloader, false) != false
      false -> false
      _ -> true
    end
  end

  @spec resolve_reloader_opts(opts :: keyword()) :: keyword()
  defp resolve_reloader_opts(opts) do
    config =
      case Application.get_env(:plushie, :code_reloader) do
        list when is_list(list) -> list
        _ -> []
      end

    cli_opts = Keyword.get(opts, :reloader_opts, [])
    Keyword.merge(config, cli_opts)
  end
end
