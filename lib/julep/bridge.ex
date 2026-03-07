defmodule Julep.Bridge do
  @moduledoc """
  Port-based bridge to the julep_gui renderer process.

  Manages the stdio Port, buffers partial JSONL lines (JSON mode) or receives
  length-prefixed frames (MessagePack mode), and forwards decoded events to
  the runtime process.

  Supports two wire formats controlled by the `:format` option:

  - `:json` -- JSONL over stdio. Opt-in for debugging and observability. The Port is opened with
    `{:line, 65_536}`, which causes the driver to deliver data as
    `{port, {:data, {:eol, line}}}` for complete lines and
    `{port, {:data, {:noeol, chunk}}}` for partial lines that exceed the
    line buffer. Partial chunks are accumulated in `buffer` and flushed when
    the matching `:eol` chunk arrives.

  - `:msgpack` (default) -- MessagePack over stdio with 4-byte big-endian
    length-prefixed framing. The Port is opened with `{:packet, 4}`, which
    causes the Erlang Port driver to handle framing automatically in both
    directions. Complete frames arrive as `{port, {:data, binary}}`.

  On unexpected exit the bridge applies exponential back-off and attempts
  to restart the renderer up to `max_restarts` times. If the limit is
  exhausted the GenServer stops with `{:max_restarts_reached, reason}`.
  """
  use GenServer

  require Logger

  # Maximum accumulated buffer size for partial JSON lines (64 MiB).
  @max_buffer_size 64 * 1024 * 1024

  # Maximum exponential backoff delay in milliseconds.
  @max_backoff_ms 5_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the bridge linked to the calling process.

  Required opts:
    - `:renderer_path` - filesystem path to the julep_gui binary
    - `:runtime`       - pid to receive `{:renderer_event, event}` messages

  Optional opts:
    - `:name`          - registration name passed to `GenServer.start_link/3`
    - `:format`        - wire format, `:msgpack` (default) or `:json`
    - `:log_level`     - renderer log level (`:error`, `:warning`, `:info`, `:debug`).
                         Default: `:error`. Ignored when `RUST_LOG` is set in the environment.
    - `:max_restarts`  - max restart attempts before giving up (default: 5)
    - `:restart_delay` - base delay in ms for exponential back-off (default: 100)
  """
  @spec start_link(opts :: keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc "Sends application-level settings to the renderer."
  @spec send_settings(bridge :: GenServer.server(), settings :: map()) :: :ok
  def send_settings(bridge, settings) do
    GenServer.cast(bridge, {:send_settings, settings})
  end

  @doc "Sends an encoded snapshot of `tree` to the renderer."
  @spec send_snapshot(bridge :: GenServer.server(), tree :: map()) :: :ok
  def send_snapshot(bridge, tree) do
    GenServer.cast(bridge, {:send_snapshot, tree})
  end

  @doc "Sends a patch (list of diff ops) to the renderer."
  @spec send_patch(bridge :: GenServer.server(), ops :: [map()]) :: :ok
  def send_patch(bridge, ops) do
    GenServer.cast(bridge, {:send_patch, ops})
  end

  @doc "Sends an effect request to the renderer."
  @spec send_effect_request(
          bridge :: GenServer.server(),
          id :: String.t(),
          kind :: String.t(),
          payload :: map()
        ) :: :ok
  def send_effect_request(bridge, id, kind, payload) do
    GenServer.cast(bridge, {:send_effect_request, id, kind, payload})
  end

  @doc "Sends a widget operation to the renderer."
  @spec send_widget_op(bridge :: GenServer.server(), op :: String.t(), payload :: map()) :: :ok
  def send_widget_op(bridge, op, payload) do
    GenServer.cast(bridge, {:send_widget_op, op, payload})
  end

  @doc "Registers a renderer-side subscription."
  @spec send_subscription_register(
          bridge :: GenServer.server(),
          kind :: String.t(),
          tag :: String.t()
        ) :: :ok
  def send_subscription_register(bridge, kind, tag) do
    GenServer.cast(bridge, {:send_subscription_register, kind, tag})
  end

  @doc "Unregisters a renderer-side subscription."
  @spec send_subscription_unregister(bridge :: GenServer.server(), kind :: String.t()) :: :ok
  def send_subscription_unregister(bridge, kind) do
    GenServer.cast(bridge, {:send_subscription_unregister, kind})
  end

  @doc "Sends a window lifecycle operation to the renderer."
  @spec send_window_op(
          bridge :: GenServer.server(),
          op :: String.t(),
          window_id :: String.t(),
          settings :: map()
        ) :: :ok
  def send_window_op(bridge, op, window_id, settings \\ %{}) do
    GenServer.cast(bridge, {:send_window_op, op, window_id, settings})
  end

  @doc "Sends an image operation (create/update/delete) to the renderer."
  @spec send_image_op(bridge :: GenServer.server(), op :: String.t(), payload :: map()) :: :ok
  def send_image_op(bridge, op, payload) do
    GenServer.cast(bridge, {:send_image_op, op, payload})
  end

  @doc "Sends a single extension command to the renderer."
  @spec send_extension_command(
          bridge :: GenServer.server(),
          node_id :: String.t(),
          op :: String.t(),
          payload :: map()
        ) :: :ok
  def send_extension_command(bridge, node_id, op, payload) do
    GenServer.cast(bridge, {:send_extension_command, node_id, op, payload})
  end

  @doc "Sends a batch of extension commands to the renderer."
  @spec send_extension_commands(
          bridge :: GenServer.server(),
          commands :: [{String.t(), String.t(), map()}]
        ) :: :ok
  def send_extension_commands(bridge, commands) do
    GenServer.cast(bridge, {:send_extension_commands, commands})
  end

  @doc "Stops the bridge GenServer."
  @spec stop(bridge :: GenServer.server()) :: :ok
  def stop(bridge) do
    GenServer.stop(bridge)
  end

  # ---------------------------------------------------------------------------
  # State
  # ---------------------------------------------------------------------------

  defstruct [
    :port,
    :runtime,
    :renderer_path,
    :buffer,
    :format,
    :log_level,
    :max_restarts,
    :restart_count,
    :restart_delay
  ]

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    renderer_path = Keyword.fetch!(opts, :renderer_path)
    runtime = Keyword.fetch!(opts, :runtime)
    format = Keyword.get(opts, :format, :msgpack)

    log_level = Keyword.get(opts, :log_level, :error)

    state = %__MODULE__{
      port: nil,
      runtime: runtime,
      renderer_path: renderer_path,
      buffer: "",
      format: format,
      log_level: log_level,
      max_restarts: Keyword.get(opts, :max_restarts, 5),
      restart_count: 0,
      restart_delay: Keyword.get(opts, :restart_delay, 100)
    }

    case open_port(state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:send_settings, settings}, state) do
    data = Julep.Protocol.encode_settings(settings, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_snapshot, tree}, state) do
    data = Julep.Protocol.encode_snapshot(tree, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_patch, ops}, state) do
    data = Julep.Protocol.encode_patch(ops, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_effect_request, id, kind, payload}, state) do
    data = Julep.Protocol.encode_effect_request(id, kind, payload, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_widget_op, op, payload}, state) do
    data = Julep.Protocol.encode_widget_op(op, payload, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_subscription_register, kind, tag}, state) do
    data = Julep.Protocol.encode_subscription_register(kind, tag, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_subscription_unregister, kind}, state) do
    data = Julep.Protocol.encode_subscription_unregister(kind, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_window_op, op, window_id, settings}, state) do
    data = Julep.Protocol.encode_window_op(op, window_id, settings, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_image_op, op, payload}, state) do
    data = Julep.Protocol.encode_image_op(op, payload, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_extension_command, node_id, op, payload}, state) do
    data = Julep.Protocol.encode_extension_command(node_id, op, payload, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  def handle_cast({:send_extension_commands, commands}, state) do
    data = Julep.Protocol.encode_extension_commands(commands, state.format)
    send_to_port(state.port, data)
    {:noreply, state}
  end

  # MessagePack frame -- {:packet, 4} driver delivers raw binaries.
  @impl true
  def handle_info({port, {:data, binary}}, %{port: port, format: :msgpack} = state)
      when is_binary(binary) do
    state = dispatch_message(binary, :msgpack, state)
    {:noreply, state}
  end

  # Complete line -- flush any buffered prefix and dispatch.
  def handle_info({port, {:data, {:eol, chunk}}}, %{port: port} = state) do
    line = state.buffer <> to_string(chunk)
    state = dispatch_message(line, :json, %{state | buffer: ""})
    {:noreply, state}
  end

  # Partial line exceeding {:line, N} -- accumulate.
  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    new_buffer = state.buffer <> to_string(chunk)

    if byte_size(new_buffer) > @max_buffer_size do
      Logger.error(
        "julep bridge: JSON buffer exceeded #{@max_buffer_size} bytes, dropping message"
      )

      {:noreply, %{state | buffer: ""}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    # Clean exit (user closed window). Stop normally -- don't restart.
    Logger.info("julep bridge: renderer exited cleanly (status 0)")
    send(state.runtime, {:renderer_exit, :normal})
    {:stop, :normal, %{state | port: nil}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    handle_port_exit(state, {:exit_status, status})
  end

  def handle_info({:DOWN, _ref, :port, port, reason}, %{port: port} = state) do
    handle_port_exit(state, reason)
  end

  def handle_info(:restart_renderer, state) do
    case open_port(state) do
      {:ok, state} ->
        new_count = state.restart_count + 1
        :telemetry.execute([:julep, :bridge, :restart], %{count: new_count}, %{})
        send(state.runtime, :renderer_restarted)
        {:noreply, %{state | restart_count: new_count}}

      {:error, reason} ->
        {:stop, {:renderer_restart_failed, reason}, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{port: port} = _state) when is_port(port) do
    Port.close(port)
  catch
    _, _ -> :ok
  end

  def terminate(_reason, _state), do: :ok

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp open_port(state) do
    path = state.renderer_path

    if File.exists?(path) do
      port_opts =
        case state.format do
          :msgpack -> [:binary, :exit_status, :use_stdio, {:packet, 4}]
          :json -> [:binary, :exit_status, :use_stdio, {:line, 65_536}]
        end

      args = if state.format == :json, do: ["--json"], else: []
      env = renderer_env(state.log_level)

      port =
        Port.open({:spawn_executable, path}, [{:args, args}, {:env, env} | port_opts])

      {:ok, %{state | port: port, buffer: ""}}
    else
      {:error, {:renderer_not_found, path}}
    end
  end

  # Build the environment variables for the renderer Port. Sets RUST_LOG
  # when an explicit :log_level was configured, but only when the system
  # environment doesn't already have RUST_LOG set (env var always wins).
  defp renderer_env(log_level) do
    if System.get_env("RUST_LOG") do
      []
    else
      rust_log =
        case log_level do
          :error -> "julep_gui=error"
          :warning -> "julep_gui=warn"
          :info -> "julep_gui=info"
          :debug -> "julep_gui=debug"
        end

      [{~c"RUST_LOG", String.to_charlist(rust_log)}]
    end
  end

  defp send_to_port(nil, _data), do: :ok

  defp send_to_port(port, data) when is_port(port) do
    Port.command(port, data)
    # byte_size measures payload size (excludes framing overhead in both
    # JSON and msgpack modes). This is intentionally consistent across
    # formats -- framing is a transport concern, not a telemetry concern.
    :telemetry.execute([:julep, :bridge, :send], %{byte_size: IO.iodata_length(data)}, %{})
  rescue
    ArgumentError ->
      Logger.warning("julep bridge: port closed during send")
      :error
  end

  defp dispatch_message(data, format, state) do
    :telemetry.execute([:julep, :bridge, :receive], %{byte_size: byte_size(data)}, %{})

    case Julep.Protocol.decode_message(data, format) do
      {:error, reason} ->
        Logger.warning("julep bridge: failed to decode message: #{inspect(reason)}")
        :telemetry.execute([:julep, :bridge, :decode_error], %{}, %{reason: reason})
        state

      event ->
        send(state.runtime, {:renderer_event, event})
        # Reset restart count on first successful message from the renderer.
        %{state | restart_count: 0}
    end
  end

  defp handle_port_exit(state, reason) do
    send(state.runtime, {:renderer_exit, reason})

    if state.restart_count < state.max_restarts do
      delay = min(round(state.restart_delay * :math.pow(2, state.restart_count)), @max_backoff_ms)
      Process.send_after(self(), :restart_renderer, delay)
      {:noreply, %{state | port: nil}}
    else
      Logger.error("""
      julep bridge: renderer crashed #{state.max_restarts} times, giving up.

      Troubleshooting:
        1. Check RUST_LOG=julep_gui=debug for renderer errors
        2. Verify the binary exists: mix julep.build
        3. Check system dependencies (libxkbcommon, etc.)
        4. Try running the renderer directly: ./path/to/julep_gui --json
      """)

      :telemetry.execute([:julep, :bridge, :max_restarts_reached], %{}, %{
        reason: reason,
        max_restarts: state.max_restarts
      })

      {:stop, {:max_restarts_reached, reason}, state}
    end
  end
end
