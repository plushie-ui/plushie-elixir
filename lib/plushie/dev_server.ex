defmodule Plushie.DevServer do
  @moduledoc """
  File watcher and recompiler for dev-mode live reload.

  Watches compilation directories for `.ex` and `.exs` changes,
  recompiles, and tells the runtime to re-render. The UI updates
  without losing application state.

  When native extensions are configured, also watches their Rust
  crate directories for `.rs` and `Cargo.toml` changes. On change,
  runs `cargo build` via a Port, streams output to the dev overlay,
  and restarts the renderer on success.

  By default, watches all directories in `elixirc_paths` (e.g.
  `lib/` and `examples/` in dev). Override with the `:dirs` option.

  Requires the `:file_system` package. Started automatically by
  `mix plushie.gui` in dev mode, or manually:

      Plushie.DevServer.start_link(runtime: runtime_pid)
  """

  use GenServer

  require Logger

  @default_debounce_ms 100
  @rust_debounce_ms 200
  @fallback_dirs ["lib"]
  @elixir_extensions ~w(.ex .exs)
  @rust_extensions ~w(.rs .toml)

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
    bridge = Keyword.get(opts, :bridge)

    default_dirs =
      if Code.ensure_loaded?(Mix.Project) and function_exported?(Mix.Project, :config, 0) do
        Mix.Project.config()[:elixirc_paths] || @fallback_dirs
      else
        @fallback_dirs
      end

    dirs = Keyword.get(opts, :dirs, default_dirs) |> Enum.map(&Path.expand/1)
    debounce_ms = Keyword.get(opts, :debounce_ms, @default_debounce_ms)

    {:ok, watcher} = apply(FileSystem, :start_link, [[dirs: dirs]])
    apply(FileSystem, :subscribe, [watcher])

    # Start Rust file watcher for native extension crates if applicable.
    rust_watcher = start_rust_watcher(bridge)

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
      overlay_expanded: false
    }

    {:ok, state}
  end

  @impl true
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
      # Kill any running build -- it's already outdated.
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

    overlay = %Plushie.DevOverlay{
      status: :building,
      source: :rust,
      message: "Rebuilding... (rust)",
      detail: state.rust_build_output,
      expanded: state.overlay_expanded
    }

    send(state.runtime, {:dev_overlay, overlay})
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

    overlay = %Plushie.DevOverlay{
      status: :succeeded,
      source: :rust,
      message: "Rebuilt (rust), restarting...",
      detail: state.rust_build_output,
      expanded: state.overlay_expanded
    }

    send(state.runtime, {:dev_overlay, overlay})

    # Restart the renderer to pick up the new binary.
    if state.bridge do
      Plushie.Bridge.restart_renderer(state.bridge)
    end

    state = %{state | rust_build_output: ""}
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{rust_build_port: port} = state)
      when port != nil do
    Logger.warning("plushie dev: rust build failed (exit code #{status})")
    state = %{state | rust_build_port: nil}

    overlay = %Plushie.DevOverlay{
      status: :failed,
      source: :rust,
      message: "Build failed (rust)",
      detail: state.rust_build_output,
      expanded: true
    }

    # Remember that the user saw expanded (failure auto-expands).
    state = %{state | overlay_expanded: true, rust_build_output: ""}
    send(state.runtime, {:dev_overlay, overlay})
    {:noreply, state}
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

    # Show overlay during Elixir recompile.
    modules_str =
      paths
      |> Enum.sort()
      |> Enum.map_join(", ", &Path.rootname(Path.basename(&1)))

    overlay = %Plushie.DevOverlay{
      status: :building,
      source: :elixir,
      message: "Rebuilding... (elixir)",
      detail: modules_str,
      expanded: state.overlay_expanded
    }

    send(state.runtime, {:dev_overlay, overlay})

    # Suppress "redefining module" warnings -- we're intentionally
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
      send(state.runtime, :force_rerender)

      overlay = %Plushie.DevOverlay{
        status: :succeeded,
        source: :elixir,
        message: "Rebuilt (elixir)",
        detail: Enum.join(compiled, ", "),
        expanded: state.overlay_expanded
      }

      send(state.runtime, {:dev_overlay, overlay})
      Logger.info("plushie dev: reload complete")
    else
      overlay = %Plushie.DevOverlay{
        status: :failed,
        source: :elixir,
        message: "Build failed (elixir)",
        detail: Enum.join(Enum.reverse(errors), "\n\n"),
        expanded: true
      }

      state = %{state | overlay_expanded: true}
      send(state.runtime, {:dev_overlay, overlay})
      Logger.warning("plushie dev: #{length(errors)} file(s) failed to compile")
    end

    state
  end

  # ---------------------------------------------------------------------------
  # Rust build
  # ---------------------------------------------------------------------------

  defp start_rust_build(state) do
    state = kill_rust_build(state)
    state = %{state | rust_build_output: ""}

    overlay = %Plushie.DevOverlay{
      status: :building,
      source: :rust,
      message: "Rebuilding... (rust)",
      detail: "",
      expanded: state.overlay_expanded
    }

    send(state.runtime, {:dev_overlay, overlay})

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

      overlay = %{
        overlay
        | status: :failed,
          message: "Build failed (rust)",
          detail: "cargo not found or build workspace missing"
      }

      send(state.runtime, {:dev_overlay, overlay})
      state
    end
  end

  defp kill_rust_build(%{rust_build_port: nil} = state), do: state

  defp kill_rust_build(%{rust_build_port: port} = state) do
    Port.close(port)
    %{state | rust_build_port: nil, rust_build_output: ""}
  rescue
    # Port already closed.
    ArgumentError -> %{state | rust_build_port: nil, rust_build_output: ""}
  end

  # ---------------------------------------------------------------------------
  # Rust watcher setup
  # ---------------------------------------------------------------------------

  defp start_rust_watcher(nil), do: nil

  defp start_rust_watcher(_bridge) do
    crate_dirs = native_extension_dirs()

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

  defp native_extension_dirs do
    extensions = Application.get_env(:plushie, :extensions, [])

    Enum.flat_map(extensions, fn mod ->
      if Code.ensure_loaded?(mod) and function_exported?(mod, :native_crate, 0) do
        crate_rel = mod.native_crate()
        path = Path.expand(crate_rel)
        if File.dir?(path), do: [path], else: []
      else
        []
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # File type detection
  # ---------------------------------------------------------------------------

  defp watchable_elixir?(path) do
    ext = Path.extname(path)
    ext in @elixir_extensions and not String.contains?(path, "/_build/")
  end

  defp watchable_rust?(path) do
    ext = Path.extname(path)
    ext in @rust_extensions and not String.contains?(path, "/target/")
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
