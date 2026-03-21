defmodule Mix.Tasks.Plushie.Stdio do
  @shortdoc "Run a plushie app as a stdio protocol process"
  @moduledoc """
  Runs a Plushie application reading/writing the wire protocol on
  stdin/stdout.

  This is the companion to the renderer's `--exec` flag, which spawns
  a host process and communicates with it over stdio.

      mix plushie.stdio MyApp
      mix plushie.stdio MyApp --json

  ## Options

    * `--json` -- use JSON wire format instead of MessagePack (default)
    * `--daemon` -- keep running after all windows close

  ## Stdio conventions

  stdout is exclusively the protocol channel. All log output is
  redirected to stderr. Application code must not write to stdout
  (use Logger, which is redirected automatically).

  ## Usage with plushie --exec

      # Local (renderer spawns Elixir):
      plushie --exec "mix plushie.stdio MyApp"

      # Remote via SSH:
      plushie --exec "ssh user@server 'cd /app && mix plushie.stdio MyApp'"
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: [json: :boolean, daemon: :boolean])

    app_module =
      case argv do
        [module_str | _] -> Module.concat([module_str])
        [] -> Mix.raise("Usage: mix plushie.stdio MyModule")
      end

    format = if opts[:json], do: :json, else: :msgpack
    daemon = Keyword.get(opts, :daemon, false)

    # Redirect all logging to stderr so stdout is exclusively protocol.
    :logger.update_handler_config(:default, %{config: %{type: :standard_error}})

    # Suppress any accidental stdout from Mix shell.
    Mix.shell(Mix.Shell.Quiet)

    # Start the application and dependencies.
    Mix.Task.run("app.start")

    # Start Plushie in stdio mode.
    case Plushie.start_link(app_module, transport: :stdio, format: format, daemon: daemon) do
      {:ok, _pid} ->
        # Block until the supervisor exits.
        # The supervisor will stop when Bridge detects stdin EOF.
        ref = Process.monitor(Process.whereis(:"Plushie.Supervisor"))

        receive do
          {:DOWN, ^ref, :process, _, _reason} -> :ok
        end

      {:error, reason} ->
        Mix.raise("Failed to start plushie: #{inspect(reason)}")
    end
  end
end
