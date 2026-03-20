defmodule Mix.Tasks.Toddy.Stdio do
  @shortdoc "Run a toddy app as a stdio protocol process"
  @moduledoc """
  Runs a Toddy application reading/writing the wire protocol on
  stdin/stdout.

  This is the companion to the renderer's `--exec` flag, which spawns
  a host process and communicates with it over stdio.

      mix toddy.stdio MyApp
      mix toddy.stdio MyApp --json

  ## Options

    * `--json` -- use JSON wire format instead of MessagePack (default)
    * `--daemon` -- keep running after all windows close

  ## Stdio conventions

  stdout is exclusively the protocol channel. All log output is
  redirected to stderr. Application code must not write to stdout
  (use Logger, which is redirected automatically).

  ## Usage with toddy --exec

      # Local (renderer spawns Elixir):
      toddy --exec "mix toddy.stdio MyApp"

      # Remote via SSH:
      toddy --exec "ssh user@server 'cd /app && mix toddy.stdio MyApp'"
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: [json: :boolean, daemon: :boolean])

    app_module =
      case argv do
        [module_str | _] -> Module.concat([module_str])
        [] -> Mix.raise("Usage: mix toddy.stdio MyModule")
      end

    format = if opts[:json], do: :json, else: :msgpack
    daemon = Keyword.get(opts, :daemon, false)

    # Redirect all logging to stderr so stdout is exclusively protocol.
    :logger.update_handler_config(:default, %{config: %{type: :standard_error}})

    # Suppress any accidental stdout from Mix shell.
    Mix.shell(Mix.Shell.Quiet)

    # Start the application and dependencies.
    Mix.Task.run("app.start")

    # Start Toddy in stdio mode.
    case Toddy.start_link(app_module, transport: :stdio, format: format, daemon: daemon) do
      {:ok, _pid} ->
        # Block until the supervisor exits.
        # The supervisor will stop when Bridge detects stdin EOF.
        ref = Process.monitor(Process.whereis(:"Toddy.Supervisor"))

        receive do
          {:DOWN, ^ref, :process, _, _reason} -> :ok
        end

      {:error, reason} ->
        Mix.raise("Failed to start toddy: #{inspect(reason)}")
    end
  end
end
