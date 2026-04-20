defmodule Plushie.Bridge do
  @moduledoc """
  Bridge to the plushie renderer process.

  Manages the connection to the renderer, buffers partial JSONL lines (JSON
  mode) or receives length-prefixed frames (MessagePack mode), and forwards
  decoded events to the runtime process.

  ## Transport modes

  Transport I/O is delegated to modules implementing `Plushie.Transport`.
  Controlled by the `:transport` option:

  - `:spawn` (default) - spawns the renderer binary as a child process
    using an Erlang Port (`Plushie.Transport.Port`).

  - `:stdio` - reads/writes the BEAM's own stdin/stdout. Used when the
    renderer spawns the Elixir process (`Plushie.Transport.Port`).

  - `{:iostream, pid}` - sends and receives protocol messages via an
    external process (`Plushie.Transport.IOStream`). See that module for
    the adapter protocol.

  ## Wire formats

  Controlled by the `:format` option:

  - `:json` - JSONL over stdio. Opt-in for debugging and observability.
  - `:msgpack` (default) - MessagePack with 4-byte length-prefixed framing.

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
    - `:heartbeat_interval` - maximum time (ms) between renderer messages before
                         the bridge considers the renderer unresponsive and triggers
                         a restart. `nil` disables the watchdog. Default: `30_000`.
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

  @doc "Sends a widget-targeted command to the renderer."
  @spec send_command(
          bridge :: GenServer.server(),
          id :: String.t(),
          family :: String.t(),
          value :: term()
        ) :: :ok
  def send_command(bridge, id, family, value) do
    GenServer.cast(bridge, {:send_command, id, family, value})
  end

  @doc "Sends a batch of widget-targeted commands to the renderer."
  @spec send_commands(
          bridge :: GenServer.server(),
          commands :: [{String.t(), String.t(), term()}]
        ) :: :ok
  def send_commands(bridge, commands) do
    GenServer.cast(bridge, {:send_commands, commands})
  end

  @doc """
  Sends an interact request to the renderer.

  The renderer will process the interaction against its widget tree and
  respond with `interact_step` / `interact_response` messages. These are
  forwarded to the runtime as `{:interact_step, id, events}` and
  `{:interact_response, id, events}`.

  ## Parameters

  - `id` - unique request identifier, used to correlate responses.
  - `action` - the interaction verb. One of: `"click"`, `"toggle"`,
    `"select"`, `"type_text"`, `"submit"`, `"press"`, `"release"`,
    `"type_key"`, `"slide"`, `"paste"`, `"scroll"`, `"move_to"`,
    `"sort"`, `"canvas_press"`, `"canvas_release"`, `"canvas_move"`,
    `"pane_focus_cycle"`.
  - `selector` - a map identifying the target widget. Keys are
    optional and include `"by"` (e.g. `"id"`, `"text"`, `"role"`,
    `"label"`, `"focused"`) and `"value"` (the lookup value). An
    empty map targets the focused widget or the window root.
  - `payload` - action-specific data. Examples:
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
    :transport_mod,
    :transport_state,
    :runtime,
    :buffer,
    :discard_next_eol,
    :format,
    :max_restarts,
    :restart_count,
    :restart_delay,
    :awaiting_resync,
    :queued_messages,
    :pending_screenshot,
    :heartbeat_interval,
    :heartbeat_timer,
    session_id: ""
  ]

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl GenServer
  def init(opts) do
    runtime = Keyword.fetch!(opts, :runtime)
    transport = Keyword.get(opts, :transport, :spawn)
    format = Keyword.get(opts, :format, :msgpack)
    heartbeat_interval = Keyword.get(opts, :heartbeat_interval, 30_000)

    {transport_mod, transport_opts} = transport_init_args(transport, format, opts)

    case transport_mod.init(transport_opts) do
      {:ok, transport_state} ->
        state = %__MODULE__{
          transport_mod: transport_mod,
          transport_state: transport_state,
          runtime: runtime,
          buffer: "",
          discard_next_eol: false,
          format: format,
          max_restarts: Keyword.get(opts, :max_restarts, 5),
          restart_count: 0,
          restart_delay: Keyword.get(opts, :restart_delay, 100),
          awaiting_resync: false,
          queued_messages: [],
          pending_screenshot: nil,
          heartbeat_interval: heartbeat_interval,
          heartbeat_timer: nil,
          session_id: Keyword.get(opts, :session_id, "")
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp transport_init_args({:iostream, io_pid}, _format, _opts) do
    {Plushie.Transport.IOStream, [io_pid: io_pid]}
  end

  defp transport_init_args(mode, format, opts) when mode in [:spawn, :stdio] do
    renderer_path =
      case mode do
        :spawn -> Keyword.fetch!(opts, :renderer_path)
        :stdio -> Keyword.get(opts, :renderer_path)
      end

    {Plushie.Transport.Port,
     [
       mode: mode,
       format: format,
       renderer_path: renderer_path,
       renderer_args: Keyword.get(opts, :renderer_args, []),
       log_level: Keyword.get(opts, :log_level, :error)
     ]}
  end

  @impl GenServer
  def handle_cast({:send_settings, settings}, state) do
    {:noreply,
     encode_and_send(state, :settings, fn fmt ->
       Plushie.Protocol.encode_settings(settings, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_snapshot, tree}, state) do
    {:noreply,
     encode_and_send(state, :snapshot, fn fmt -> Plushie.Protocol.encode_snapshot(tree, fmt) end)}
  end

  @impl GenServer
  def handle_cast({:send_patch, ops}, state) do
    {:noreply,
     encode_and_send(state, :patch, fn fmt -> Plushie.Protocol.encode_patch(ops, fmt) end)}
  end

  @impl GenServer
  def handle_cast({:send_effect, id, kind, payload}, state) do
    {:noreply,
     encode_and_send(state, :effect, fn fmt ->
       Plushie.Protocol.encode_effect(id, kind, payload, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_widget_op, op, payload}, state) do
    {:noreply,
     encode_and_send(state, :widget_op, fn fmt ->
       Plushie.Protocol.encode_widget_op(op, payload, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_subscribe, kind, tag, max_rate, window_id}, state) do
    {:noreply,
     encode_and_send(state, :subscribe, fn fmt ->
       Plushie.Protocol.encode_subscribe(kind, tag, fmt, max_rate, window_id)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_unsubscribe, kind, tag}, state) do
    {:noreply,
     encode_and_send(state, :unsubscribe, fn fmt ->
       Plushie.Protocol.encode_unsubscribe(kind, fmt, tag)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_window_op, op, window_id, settings}, state) do
    {:noreply,
     encode_and_send(state, :window_op, fn fmt ->
       Plushie.Protocol.encode_window_op(op, window_id, settings, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_system_op, op, settings}, state) do
    {:noreply,
     encode_and_send(state, :system_op, fn fmt ->
       Plushie.Protocol.encode_system_op(op, settings, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_system_query, op, settings}, state) do
    {:noreply,
     encode_and_send(state, :system_query, fn fmt ->
       Plushie.Protocol.encode_system_query(op, settings, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_image_op, op, payload}, state) do
    {:noreply,
     encode_and_send(state, :image_op, fn fmt ->
       Plushie.Protocol.encode_image_op(op, payload, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_command, id, family, value}, state) do
    {:noreply,
     encode_and_send(state, :command, fn fmt ->
       Plushie.Protocol.Encode.encode_command(id, family, value, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_commands, commands}, state) do
    {:noreply,
     encode_and_send(state, :commands, fn fmt ->
       Plushie.Protocol.Encode.encode_commands(commands, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_interact, id, action, selector, payload}, state) do
    {:noreply,
     encode_and_send(state, :interact, fn fmt ->
       Plushie.Protocol.encode_interact(id, action, selector, payload, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_advance_frame, timestamp}, state) do
    {:noreply,
     encode_and_send(state, :advance_frame, fn fmt ->
       Plushie.Protocol.encode_advance_frame(timestamp, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_register_effect_stub, kind, response}, state) do
    {:noreply,
     encode_and_send(state, :register_effect_stub, fn fmt ->
       Plushie.Protocol.encode_register_effect_stub(kind, response, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast({:send_unregister_effect_stub, kind}, state) do
    {:noreply,
     encode_and_send(state, :unregister_effect_stub, fn fmt ->
       Plushie.Protocol.encode_unregister_effect_stub(kind, fmt)
     end)}
  end

  @impl GenServer
  def handle_cast(:resync_complete, state) do
    {:noreply, flush_queued_messages(%{state | awaiting_resync: false, restart_count: 0})}
  end

  # Intentional restart (e.g. after Rust rebuild in dev mode).
  # No backoff, no restart counting: the renderer is being replaced
  # with a freshly built binary, not recovering from a crash.
  @impl GenServer
  def handle_cast(:dev_restart, state) do
    if state.transport_mod.restartable?(state.transport_state) do
      state = cancel_heartbeat_timer(state)
      state = fail_pending_screenshot(state, {:renderer_exit, :dev_restart})
      state.transport_mod.close(state.transport_state)

      case state.transport_mod.reopen(state.transport_state) do
        {:ok, transport_state} ->
          state = %{state | transport_state: transport_state, buffer: "", discard_next_eol: false}
          send(state.runtime, :renderer_restarted)
          {:noreply, %{state | awaiting_resync: true, restart_count: 0}}

        {:error, reason} ->
          Logger.error("plushie bridge: dev restart failed: #{inspect(reason)}")
          send(state.runtime, {:renderer_exit, {:dev_restart_failed, reason}})
          {:noreply, %{state | transport_state: %{state.transport_state | port: nil}}}
      end
    else
      Logger.warning("plushie bridge: dev restart only supported for :spawn transport")
      {:noreply, state}
    end
  end

  @impl GenServer
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

  @impl GenServer
  def handle_call({:screenshot, _name, _opts}, _from, state) do
    {:reply, {:error, :screenshot_in_progress}, state}
  end

  @impl GenServer
  def handle_info(:restart_renderer, state) do
    case state.transport_mod.reopen(state.transport_state) do
      {:ok, transport_state} ->
        new_count = state.restart_count + 1
        :telemetry.execute([:plushie, :bridge, :restart], %{count: new_count}, %{})
        send(state.runtime, :renderer_restarted)

        {:noreply,
         %{
           state
           | transport_state: transport_state,
             restart_count: new_count,
             awaiting_resync: true,
             buffer: "",
             discard_next_eol: false
         }}

      {:error, reason} ->
        {:stop, {:renderer_restart_failed, reason}, state}
    end
  end

  @impl GenServer
  def handle_info(:heartbeat_timeout, %{awaiting_resync: true} = state) do
    # Renderer is already restarting; ignore stale timer.
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:heartbeat_timeout, state) do
    Logger.warning(
      "plushie bridge: renderer unresponsive " <>
        "(no message in #{state.heartbeat_interval}ms), triggering restart"
    )

    state = %{state | heartbeat_timer: nil}
    handle_transport_closed(state, :heartbeat_timeout)
  end

  # Delegate all other messages to the transport module.
  @impl GenServer
  def handle_info(msg, state) do
    case state.transport_mod.handle_info(msg, state.transport_state) do
      {:data, data, transport_state} ->
        state = %{state | transport_state: transport_state}
        handle_transport_data(data, state)

      {:closed, reason, transport_state} ->
        state = %{state | transport_state: transport_state}
        handle_transport_closed(state, reason)

      :ignore ->
        Logger.debug("plushie bridge: unhandled message: #{inspect(msg)}")
        {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, %{heartbeat_timer: ref} = state) when is_reference(ref) do
    Process.cancel_timer(ref)
    state.transport_mod.close(state.transport_state)
  end

  @impl GenServer
  def terminate(_reason, state), do: state.transport_mod.close(state.transport_state)

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Encodes a protocol message and sends it via the transport. When
  # session_id is set (multiplexed mode), the message is re-serialized
  # with the session field injected.
  defp encode_and_send(%{session_id: ""} = state, kind, encode_fn) do
    data = encode_fn.(state.format)
    maybe_send_or_queue(state, kind, data)
  rescue
    e ->
      Logger.error("plushie bridge: failed to encode #{kind} message: #{Exception.message(e)}")

      state
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

      {:error, reason} ->
        Logger.error(
          "plushie bridge: failed to inject session_id into #{kind} message: #{inspect(reason)}"
        )

        state
    end
  rescue
    e ->
      Logger.error("plushie bridge: failed to encode #{kind} message: #{Exception.message(e)}")

      state
  end

  defp deserialize(data, :json), do: Jason.decode(data)
  defp deserialize(data, :msgpack), do: Msgpax.unpack(data, binary: true)

  defp reserialize(map, :json), do: Jason.encode!(map) <> "\n"
  defp reserialize(map, :msgpack), do: Msgpax.pack!(map)

  defp send_data(state, data) do
    case state.transport_mod.send_data(state.transport_state, data) do
      {:ok, transport_state} ->
        {:ok, %{state | transport_state: transport_state}}

      {:error, _reason} ->
        :error
    end
  end

  # Emit a typed `BufferOverflow` diagnostic to the runtime. Returns
  # the cleared state. The caller is responsible for stopping the
  # bridge with `{:buffer_overflow, size, @max_buffer_size}`.
  defp emit_buffer_overflow(state, size) do
    diag = %Plushie.Event.Diagnostic.BufferOverflow{
      size: size,
      limit: @max_buffer_size
    }

    Logger.error(
      "plushie bridge: wire frame of #{size} bytes exceeds #{@max_buffer_size} byte limit; stopping bridge"
    )

    send(
      state.runtime,
      {:renderer_event,
       %Plushie.Event.DiagnosticMessage{
         session: "",
         level: :error,
         diagnostic: diag
       }}
    )

    state
  end

  # Process a single decoded protocol message. Returns `{:continue,
  # state}` on the happy path, or `{:stop, reason, state}` when the
  # message signals a fatal bridge condition (protocol version
  # mismatch, oversize frame). Returning `:stop` directly from the
  # calling `handle_info` avoids a scheduler round-trip through a
  # self-sent "please stop" message, which under heavy async-test
  # load could miss the test's `assert_receive` window.
  defp dispatch_message(data, format, state) do
    cond do
      format == :json and String.trim(data) == "" ->
        {:continue, state}

      byte_size(data) > @max_buffer_size ->
        # Transport-level framing only enforces overflow when
        # `Plushie.Transport.Framing` is on the decode path (TCP/Unix
        # socket via `SocketAdapter`). The Erlang Port {:packet, 4}
        # path bypasses Framing; `{:packet, 4}` allows up to 4 GiB, so
        # this is the backstop that enforces the protocol's 64 MiB
        # per-message cap there. Surface the typed diagnostic on the
        # same event channel as other overflow detections so apps
        # observe a structured event, then stop the bridge.
        size = byte_size(data)
        state = emit_buffer_overflow(state, size)
        {:stop, {:buffer_overflow, size, @max_buffer_size}, state}

      true ->
        :telemetry.execute([:plushie, :bridge, :receive], %{byte_size: byte_size(data)}, %{})

        try do
          case Plushie.Protocol.decode_message!(data, format) do
            {:hello, %{protocol: protocol} = hello} ->
              expected = Plushie.Protocol.protocol_version()

              if protocol != expected do
                err =
                  Plushie.Protocol.ProtocolVersionMismatchError.exception(
                    expected: expected,
                    got: protocol
                  )

                Logger.error("plushie bridge: #{Exception.message(err)}. Stopping bridge.")
                {:stop, {:protocol_mismatch, protocol, expected}, state}
              else
                send(state.runtime, {:renderer_event, {:hello, hello}})
                {:continue, reset_heartbeat_timer(state)}
              end

            {:screenshot_response, response} ->
              state =
                case state.pending_screenshot do
                  nil ->
                    send(state.runtime, {:renderer_event, {:screenshot_response, response}})
                    state

                  from ->
                    GenServer.reply(from, response)
                    %{state | pending_screenshot: nil}
                end

              {:continue, reset_heartbeat_timer(state)}

            event ->
              send(state.runtime, {:renderer_event, event})
              {:continue, reset_heartbeat_timer(state)}
          end
        rescue
          error in Plushie.Protocol.Error ->
            :telemetry.execute([:plushie, :bridge, :protocol_error], %{}, %{
              reason: error.reason,
              format: format
            })

            Logger.error("plushie bridge: #{Exception.message(error)}")
            {:continue, state}
        end
    end
  end

  # Handle transport data. Msgpack delivers complete binaries directly.
  # JSON delivers :eol/:noeol tuples that need buffering.
  defp handle_transport_data(binary, %{format: :msgpack} = state) when is_binary(binary) do
    finalize_dispatch(dispatch_message(binary, :msgpack, state))
  end

  defp handle_transport_data({:eol, _chunk}, %{discard_next_eol: true} = state) do
    {:noreply, %{state | buffer: "", discard_next_eol: false}}
  end

  defp handle_transport_data({:eol, chunk}, state) do
    line = state.buffer <> chunk
    finalize_dispatch(dispatch_message(line, :json, %{state | buffer: ""}))
  end

  defp handle_transport_data({:noeol, _chunk}, %{discard_next_eol: true} = state) do
    {:noreply, state}
  end

  defp handle_transport_data({:noeol, chunk}, state) do
    new_buffer = state.buffer <> chunk

    if byte_size(new_buffer) > @max_buffer_size do
      # An unterminated JSON line has already grown past the cap, so
      # it can never decode legitimately. This path is not covered by
      # `Plushie.Transport.Framing` (the Port mode delivers
      # `:eol/:noeol` tuples directly and never calls Framing). Emit
      # the typed diagnostic so apps observe a structured event,
      # matching the Framing-backed socket transport's behaviour.
      size = byte_size(new_buffer)
      state = emit_buffer_overflow(%{state | buffer: "", discard_next_eol: true}, size)
      {:stop, {:buffer_overflow, size, @max_buffer_size}, state}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  # IOStream delivers complete protocol messages as raw binaries.
  defp handle_transport_data(binary, state) when is_binary(binary) do
    finalize_dispatch(dispatch_message(binary, state.format, state))
  end

  # Translate dispatch_message/3's tagged return into a GenServer
  # handle_info reply tuple.
  defp finalize_dispatch({:continue, state}), do: {:noreply, state}
  defp finalize_dispatch({:stop, reason, state}), do: {:stop, reason, state}

  # Transport closed cleanly or via iostream. Non-restartable transports
  # shut down; restartable ones (spawn) go through exit handling.
  defp handle_transport_closed(state, reason) do
    if state.transport_mod.restartable?(state.transport_state) do
      # Spawn mode: check for clean exit (status 0) vs crash.
      case reason do
        {:exit_status, 0} ->
          Logger.info("plushie bridge: renderer exited cleanly (status 0)")
          state = cancel_heartbeat_timer(state)
          send(state.runtime, {:renderer_exit, :normal})
          {:stop, :normal, state}

        _ ->
          handle_transport_exit(state, reason)
      end
    else
      # Non-restartable (stdio, iostream): shut down cleanly.
      log_transport_close(state.transport_mod, reason)
      state = cancel_heartbeat_timer(state)
      state = fail_pending_screenshot(state, {:renderer_exit, reason})
      send(state.runtime, {:renderer_exit, reason})
      {:stop, :normal, state}
    end
  end

  defp handle_transport_exit(state, reason) do
    state = cancel_heartbeat_timer(state)
    state = fail_pending_screenshot(state, {:renderer_exit, reason})
    send(state.runtime, {:renderer_exit, reason})

    if state.restart_count < state.max_restarts do
      delay = min(round(state.restart_delay * :math.pow(2, state.restart_count)), @max_backoff_ms)
      Process.send_after(self(), :restart_renderer, delay)
      {:noreply, %{state | awaiting_resync: true}}
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

  defp log_transport_close(Plushie.Transport.IOStream, reason)
       when reason in [:normal, :shutdown],
       do: :ok

  defp log_transport_close(Plushie.Transport.IOStream, reason) do
    Logger.info("plushie bridge: iostream closed: #{inspect(reason)}")
  end

  defp log_transport_close(Plushie.Transport.Port, _reason) do
    Logger.info("plushie bridge: stdio port closed, shutting down")
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
          {:ok, state} -> state
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

  defp transport_ready?(state) do
    state.transport_mod.transport_ready?(state.transport_state)
  end

  # Settings, snapshots, patches, subscriptions, and window ops are rebuilt
  # by the runtime during resync. These command-like messages are not.
  defp queue_during_restart?(kind) do
    kind in [
      :effect,
      :widget_op,
      :image_op,
      :command,
      :commands,
      :interact,
      :advance_frame,
      :register_effect_stub,
      :unregister_effect_stub,
      :system_op,
      :system_query
    ]
  end

  # Prepend to avoid O(n) list append; reversed before flushing.
  defp queue_message(state, kind, data) do
    Logger.debug("plushie bridge: queued #{kind} while renderer is unavailable")
    %{state | queued_messages: [data | state.queued_messages]}
  end

  defp flush_queued_messages(%{queued_messages: []} = state), do: state

  defp flush_queued_messages(state) do
    do_flush_queued_messages(state, Enum.reverse(state.queued_messages))
  end

  defp do_flush_queued_messages(state, []), do: %{state | queued_messages: []}

  defp do_flush_queued_messages(state, [data | rest]) do
    case send_data(state, data) do
      {:ok, state} -> do_flush_queued_messages(state, rest)
      :error -> %{state | queued_messages: [data | rest]}
    end
  end

  # Heartbeat watchdog: resets the timer that detects an unresponsive renderer.
  # Called after every successful message from the renderer.
  defp reset_heartbeat_timer(%{heartbeat_interval: nil} = state), do: state
  defp reset_heartbeat_timer(%{awaiting_resync: true} = state), do: state

  defp reset_heartbeat_timer(state) do
    state = cancel_heartbeat_timer(state)
    ref = Process.send_after(self(), :heartbeat_timeout, state.heartbeat_interval)
    %{state | heartbeat_timer: ref}
  end

  defp cancel_heartbeat_timer(%{heartbeat_timer: nil} = state), do: state

  defp cancel_heartbeat_timer(%{heartbeat_timer: ref} = state) do
    Process.cancel_timer(ref)
    %{state | heartbeat_timer: nil}
  end
end
