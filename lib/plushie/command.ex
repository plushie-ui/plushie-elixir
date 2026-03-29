defmodule Plushie.Command do
  @moduledoc """
  Commands describe side effects that `update/2` wants the runtime to perform.

  They are plain data -- inspectable, testable, serializable. The runtime
  interprets them after `update/2` returns. Nothing executes inside `update`.

  ## Categories

  - **Basic**: `none/0`, `done/2`, `async/2`, `stream/2`, `cancel/1`, `send_after/2`, `exit/0`
  - **Focus**: `focus/1`, `focus_next/0`, `focus_previous/0`
  - **Text**: `select_all/1`, `move_cursor_to_front/1`, `move_cursor_to_end/1`,
    `move_cursor_to/2`, `select_range/3`
  - **Scroll**: `scroll_to/2`, `snap_to/3`, `snap_to_end/1`, `scroll_by/3`
  - **Window ops**: `close_window/1`, `resize_window/3`, `move_window/3`,
    `maximize_window/2`, `minimize_window/2`, `set_window_mode/2`,
    `toggle_maximize/1`, `toggle_decorations/1`, `gain_focus/1`,
    `set_window_level/2`, `drag_window/1`, `drag_resize_window/2`,
    `request_user_attention/2`, `screenshot/2`, `set_resizable/2`,
    `set_min_size/3`, `set_max_size/3`, `enable_mouse_passthrough/1`,
    `disable_mouse_passthrough/1`, `show_system_menu/1`, `set_icon/4`,
    `set_resize_increments/3`, `allow_automatic_tabbing/1`.
  - **Window queries**: `get_window_size/2`, `get_window_position/2`,
    `is_maximized/2`, `is_minimized/2`, `get_mode/2`, `get_scale_factor/2`,
    `raw_id/2`, `monitor_size/2`
  - **System ops**: `allow_automatic_tabbing/1`
  - **System queries**: `get_system_theme/1`, `get_system_info/1`
  - **PaneGrid ops**: `pane_split/4`, `pane_close/2`, `pane_swap/3`,
    `pane_maximize/2`, `pane_restore/1`
  - **Image ops**: `create_image/2`, `create_image/4`, `update_image/2`,
    `update_image/4`, `delete_image/1`, `list_images/1`, `clear_images/0`
  - **Queries**: `tree_hash/1`, `find_focused/1`
  - **Font**: `load_font/1`
  - **Accessibility**: `announce/1`
  - **Native widget**: `widget_command/3`, `widget_commands/1`
  - **Test/Headless**: `advance_frame/1`
  - **Batch**: `batch/1`

  ## Result delivery

  Commands deliver results back to `update/2` through three mechanisms:

  - **Async/Stream**: `async/2` delivers `%Plushie.Event.Async{tag: tag, result: result}`.
    `stream/2` delivers `%Plushie.Event.Stream{tag: tag, value: value}` for each chunk.
  - **Window and system queries**: `get_window_size/2`, `get_mode/2`, etc. deliver
    `%Plushie.Event.SystemEvent{}` structs through `update/2`. The `type` field identifies the
    query kind, `tag` holds the stringified event tag, and `data` holds the result payload.
    For example, `get_system_theme(:my_tag)` delivers
    `%SystemEvent{type: :system_theme, tag: "my_tag", data: "dark"}`.
  - **Platform effects**: `Plushie.Effects` functions deliver
    `%Plushie.Event.Effect{request_id: id, result: result}`. The `request_id` correlates
    with the command payload's `:id` field. Timeouts deliver the same struct with
    `result: {:error, :timeout}`. See `Plushie.Effects` for details.

  ## Usage

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "save"}) do
        cmd = Plushie.Command.async(fn -> save(model) end, :save_result)
        {model, cmd}
      end

      def update(model, %Plushie.Event.Async{tag: :save_result, result: :ok}), do: %{model | saved: true}

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
  """
  @spec done(value :: term(), msg_fn :: (term() -> term())) :: %__MODULE__{}
  def done(value, msg_fn) when is_function(msg_fn, 1) do
    %__MODULE__{type: :done, payload: %{value: value, mapper: msg_fn}}
  end

  @doc """
  Run `fun` asynchronously in a Task. When it returns, the runtime dispatches
  `%Plushie.Event.Async{tag: event_tag, result: result}` through `update/2`.

  Only one task per tag can be active. If a task with the same tag is
  already running, it is killed and replaced. Use unique tags if you
  need concurrent tasks.
  """
  @spec async(fun :: fun(), event_tag :: atom()) :: %__MODULE__{}
  def async(fun, event_tag) when is_function(fun) and is_atom(event_tag) do
    %__MODULE__{type: :async, payload: %{fun: fun, tag: event_tag}}
  end

  @doc "Focus the widget identified by `widget_id`."
  @spec focus(widget_id :: widget_id()) :: %__MODULE__{}
  def focus(widget_id) do
    %__MODULE__{type: :focus, payload: %{target: widget_id}}
  end

  @doc "Focus a specific interactive element within a canvas."
  @spec focus_element(canvas_id :: widget_id(), element_id :: String.t()) :: %__MODULE__{}
  def focus_element(canvas_id, element_id) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "focus_element", target: canvas_id, element_id: element_id}
    }
  end

  @doc "Move focus to the next focusable widget."
  @spec focus_next() :: %__MODULE__{}
  def focus_next, do: %__MODULE__{type: :focus_next, payload: %{}}

  @doc "Move focus to the previous focusable widget."
  @spec focus_previous() :: %__MODULE__{}
  def focus_previous, do: %__MODULE__{type: :focus_previous, payload: %{}}

  @doc "Select all text in the widget identified by `widget_id`."
  @spec select_all(widget_id :: widget_id()) :: %__MODULE__{}
  def select_all(widget_id) do
    %__MODULE__{type: :select_all, payload: %{target: widget_id}}
  end

  @doc "Scroll the widget identified by `widget_id` to `offset`."
  @spec scroll_to(widget_id :: widget_id(), offset :: term()) :: %__MODULE__{}
  def scroll_to(widget_id, offset) do
    %__MODULE__{type: :scroll_to, payload: %{target: widget_id, offset_y: offset}}
  end

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

  @doc "Close the window identified by `window_id`."
  @spec close_window(window_id :: window_id()) :: %__MODULE__{}
  def close_window(window_id) do
    %__MODULE__{type: :close_window, payload: %{window_id: window_id}}
  end

  @doc "Exit the application."
  @spec exit() :: %__MODULE__{}
  def exit, do: %__MODULE__{type: :exit, payload: %{}}

  @doc "Snap the scrollable widget to an absolute offset."
  @spec snap_to(widget_id :: widget_id(), x :: float(), y :: float()) :: %__MODULE__{}
  def snap_to(widget_id, x \\ 0.0, y \\ 0.0) do
    %__MODULE__{type: :snap_to, payload: %{target: widget_id, x: x, y: y}}
  end

  @doc "Snap the scrollable widget to the end of its content."
  @spec snap_to_end(widget_id :: widget_id()) :: %__MODULE__{}
  def snap_to_end(widget_id) do
    %__MODULE__{type: :snap_to_end, payload: %{target: widget_id}}
  end

  @doc "Scroll the widget by a relative offset."
  @spec scroll_by(widget_id :: widget_id(), x :: float(), y :: float()) :: %__MODULE__{}
  def scroll_by(widget_id, x \\ 0.0, y \\ 0.0) do
    %__MODULE__{type: :scroll_by, payload: %{target: widget_id, x: x, y: y}}
  end

  @doc "Move the text cursor to the front of the input."
  @spec move_cursor_to_front(widget_id :: widget_id()) :: %__MODULE__{}
  def move_cursor_to_front(widget_id) do
    %__MODULE__{type: :move_cursor_to_front, payload: %{target: widget_id}}
  end

  @doc "Move the text cursor to the end of the input."
  @spec move_cursor_to_end(widget_id :: widget_id()) :: %__MODULE__{}
  def move_cursor_to_end(widget_id) do
    %__MODULE__{type: :move_cursor_to_end, payload: %{target: widget_id}}
  end

  @doc "Move the text cursor to a specific position."
  @spec move_cursor_to(widget_id :: widget_id(), position :: non_neg_integer()) :: %__MODULE__{}
  def move_cursor_to(widget_id, position) do
    %__MODULE__{type: :move_cursor_to, payload: %{target: widget_id, position: position}}
  end

  @doc "Select a range of text in the input."
  @spec select_range(
          widget_id :: widget_id(),
          start_pos :: non_neg_integer(),
          end_pos :: non_neg_integer()
        ) :: %__MODULE__{}
  def select_range(widget_id, start_pos, end_pos) do
    %__MODULE__{
      type: :select_range,
      payload: %{target: widget_id, start: start_pos, end: end_pos}
    }
  end

  # ---------------------------------------------------------------------------
  # Window operations
  # ---------------------------------------------------------------------------

  @doc """
  Sets the window icon from raw RGBA pixel data.

  The `rgba_data` must be a binary of `width * height * 4` bytes (one byte
  each for R, G, B, A per pixel, row-major). The raw binary is stored as-is
  in the command payload. The protocol layer handles format-specific encoding
  (native binary for msgpack via Msgpax.Bin, base64 for JSON).

  ## Example

      icon_data = File.read!("icon_32x32.rgba")
      Plushie.Command.set_icon("main", icon_data, 32, 32)
  """
  @spec set_icon(
          window_id :: window_id(),
          rgba_data :: binary(),
          width :: pos_integer(),
          height :: pos_integer()
        ) :: %__MODULE__{}
  def set_icon(window_id, rgba_data, width, height)
      when is_binary(rgba_data) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 do
    %__MODULE__{
      type: :window_op,
      payload: %{
        op: "set_icon",
        window_id: window_id,
        icon_data: rgba_data,
        width: width,
        height: height
      }
    }
  end

  @doc "Resize a window to the given dimensions."
  @spec resize_window(window_id :: window_id(), width :: number(), height :: number()) ::
          %__MODULE__{}
  def resize_window(window_id, width, height) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "resize", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Move a window to the given position."
  @spec move_window(window_id :: window_id(), x :: number(), y :: number()) :: %__MODULE__{}
  def move_window(window_id, x, y) do
    %__MODULE__{type: :window_op, payload: %{op: "move", window_id: window_id, x: x, y: y}}
  end

  @doc "Maximize or restore a window."
  @spec maximize_window(window_id :: window_id(), maximized :: boolean()) :: %__MODULE__{}
  def maximize_window(window_id, maximized \\ true) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "maximize", window_id: window_id, maximized: maximized}
    }
  end

  @doc "Minimize or restore a window."
  @spec minimize_window(window_id :: window_id(), minimized :: boolean()) :: %__MODULE__{}
  def minimize_window(window_id, minimized \\ true) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "minimize", window_id: window_id, minimized: minimized}
    }
  end

  @doc "Set window mode (windowed, fullscreen, etc.)."
  @spec set_window_mode(window_id :: window_id(), mode :: atom() | String.t()) :: %__MODULE__{}
  def set_window_mode(window_id, mode) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "set_mode", window_id: window_id, mode: to_string(mode)}
    }
  end

  @doc "Toggle window maximized state."
  @spec toggle_maximize(window_id :: window_id()) :: %__MODULE__{}
  def toggle_maximize(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "toggle_maximize", window_id: window_id}}
  end

  @doc "Toggle window decorations (title bar, borders)."
  @spec toggle_decorations(window_id :: window_id()) :: %__MODULE__{}
  def toggle_decorations(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "toggle_decorations", window_id: window_id}}
  end

  @doc "Give focus to a window."
  @spec gain_focus(window_id :: window_id()) :: %__MODULE__{}
  def gain_focus(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "gain_focus", window_id: window_id}}
  end

  @doc """
  Set window stacking level (:normal, :always_on_top, :always_on_bottom).

  On Wayland, window stacking is compositor-controlled and this command may
  be silently ignored.
  """
  @spec set_window_level(window_id :: window_id(), level :: atom() | String.t()) :: %__MODULE__{}
  def set_window_level(window_id, level) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "set_level", window_id: window_id, level: to_string(level)}
    }
  end

  @doc "Start dragging the window."
  @spec drag_window(window_id :: window_id()) :: %__MODULE__{}
  def drag_window(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "drag", window_id: window_id}}
  end

  @doc "Start drag-resizing the window from the given edge/corner direction."
  @spec drag_resize_window(window_id :: window_id(), direction :: atom() | String.t()) ::
          %__MODULE__{}
  def drag_resize_window(window_id, direction) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "drag_resize", window_id: window_id, direction: to_string(direction)}
    }
  end

  @doc "Request user attention for a window. Urgency can be :informational or :critical."
  @spec request_user_attention(window_id :: window_id(), urgency :: atom() | nil) :: %__MODULE__{}
  def request_user_attention(window_id, urgency \\ nil) do
    %__MODULE__{
      type: :window_op,
      payload: %{
        op: "request_attention",
        window_id: window_id,
        urgency: urgency && to_string(urgency)
      }
    }
  end

  @doc "Take a screenshot of a window. Result arrives as a tagged event."
  @spec screenshot(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def screenshot(window_id, tag) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "screenshot", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc "Set whether a window is resizable."
  @spec set_resizable(window_id :: window_id(), resizable :: boolean()) :: %__MODULE__{}
  def set_resizable(window_id, resizable) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "set_resizable", window_id: window_id, resizable: resizable}
    }
  end

  @doc "Set the minimum size of a window."
  @spec set_min_size(window_id :: window_id(), width :: number(), height :: number()) ::
          %__MODULE__{}
  def set_min_size(window_id, width, height) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "set_min_size", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Set the maximum size of a window."
  @spec set_max_size(window_id :: window_id(), width :: number(), height :: number()) ::
          %__MODULE__{}
  def set_max_size(window_id, width, height) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "set_max_size", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Enable mouse passthrough on a window (clicks pass through to windows below)."
  @spec enable_mouse_passthrough(window_id :: window_id()) :: %__MODULE__{}
  def enable_mouse_passthrough(window_id) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "mouse_passthrough", window_id: window_id, enabled: true}
    }
  end

  @doc "Disable mouse passthrough on a window."
  @spec disable_mouse_passthrough(window_id :: window_id()) :: %__MODULE__{}
  def disable_mouse_passthrough(window_id) do
    %__MODULE__{
      type: :window_op,
      payload: %{op: "mouse_passthrough", window_id: window_id, enabled: false}
    }
  end

  @doc "Show the system menu for a window."
  @spec show_system_menu(window_id :: window_id()) :: %__MODULE__{}
  def show_system_menu(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "show_system_menu", window_id: window_id}}
  end

  @doc """
  Sets the resize increment size for a window.

  When set, the window will only resize in multiples of the given width and
  height. Pass `nil` for both to clear the constraint. Useful for terminal
  emulators and grid-aligned apps.
  """
  @spec set_resize_increments(
          window_id :: window_id(),
          width :: number() | nil,
          height :: number() | nil
        ) :: %__MODULE__{}
  def set_resize_increments(window_id, width, height) do
    %__MODULE__{
      type: :window_op,
      payload: %{
        op: "set_resize_increments",
        window_id: window_id,
        width: width,
        height: height
      }
    }
  end

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
  # Window queries (results arrive as events)
  # ---------------------------------------------------------------------------

  @doc """
  Query the size of a window.

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, data}}`
  where `data` is `%{"width" => width, "height" => height}`.
  """
  @spec get_window_size(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def get_window_size(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "get_size", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the position of a window.

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, data}}`
  where `data` is `%{"x" => x, "y" => y}` or `nil` if unavailable.
  """
  @spec get_window_position(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def get_window_position(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "get_position", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query whether a window is maximized.

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, boolean}}`.
  """
  @spec is_maximized(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def is_maximized(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "is_maximized", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query whether a window is minimized.

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, boolean}}`.
  """
  @spec is_minimized(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def is_minimized(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "is_minimized", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the current window mode (windowed, fullscreen, hidden).

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, mode}}`.
  """
  @spec get_mode(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def get_mode(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "get_mode", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the window's current scale factor (DPI scaling).

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, factor}}`.
  """
  @spec get_scale_factor(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def get_scale_factor(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "get_scale_factor", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the raw platform window ID (e.g. X11 window ID, HWND).

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, platform_id}}`.
  """
  @spec raw_id(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def raw_id(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "raw_id", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the monitor size for the display containing a window.

  Result arrives as `%Plushie.Event.Effect{request_id: window_id, result: {:ok, data}}`
  where `data` is `%{"width" => width, "height" => height}` or `nil` if the
  monitor cannot be determined.
  """
  @spec monitor_size(window_id :: window_id(), tag :: event_tag()) :: %__MODULE__{}
  def monitor_size(window_id, tag) do
    %__MODULE__{
      type: :window_query,
      payload: %{op: "monitor_size", window_id: window_id, tag: to_string(tag)}
    }
  end

  # ---------------------------------------------------------------------------
  # System queries (results arrive as events)
  # ---------------------------------------------------------------------------

  @doc """
  Query the current system theme (light/dark mode).

  The result arrives in `update/2` as
  `%Plushie.Event.SystemEvent{type: :system_theme, tag: tag, data: mode}` where
  `tag` is the stringified event tag and `mode` is `"light"`, `"dark"`, or
  `"none"` (when no system preference is detected). Returns `"none"` on
  Linux systems without a desktop environment. Apps should provide a theme
  fallback.

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "check_theme"}) do
        {model, Plushie.Command.get_system_theme(:theme_result)}
      end

      def update(model, %Plushie.Event.SystemEvent{type: :system_theme, tag: "theme_result", data: mode}) do
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
  `%Plushie.Event.SystemEvent{type: :system_info, tag: tag, data: info}` where `tag`
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

      def update(model, %Plushie.Event.SystemEvent{type: :system_info, tag: "sys_info", data: info}) do
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
  `%Plushie.Event.Stream{tag: event_tag, value: value}`. The function's final
  return value is delivered as `%Plushie.Event.Async{tag: event_tag, result: result}`.

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

  # ---------------------------------------------------------------------------
  # Image operations
  # ---------------------------------------------------------------------------

  @doc """
  Creates an in-memory image from encoded PNG/JPEG bytes.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec create_image(handle :: String.t(), data :: binary()) :: %__MODULE__{}
  def create_image(handle, data) when is_binary(handle) and is_binary(data) do
    %__MODULE__{
      type: :image_op,
      payload: %{op: "create_image", handle: handle, data: data}
    }
  end

  @doc """
  Creates an in-memory image from raw RGBA pixel data.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec create_image(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: %__MODULE__{}
  def create_image(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and is_integer(height) and is_binary(pixels) do
    %__MODULE__{
      type: :image_op,
      payload: %{
        op: "create_image",
        handle: handle,
        width: width,
        height: height,
        pixels: pixels
      }
    }
  end

  @doc """
  Updates an existing in-memory image with new encoded PNG/JPEG bytes.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec update_image(handle :: String.t(), data :: binary()) :: %__MODULE__{}
  def update_image(handle, data) when is_binary(handle) and is_binary(data) do
    %__MODULE__{
      type: :image_op,
      payload: %{op: "update_image", handle: handle, data: data}
    }
  end

  @doc """
  Updates an existing in-memory image with new raw RGBA pixel data.

  The raw binary is stored as-is in the command payload. The protocol layer
  handles format-specific encoding (native binary for msgpack, base64 for JSON).
  """
  @spec update_image(
          handle :: String.t(),
          width :: pos_integer(),
          height :: pos_integer(),
          pixels :: binary()
        ) :: %__MODULE__{}
  def update_image(handle, width, height, pixels)
      when is_binary(handle) and is_integer(width) and is_integer(height) and is_binary(pixels) do
    %__MODULE__{
      type: :image_op,
      payload: %{
        op: "update_image",
        handle: handle,
        width: width,
        height: height,
        pixels: pixels
      }
    }
  end

  @doc "Deletes an in-memory image by handle name."
  @spec delete_image(handle :: String.t()) :: %__MODULE__{}
  def delete_image(handle) when is_binary(handle) do
    %__MODULE__{
      type: :image_op,
      payload: %{op: "delete_image", handle: handle}
    }
  end

  @doc """
  Lists all in-memory image handles.

  The result arrives in `update/2` as
  `%SystemEvent{type: :image_list, tag: tag, data: %{"handles" => [...]}}`.
  """
  @spec list_images(tag :: atom()) :: %__MODULE__{}
  def list_images(tag) when is_atom(tag) do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "list_images", tag: Atom.to_string(tag)}
    }
  end

  @doc "Clears all in-memory images."
  @spec clear_images() :: %__MODULE__{}
  def clear_images do
    %__MODULE__{
      type: :widget_op,
      payload: %{op: "clear_images"}
    }
  end

  @doc """
  Computes a SHA-256 hash of the renderer's current tree state.

  The result arrives in `update/2` as
  `%SystemEvent{type: :tree_hash, tag: tag, data: %{"hash" => "..."}}`.
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
  `%SystemEvent{type: :find_focused, tag: tag, data: %{"focused" => "..." | nil}}`.

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
end
