defmodule Mix.Tasks.Julep.Dev do
  @moduledoc """
  Starts a Julep GUI application with live code reloading.

  This is a convenience wrapper around `Julep.start(MyApp, dev: true)`.
  The same thing works from an IEx session without this task.

  ## Usage

      mix julep.dev MyApp
      mix julep.dev MyApp --build

  ## Options

  - `--build` -- Build the renderer binary before starting (cargo build)
  - `--release` -- Use the release build of the renderer
  - `--debounce` -- Debounce interval in ms (default: 100)
  """

  use Mix.Task

  @shortdoc "Start a Julep app with live code reloading"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} = OptionParser.parse(args,
      strict: [build: :boolean, release: :boolean, debounce: :integer]
    )

    app_module = case args do
      [mod_str | _] ->
        Module.concat([mod_str])
      [] ->
        Mix.raise("Usage: mix julep.dev ModuleName")
    end

    Mix.Task.run("compile")

    if opts[:build] do
      build_renderer(opts[:release] || false)
    end

    renderer_path = renderer_path(opts[:release] || false)

    unless File.exists?(renderer_path) do
      Mix.raise("""
      Renderer binary not found at #{renderer_path}.
      Run `mix julep.dev #{inspect(app_module)} --build` to build it,
      or build manually with: cargo build --manifest-path native/julep_gui/Cargo.toml
      """)
    end

    Mix.Task.run("app.start")

    dev_opts =
      if debounce = opts[:debounce] do
        [debounce_ms: debounce]
      else
        []
      end

    case Julep.start(app_module, renderer: renderer_path, dev: true, dev_opts: dev_opts) do
      {:ok, pid} ->
        Mix.shell().info("Julep dev mode -- #{inspect(app_module)}")
        Mix.shell().info("Watching lib/ for changes")

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
