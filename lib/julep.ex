defmodule Julep do
  @moduledoc """
  Native desktop GUIs from Elixir, powered by iced.

  ## Quick start

      {:ok, pid} = Julep.start(MyApp)

  ## Dev mode (live code reloading)

      {:ok, pid} = Julep.start(MyApp, dev: true)

  ## Under a supervisor

      children = [
        {Julep, app: MyApp}
      ]

  ## Options

  - `:app`        -- (required) the app module implementing `Julep.App`
  - `:app_opts`   -- opts forwarded to `app.init/1` (default: `[]`)
  - `:renderer`   -- path to the julep binary (default: auto-resolved)
  - `:name`       -- supervisor registration name (default: `Julep`)
  - `:dev`        -- enable live code reloading (default: `false`)
  - `:dev_opts`   -- options forwarded to `Julep.DevServer` (default: `[]`)
  - `:format`      -- wire format, `:msgpack` (default) or `:json`
  - `:log_level`   -- renderer log level (`:error`, `:warning`, `:info`, `:debug`).
                      Default: `:error`.
  """

  use Supervisor

  @default_renderer_path :auto

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts a Julep application under a supervisor linked to the calling process.

  Returns `{:ok, pid}` on success.
  """
  @spec start(module(), keyword()) :: Supervisor.on_start()
  def start(app_module, opts \\ []) do
    opts =
      opts
      |> Keyword.put(:app, app_module)
      |> put_instance_name()

    Supervisor.start_link(__MODULE__, opts, name: sup_name(opts[:instance_name]))
  end

  @doc "Stops the Julep supervisor."
  @spec stop(Supervisor.supervisor()) :: :ok
  def stop(pid \\ __MODULE__) do
    Supervisor.stop(pid)
  end

  @doc """
  Child spec for embedding Julep under an existing supervisor.

  ## Example

      children = [
        {Julep, app: MyApp, name: :my_app_gui}
      ]
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    opts = put_instance_name(opts)
    name = opts[:instance_name]

    %{
      id: name,
      start: {__MODULE__, :start, [opts[:app], opts]},
      type: :supervisor
    }
  end

  # ---------------------------------------------------------------------------
  # Supervisor callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    name = opts[:instance_name]
    app = Keyword.fetch!(opts, :app)

    renderer_path =
      case Keyword.get(opts, :renderer, @default_renderer_path) do
        :auto -> Julep.Binary.renderer_path()
        path -> path
      end

    dev? = Keyword.get(opts, :dev, false)
    format = Keyword.get(opts, :format, :msgpack)
    log_level = Keyword.get(opts, :log_level, :error)

    # Bridge MUST start before Runtime. Runtime's handle_continue(:initial_render)
    # fires immediately and casts Settings + Snapshot to Bridge. If Bridge hasn't
    # started yet, those casts are lost and the renderer hangs.
    children = [
      # Bridge starts first: opens the Port and spawns the renderer process,
      # which blocks on stdin waiting for a Settings message. Bridge registers
      # under bridge_name(name) so Runtime can cast to it immediately.
      Supervisor.child_spec(
        {Julep.Bridge,
         [
           renderer_path: Path.expand(renderer_path),
           runtime: runtime_name(name),
           name: bridge_name(name),
           format: format,
           log_level: log_level
         ]},
        restart: :transient,
        significant: true
      ),
      # Runtime starts second. Its handle_continue sends Settings then
      # Snapshot to the already-registered Bridge. Bridge forwards renderer
      # events to the registered runtime_name, which is alive by this point.
      Supervisor.child_spec(
        {Julep.Runtime,
         [
           app: app,
           bridge: bridge_name(name),
           name: runtime_name(name),
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
              {Julep.DevServer, dev_opts},
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
