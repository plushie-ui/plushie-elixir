defmodule Plushie do
  @moduledoc """
  Native desktop GUIs from Elixir, powered by iced.

  ## Quick start

      {:ok, pid} = Plushie.start_link(MyApp)

  ## Dev mode (live code reloading)

      {:ok, pid} = Plushie.start_link(MyApp, dev: true)

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
  - `:dev`        -- enable live code reloading (default: `false`)
  - `:dev_opts`   -- options forwarded to `Plushie.DevServer` (default: `[]`)
  - `:transport`   -- `:spawn` (default, spawns the renderer as a child
                      process), `:stdio` (reads/writes the BEAM's own
                      stdin/stdout, for use with `plushie --exec`), or
                      `{:iostream, pid}` (custom transport via iostream
                      adapter -- see `Plushie.Bridge` for the protocol)
  - `:format`      -- wire format, `:msgpack` (default) or `:json`
  - `:log_level`   -- plushie binary log level (`:off`, `:error`, `:warning`, `:info`, `:debug`).
                      Default: `:error`.
  - `:renderer_args` -- extra CLI args passed to the renderer process

  When `:transport` is `:stdio` or `{:iostream, pid}`, the `:binary`
  option is ignored (no renderer subprocess is spawned).
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
      |> put_instance_name()

    Supervisor.start_link(__MODULE__, opts, name: sup_name(opts[:instance_name]))
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
    opts = put_instance_name(opts)
    name = opts[:instance_name]

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
  @impl true
  def init(opts) do
    name = opts[:instance_name]
    app = Keyword.fetch!(opts, :app)
    transport = Keyword.get(opts, :transport, :spawn)

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

    bridge_opts =
      [
        runtime: runtime_name(name),
        name: bridge_name(name),
        transport: transport,
        format: format,
        log_level: log_level,
        renderer_args: Keyword.get(opts, :renderer_args, []),
        session_id: session_id
      ]
      |> then(fn opts ->
        if binary_path do
          Keyword.put(opts, :renderer_path, Path.expand(binary_path))
        else
          opts
        end
      end)

    # Bridge MUST start before Runtime. Runtime's handle_continue(:initial_render)
    # fires immediately and casts Settings + Snapshot to Bridge. If Bridge hasn't
    # started yet, those casts are lost and the renderer hangs.
    children = [
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
              {Plushie.DevServer, dev_opts},
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

  defp put_instance_name(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> Keyword.put_new(opts, :instance_name, name)
      :error -> Keyword.put_new(opts, :instance_name, __MODULE__)
    end
  end

  @doc "Returns the registered name of the runtime for the given instance."
  def runtime_for(instance_name \\ __MODULE__), do: runtime_name(instance_name)

  @doc "Returns the registered name of the bridge for the given instance."
  def bridge_for(instance_name \\ __MODULE__), do: bridge_name(instance_name)

  defp sup_name(instance_name), do: :"#{instance_name}.Supervisor"
  defp runtime_name(instance_name), do: :"#{instance_name}.Runtime"
  defp bridge_name(instance_name), do: :"#{instance_name}.Bridge"
  defp dev_server_name(instance_name), do: :"#{instance_name}.DevServer"

  defp resolve_code_reloader(opts) do
    case Keyword.get(opts, :code_reloader) do
      nil -> Application.get_env(:plushie, :code_reloader, false) != false
      false -> false
      _ -> true
    end
  end

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
