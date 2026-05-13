defmodule Mix.Tasks.Plushie.Gui do
  @moduledoc """
  Starts a Plushie GUI application.

  ## Usage

      mix plushie.gui MyApp
      mix plushie.gui MyApp --build
      mix plushie.gui MyApp --no-watch

  ## Options

  - `--build` - Build the plushie binary before starting
  - `--release` - Use the release build
  - `--json` - Use JSON wire protocol (debugging)
  - `--watch` - Enable file watching and live reload
  - `--no-watch` - Disable file watching
  - `--debounce` - File watch debounce interval in ms (default: 100)
  - `--daemon` - Keep running after the last window closes

  ## File watching

  File watching is opt-in. Enable it with `--watch` or by setting
  `config :plushie, code_reloader: true` in your config. When active,
  editing any `.ex` file under `lib/` recompiles and updates the GUI
  in place, preserving application state.
  """

  use Mix.Task

  @shortdoc "Start a Plushie GUI application"

  @switches [
    build: :boolean,
    release: :boolean,
    json: :boolean,
    watch: :boolean,
    debounce: :integer,
    daemon: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, args} = OptionParser.parse!(args, strict: @switches)

    app_module =
      case args do
        [mod_str | _] -> Module.concat([mod_str])
        [] -> Mix.raise("Usage: mix plushie.gui ModuleName")
      end

    watch? = resolve_watch_flag(opts)

    Mix.Task.run("compile")

    Mix.PlushieHelpers.validate_module!(app_module)

    binary_path = Mix.PlushieHelpers.resolve_binary!(opts)
    Mix.Task.run("app.start")
    Mix.PlushieHelpers.warn_if_unconfigured()

    start_opts = [binary: binary_path]
    start_opts = if opts[:json], do: Keyword.put(start_opts, :format, :json), else: start_opts
    start_opts = if opts[:daemon], do: Keyword.put(start_opts, :daemon, true), else: start_opts

    start_opts =
      if watch? do
        reloader_opts = if opts[:debounce], do: [debounce_ms: opts[:debounce]], else: []

        Keyword.put(start_opts, :code_reloader, true)
        |> Keyword.put(:reloader_opts, reloader_opts)
      else
        start_opts
      end

    case Plushie.start_link(app_module, start_opts) do
      {:ok, pid} ->
        if watch? do
          Mix.shell().info(
            "Plushie started with #{inspect(app_module)} (watching lib/ for changes)"
          )
        else
          Mix.shell().info("Plushie started with #{inspect(app_module)}")
        end

        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, reason} ->
            if reason != :normal do
              Mix.raise("Plushie exited with reason: #{inspect(reason)}")
            end
        end

      {:error, reason} ->
        Mix.raise("Failed to start Plushie: #{inspect(reason)}")
    end
  end

  defp resolve_watch_flag(opts) do
    case Keyword.get(opts, :watch) do
      true ->
        Application.put_env(:plushie, :code_reloader, true)
        true

      false ->
        Application.put_env(:plushie, :code_reloader, false)
        false

      nil ->
        code_reloader_enabled?(Application.get_env(:plushie, :code_reloader, false))
    end
  end

  defp code_reloader_enabled?(nil), do: false
  defp code_reloader_enabled?(false), do: false
  defp code_reloader_enabled?(_), do: true
end
