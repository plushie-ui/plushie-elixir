defmodule Plushie.Dev.DevServer do
  @moduledoc """
  File watcher and recompiler for dev-mode live reload.

  Watches compilation directories for `.ex` and `.exs` changes,
  recompiles, and tells the runtime to re-render. The UI updates
  without losing application state.

  When native widgets are detected (via `Plushie.WidgetRegistry`),
  also watches their Rust crate directories for `.rs` and `Cargo.toml`
  changes. On change, runs `cargo build` via a Port, streams output
  to the dev overlay, and restarts the renderer on success.

  By default, watches all directories in `elixirc_paths` (e.g.
  `lib/` and `examples/` in dev). Override with the `:dirs` option.

  Requires the `:file_system` package. Started automatically when
  `config :plushie, code_reloader: true` is set, or via start_link:

      Plushie.Dev.DevServer.start_link(runtime: runtime_pid)
  """

  use GenServer

  require Logger

  @default_debounce_ms 100
  @rust_debounce_ms 200
  @fallback_dirs ["lib"]
  @elixir_file_exts ~w(.ex .exs)
  @rust_file_exts ~w(.rs .toml)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Starts the dev server with the given options."
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    Process.flag(:trap_exit, true)
    ensure_file_system!()

    runtime = Keyword.fetch!(opts, :runtime)
    bridge = Keyword.get(opts, :bridge)

    default_dirs =
      if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :config, 0) do
        Mix.Project.config()[:elixirc_paths] || @fallback_dirs
      else
        @fallback_dirs
      end

    dirs = Keyword.get(opts, :dirs, default_dirs) |> Enum.map(&Path.expand/1)
    debounce_ms = Keyword.get(opts, :debounce_ms, @default_debounce_ms)

    watcher =
      case apply(FileSystem, :start_link, [[dirs: dirs]]) do
        {:ok, pid} -> pid
        :ignore -> nil
      end

    if watcher, do: apply(FileSystem, :subscribe, [watcher])

    # Start Rust file watcher for native widget crates if applicable.
    rust_watcher = start_rust_watcher(bridge)

    rebuild_artifacts = Keyword.get(opts, :rebuild_artifacts, [:bin])

    state = %{
      runtime: runtime,
      bridge: bridge,
      watcher: watcher,
      debounce_ms: debounce_ms,
      debounce_ref: nil,
      changed_paths: MapSet.new(),
      rust_watcher: rust_watcher,
      rust_debounce_ref: nil,
      rust_build_port: nil,
      rust_build_output: "",
      wasm_build_port: nil,
      wasm_build_output: "",
      rebuild_artifacts: rebuild_artifacts,
      overlay_expanded: false
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:file_event, watcher, {path, _events}}, %{watcher: watcher} = state) do
    if watchable_elixir?(path) do
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

  def handle_info({:file_event, watcher, {path, _events}}, %{rust_watcher: watcher} = state)
      when watcher != nil do
    if watchable_rust?(path) do
      # Kill any running build; it's already outdated.
      state = kill_rust_build(state)

      # Cancel pending debounce and start a new one.
      if state.rust_debounce_ref, do: Process.cancel_timer(state.rust_debounce_ref)
      ref = Process.send_after(self(), :rust_build, @rust_debounce_ms)
      {:noreply, %{state | rust_debounce_ref: ref}}
    else
      {:noreply, state}
    end
  end

  def handle_info({:file_event, _watcher, :stop}, state) do
    Logger.warning("plushie dev: file watcher stopped")
    {:noreply, state}
  end

  def handle_info(:recompile, state) do
    state = %{state | debounce_ref: nil}
    paths = state.changed_paths
    state = %{state | changed_paths: MapSet.new()}

    if MapSet.size(paths) > 0 do
      state = do_recompile(state, paths)
      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  # -- Rust build messages ----------------------------------------------------

  def handle_info(:rust_build, state) do
    state = %{state | rust_debounce_ref: nil}
    state = start_rust_build(state)
    {:noreply, state}
  end

  # Streaming output from cargo build.
  def handle_info({port, {:data, {:eol, line}}}, %{rust_build_port: port} = state)
      when port != nil do
    clean_line = strip_ansi(line)
    state = %{state | rust_build_output: state.rust_build_output <> clean_line <> "\n"}
    state = send_overlay(state, :building, all_build_output(state))
    {:noreply, state}
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, %{rust_build_port: port} = state)
      when port != nil do
    clean_chunk = strip_ansi(chunk)
    state = %{state | rust_build_output: state.rust_build_output <> clean_chunk}
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, 0}}, %{rust_build_port: port} = state)
      when port != nil do
    Logger.info("plushie dev: rust build succeeded")
    state = %{state | rust_build_port: nil}

    if :wasm in state.rebuild_artifacts do
      # Chain WASM build after successful native build.
      {:noreply, start_wasm_build(state)}
    else
      finish_rebuild(state)
    end
  end

  def handle_info({port, {:exit_status, status}}, %{rust_build_port: port} = state)
      when port != nil do
    Logger.warning("plushie dev: rust build failed (exit code #{status})")
    state = %{state | rust_build_port: nil}
    state = send_overlay(state, :failed, state.rust_build_output)
    {:noreply, %{state | rust_build_output: ""}}
  end

  # -- WASM build port handlers -----------------------------------------------

  def handle_info({port, {:data, {:eol, line}}}, %{wasm_build_port: port} = state)
      when port != nil do
    clean_line = strip_ansi(line)
    state = %{state | wasm_build_output: state.wasm_build_output <> clean_line <> "\n"}
    state = send_overlay(state, :building, all_build_output(state))
    {:noreply, state}
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, %{wasm_build_port: port} = state)
      when port != nil do
    clean_chunk = strip_ansi(chunk)
    state = %{state | wasm_build_output: state.wasm_build_output <> clean_chunk}
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, 0}}, %{wasm_build_port: port} = state)
      when port != nil do
    Logger.info("plushie dev: wasm build succeeded")
    state = %{state | wasm_build_port: nil}
    finish_rebuild(state)
  end

  def handle_info({port, {:exit_status, status}}, %{wasm_build_port: port} = state)
      when port != nil do
    Logger.warning("plushie dev: wasm build failed (exit code #{status})")
    state = %{state | wasm_build_port: nil}
    state = send_overlay(state, :failed, all_build_output(state))
    state = %{state | rust_build_output: "", wasm_build_output: ""}

    # Native build succeeded even though WASM failed; still restart renderer.
    if state.bridge, do: Plushie.Bridge.restart_renderer(state.bridge)

    {:noreply, state}
  end

  # Handle EXIT from linked watchers or build ports. Watcher deaths are
  # logged but not fatal; port cleanup happens in terminate/2.
  def handle_info({:EXIT, pid, reason}, state) do
    cond do
      pid == state.watcher ->
        Logger.warning("plushie dev: file watcher exited: #{inspect(reason)}")
        {:noreply, %{state | watcher: nil}}

      pid == state.rust_watcher ->
        Logger.warning("plushie dev: rust file watcher exited: #{inspect(reason)}")
        {:noreply, %{state | rust_watcher: nil}}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(msg, state) do
    Logger.debug("plushie dev: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Elixir recompilation
  # ---------------------------------------------------------------------------

  defp do_recompile(state, paths) do
    count = MapSet.size(paths)
    Logger.info("plushie dev: recompiling #{count} file(s)...")

    modules_str =
      paths
      |> Enum.sort()
      |> Enum.map_join(", ", &Path.rootname(Path.basename(&1)))

    state = send_overlay(state, :building, modules_str)

    # Snapshot widget impls before recompilation to detect new widgets.
    prev_widget_impls = protocol_impl_set()

    # Suppress "redefining module" warnings. We're intentionally
    # reloading modules that are already loaded from _build.
    prev = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    {compiled, errors} =
      paths
      |> Enum.sort()
      |> Enum.reduce({[], []}, fn path, {compiled_acc, err_acc} ->
        try do
          modules = Code.compile_file(path)
          names = Enum.map(modules, fn {mod, _} -> inspect(mod) end)
          {compiled_acc ++ names, err_acc}
        rescue
          e ->
            Logger.error("plushie dev: #{Path.relative_to_cwd(path)}: #{Exception.message(e)}")
            {compiled_acc, [Exception.message(e) | err_acc]}
        end
      end)

    Code.put_compiler_option(:ignore_module_conflict, prev)

    if errors == [] do
      # Reconsolidate the Widget protocol if new widgets appeared.
      if protocol_impl_set() != prev_widget_impls do
        reconsolidate_widgets()
      end

      send(state.runtime, :force_rerender)

      state = send_overlay(state, :succeeded, Enum.join(compiled, ", "))
      Logger.info("plushie dev: reload complete")
      state
    else
      state = send_overlay(state, :failed, Enum.join(Enum.reverse(errors), "\n\n"))
      Logger.warning("plushie dev: compilation failed")
      state
    end
  end

  # ---------------------------------------------------------------------------
  # Rust build
  # ---------------------------------------------------------------------------

  defp start_rust_build(state) do
    state = kill_rust_build(state)
    state = %{state | rust_build_output: ""}

    state = send_overlay(state, :building, "")

    build_dir =
      if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :build_path, 0) do
        Path.join(Mix.Project.build_path(), "plushie-renderer")
      end

    cargo = System.find_executable("cargo")

    if cargo && build_dir && File.dir?(build_dir) do
      release? = Application.get_env(:plushie, :build_profile) == :release
      args = if release?, do: ["build", "--release"], else: ["build"]

      port =
        Port.open({:spawn_executable, cargo}, [
          :binary,
          :exit_status,
          :stderr_to_stdout,
          {:line, 4096},
          {:args, args},
          {:cd, build_dir}
        ])

      %{state | rust_build_port: port}
    else
      Logger.warning(
        "plushie dev: cannot start rust build (cargo not found or workspace missing)"
      )

      send_overlay(state, :failed, "cargo not found or build workspace missing")
    end
  end

  defp kill_rust_build(%{rust_build_port: nil, wasm_build_port: nil} = state), do: state

  defp kill_rust_build(state) do
    state = kill_port(state, :rust_build_port)
    state = kill_port(state, :wasm_build_port)
    %{state | rust_build_output: "", wasm_build_output: ""}
  end

  defp kill_port(state, key) do
    case Map.get(state, key) do
      nil ->
        state

      port ->
        Port.close(port)
        Map.put(state, key, nil)
    end
  rescue
    ArgumentError -> Map.put(state, key, nil)
  end

  defp finish_rebuild(state) do
    state = send_overlay(state, :succeeded, all_build_output(state))

    if state.bridge, do: Plushie.Bridge.restart_renderer(state.bridge)

    {:noreply, %{state | rust_build_output: "", wasm_build_output: ""}}
  end

  defp start_wasm_build(state) do
    source_path = Mix.PlushieHelpers.source_path()
    wasm_pack = System.find_executable("wasm-pack")

    if source_path && wasm_pack do
      wasm_crate = Path.join(source_path, "plushie-renderer-wasm")

      if File.dir?(wasm_crate) do
        release? = Application.get_env(:plushie, :build_profile) == :release
        profile = if release?, do: "--release", else: "--dev"
        env = [{"WASM_BINDGEN_EXTERNREF", "0"}]

        state = send_overlay(state, :building, state.rust_build_output)

        port =
          Port.open({:spawn_executable, wasm_pack}, [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            {:line, 4096},
            {:args, ["build", "--target", "web", profile]},
            {:cd, wasm_crate},
            {:env, env}
          ])

        %{state | wasm_build_port: port, wasm_build_output: ""}
      else
        Logger.warning("plushie dev: wasm crate not found at #{wasm_crate}, skipping")
        {:noreply, state} = finish_rebuild(state)
        state
      end
    else
      Logger.info("plushie dev: wasm-pack or source_path not available, skipping wasm build")
      {:noreply, state} = finish_rebuild(state)
      state
    end
  end

  # ---------------------------------------------------------------------------
  # Rust watcher setup
  # ---------------------------------------------------------------------------

  defp start_rust_watcher(nil), do: nil

  defp start_rust_watcher(_bridge) do
    crate_dirs = native_widget_dirs()

    if crate_dirs != [] do
      Logger.info("plushie dev: watching rust crates: #{Enum.join(crate_dirs, ", ")}")

      case apply(FileSystem, :start_link, [[dirs: crate_dirs]]) do
        {:ok, watcher} ->
          apply(FileSystem, :subscribe, [watcher])
          watcher

        {:error, reason} ->
          Logger.warning("plushie dev: failed to start rust watcher: #{inspect(reason)}")
          nil
      end
    else
      nil
    end
  end

  defp native_widget_dirs do
    Plushie.WidgetRegistry.native_widgets()
    |> Enum.flat_map(fn mod ->
      crate_rel = mod.native_crate()
      path = Path.expand(crate_rel)
      if File.dir?(path), do: [path], else: []
    end)
  end

  # ---------------------------------------------------------------------------
  # File type detection
  # ---------------------------------------------------------------------------

  defp watchable_elixir?(path) do
    ext = Path.extname(path)
    ext in @elixir_file_exts and not String.contains?(path, "/_build/")
  end

  defp watchable_rust?(path) do
    ext = Path.extname(path)
    ext in @rust_file_exts and not String.contains?(path, "/target/")
  end

  # ---------------------------------------------------------------------------
  # Utilities
  # ---------------------------------------------------------------------------

  defp strip_ansi(text) when is_binary(text) do
    String.replace(text, ~r/\e\[[0-9;]*m/, "")
  end

  defp strip_ansi(text) when is_list(text) do
    text |> IO.iodata_to_binary() |> strip_ansi()
  end

  defp send_overlay(state, status, detail) do
    expanded = if status == :failed, do: true, else: state.overlay_expanded

    overlay = %Plushie.Dev.RebuildingOverlay{
      status: status,
      detail: detail,
      expanded: expanded
    }

    send(state.runtime, {:dev_overlay, overlay})
    %{state | overlay_expanded: expanded}
  end

  defp all_build_output(state) do
    state.rust_build_output <> state.wasm_build_output
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

  # -- Protocol reconsolidation -----------------------------------------------

  defp protocol_impl_set do
    Protocol.extract_impls(Plushie.Tree.Node, :code.get_path()) |> MapSet.new()
  end

  @impl GenServer
  def terminate(_reason, state) do
    kill_rust_build(state)

    if state.watcher, do: Process.exit(state.watcher, :shutdown)
    if state.rust_watcher, do: Process.exit(state.rust_watcher, :shutdown)

    :ok
  end

  defp reconsolidate_widgets do
    # MUST use :code.get_path() to scan ALL paths including deps.
    # Protocol.consolidate only knows about types you pass it --
    # passing a subset loses widgets from hex deps.
    impls = Protocol.extract_impls(Plushie.Tree.Node, :code.get_path())
    {:ok, binary} = Protocol.consolidate(Plushie.Tree.Node, impls)
    :code.load_binary(Plushie.Tree.Node, ~c"nofile", binary)
    Plushie.WidgetRegistry.invalidate()
    Logger.info("plushie dev: widget protocol reconsolidated")
  end
end
