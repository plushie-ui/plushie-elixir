defmodule Toddy do
  @moduledoc """
  Native desktop GUIs from Elixir, powered by iced.

  ## Quick start

      {:ok, pid} = Toddy.start_link(MyApp)

  ## Dev mode (live code reloading)

      {:ok, pid} = Toddy.start_link(MyApp, dev: true)

  ## Under a supervisor

      children = [
        {Toddy, app: MyApp}
      ]

  ## Options

  - `:app`        -- (required) the app module implementing `Toddy.App`
  - `:app_opts`   -- opts forwarded to `app.init/1` (default: `[]`)
  - `:binary`     -- path to the toddy binary (default: auto-resolved)
  - `:name`       -- supervisor registration name (default: `Toddy`)
  - `:daemon`     -- if `true`, keep running after the last window closes
                      (default: `false`). In daemon mode, `all_windows_closed`
                      is delivered to `update/2` instead of triggering shutdown.
  - `:dev`        -- enable live code reloading (default: `false`)
  - `:dev_opts`   -- options forwarded to `Toddy.DevServer` (default: `[]`)
  - `:transport`   -- `:spawn` (default, spawns the renderer as a child
                      process) or `:stdio` (reads/writes the BEAM's own
                      stdin/stdout, for use with `toddy --exec`)
  - `:format`      -- wire format, `:msgpack` (default) or `:json`
  - `:log_level`   -- toddy binary log level (`:off`, `:error`, `:warning`, `:info`, `:debug`).
                      Default: `:error`.

  When `:transport` is `:stdio`, the `:binary` option is ignored (no
  renderer subprocess is spawned).
  """

  use Supervisor

  @default_binary_path :auto

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts a Toddy application under a supervisor linked to the calling process.

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
  Stops a running Toddy supervisor.

  Accepts a pid or the instance name passed as `:name` to `start_link/2`
  (defaults to `Toddy`, matching the default registration).
  """
  @spec stop(pid() | atom()) :: :ok
  def stop(pid_or_name \\ __MODULE__)
  def stop(pid) when is_pid(pid), do: Supervisor.stop(pid)
  def stop(name) when is_atom(name), do: Supervisor.stop(sup_name(name))

  @doc """
  Child spec for embedding Toddy under an existing supervisor.

  ## Example

      children = [
        {Toddy, app: MyApp, name: :my_app_gui}
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
      if transport == :stdio do
        nil
      else
        case Keyword.get(opts, :binary, @default_binary_path) do
          :auto -> Toddy.Binary.path!()
          path -> path
        end
      end

    daemon? = Keyword.get(opts, :daemon, false)
    dev? = Keyword.get(opts, :dev, false)
    format = Keyword.get(opts, :format, :msgpack)
    log_level = Keyword.get(opts, :log_level, :error)

    bridge_opts =
      [
        runtime: runtime_name(name),
        name: bridge_name(name),
        transport: transport,
        format: format,
        log_level: log_level
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
        {Toddy.Bridge, bridge_opts},
        restart: :transient,
        significant: true
      ),
      # Runtime sends Settings then Snapshot to the already-registered Bridge.
      # Bridge forwards renderer events back to Runtime.
      Supervisor.child_spec(
        {Toddy.Runtime,
         [
           app: app,
           bridge: bridge_name(name),
           name: runtime_name(name),
           daemon: daemon?,
           app_opts: Keyword.get(opts, :app_opts, [])
         ]},
        restart: :transient,
        significant: true
      )
    ]

    children =
      if dev? do
        dev_opts =
          Keyword.get(opts, :dev_opts, [])
          |> Keyword.put(:runtime, runtime_name(name))
          |> Keyword.put_new(:name, dev_server_name(name))

        children ++
          [
            Supervisor.child_spec(
              {Toddy.DevServer, dev_opts},
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

  defp sup_name(instance_name), do: :"#{instance_name}.Supervisor"
  defp runtime_name(instance_name), do: :"#{instance_name}.Runtime"
  defp bridge_name(instance_name), do: :"#{instance_name}.Bridge"
  defp dev_server_name(instance_name), do: :"#{instance_name}.DevServer"
end
