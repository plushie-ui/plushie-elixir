defmodule Julep.DevServer do
  @moduledoc """
  File watcher and recompiler for dev-mode live reload.

  Watches `lib/` for `.ex` and `.exs` changes, recompiles, and tells the
  runtime to re-render. The UI updates without losing application state.

  Requires the `:file_system` package. Start via `mix julep.dev` or manually:

      Julep.DevServer.start_link(runtime: runtime_pid, dirs: ["lib"])
  """

  use GenServer

  require Logger

  @default_debounce_ms 100
  @default_dirs ["lib"]
  @elixir_extensions ~w(.ex .exs)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    ensure_file_system!()

    runtime = Keyword.fetch!(opts, :runtime)
    dirs = Keyword.get(opts, :dirs, @default_dirs) |> Enum.map(&Path.expand/1)
    debounce_ms = Keyword.get(opts, :debounce_ms, @default_debounce_ms)

    {:ok, watcher} = FileSystem.start_link(dirs: dirs)
    FileSystem.subscribe(watcher)

    state = %{
      runtime: runtime,
      watcher: watcher,
      debounce_ms: debounce_ms,
      debounce_ref: nil,
      recompiling: false,
      changed_paths: MapSet.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:file_event, _watcher, {path, _events}}, state) do
    if watchable?(path) do
      state = %{state | changed_paths: MapSet.put(state.changed_paths, path)}

      if is_nil(state.debounce_ref) do
        ref = Process.send_after(self(), :recompile, state.debounce_ms)
        {:noreply, %{state | debounce_ref: ref}}
      else
        {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info({:file_event, _watcher, :stop}, state) do
    Logger.warning("julep dev: file watcher stopped")
    {:noreply, state}
  end

  def handle_info(:recompile, state) do
    state = %{state | debounce_ref: nil}
    paths = state.changed_paths
    state = %{state | changed_paths: MapSet.new()}

    if not state.recompiling and MapSet.size(paths) > 0 do
      state = %{state | recompiling: true}
      do_recompile(state.runtime, paths)
      {:noreply, %{state | recompiling: false}}
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_recompile(runtime, paths) do
    count = MapSet.size(paths)
    Logger.info("julep dev: recompiling #{count} file(s)...")

    errors =
      paths
      |> Enum.sort()
      |> Enum.reduce([], fn path, errs ->
        try do
          Code.compile_file(path)
          errs
        rescue
          e ->
            Logger.error("julep dev: #{Path.relative_to_cwd(path)}: #{Exception.message(e)}")
            [path | errs]
        end
      end)

    if errors == [] do
      send(runtime, :force_rerender)
      Logger.info("julep dev: reload complete")
    else
      Logger.warning("julep dev: #{length(errors)} file(s) failed to compile")
    end
  end

  defp watchable?(path) do
    ext = Path.extname(path)
    ext in @elixir_extensions and not String.contains?(path, "/_build/")
  end

  defp ensure_file_system! do
    unless Code.ensure_loaded?(FileSystem) do
      raise """
      The :file_system package is required for live reload.

      Add it to your deps in mix.exs:

          {:file_system, "~> 1.0"}
      """
    end
  end
end
