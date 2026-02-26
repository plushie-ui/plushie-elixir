defmodule Julep do
  @moduledoc """
  Native desktop GUIs from Elixir, powered by iced.

  ## Quick start

      {:ok, pid} = Julep.start(MyApp)

  ## Under a supervisor

      children = [
        {Julep, app: MyApp}
      ]

  ## Options

  - `:app`        -- (required) the app module implementing `Julep.App`
  - `:app_opts`   -- opts forwarded to `app.init/1` (default: `[]`)
  - `:renderer`   -- path to the julep_gui binary (default: built debug binary)
  - `:name`       -- supervisor registration name (default: `Julep`)
  """

  use Supervisor

  @default_renderer_path "native/julep_gui/target/debug/julep_gui"

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
    name          = opts[:instance_name]
    app           = Keyword.fetch!(opts, :app)
    renderer_path = Keyword.get(opts, :renderer, @default_renderer_path)

    children = [
      # Runtime starts first and registers under runtime_name(name).
      # It defers its initial snapshot send to handle_continue, which fires
      # after init returns -- by then the supervisor has started Bridge.
      {Julep.Runtime, [
        app:        app,
        bridge:     bridge_name(name),
        name:       runtime_name(name),
        app_opts:   Keyword.get(opts, :app_opts, [])
      ]},
      # Bridge starts second and can already send events to the registered
      # runtime_name because Runtime is alive by this point.
      {Julep.Bridge, [
        renderer_path: Path.expand(renderer_path),
        runtime:       runtime_name(name),
        name:          bridge_name(name)
      ]}
    ]

    # :rest_for_one: if Runtime crashes, Bridge restarts too (correct order).
    Supervisor.init(children, strategy: :rest_for_one)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp put_instance_name(opts) do
    case Keyword.fetch(opts, :name) do
      {:ok, name} -> Keyword.put_new(opts, :instance_name, name)
      :error      -> Keyword.put_new(opts, :instance_name, __MODULE__)
    end
  end

  defp sup_name(instance_name),     do: :"#{instance_name}.Supervisor"
  defp runtime_name(instance_name), do: :"#{instance_name}.Runtime"
  defp bridge_name(instance_name),  do: :"#{instance_name}.Bridge"
end
