defmodule Plushie.Connect do
  @moduledoc """
  Runs a Plushie application from a standalone entry point.

  When `PLUSHIE_SOCKET` is set, it connects to an already-listening
  renderer. Otherwise it starts the renderer as a child process using
  normal Plushie binary resolution, including `PLUSHIE_BINARY_PATH`.
  """

  @type option ::
          {:socket, String.t()}
          | {:token, String.t() | nil}
          | {:format, :msgpack | :json}
          | {:daemon, boolean()}
          | {:name, atom()}
          | {:app_opts, term()}

  @doc """
  Runs `app_module` and blocks until it exits.

  Socket resolution order:

  - `:socket` option
  - `PLUSHIE_SOCKET` environment variable

  Token resolution order:

  - `:token` option
  - `PLUSHIE_TOKEN` environment variable
  - JSON negotiation line on stdin, read with a short timeout

  Returns `:ok` when the Plushie supervisor exits normally, or
  `{:error, reason}` when connection or startup fails.
  """
  @spec run(module(), [option()]) :: :ok | {:error, term()}
  def run(app_module, opts \\ []) when is_atom(app_module) and is_list(opts) do
    format = Keyword.get(opts, :format, :msgpack)
    daemon = Keyword.get(opts, :daemon, false)

    with :ok <- validate_format(format) do
      case resolve_socket(opts) do
        {:ok, socket} -> run_socket(app_module, socket, opts, format, daemon)
        :spawn -> run_spawn(app_module, opts, format, daemon)
      end
    end
  end

  @doc """
  Same as `run/2`, but raises on failure.
  """
  @spec run!(module(), [option()]) :: :ok
  def run!(app_module, opts \\ []) do
    case run(app_module, opts) do
      :ok -> :ok
      {:error, reason} -> raise RuntimeError, "failed to connect Plushie app: #{inspect(reason)}"
    end
  end

  @doc false
  @spec resolve_token([option()]) :: String.t() | nil
  def resolve_token(opts) do
    cond do
      Keyword.has_key?(opts, :token) ->
        Keyword.get(opts, :token)

      (env_token = System.get_env("PLUSHIE_TOKEN")) != nil ->
        env_token

      true ->
        read_token_from_stdin()
    end
  end

  defp validate_format(format) when format in [:msgpack, :json], do: :ok
  defp validate_format(format), do: {:error, {:invalid_format, format}}

  defp resolve_socket(opts) do
    case Keyword.get(opts, :socket) || System.get_env("PLUSHIE_SOCKET") do
      socket when is_binary(socket) and socket != "" -> {:ok, socket}
      _ -> :spawn
    end
  end

  defp run_socket(app_module, socket, opts, format, daemon) do
    token = resolve_token(opts)

    with {:ok, adapter} <- Plushie.SocketAdapter.start_link(socket, format),
         {:ok, pid} <-
           Plushie.start_link(app_module,
             transport: {:iostream, adapter},
             format: format,
             daemon: daemon,
             token: token,
             name: Keyword.get(opts, :name, Plushie),
             app_opts: Keyword.get(opts, :app_opts, [])
           ) do
      wait(pid)
    else
      {:error, {:shutdown, {:connect_failed, reason}}} -> {:error, {:connect_failed, reason}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_spawn(app_module, opts, format, daemon) do
    case Plushie.start_link(app_module,
           format: format,
           daemon: daemon,
           name: Keyword.get(opts, :name, Plushie),
           app_opts: Keyword.get(opts, :app_opts, [])
         ) do
      {:ok, pid} -> wait(pid)
      {:error, reason} -> {:error, reason}
    end
  end

  defp wait(pid) do
    ref = Process.monitor(pid)

    receive do
      {:DOWN, ^ref, :process, _, _reason} -> :ok
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
