defmodule Mix.Tasks.Toddy.Gui do
  @moduledoc """
  Starts a Toddy GUI application.

  ## Usage

      mix toddy.gui MyApp
      mix toddy.gui MyApp --build
      mix toddy.gui MyApp --no-watch

  ## Options

  - `--build` -- Build the toddy binary before starting
  - `--release` -- Use the release build
  - `--json` -- Use JSON wire protocol (debugging)
  - `--watch` -- Enable file watching and live reload (default in dev)
  - `--no-watch` -- Disable file watching
  - `--debounce` -- File watch debounce interval in ms (default: 100)
  - `--daemon` -- Keep running after the last window closes

  ## File watching

  In `MIX_ENV=dev`, file watching is enabled by default. Edit any
  `.ex` file under `lib/` and the GUI updates in place, preserving
  application state.

  In other environments, watching is disabled. Passing `--watch`
  outside of dev will raise an error.
  """

  use Mix.Task

  @shortdoc "Start a Toddy GUI application"

  @impl Mix.Task
  def run(args) do
    {opts, args, _} =
      OptionParser.parse(args,
        strict: [
          build: :boolean,
          release: :boolean,
          json: :boolean,
          watch: :boolean,
          debounce: :integer,
          daemon: :boolean
        ]
      )

    app_module =
      case args do
        [mod_str | _] -> Module.concat([mod_str])
        [] -> Mix.raise("Usage: mix toddy.gui ModuleName")
      end

    watch? = resolve_watch_flag(opts)

    Mix.Task.run("compile")

    binary_path = Mix.ToddyHelpers.resolve_binary!(opts)
    Mix.Task.run("app.start")

    start_opts = [binary: binary_path]
    start_opts = if opts[:json], do: Keyword.put(start_opts, :format, :json), else: start_opts
    start_opts = if opts[:daemon], do: Keyword.put(start_opts, :daemon, true), else: start_opts
    start_opts = if watch?, do: Keyword.merge(start_opts, dev_opts(opts)), else: start_opts

    case Toddy.start_link(app_module, start_opts) do
      {:ok, pid} ->
        if watch? do
          Mix.shell().info(
            "Toddy started with #{inspect(app_module)} (watching lib/ for changes)"
          )
        else
          Mix.shell().info("Toddy started with #{inspect(app_module)}")
        end

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

  defp resolve_watch_flag(opts) do
    explicit = Keyword.get(opts, :watch)

    case {explicit, Mix.env()} do
      {true, :dev} ->
        true

      {true, _} ->
        Mix.raise("--watch is only available in MIX_ENV=dev")

      {false, _} ->
        false

      {nil, :dev} ->
        true

      {nil, _} ->
        false
    end
  end

  defp dev_opts(opts) do
    dev_opts =
      case opts[:debounce] do
        nil -> []
        ms -> [debounce_ms: ms]
      end

    [dev: true, dev_opts: dev_opts]
  end
end
