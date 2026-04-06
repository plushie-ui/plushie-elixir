defmodule Plushie.Command do
  @moduledoc """
  Commands describe side effects that `update/2` wants the runtime to perform.

  They are plain data -- inspectable, testable, serializable. The runtime
  interprets them after `update/2` returns. Nothing executes inside `update`.

  ## Categories

  - **Basic**: `none/0`, `done/2`, `async/2`, `stream/2`, `cancel/1`, `send_after/2`, `exit/0`
  - **Focus**: `focus/1`, `focus_next/0`, `focus_previous/0`
  - **Text**: `select_all/1`, `move_cursor_to_front/1`, `move_cursor_to_end/1`,
    `move_cursor_to/2`, `select_range/3` (see `Command.Text`)
  - **Scroll**: `scroll_to/2`, `snap_to/3`, `snap_to_end/1`, `scroll_by/3`
    (see `Command.Scroll`)
  - **Window ops**: `close_window/1`, `resize_window/3`, `move_window/3`,
    `maximize_window/2`, `minimize_window/2`, `set_window_mode/2`,
    `toggle_maximize/1`, `toggle_decorations/1`, `focus_window/1`,
    `set_window_level/2`, `drag_window/1`, `drag_resize_window/2`,
    `request_user_attention/2`, `screenshot/2`, `set_resizable/2`,
    `set_min_size/3`, `set_max_size/3`, `enable_mouse_passthrough/1`,
    `disable_mouse_passthrough/1`, `show_system_menu/1`, `set_icon/4`,
    `set_resize_increments/3` (see `Command.Window`)
  - **Window queries**: `get_window_size/2`, `get_window_position/2`,
    `is_maximized/2`, `is_minimized/2`, `get_mode/2`, `get_scale_factor/2`,
    `raw_id/2`, `monitor_size/2` (see `Command.WindowQuery`)
  - **System ops**: `allow_automatic_tabbing/1`
  - **System queries**: `get_system_theme/1`, `get_system_info/1`
  - **PaneGrid ops**: `pane_split/4`, `pane_close/2`, `pane_swap/3`,
    `pane_maximize/2`, `pane_restore/1`
  - **Image ops**: `create_image/2`, `create_image/4`, `update_image/2`,
    `update_image/4`, `delete_image/1`, `list_images/1`, `clear_images/0`
    (see `Command.Image`)
  - **Queries**: `tree_hash/1`, `find_focused/1`
  - **Font**: `load_font/1`
  - **Accessibility**: `announce/1`
  - **Native widget**: `widget_command/3`, `widget_commands/1`
  - **Test/Headless**: `advance_frame/1`
  - **Batch**: `batch/1`

  ## Result delivery

  Commands deliver results back to `update/2` through three mechanisms:

  - **Async/Stream**: `async/2` delivers `%Plushie.Event.AsyncEvent{tag: tag, result: result}`.
    `stream/2` delivers `%Plushie.Event.StreamEvent{tag: tag, value: value}` for each chunk.
  - **Window and system queries**: `get_window_size/2`, `get_mode/2`, etc. deliver
    `%Plushie.Event.SystemEvent{}` structs through `update/2`. The `type` field identifies the
    query kind, `tag` holds the stringified event tag, and `value` holds the result payload.
    For example, `get_system_theme(:my_tag)` delivers
    `%SystemEvent{type: :system_theme, tag: "my_tag", value: "dark"}`.
  - **Platform effects**: `Plushie.Effect` functions deliver
    `%Plushie.Event.EffectEvent{tag: tag, result: result}`. The `tag` matches the
    atom you provided when creating the effect command. Timeouts deliver the
    same struct with `result: {:error, :timeout}`. See `Plushie.Effect`.

  ## Usage

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "save"}) do
        cmd = Plushie.Command.async(fn -> save(model) end, :save_result)
        {model, cmd}
      end

      def update(model, %Plushie.Event.AsyncEvent{tag: :save_result, result: :ok}), do: %{model | saved: true}

  Multiple commands can be issued at once via `batch/1`:

      cmd = Plushie.Command.batch([
        Plushie.Command.focus("name_input"),
        Plushie.Command.send_after(5000, :auto_save)
      ])
  """

  @enforce_keys [:type, :payload]
  defstruct [:type, :payload]

  @typedoc "Stable string identifier for a widget node in the UI tree."
  @type widget_id :: String.t()

  @typedoc "Stable string identifier for a window node in the UI tree."
  @type window_id :: String.t()

  @typedoc "Tag atom used to identify async results in `update/2`."
  @type event_tag :: atom()

  @typedoc """
  A command to be dispatched by the runtime.

  Always a `%Command{}` struct. `batch/1` wraps multiple commands into a
  single struct with `type: :batch`. The runtime normalizes bare lists
  internally, but the public type is always a struct.
  """
  @type t :: %__MODULE__{type: atom(), payload: map()}

  @doc "A no-op command. Returned implicitly when `update/2` returns a bare model."
  @spec none() :: %__MODULE__{}
  def none, do: %__MODULE__{type: :none, payload: %{}}

  @doc """
  Wraps an already-resolved value in a command. The runtime immediately
  dispatches `msg_fn.(value)` through `update/2` without spawning a task.

  Useful for lifting a pure value into the command pipeline.

  The mapper receives only the value, not the model. Do not capture the
  current model in the closure: it will be stale by the time the event
  is processed. The mapper should produce an event struct that `update/2`
  handles by reading the current model at that point.
  """
  @spec done(value :: term(), msg_fn :: (term() -> term())) :: %__MODULE__{}
  def done(value, msg_fn) when is_function(msg_fn, 1) do
    %__MODULE__{type: :done, payload: %{value: value, mapper: msg_fn}}
  end

  @doc """
  Run `fun` asynchronously in a Task. When it returns, the runtime dispatches
  `%Plushie.Event.AsyncEvent{tag: event_tag, result: result}` through `update/2`.

  Only one task per tag can be active. If a task with the same tag is
  already running, it is killed and replaced. Use unique tags if you
  need concurrent tasks.
  """
  @spec async(fun :: fun(), event_tag :: atom()) :: %__MODULE__{}
  def async(fun, event_tag) when is_function(fun) and is_atom(event_tag) do
    %__MODULE__{type: :async, payload: %{fun: fun, tag: event_tag}}
  end

  @doc """
  Focus the widget identified by `widget_id`.

  Supports window-qualified paths: `"main#email"` targets widget
  `"email"` in window `"main"`.
  """
  @spec focus(widget_id :: widget_id()) :: %__MODULE__{}
  def focus(widget_id) do
    %__MODULE__{type: :focus, payload: targeted_payload(widget_id)}
  end

  @doc "Focus a specific interactive element within a canvas. Supports `\"window#canvas\"`."
  @spec focus_element(canvas_id :: widget_id(), element_id :: String.t()) :: %__MODULE__{}
  def focus_element(canvas_id, element_id) do
    %__MODULE__{
      type: :widget_op,
      payload: targeted_payload(canvas_id, %{op: "focus_element", element_id: element_id})
    }
  end

  @doc "Move focus to the next focusable widget."
  @spec focus_next() :: %__MODULE__{}
  def focus_next, do: %__MODULE__{type: :focus_next, payload: %{}}

  @doc "Move focus to the previous focusable widget."
  @spec focus_previous() :: %__MODULE__{}
  def focus_previous, do: %__MODULE__{type: :focus_previous, payload: %{}}

  @doc """
  Send `event` through `update/2` after `delay_ms` milliseconds.

  If a timer with the same event term is already pending, the previous
  timer is canceled and replaced. This prevents duplicate deliveries
  when `send_after` is called repeatedly for the same event.
  """
  @spec send_after(delay_ms :: non_neg_integer(), event :: term()) :: %__MODULE__{}
  def send_after(delay_ms, event) when is_integer(delay_ms) and delay_ms >= 0 do
    %__MODULE__{type: :send_after, payload: %{delay: delay_ms, event: event}}
  end

  # ---------------------------------------------------------------------------
  # Delegated: Text (Command.Text)
  # ---------------------------------------------------------------------------

  defdelegate select_all(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to_front(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to_end(widget_id), to: __MODULE__.Text
  defdelegate move_cursor_to(widget_id, position), to: __MODULE__.Text
  defdelegate select_range(widget_id, start_pos, end_pos), to: __MODULE__.Text

  # ---------------------------------------------------------------------------
  # Delegated: Scroll (Command.Scroll)
  # ---------------------------------------------------------------------------

  defdelegate scroll_to(widget_id, offset), to: __MODULE__.Scroll
  defdelegate snap_to(widget_id, x \\ 0.0, y \\ 0.0), to: __MODULE__.Scroll
  defdelegate snap_to_end(widget_id), to: __MODULE__.Scroll
  defdelegate scroll_by(widget_id, x \\ 0.0, y \\ 0.0), to: __MODULE__.Scroll

  # ---------------------------------------------------------------------------
  # Delegated: Window operations (Command.Window)
  # ---------------------------------------------------------------------------

  defdelegate close_window(window_id), to: __MODULE__.Window
  defdelegate set_icon(window_id, rgba_data, width, height), to: __MODULE__.Window
  defdelegate resize_window(window_id, width, height), to: __MODULE__.Window
  defdelegate move_window(window_id, x, y), to: __MODULE__.Window
  defdelegate maximize_window(window_id, maximized \\ true), to: __MODULE__.Window
  defdelegate minimize_window(window_id, minimized \\ true), to: __MODULE__.Window
  defdelegate set_window_mode(window_id, mode), to: __MODULE__.Window
  defdelegate toggle_maximize(window_id), to: __MODULE__.Window
  defdelegate toggle_decorations(window_id), to: __MODULE__.Window
  defdelegate focus_window(window_id), to: __MODULE__.Window
  defdelegate set_window_level(window_id, level), to: __MODULE__.Window
  defdelegate drag_window(window_id), to: __MODULE__.Window
  defdelegate drag_resize_window(window_id, direction), to: __MODULE__.Window
  defdelegate request_user_attention(window_id, urgency \\ nil), to: __MODULE__.Window
  defdelegate screenshot(window_id, tag), to: __MODULE__.Window
  defdelegate set_resizable(window_id, resizable), to: __MODULE__.Window
  defdelegate set_min_size(window_id, width, height), to: __MODULE__.Window
  defdelegate set_max_size(window_id, width, height), to: __MODULE__.Window
  defdelegate enable_mouse_passthrough(window_id), to: __MODULE__.Window
  defdelegate disable_mouse_passthrough(window_id), to: __MODULE__.Window
  defdelegate show_system_menu(window_id), to: __MODULE__.Window
  defdelegate set_resize_increments(window_id, width, height), to: __MODULE__.Window

  # ---------------------------------------------------------------------------
  # Delegated: Window queries (Command.WindowQuery)
  # ---------------------------------------------------------------------------

  defdelegate get_window_size(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate get_window_position(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate is_maximized(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate is_minimized(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate get_mode(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate get_scale_factor(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate raw_id(window_id, tag), to: __MODULE__.WindowQuery
  defdelegate monitor_size(window_id, tag), to: __MODULE__.WindowQuery

  # ---------------------------------------------------------------------------
  # Delegated: Image operations (Command.Image)
  # ---------------------------------------------------------------------------

  defdelegate create_image(handle, data), to: __MODULE__.Image
  defdelegate create_image(handle, width, height, pixels), to: __MODULE__.Image
  defdelegate update_image(handle, data), to: __MODULE__.Image
  defdelegate update_image(handle, width, height, pixels), to: __MODULE__.Image
  defdelegate delete_image(handle), to: __MODULE__.Image
  defdelegate list_images(tag), to: __MODULE__.Image
  defdelegate clear_images(), to: __MODULE__.Image

  @doc "Exit the application."
  @spec exit() :: %__MODULE__{}
  def exit, do: %__MODULE__{type: :exit, payload: %{}}

  @doc """
  Sets whether the system can automatically organize windows into tabs.

  This is a macOS-specific setting. On other platforms it is a no-op.
  See: https://developer.apple.com/documentation/appkit/nswindow/1646657-allowsautomaticwindowtabbing
  """
  @spec allow_automatic_tabbing(enabled :: boolean()) :: %__MODULE__{}
  def allow_automatic_tabbing(enabled) when is_boolean(enabled) do
    %__MODULE__{
      type: :system_op,
      payload: %{op: "allow_automatic_tabbing", enabled: enabled}
    }
  end

  # ---------------------------------------------------------------------------
  # System queries (results arrive as events)
  # ---------------------------------------------------------------------------

  @doc """
  Query the current system theme (light/dark mode).

  The result arrives in `update/2` as
  `%Plushie.Event.SystemEvent{type: :system_theme, tag: tag, value: mode}` where
  `tag` is the stringified event tag and `mode` is `"light"`, `"dark"`, or
  `"none"` (when no system preference is detected). Returns `"none"` on
  Linux systems without a desktop environment. Apps should provide a theme
  fallback.

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "check_theme"}) do
        {model, Plushie.Command.get_system_theme(:theme_result)}
      end

      def update(model, %Plushie.Event.SystemEvent{type: :system_theme, tag: "theme_result", value: mode}) do
        %{model | theme_mode: mode}
      end
  """
  @spec get_system_theme(tag :: event_tag()) :: %__MODULE__{}
  def get_system_theme(tag) do
    %__MODULE__{
      type: :system_query,
      payload: %{op: "get_system_theme", tag: to_string(tag)}
    }
  end

  @doc """
  Query system information (OS, CPU, memory, graphics).

  The result arrives in `update/2` as
  `%Plushie.Event.SystemEvent{type: :system_info, tag: tag, value: info}` where `tag`
  is the stringified event tag and `info` is a map with keys:
  `"system_name"`, `"system_kernel"`, `"system_version"`,
  `"system_short_version"`, `"cpu_brand"`, `"cpu_cores"`, `"memory_total"`,
  `"memory_used"`, `"graphics_backend"`, `"graphics_adapter"`.

  System info is always available (the `sysinfo` iced feature is enabled
  unconditionally).

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "sys_info"}) do
        {model, Plushie.Command.get_system_info(:sys_info)}
      end

      def update(model, %Plushie.Event.SystemEvent{type: :system_info, tag: "sys_info", value: info}) do
        %{model | system: info}
      end
  """
  @spec get_system_info(tag :: event_tag()) :: %__MODULE__{}
  def get_system_info(tag) do
    %__MODULE__{
      type: :system_query,
      payload: %{op: "get_system_info", tag: to_string(tag)}
    }
  end

  # ---------------------------------------------------------------------------
  # Accessibility
  # ---------------------------------------------------------------------------

  @doc """
  Triggers a screen reader announcement without a visible widget.

  The text is immediately announced by assistive technology as a
  live-region assertion. Useful for status updates, error messages,
  and other dynamic content that should be announced but doesn't
  need to be visually displayed.

  ## Example

      Command.announce("File saved successfully")
      Command.announce("3 search results found")
  """
  @spec announce(text :: String.t()) :: %__MODULE__{}
  def announce(text) when is_binary(text) do
    %__MODULE__{type: :widget_op, payload: %{op: "announce", text: text}}
  end

  # ---------------------------------------------------------------------------
  # PaneGrid operations
  # ---------------------------------------------------------------------------

  @doc "Split a pane in the pane grid along the given axis."
  @spec pane_split(
          pane_grid_id :: widget_id(),
          pane_id :: term(),
          axis :: atom() | String.t(),
          new_pane_id :: term()
        ) :: %__MODULE__{}
  def pane_split(pane_grid_id, pane_id, axis, new_pane_id) do
    %__MODULE__{
      type: :widget_op,
      payload: %{
        op: "pane_split",
        target: pane_grid_id,
        pane: pane_id,
        axis: to_string(axis),
        new_pane_id: new_pane_id
      }
    }
  end

  @doc "Close a pane in the pane grid."
  @spec pane_close(pane_grid_id :: widget_id(), pane_id :: term()) :: %__MODULE__{}
  def pane_close(pane_grid_id, pane_id) do
    %__MODULE__{
      type: :widget_op,
      payload: %{
        op: "pane_close",
        target: pane_grid_id,
        pane: pane_id
      }
    }
  end

  @doc "Swap two panes in the pane grid."
  @spec pane_swap(pane_grid_id :: widget_id(), pane_a :: term(), pane_b :: term()) ::
          %__MODULE__{}
  def pane_swap(pane_grid_id, pane_a, pane_b) do
    %__MODULE__{
      type: :widget_op,
      payload: %{
        op: "pane_swap",
        target: pane_grid_id,
        a: pane_a,
        b: pane_b
      }
    }
  end

  @doc "Maximize a pane in the pane grid."
  @spec pane_maximize(pane_grid_id :: widget_id(), pane_id :: term()) :: %__MODULE__{}
  def pane_maximize(pane_grid_id, pane_id) do
    %__MODULE__{
      type: :widget_op,
      payload: %{
        op: "pane_maximize",
        target: pane_grid_id,
        pane: pane_id
      }
    }
  end

  @doc "Restore all panes from maximized state."
  @spec pane_restore(pane_grid_id :: widget_id()) :: %__MODULE__{}
  def pane_restore(pane_grid_id) do
    %__MODULE__{
      type: :widget_op,
      payload: %{
        op: "pane_restore",
        target: pane_grid_id
      }
    }
  end

  @doc """
  Run `fun` as a streaming async task. The function receives an `emit` callback
  that sends intermediate results to `update/2` as
  `%Plushie.Event.StreamEvent{tag: event_tag, value: value}`. The function's final
  return value is delivered as `%Plushie.Event.AsyncEvent{tag: event_tag, result: result}`.

  Only one task per tag can be active. If a task with the same tag is
  already running, it is killed and replaced. Use unique tags if you
  need concurrent streams.

  This is sugar over spawning a process manually. You can achieve the same
  thing with bare `Task` and `send/2` if you prefer direct Elixir patterns.

  ## Example

      Command.stream(fn emit ->
        for chunk <- File.stream!("big.csv") do
          emit.({:chunk, process(chunk)})
        end
        :done
      end, :file_import)
  """
  @spec stream(fun :: (fun() -> term()), event_tag :: atom()) :: %__MODULE__{}
  def stream(fun, event_tag) when is_function(fun, 1) and is_atom(event_tag) do
    %__MODULE__{type: :stream, payload: %{fun: fun, tag: event_tag}}
  end

  @doc """
  Cancel a running async or stream command by its tag.

  If the task has already completed, this is a no-op. The runtime tracks
  running tasks by their event tag and terminates the associated process.

  ## Example

      Command.cancel(:file_import)
  """
  @spec cancel(event_tag :: atom()) :: %__MODULE__{}
  def cancel(event_tag) when is_atom(event_tag) do
    %__MODULE__{type: :cancel, payload: %{tag: event_tag}}
  end

  @doc """
  Computes a SHA-256 hash of the renderer's current tree state.

  The result arrives in `update/2` as
  `%SystemEvent{type: :tree_hash, tag: tag, value: %{"hash" => "..."}}`.
  """
  @spec tree_hash(tag :: atom()) :: %__MODULE__{}
  def tree_hash(tag) when is_atom(tag) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "tree_hash", tag: Atom.to_string(tag)}
    }
  end

  @doc """
  Queries which widget currently has focus.

  The result arrives in `update/2` as
  `%SystemEvent{type: :find_focused, tag: tag, value: %{"focused" => "..." | nil}}`.

  Note: if no widget is focused, the `"focused"` field may be `nil`.
  """
  @spec find_focused(tag :: atom()) :: %__MODULE__{}
  def find_focused(tag) when is_atom(tag) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "find_focused", tag: Atom.to_string(tag)}
    }
  end

  @doc """
  Loads a font at runtime from binary data.

  The font data should be the raw bytes of a TrueType (.ttf) or OpenType
  (.otf) font file. Once loaded, the font can be referenced by name in
  widget `font` props.

  ## Example

      font_data = File.read!("path/to/CustomFont.ttf")
      Plushie.Command.load_font(font_data)
  """
  @spec load_font(data :: binary()) :: %__MODULE__{}
  def load_font(data) when is_binary(data) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "load_font", data: data}
    }
  end

  # ---------------------------------------------------------------------------
  # Widget commands
  # ---------------------------------------------------------------------------

  @doc """
  Send a command to a native widget.

  Widget commands bypass the normal tree update / diff / patch cycle and
  are delivered directly to the target native widget on the Rust side.
  """
  @spec widget_command(node_id :: String.t(), op :: String.t(), payload :: map()) ::
          %__MODULE__{}
  def widget_command(node_id, op, payload \\ %{})
      when is_binary(node_id) and is_binary(op) do
    %__MODULE__{
      type: :widget_command,
      payload: %{node_id: node_id, op: op, payload: payload}
    }
  end

  @doc """
  Send a batch of widget commands (processed in one cycle).

  Each command in the list is a `{node_id, op, payload}` tuple.
  """
  @spec widget_commands(commands :: [{String.t(), String.t(), map()}]) :: %__MODULE__{}
  def widget_commands(commands) when is_list(commands) do
    %__MODULE__{type: :widget_commands, payload: %{commands: commands}}
  end

  @doc """
  Advance the animation clock by one frame in headless/test mode.

  Sends an `advance_frame` message to the renderer with the given
  `timestamp` (monotonic milliseconds). If `on_animation_frame` is
  subscribed, the renderer emits an `animation_frame` event back.

  This is a test/headless-only command. In normal daemon mode the
  renderer drives animation frames from the display vsync.

  ## Example

      Plushie.Command.advance_frame(16)
  """
  @spec advance_frame(timestamp :: non_neg_integer()) :: %__MODULE__{}
  def advance_frame(timestamp) when is_integer(timestamp) and timestamp >= 0 do
    %__MODULE__{
      type: :advance_frame,
      payload: %{timestamp: timestamp}
    }
  end

  @doc """
  Issue multiple commands. Commands in the batch execute sequentially
  in list order, with state threaded through each.

  Accepts a single command, a list of commands, or a nested list -- anything
  `List.wrap/1` can normalize.
  """
  @spec batch(commands :: t() | [t()]) :: %__MODULE__{}
  def batch(commands) do
    %__MODULE__{type: :batch, payload: %{commands: List.wrap(commands)}}
  end

  # -- Helpers -----------------------------------------------------------------

  # Parses a widget ID that may contain a window qualifier.
  # "main#form/email" -> {"main", "form/email"}
  # "form/email"      -> {nil, "form/email"}
  # Non-string IDs pass through unchanged.
  @doc false
  @spec parse_target(widget_id()) :: {String.t() | nil, widget_id()}
  def parse_target(widget_id) when is_binary(widget_id) do
    case String.split(widget_id, "#", parts: 2) do
      [window_id, path] when window_id != "" -> {window_id, path}
      _ -> {nil, widget_id}
    end
  end

  def parse_target(widget_id), do: {nil, widget_id}

  @doc """
  Builds a command payload from a widget ID, handling window-qualified paths.

  Adds `:target` (and `:window_id` when present) to the given `extra` map.
  """
  @spec targeted_payload(widget_id(), map()) :: map()
  def targeted_payload(widget_id, extra \\ %{}) do
    {window_id, target} = parse_target(widget_id)
    payload = Map.put(extra, :target, target)
    if window_id, do: Map.put(payload, :window_id, window_id), else: payload
  end
end
