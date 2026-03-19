defmodule Mix.Tasks.Toddy.Dev do
  @moduledoc """
  Starts a Toddy GUI application with live code reloading.

  This is a convenience wrapper around `Toddy.start(MyApp, dev: true)`.
  The same thing works from an IEx session without this task.

  ## Usage

      mix toddy.dev MyApp
      mix toddy.dev MyApp --build

  ## Options

  - `--build` -- Build the renderer binary before starting (cargo build)
  - `--release` -- Use the release build of the renderer
  - `--debounce` -- Debounce interval in ms (default: 100)
  """

  use Mix.Task

  @shortdoc "Start a Toddy app with live code reloading"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [build: :boolean, release: :boolean, debounce: :integer]
      )

    app_module =
      case args do
        [mod_str | _] ->
          Module.concat([mod_str])

        [] ->
          Mix.raise("Usage: mix toddy.dev ModuleName")
      end

    Mix.Task.run("compile")

    if opts[:build] do
      build_renderer(opts[:release] || false)
    end

    renderer_path =
      if opts[:build] do
        # We just built it; use the known cargo output path
        local_build_path(opts[:release] || false)
      else
        # Try the smart resolver (env var, priv/bin/, dev build) first.
        # If --release was passed without --build, prefer the release dev build.
        if opts[:release] do
          release_path = local_build_path(true)
          if File.exists?(release_path), do: release_path, else: Toddy.Binary.renderer_path()
        else
          Toddy.Binary.renderer_path()
        end
      end

    unless File.exists?(renderer_path) do
      Mix.raise("""
      Renderer binary not found at #{renderer_path}.
      Run `mix toddy.dev #{inspect(app_module)} --build` to build it,
      or build manually with: cd ../toddy && cargo build
      """)
    end

    Mix.Task.run("app.start")

    dev_opts =
      if debounce = opts[:debounce] do
        [debounce_ms: debounce]
      else
        []
      end

    case Toddy.start(app_module, renderer: renderer_path, dev: true, dev_opts: dev_opts) do
      {:ok, pid} ->
        Mix.shell().info("Toddy dev mode -- #{inspect(app_module)}")
        Mix.shell().info("Watching lib/ for changes")

        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            if reason != :normal do
              Mix.raise("Toddy exited with reason: #{inspect(reason)}")
            end
        end

      {:error, reason} ->
        Mix.raise("Failed to start Toddy: #{inspect(reason)}")
    end
  end

  defp build_renderer(release?) do
    source_dir = Mix.ToddyHelpers.renderer_source_path()
    args = ["build"]
    args = if release?, do: args ++ ["--release"], else: args

    Mix.shell().info("Building renderer...")

    case System.cmd("cargo", args,
           stderr_to_stdout: true,
           into: IO.stream(:stdio, :line),
           cd: source_dir
         ) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("cargo build failed with exit code #{code}")
    end
  end

  defp local_build_path(release?) do
    Mix.ToddyHelpers.renderer_binary_path(release?)
  end
end
