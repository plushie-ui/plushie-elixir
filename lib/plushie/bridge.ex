defmodule Plushie.Bridge do
  @moduledoc """
  Bridge to the plushie renderer process.

  Manages the connection to the renderer, buffers partial JSONL lines (JSON
  mode) or receives length-prefixed frames (MessagePack mode), and forwards
  decoded events to the runtime process.

  ## Transport modes

  Controlled by the `:transport` option:

  - `:spawn` (default) -- spawns the renderer binary as a child process
    using an Erlang Port. The Port handles stdio framing automatically.

  - `:stdio` -- reads/writes the BEAM's own stdin/stdout. Used when the
    renderer spawns the Elixir process (e.g. `plushie --exec`).

  - `{:iostream, pid}` -- sends and receives protocol messages via an
    external process (the iostream adapter). Used for custom transports
    like SSH channels, TCP sockets, or WebSockets where the adapter
    process handles the underlying I/O and framing.

    The iostream adapter must:
    1. Receive `{:iostream_bridge, bridge_pid}` on startup (Bridge sends
       this during init).
    2. Send `{:iostream_data, binary}` to the bridge when protocol data
       arrives (one complete protocol message per delivery).
    3. Handle `{:iostream_send, iodata}` messages from the bridge by
       writing the data to the underlying transport.
    4. Send `{:iostream_closed, reason}` when the transport is closed.

  ## Wire formats

  Controlled by the `:format` option:

  - `:json` -- JSONL over stdio. Opt-in for debugging and observability.
    The Port is opened with `{:line, 65_536}`, which causes the driver to
    deliver data as `{port, {:data, {:eol, line}}}` for complete lines and
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

  During restart the runtime rebuilds renderer-owned state by re-sending
  settings, a full snapshot, subscriptions, and windows. Transient commands
  that cannot be rebuilt from that state are held until the runtime finishes
  resync, then sent in order.
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
    - `:runtime`       - pid to receive `{:renderer_event, event}` messages

  Required for `:spawn` transport (default):
    - `:renderer_path` - filesystem path to the plushie binary

  Optional opts:
    - `:name`          - registration name passed to `GenServer.start_link/3`
    - `:transport`     - `:spawn` (default, spawns renderer as child process),
                         `:stdio` (reads/writes the BEAM's own stdin/stdout),
                         or `{:iostream, pid}` (custom transport via iostream adapter)
    - `:format`        - wire format, `:msgpack` (default) or `:json`
    - `:log_level`     - renderer log level (`:off`, `:error`, `:warning`, `:info`, `:debug`).
                         Default: `:error`. Ignored when `RUST_LOG` is set in the environment.
    - `:renderer_args` - extra CLI args prepended to the renderer command (e.g. `["--headless"]`)
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
  @spec send_effect(
          bridge :: GenServer.server(),
          id :: String.t(),
          kind :: String.t(),
          payload :: map()
        ) :: :ok
  def send_effect(bridge, id, kind, payload) do
    GenServer.cast(bridge, {:send_effect, id, kind, payload})
  end

  @doc "Sends a widget operation to the renderer."
  @spec send_widget_op(bridge :: GenServer.server(), op :: String.t(), payload :: map()) :: :ok
  def send_widget_op(bridge, op, payload) do
    GenServer.cast(bridge, {:send_widget_op, op, payload})
  end

  @doc "Subscribes to a renderer-side event source."
  @spec send_subscribe(
          bridge :: GenServer.server(),
          kind :: String.t(),
          tag :: String.t(),
          max_rate :: non_neg_integer() | nil,
          window_id :: String.t() | nil
        ) :: :ok
  def send_subscribe(bridge, kind, tag, max_rate \\ nil, window_id \\ nil) do
    GenServer.cast(bridge, {:send_subscribe, kind, tag, max_rate, window_id})
  end

  @doc "Unsubscribes from a renderer-side event source."
  @spec send_unsubscribe(
          bridge :: GenServer.server(),
          kind :: String.t(),
          tag :: String.t() | nil
        ) :: :ok
  def send_unsubscribe(bridge, kind, tag \\ nil) do
    GenServer.cast(bridge, {:send_unsubscribe, kind, tag})
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

  @doc "Sends a system-wide operation to the renderer."
  @spec send_system_op(
          bridge :: GenServer.server(),
          op :: String.t(),
          settings :: map()
        ) :: :ok
  def send_system_op(bridge, op, settings \\ %{}) do
    GenServer.cast(bridge, {:send_system_op, op, settings})
  end

  @doc "Sends a system-wide query to the renderer."
  @spec send_system_query(
          bridge :: GenServer.server(),
          op :: String.t(),
          settings :: map()
        ) :: :ok
  def send_system_query(bridge, op, settings \\ %{}) do
    GenServer.cast(bridge, {:send_system_query, op, settings})
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

  @doc """
  Sends an interact request to the renderer.

  The renderer will process the interaction against its widget tree and
  respond with `interact_step` / `interact_response` messages. These are
  forwarded to the runtime as `{:interact_step, id, events}` and
  `{:interact_response, id, events}`.

  ## Parameters

  - `id` -- unique request identifier, used to correlate responses.
  - `action` -- the interaction verb. One of: `"click"`, `"toggle"`,
    `"select"`, `"type_text"`, `"submit"`, `"press"`, `"release"`,
    `"type_key"`, `"slide"`, `"paste"`, `"scroll"`, `"move_to"`,
    `"sort"`, `"canvas_press"`, `"canvas_release"`, `"canvas_move"`,
    `"pane_focus_cycle"`.
  - `selector` -- a map identifying the target widget. Keys are
    optional and include `"by"` (e.g. `"id"`, `"text"`, `"role"`,
    `"label"`, `"focused"`) and `"value"` (the lookup value). An
    empty map targets the focused widget or the window root.
  - `payload` -- action-specific data. Examples:
    - `%{text: "hello"}` for `"type_text"` / `"paste"`
    - `%{value: "option"}` for `"select"`
    - `%{value: 0.5}` for `"slide"`
    - `%{key: "Enter", modifiers: %{}}` for `"press"` / `"release"` / `"type_key"`
    - `%{x: 10, y: 20, button: "left"}` for `"canvas_press"` / `"canvas_release"`
    - `%{x: 10, y: 20}` for `"canvas_move"` / `"move_to"`
    - `%{delta_x: 0, delta_y: -3}` for `"scroll"`
    - `%{column: "name", direction: "asc"}` for `"sort"`
    - `%{}` for `"click"`, `"toggle"`, `"submit"`, `"pane_focus_cycle"`
  """
  @spec send_interact(
          bridge :: GenServer.server(),
          id :: String.t(),
          action :: String.t(),
          selector :: map(),
          payload :: map()
        ) :: :ok
  def send_interact(bridge, id, action, selector, payload \\ %{}) do
    GenServer.cast(bridge, {:send_interact, id, action, selector, payload})
  end

  @doc "Sends an advance_frame message to the renderer (headless/test mode)."
  @spec send_advance_frame(bridge :: GenServer.server(), timestamp :: non_neg_integer()) :: :ok
  def send_advance_frame(bridge, timestamp) do
    GenServer.cast(bridge, {:send_advance_frame, timestamp})
  end

  @doc "Registers an effect stub with the renderer."
  @spec send_register_effect_stub(
          bridge :: GenServer.server(),
          kind :: String.t(),
          response :: term()
        ) :: :ok
  def send_register_effect_stub(bridge, kind, response) do
    GenServer.cast(bridge, {:send_register_effect_stub, kind, response})
  end

  @doc "Removes a previously registered effect stub."
  @spec send_unregister_effect_stub(bridge :: GenServer.server(), kind :: String.t()) :: :ok
  def send_unregister_effect_stub(bridge, kind) do
    GenServer.cast(bridge, {:send_unregister_effect_stub, kind})
  end

  @doc """
  Restarts the renderer process intentionally (e.g. after a Rust rebuild).

  Unlike crash recovery, this does not count against the restart limit
  and does not use exponential backoff. The existing renderer is closed
  cleanly before opening the new one. The runtime receives
  `:renderer_restarted` and re-syncs as usual.
  """
  @spec restart_renderer(bridge :: GenServer.server()) :: :ok
  def restart_renderer(bridge) do
    GenServer.cast(bridge, :dev_restart)
  end

  @doc false
  @spec send_resync_complete(bridge :: GenServer.server()) :: :ok
  def send_resync_complete(bridge) do
    GenServer.cast(bridge, :resync_complete)
  end

  @doc "Stops the bridge GenServer."
  @spec stop(bridge :: GenServer.server()) :: :ok
  def stop(bridge) do
    GenServer.stop(bridge)
  end

  @doc """
  Captures a renderer screenshot and returns the raw response map.

  Width and height are optional positive integers. The call blocks until the
  renderer replies with `screenshot_response`.
  """
  @spec screenshot(
          bridge :: GenServer.server(),
          name :: String.t(),
          opts :: keyword(),
          timeout :: timeout()
        ) :: map()
  def screenshot(bridge, name, opts \\ [], timeout \\ 30_000) do
    case GenServer.call(bridge, {:screenshot, name, opts}, timeout) do
      %{} = response -> response
      {:error, reason} -> raise RuntimeError, "screenshot failed: #{inspect(reason)}"
    end
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
    :transport,
    :log_level,
    :renderer_args,
    :max_restarts,
    :restart_count,
    :restart_delay,
    :iostream_ref,
    :awaiting_resync,
    :queued_messages,
    :pending_screenshot,
    session_id: ""
  ]

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    transport = Keyword.get(opts, :transport, :spawn)
    format = Keyword.get(opts, :format, :msgpack)
    log_level = Keyword.get(opts, :log_level, :error)

    renderer_path =
      case transport do
        :spawn -> Keyword.fetch!(opts, :renderer_path)
        :stdio -> Keyword.get(opts, :renderer_path)
        {:iostream, _} -> Keyword.get(opts, :renderer_path)
      end

    state = %__MODULE__{
      port: nil,
      runtime: runtime,
      renderer_path: renderer_path,
      buffer: "",
      format: format,
      transport: transport,
      log_level: log_level,
      renderer_args: Keyword.get(opts, :renderer_args, []),
      max_restarts: Keyword.get(opts, :max_restarts, 5),
      restart_count: 0,
      restart_delay: Keyword.get(opts, :restart_delay, 100),
      awaiting_resync: false,
      queued_messages: [],
      pending_screenshot: nil,
      session_id: Keyword.get(opts, :session_id, "")
    }

    case open_port(state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:send_settings, settings}, state) do
    {:noreply,
     encode_and_send(state, :settings, fn fmt ->
       Plushie.Protocol.encode_settings(settings, fmt)
     end)}
  end

  def handle_cast({:send_snapshot, tree}, state) do
    {:noreply,
     encode_and_send(state, :snapshot, fn fmt -> Plushie.Protocol.encode_snapshot(tree, fmt) end)}
  end

  def handle_cast({:send_patch, ops}, state) do
    {:noreply,
     encode_and_send(state, :patch, fn fmt -> Plushie.Protocol.encode_patch(ops, fmt) end)}
  end

  def handle_cast({:send_effect, id, kind, payload}, state) do
    {:noreply,
     encode_and_send(state, :effect, fn fmt ->
       Plushie.Protocol.encode_effect(id, kind, payload, fmt)
     end)}
  end

  def handle_cast({:send_widget_op, op, payload}, state) do
    {:noreply,
     encode_and_send(state, :widget_op, fn fmt ->
       Plushie.Protocol.encode_widget_op(op, payload, fmt)
     end)}
  end

  def handle_cast({:send_subscribe, kind, tag, max_rate, window_id}, state) do
    {:noreply,
     encode_and_send(state, :subscribe, fn fmt ->
       Plushie.Protocol.encode_subscribe(kind, tag, fmt, max_rate, window_id)
     end)}
  end

  def handle_cast({:send_unsubscribe, kind, tag}, state) do
    {:noreply,
     encode_and_send(state, :unsubscribe, fn fmt ->
       Plushie.Protocol.encode_unsubscribe(kind, fmt, tag)
     end)}
  end

  def handle_cast({:send_window_op, op, window_id, settings}, state) do
    {:noreply,
     encode_and_send(state, :window_op, fn fmt ->
       Plushie.Protocol.encode_window_op(op, window_id, settings, fmt)
     end)}
  end

  def handle_cast({:send_system_op, op, settings}, state) do
    {:noreply,
     encode_and_send(state, :system_op, fn fmt ->
       Plushie.Protocol.encode_system_op(op, settings, fmt)
     end)}
  end

  def handle_cast({:send_system_query, op, settings}, state) do
    {:noreply,
     encode_and_send(state, :system_query, fn fmt ->
       Plushie.Protocol.encode_system_query(op, settings, fmt)
     end)}
  end

  def handle_cast({:send_image_op, op, payload}, state) do
    {:noreply,
     encode_and_send(state, :image_op, fn fmt ->
       Plushie.Protocol.encode_image_op(op, payload, fmt)
     end)}
  end

  def handle_cast({:send_extension_command, node_id, op, payload}, state) do
    {:noreply,
     encode_and_send(state, :extension_command, fn fmt ->
       Plushie.Protocol.encode_extension_command(node_id, op, payload, fmt)
     end)}
  end

  def handle_cast({:send_extension_commands, commands}, state) do
    {:noreply,
     encode_and_send(state, :extension_commands, fn fmt ->
       Plushie.Protocol.encode_extension_commands(commands, fmt)
     end)}
  end

  def handle_cast({:send_interact, id, action, selector, payload}, state) do
    {:noreply,
     encode_and_send(state, :interact, fn fmt ->
       Plushie.Protocol.encode_interact(id, action, selector, payload, fmt)
     end)}
  end

  def handle_cast({:send_advance_frame, timestamp}, state) do
    {:noreply,
     encode_and_send(state, :advance_frame, fn fmt ->
       Plushie.Protocol.encode_advance_frame(timestamp, fmt)
     end)}
  end

  def handle_cast({:send_register_effect_stub, kind, response}, state) do
    {:noreply,
     encode_and_send(state, :register_effect_stub, fn fmt ->
       Plushie.Protocol.encode_register_effect_stub(kind, response, fmt)
     end)}
  end

  def handle_cast({:send_unregister_effect_stub, kind}, state) do
    {:noreply,
     encode_and_send(state, :unregister_effect_stub, fn fmt ->
       Plushie.Protocol.encode_unregister_effect_stub(kind, fmt)
     end)}
  end

  def handle_cast(:resync_complete, state) do
    {:noreply, flush_queued_messages(%{state | awaiting_resync: false})}
  end

  # Intentional restart (e.g. after Rust rebuild in dev mode).
  # No backoff, no restart counting -- the renderer is being replaced
  # with a freshly built binary, not recovering from a crash.
  def handle_cast(:dev_restart, %{transport: :spawn} = state) do
    state = fail_pending_screenshot(state, {:renderer_exit, :dev_restart})

    if state.port do
      Port.close(state.port)
    end

    case open_port(%{state | port: nil, buffer: ""}) do
      {:ok, state} ->
        send(state.runtime, :renderer_restarted)
        {:noreply, %{state | awaiting_resync: true, restart_count: 0}}

      {:error, reason} ->
        Logger.error("plushie bridge: dev restart failed: #{inspect(reason)}")
        send(state.runtime, {:renderer_exit, {:dev_restart_failed, reason}})
        {:noreply, %{state | port: nil}}
    end
  end

  def handle_cast(:dev_restart, state) do
    Logger.warning("plushie bridge: dev restart only supported for :spawn transport")
    {:noreply, state}
  end

  @impl true
  def handle_call({:screenshot, name, opts}, from, %{pending_screenshot: nil} = state) do
    message =
      %{type: "screenshot", name: name}
      |> maybe_put_dimension(opts, :width)
      |> maybe_put_dimension(opts, :height)

    state =
      encode_and_send(state, :screenshot, fn fmt ->
        Plushie.Protocol.encode(message, fmt)
      end)

    {:noreply, %{state | pending_screenshot: from}}
  end

  def handle_call({:screenshot, _name, _opts}, _from, state) do
    {:reply, {:error, :screenshot_in_progress}, state}
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
    line = state.buffer <> chunk
    state = dispatch_message(line, :json, %{state | buffer: ""})
    {:noreply, state}
  end

  # Partial line exceeding {:line, N} -- accumulate.
  def handle_info({port, {:data, {:noeol, chunk}}}, %{port: port} = state) do
    new_buffer = state.buffer <> chunk

    if byte_size(new_buffer) > @max_buffer_size do
      Logger.error(
        "plushie bridge: JSON buffer exceeded #{@max_buffer_size} bytes, dropping message"
      )

      {:noreply, %{state | buffer: ""}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  # Stdio transport: stdin closed (renderer exited or pipe broken).
  def handle_info({port, :eof}, %{port: port, transport: :stdio} = state) do
    Logger.info("plushie bridge: stdin closed (renderer exited) -- shutting down")
    send(state.runtime, {:renderer_exit, :normal})
    {:stop, :normal, %{state | port: nil}}
  end

  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    # Clean exit (user closed window). Stop normally -- don't restart.
    Logger.info("plushie bridge: renderer exited cleanly (status 0)")
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
        :telemetry.execute([:plushie, :bridge, :restart], %{count: new_count}, %{})
        send(state.runtime, :renderer_restarted)
        {:noreply, %{state | restart_count: new_count, awaiting_resync: true}}

      {:error, reason} ->
        {:stop, {:renderer_restart_failed, reason}, state}
    end
  end

  def handle_info({:stop_protocol_mismatch, got, expected}, state) do
    {:stop, {:protocol_mismatch, got, expected}, state}
  end

  # iostream adapter sends us a complete protocol message.
  def handle_info({:iostream_data, data}, %{transport: {:iostream, _}} = state) do
    state = dispatch_message(data, state.format, state)
    {:noreply, state}
  end

  # iostream adapter reports the transport is closed.
  def handle_info({:iostream_closed, reason}, %{transport: {:iostream, _}} = state) do
    log_iostream_exit(reason, "iostream closed")
    state = fail_pending_screenshot(state, {:renderer_exit, reason})
    send(state.runtime, {:renderer_exit, reason})
    {:stop, :normal, %{state | port: nil}}
  end

  # iostream adapter process exited.
  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{iostream_ref: ref} = state
      )
      when is_reference(ref) do
    log_iostream_exit(reason, "iostream process exited")
    state = fail_pending_screenshot(state, {:renderer_exit, reason})
    send(state.runtime, {:renderer_exit, reason})
    {:stop, :normal, state}
  end

  def handle_info(msg, state) do
    Logger.debug("plushie bridge: unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp log_iostream_exit(reason, _prefix) when reason in [:normal, :shutdown], do: :ok

  defp log_iostream_exit(reason, prefix) do
    Logger.info("plushie bridge: #{prefix}: #{inspect(reason)}")
  end

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

  # Encodes a protocol message and sends it via the transport. When
  # session_id is set (multiplexed mode), the message is re-serialized
  # with the session field injected.
  defp encode_and_send(%{session_id: ""} = state, kind, encode_fn) do
    data = encode_fn.(state.format)
    maybe_send_or_queue(state, kind, data)
  end

  defp encode_and_send(state, kind, encode_fn) do
    # Multiplexed mode: encode with the default empty session first,
    # then decode, inject session_id, and re-encode. This is only used
    # by the test pool adapter where the overhead is negligible.
    data = encode_fn.(state.format)

    binary = IO.iodata_to_binary(data)

    case deserialize(binary, state.format) do
      {:ok, map} ->
        map = Map.put(map, "session", state.session_id)
        reencoded = reserialize(map, state.format)
        maybe_send_or_queue(state, kind, reencoded)

      {:error, _} ->
        # Fallback: send without session injection
        maybe_send_or_queue(state, kind, data)
    end
  end

  defp deserialize(data, :json), do: Jason.decode(data)
  defp deserialize(data, :msgpack), do: Msgpax.unpack(data)

  defp reserialize(map, :json), do: Jason.encode!(map) <> "\n"
  defp reserialize(map, :msgpack), do: Msgpax.pack!(map)

  defp open_port(%{transport: {:iostream, io_pid}} = state) do
    ref = Process.monitor(io_pid)
    send(io_pid, {:iostream_bridge, self()})
    {:ok, %{state | iostream_ref: ref}}
  end

  defp open_port(%{transport: :stdio} = state) do
    port_opts =
      case state.format do
        :msgpack -> [:binary, :eof, {:packet, 4}]
        :json -> [:binary, :eof, {:line, 65_536}]
      end

    port = Port.open({:fd, 0, 1}, port_opts)
    {:ok, %{state | port: port, buffer: ""}}
  end

  defp open_port(state) do
    path = state.renderer_path

    if File.exists?(path) do
      port_opts =
        case state.format do
          :msgpack -> [:binary, :exit_status, :use_stdio, {:packet, 4}]
          # 65KB line limit is sufficient for normal protocol messages.
          # Unusually large JSON messages (e.g., full tree snapshots with
          # many nodes) may be split into :noeol chunks, which are buffered
          # and reassembled. For large payloads, use msgpack mode (default)
          # which has no line limit.
          :json -> [:binary, :exit_status, :use_stdio, {:line, 65_536}]
        end

      format_args = if state.format == :json, do: ["--json"], else: []
      args = state.renderer_args ++ format_args
      env = Plushie.RendererEnv.build(rust_log: rust_log_value(state.log_level))

      port =
        Port.open({:spawn_executable, path}, [{:args, args}, {:env, env} | port_opts])

      {:ok, %{state | port: port, buffer: ""}}
    else
      {:error, {:renderer_not_found, path}}
    end
  end

  @typep log_level :: :off | :error | :warning | :info | :debug

  # Translate log_level atom to RUST_LOG filter string. Returns nil when
  # the system RUST_LOG env var is already set (env var always wins).
  @spec rust_log_value(log_level()) :: String.t() | nil
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

  defp send_data(%{transport: {:iostream, io_pid}}, data) do
    send(io_pid, {:iostream_send, data})
    :telemetry.execute([:plushie, :bridge, :send], %{byte_size: IO.iodata_length(data)}, %{})
  rescue
    ArgumentError ->
      Logger.warning("plushie bridge: iostream process unreachable during send")
      :error
  end

  defp send_data(%{port: nil}, _data), do: :error

  defp send_data(%{port: port}, data) when is_port(port) do
    Port.command(port, data)
    # byte_size measures payload size (excludes framing overhead in both
    # JSON and msgpack modes). This is intentionally consistent across
    # formats -- framing is a transport concern, not a telemetry concern.
    :telemetry.execute([:plushie, :bridge, :send], %{byte_size: IO.iodata_length(data)}, %{})
  rescue
    ArgumentError ->
      Logger.warning("plushie bridge: port closed during send")
      :error
  end

  defp dispatch_message(data, format, state) do
    if format == :json and String.trim(data) == "" do
      state
    else
      :telemetry.execute([:plushie, :bridge, :receive], %{byte_size: byte_size(data)}, %{})

      try do
        case Plushie.Protocol.decode_message!(data, format) do
          {:hello, %{protocol: protocol} = hello} ->
            expected = Plushie.Protocol.protocol_version()

            if protocol != expected do
              Logger.error(
                "plushie bridge: protocol mismatch -- renderer reports protocol #{protocol}, " <>
                  "expected #{expected}. Stopping bridge."
              )

              send(self(), {:stop_protocol_mismatch, protocol, expected})
              state
            else
              send(state.runtime, {:renderer_event, {:hello, hello}})
              %{state | restart_count: 0}
            end

          {:screenshot_response, response} ->
            case state.pending_screenshot do
              nil ->
                send(state.runtime, {:renderer_event, {:screenshot_response, response}})
                %{state | restart_count: 0}

              from ->
                GenServer.reply(from, response)
                %{state | restart_count: 0, pending_screenshot: nil}
            end

          event ->
            send(state.runtime, {:renderer_event, event})
            # Reset restart count on first successful message from the renderer.
            %{state | restart_count: 0}
        end
      rescue
        error in Plushie.Protocol.Error ->
          :telemetry.execute([:plushie, :bridge, :protocol_error], %{}, %{
            reason: error.reason,
            format: format
          })

          reraise error, __STACKTRACE__
      end
    end
  end

  defp handle_port_exit(%{transport: {:iostream, _}} = state, _reason) do
    Logger.info("plushie bridge: iostream transport closed -- shutting down")
    state = fail_pending_screenshot(state, {:renderer_exit, :normal})
    send(state.runtime, {:renderer_exit, :normal})
    {:stop, :normal, %{state | port: nil}}
  end

  defp handle_port_exit(%{transport: :stdio} = state, _reason) do
    Logger.info("plushie bridge: stdio port closed -- shutting down")
    state = fail_pending_screenshot(state, {:renderer_exit, :normal})
    send(state.runtime, {:renderer_exit, :normal})
    {:stop, :normal, %{state | port: nil}}
  end

  defp handle_port_exit(state, reason) do
    state = fail_pending_screenshot(state, {:renderer_exit, reason})
    send(state.runtime, {:renderer_exit, reason})

    if state.restart_count < state.max_restarts do
      delay = min(round(state.restart_delay * :math.pow(2, state.restart_count)), @max_backoff_ms)
      Process.send_after(self(), :restart_renderer, delay)
      {:noreply, %{state | port: nil, awaiting_resync: true}}
    else
      Logger.error("""
      plushie bridge: renderer crashed #{state.max_restarts} times, giving up.

      Troubleshooting:
        1. Check RUST_LOG=plushie=debug for renderer errors
        2. Verify the binary exists: mix plushie.build
        3. Check system dependencies (libxkbcommon, etc.)
        4. Try running the renderer directly: ./path/to/plushie --json
      """)

      :telemetry.execute([:plushie, :bridge, :max_restarts_reached], %{}, %{
        reason: reason,
        max_restarts: state.max_restarts
      })

      {:stop, {:max_restarts_reached, reason}, state}
    end
  end

  defp maybe_put_dimension(map, opts, key) do
    case Keyword.get(opts, key) do
      value when is_integer(value) and value > 0 ->
        Map.put(map, key, value)

      nil ->
        map

      other ->
        raise ArgumentError, "expected #{key} to be a positive integer, got: #{inspect(other)}"
    end
  end

  defp fail_pending_screenshot(%{pending_screenshot: nil} = state, _reason), do: state

  defp fail_pending_screenshot(%{pending_screenshot: from} = state, reason) do
    GenServer.reply(from, {:error, reason})
    %{state | pending_screenshot: nil}
  end

  defp maybe_send_or_queue(state, kind, data) do
    cond do
      send_now?(state, kind) ->
        case send_data(state, data) do
          :ok -> state
          :error -> queue_message(state, kind, data)
        end

      queue_during_restart?(kind) ->
        queue_message(state, kind, data)

      true ->
        state
    end
  end

  defp send_now?(%{awaiting_resync: false} = state, _kind), do: transport_ready?(state)
  defp send_now?(state, kind), do: transport_ready?(state) and not queue_during_restart?(kind)

  # Settings, snapshots, patches, subscriptions, and window ops are rebuilt
  # by the runtime during resync. These command-like messages are not.
  defp queue_during_restart?(kind) do
    kind in [
      :effect,
      :widget_op,
      :image_op,
      :extension_command,
      :extension_commands,
      :interact,
      :advance_frame,
      :register_effect_stub,
      :unregister_effect_stub
    ]
  end

  defp queue_message(state, kind, data) do
    Logger.debug("plushie bridge: queued #{kind} while renderer is unavailable")
    %{state | queued_messages: state.queued_messages ++ [data]}
  end

  defp flush_queued_messages(%{queued_messages: []} = state), do: state

  defp flush_queued_messages(state) do
    do_flush_queued_messages(state, state.queued_messages)
  end

  defp do_flush_queued_messages(state, []), do: %{state | queued_messages: []}

  defp do_flush_queued_messages(state, [data | rest]) do
    case send_data(state, data) do
      :ok -> do_flush_queued_messages(state, rest)
      :error -> %{state | queued_messages: [data | rest]}
    end
  end

  defp transport_ready?(%{transport: {:iostream, _}}), do: true
  defp transport_ready?(%{port: port}) when is_port(port), do: true
  defp transport_ready?(_state), do: false
end
