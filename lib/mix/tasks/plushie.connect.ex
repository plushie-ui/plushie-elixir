defmodule Mix.Tasks.Plushie.Connect do
  @shortdoc "Connect to a plushie renderer"
  @moduledoc """
  Runs a Plushie application that connects to an already-listening
  renderer via a Unix domain socket or TCP port.

  ## Usage

      mix plushie.connect MyApp                              # socket from env, token from env/stdin
      mix plushie.connect MyApp /tmp/plushie.sock            # explicit socket
      mix plushie.connect MyApp :4567                        # explicit TCP port
      mix plushie.connect MyApp /path.sock --token TOKEN     # explicit token

  ## How it connects

  The renderer (`plushie --listen`) creates a socket and either spawns
  this task (via `--exec`) or prints connection info for manual use.

  **Launched by `--listen --exec`**: The renderer sets `PLUSHIE_SOCKET`
  and `PLUSHIE_TOKEN` in the environment and writes a JSON negotiation
  line to stdin. The task reads the token from the environment first,
  falling back to stdin if env vars weren't forwarded (e.g., over SSH).

  **Manual connect**: The user copies the socket path and token from
  the renderer's output and provides them as CLI arguments.

  ## Token resolution (in order)

  1. `--token` CLI flag
  2. `PLUSHIE_TOKEN` environment variable
  3. JSON line from stdin (1 second timeout): `{"token":"...","protocol":1}`
  4. No token (connect without -- renderer decides if that's OK)

  If the token is resolved from steps 1 or 2, stdin is not read.

  ## Socket resolution (in order)

  1. Positional CLI argument after the module name
  2. `PLUSHIE_SOCKET` environment variable
  3. Error

  ## Options

    * `--token TOKEN` -- shared token for authentication
    * `--json` -- use JSON wire format instead of MessagePack
    * `--daemon` -- keep running after all windows close
  """

  use Mix.Task

  @switches [token: :string, json: :boolean, daemon: :boolean]

  @impl Mix.Task
  def run(args) do
    {opts, argv} = OptionParser.parse!(args, strict: @switches)

    {app_module, socket_addr} =
      case argv do
        [module_str, addr | _] -> {Module.concat([module_str]), addr}
        [module_str] -> {Module.concat([module_str]), nil}
        [] -> Mix.raise("Usage: mix plushie.connect MyModule [socket_path_or_addr]")
      end

    format = if opts[:json], do: :json, else: :msgpack
    daemon = Keyword.get(opts, :daemon, false)

    # Start the application and dependencies.
    Mix.Task.run("app.start")

    validate_module!(app_module)

    # Resolve socket address.
    socket =
      socket_addr || System.get_env("PLUSHIE_SOCKET") ||
        Mix.raise("No socket address provided. Pass as argument or set PLUSHIE_SOCKET.")

    # Resolve token (--token > env > stdin > none).
    token = resolve_token(opts[:token])

    # Connect to the renderer's socket via the iostream adapter.
    adapter =
      case Plushie.SocketAdapter.start_link(socket, format) do
        {:ok, pid} ->
          pid

        {:error, reason} ->
          Mix.raise("""
          Could not connect to renderer at #{socket}: #{inspect(reason)}

          Make sure the renderer is running with --listen and the socket
          path is correct. You can also set PLUSHIE_SOCKET in the environment.
          """)
      end

    case Plushie.start_link(app_module,
           transport: {:iostream, adapter},
           format: format,
           daemon: daemon,
           token: token
         ) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, _, _reason} -> :ok
        end

      {:error, reason} ->
        Mix.raise("Failed to start plushie: #{inspect(reason)}")
    end
  end

  defp validate_module!(mod) do
    unless Code.ensure_loaded?(mod) do
      Mix.raise("""
      Module #{inspect(mod)} could not be loaded.

      Make sure the module name is correct and the project compiles.
      """)
    end
  end

  defp resolve_token(cli_token) do
    cond do
      cli_token != nil ->
        cli_token

      (env_token = System.get_env("PLUSHIE_TOKEN")) != nil ->
        env_token

      true ->
        read_token_from_stdin()
    end
  end

  defp read_token_from_stdin do
    task =
      Task.async(fn ->
        case IO.gets("") do
          :eof -> nil
          {:error, _} -> nil
          line when is_binary(line) -> parse_negotiation_json(String.trim(line))
        end
      end)

    case Task.yield(task, 1_000) || Task.shutdown(task, :brutal_kill) do
      {:ok, token} -> token
      _ -> nil
    end
  end

  defp parse_negotiation_json(line) do
    case Jason.decode(line) do
      {:ok, %{"token" => token}} when is_binary(token) -> token
      _ -> nil
    end
  end
end
