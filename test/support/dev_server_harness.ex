defmodule Plushie.DevServer.TestHarness do
  @moduledoc false

  # A GenServer with the same message handling as DevServer but without
  # the FileSystem dependency or real compilation. Used by DevServer tests
  # to exercise filtering and debouncing logic in isolation.

  use GenServer

  @elixir_extensions ~w(.ex .exs)

  @impl true
  def init(state) do
    {:ok, Map.put_new(state, :changed_paths, MapSet.new())}
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
    {:noreply, state}
  end

  def handle_info(:recompile, state) do
    state = %{state | debounce_ref: nil}
    paths = state.changed_paths
    state = %{state | changed_paths: MapSet.new()}

    if not state.recompiling and MapSet.size(paths) > 0 do
      # Instead of real compilation, just send :force_rerender.
      send(state.runtime, :force_rerender)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp watchable?(path) do
    ext = Path.extname(path)
    ext in @elixir_extensions and not String.contains?(path, "/_build/")
  end
end
