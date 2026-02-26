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
  """

  use Mix.Task

  @shortdoc "Start a Julep GUI application"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args,
      strict: [build: :boolean, release: :boolean]
    )

    app_module = case args do
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

    renderer_path = renderer_path(opts[:release] || false)

    unless File.exists?(renderer_path) do
      Mix.raise("""
      Renderer binary not found at #{renderer_path}.
      Run `mix julep.gui #{inspect(app_module)} --build` to build it,
      or build manually with: cargo build --manifest-path native/julep_gui/Cargo.toml
      """)
    end

    # Start the application (ensures Logger etc are running)
    Mix.Task.run("app.start")

    # Start Julep with the given app module
    case Julep.start(app_module, renderer: renderer_path) do
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
    args = ["build", "--manifest-path", "native/julep_gui/Cargo.toml"]
    args = if release?, do: args ++ ["--release"], else: args

    Mix.shell().info("Building renderer...")
    case System.cmd("cargo", args, stderr_to_stdout: true, into: IO.stream(:stdio, :line)) do
      {_, 0} -> :ok
      {_, code} -> Mix.raise("cargo build failed with exit code #{code}")
    end
  end

  defp renderer_path(release?) do
    profile = if release?, do: "release", else: "debug"
    Path.expand("native/julep_gui/target/#{profile}/julep_gui")
  end
end
