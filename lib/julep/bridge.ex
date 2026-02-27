defmodule Julep.Bridge do
  @moduledoc """
  Port-based bridge to the julep_gui renderer process.

  Manages the stdio Port, buffers partial JSONL lines, and forwards
  decoded events to the runtime process.

  The Port is opened with `{:line, 65_536}`, which causes the driver to
  deliver data as `{port, {:data, {:eol, line}}}` for complete lines and
  `{port, {:data, {:noeol, chunk}}}` for partial lines that exceed the
  line buffer. Partial chunks are accumulated in `buffer` and flushed when
  the matching `:eol` chunk arrives.

  On unexpected exit the bridge applies exponential back-off and attempts
  to restart the renderer up to `max_restarts` times. If the limit is
  exhausted the GenServer stops with `{:max_restarts_reached, reason}`.
  """
  use GenServer

  require Logger

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
    - `:max_restarts`  - max restart attempts before giving up (default: 5)
    - `:restart_delay` - base delay in ms for exponential back-off (default: 100)
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc "Sends application-level settings to the renderer."
  def send_settings(bridge, settings) do
    GenServer.cast(bridge, {:send_settings, settings})
  end

  @doc "Sends an encoded snapshot of `tree` to the renderer."
  def send_snapshot(bridge, tree) do
    GenServer.cast(bridge, {:send_snapshot, tree})
  end

  @doc "Sends a patch (list of diff ops) to the renderer."
  def send_patch(bridge, ops) do
    GenServer.cast(bridge, {:send_patch, ops})
  end

  @doc "Sends an effect request to the renderer."
  def send_effect_request(bridge, id, kind, payload) do
    GenServer.cast(bridge, {:send_effect_request, id, kind, payload})
  end

  @doc "Sends a widget operation to the renderer."
  def send_widget_op(bridge, op, payload) do
    GenServer.cast(bridge, {:send_widget_op, op, payload})
  end

  @doc "Registers a renderer-side subscription."
  def send_subscription_register(bridge, kind, tag) do
    GenServer.cast(bridge, {:send_subscription_register, kind, tag})
  end

  @doc "Unregisters a renderer-side subscription."
  def send_subscription_unregister(bridge, kind) do
    GenServer.cast(bridge, {:send_subscription_unregister, kind})
  end

  @doc "Sends a window lifecycle operation to the renderer."
  def send_window_op(bridge, op, window_id, settings \\ %{}) do
    GenServer.cast(bridge, {:send_window_op, op, window_id, settings})
  end

  @doc "Stops the bridge GenServer."
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

    state = %__MODULE__{
      port: nil,
      runtime: runtime,
      renderer_path: renderer_path,
      buffer: "",
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
    json = Julep.Protocol.encode_settings(settings)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_snapshot, tree}, state) do
    json = Julep.Protocol.encode_snapshot(tree)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_patch, ops}, state) do
    json = Julep.Protocol.encode_patch(ops)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_effect_request, id, kind, payload}, state) do
    json = Julep.Protocol.encode_effect_request(id, kind, payload)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_widget_op, op, payload}, state) do
    json = Julep.Protocol.encode_widget_op(op, payload)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_subscription_register, kind, tag}, state) do
    json = Julep.Protocol.encode_subscription_register(kind, tag)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_subscription_unregister, kind}, state) do
    json = Julep.Protocol.encode_subscription_unregister(kind)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  def handle_cast({:send_window_op, op, window_id, settings}, state) do
    json = Julep.Protocol.encode_window_op(op, window_id, settings)
    send_to_port(state.port, json)
    {:noreply, state}
  end

  # Complete line -- flush any buffered prefix and dispatch.
  @impl true
  def handle_info({port, {:data, {:eol, chunk}}}, %{port: port} = state) do
    line = state.buffer <> to_string(chunk)
    state = dispatch_line(line, %{state | buffer: ""})
    {:noreply, state}
  end

  # Partial line exceeding {:line, N} -- accumulate.
  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    {:noreply, %{state | buffer: state.buffer <> to_string(chunk)}}
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
        send(state.runtime, :renderer_restarted)
        {:noreply, %{state | restart_count: state.restart_count + 1}}

      {:error, reason} ->
        {:stop, {:renderer_restart_failed, reason}, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %{port: port} = _state) when is_port(port) do
    try do
      Port.close(port)
    catch
      _, _ -> :ok
    end
  end

  def terminate(_reason, _state), do: :ok

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp open_port(state) do
    path = state.renderer_path

    if File.exists?(path) do
      port =
        Port.open({:spawn_executable, path}, [
          :binary,
          :exit_status,
          :use_stdio,
          {:line, 65_536}
        ])

      {:ok, %{state | port: port, buffer: ""}}
    else
      {:error, {:renderer_not_found, path}}
    end
  end

  defp send_to_port(port, data) when is_port(port) do
    Port.command(port, data)
  end

  defp dispatch_line(line, state) do
    case Julep.Protocol.decode_message(line) do
      {:error, reason} ->
        Logger.warning("julep bridge: failed to decode message: #{inspect(reason)}")

      event ->
        send(state.runtime, {:renderer_event, event})
    end

    state
  end

  defp handle_port_exit(state, reason) do
    send(state.runtime, {:renderer_exit, reason})

    if state.restart_count < state.max_restarts do
      delay = round(state.restart_delay * :math.pow(2, state.restart_count))
      Process.send_after(self(), :restart_renderer, delay)
      {:noreply, %{state | port: nil}}
    else
      {:stop, {:max_restarts_reached, reason}, state}
    end
  end
end
