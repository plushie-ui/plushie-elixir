defmodule Mix.Tasks.Julep.Gui do
  @moduledoc """
  Starts a Julep GUI application.

  ## Usage

      mix julep.gui MyApp
      mix julep.gui MyApp --build
      mix julep.gui MyApp --release

  ## Options

  - `--build` -- Build the renderer binary before starting (cargo build)
  - `--release` -- Use the release build of the renderer
  - `--json` -- Use JSON instead of MessagePack for wire protocol (opt-in for debugging)
  """

  use Mix.Task

  @shortdoc "Start a Julep GUI application"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [build: :boolean, release: :boolean, json: :boolean]
      )

    app_module =
      case args do
        [mod_str | _] ->
          Module.concat([mod_str])

        [] ->
          Mix.raise("Usage: mix julep.gui ModuleName")
      end

    # Ensure the project is compiled
    Mix.Task.run("compile")

    # Build renderer if requested
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
          if File.exists?(release_path), do: release_path, else: Julep.Binary.renderer_path()
        else
          Julep.Binary.renderer_path()
        end
      end

    unless File.exists?(renderer_path) do
      Mix.raise("""
      Renderer binary not found at #{renderer_path}.
      Run `mix julep.gui #{inspect(app_module)} --build` to build it,
      or build manually with: cd ../julep-renderer && cargo build
      """)
    end

    # Start the application (ensures Logger etc are running)
    Mix.Task.run("app.start")

    # Start Julep with the given app module
    start_opts = [renderer: renderer_path]

    start_opts =
      if opts[:json], do: Keyword.put(start_opts, :format, :json), else: start_opts

    case Julep.start(app_module, start_opts) do
      {:ok, pid} ->
        Mix.shell().info("Julep started with #{inspect(app_module)}")
        # Block until the supervisor exits
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            if reason != :normal do
              Mix.raise("Julep exited with reason: #{inspect(reason)}")
            end
        end

      {:error, reason} ->
        Mix.raise("Failed to start Julep: #{inspect(reason)}")
    end
  end

  defp build_renderer(release?) do
    source_dir = Mix.JulepHelpers.renderer_source_path()
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
    Mix.JulepHelpers.renderer_binary_path(release?)
  end
end
