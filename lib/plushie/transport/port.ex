defmodule Plushie.Transport.Port do
  @moduledoc """
  Transport implementation for Erlang Port-based connections.

  Handles two modes:

  - `:spawn` (default) spawns the renderer binary as a child process.
    Supports restart on crash (the bridge re-opens the port).
  - `:stdio` reads/writes the BEAM's own stdin/stdout. Used when the
    renderer spawns the Elixir process (e.g. `plushie --exec`).
  """

  @behaviour Plushie.Transport

  require Logger

  @type t :: %__MODULE__{
          port: port() | nil,
          mode: :spawn | :stdio,
          format: :msgpack | :json,
          renderer_path: String.t() | nil,
          renderer_args: [String.t()],
          log_level: atom()
        }

  defstruct [:port, :mode, :format, :renderer_path, :renderer_args, :log_level]

  @impl Plushie.Transport
  def init(opts) do
    mode = Keyword.fetch!(opts, :mode)
    format = Keyword.fetch!(opts, :format)

    state = %__MODULE__{
      port: nil,
      mode: mode,
      format: format,
      renderer_path: Keyword.get(opts, :renderer_path),
      renderer_args: Keyword.get(opts, :renderer_args, []),
      log_level: Keyword.get(opts, :log_level, :error)
    }

    open(state)
  end

  @impl Plushie.Transport
  def send_data(%{port: nil}, _data), do: {:error, :port_closed}

  def send_data(%{port: port} = state, data) when is_port(port) do
    byte_size = IO.iodata_length(data)

    try do
      Port.command(port, data)

      :telemetry.execute([:plushie, :bridge, :send], %{byte_size: byte_size}, %{
        bridge: self()
      })

      {:ok, state}
    rescue
      ArgumentError ->
        Logger.warning("plushie bridge: port closed during send")
        {:error, :port_closed}
    end
  end

  @impl Plushie.Transport
  def close(%{port: port}) when is_port(port) do
    Port.close(port)
    :ok
  catch
    _, _ -> :ok
  end

  def close(_state), do: :ok

  @impl Plushie.Transport
  def handle_info({port, {:data, binary}}, %{port: port, format: :msgpack} = state) do
    {:data, binary, state}
  end

  def handle_info({port, {:data, {:eol, chunk}}}, %{port: port} = state) do
    {:data, {:eol, chunk}, state}
  end

  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    {:data, {:noeol, chunk}, state}
  end

  def handle_info({port, :eof}, %{port: port, mode: :stdio} = state) do
    {:closed, :normal, %{state | port: nil}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    {:closed, {:exit_status, status}, %{state | port: nil}}
  end

  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    {:closed, reason, %{state | port: nil}}
  end

  def handle_info(_msg, _state), do: :ignore

  @impl Plushie.Transport
  def restartable?(%{mode: :spawn}), do: true
  def restartable?(_state), do: false

  @impl Plushie.Transport
  def transport_ready?(%{port: port}) when is_port(port), do: true
  def transport_ready?(_state), do: false

  @impl Plushie.Transport
  @spec reopen(t :: %__MODULE__{}) :: {:ok, %__MODULE__{}} | {:error, term()}
  def reopen(state) do
    open(%{state | port: nil})
  end

  defp open(%{mode: :stdio} = state) do
    port_opts =
      case state.format do
        :msgpack -> [:binary, :eof, {:packet, 4}]
        :json -> [:binary, :eof, {:line, 65_536}]
      end

    port = Port.open({:fd, 0, 1}, port_opts)
    {:ok, %{state | port: port}}
  end

  defp open(%{mode: :spawn} = state) do
    path = state.renderer_path

    if File.exists?(path) do
      port_opts =
        case state.format do
          :msgpack -> [:binary, :exit_status, :use_stdio, {:packet, 4}]
          :json -> [:binary, :exit_status, :use_stdio, {:line, 65_536}]
        end

      format_args = if state.format == :json, do: ["--json"], else: []
      args = state.renderer_args ++ format_args
      env = Plushie.RendererEnv.build(rust_log: rust_log_value(state.log_level))

      port =
        Port.open({:spawn_executable, path}, [{:args, args}, {:env, env} | port_opts])

      {:ok, %{state | port: port}}
    else
      {:error, {:renderer_not_found, path}}
    end
  end

  defp rust_log_value(level) do
    if System.get_env("RUST_LOG") do
      nil
    else
      case level do
        :off -> "off"
        :error -> "plushie=error"
        :warning -> "plushie=warn"
        :info -> "plushie=info"
        :debug -> "plushie=debug"
      end
    end
  end
end
