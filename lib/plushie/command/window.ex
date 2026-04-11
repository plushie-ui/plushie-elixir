defmodule Plushie.Command.Window do
  @moduledoc """
  Window operation commands.

  ## Lifecycle

  `close_window/1`

  ## Sizing and position

  `resize_window/3`, `move_window/3`, `set_min_size/3`, `set_max_size/3`,
  `set_resize_increments/3`, `set_resizable/2`

  ## Window state

  `maximize_window/2`, `minimize_window/2`, `toggle_maximize/1`,
  `set_window_mode/2`, `toggle_decorations/1`, `set_window_level/2`

  ## Focus and interaction

  `focus_window/1`, `drag_window/1`, `drag_resize_window/2`,
  `request_user_attention/2`, `show_system_menu/1`

  ## Input

  `enable_mouse_passthrough/1`, `disable_mouse_passthrough/1`

  ## Visuals

  `set_icon/4`, `screenshot/2`
  """

  alias Plushie.Command

  @doc "Close the window identified by `window_id`."
  @spec close_window(window_id :: Command.window_id()) :: Command.t()
  def close_window(window_id) do
    %Command{type: :close_window, payload: %{window_id: window_id}}
  end

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
          window_id :: Command.window_id(),
          rgba_data :: binary(),
          width :: pos_integer(),
          height :: pos_integer()
        ) :: Command.t()
  def set_icon(window_id, rgba_data, width, height)
      when is_binary(rgba_data) and is_integer(width) and width > 0 and is_integer(height) and
             height > 0 do
    %Command{
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
  @spec resize_window(window_id :: Command.window_id(), width :: number(), height :: number()) ::
          Command.t()
  def resize_window(window_id, width, height) do
    %Command{
      type: :window_op,
      payload: %{op: "resize", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Move a window to the given position."
  @spec move_window(window_id :: Command.window_id(), x :: number(), y :: number()) :: Command.t()
  def move_window(window_id, x, y) do
    %Command{type: :window_op, payload: %{op: "move", window_id: window_id, x: x, y: y}}
  end

  @doc "Maximize or restore a window."
  @spec maximize_window(window_id :: Command.window_id(), maximized :: boolean()) :: Command.t()
  def maximize_window(window_id, maximized \\ true) do
    %Command{
      type: :window_op,
      payload: %{op: "maximize", window_id: window_id, maximized: maximized}
    }
  end

  @doc "Minimize or restore a window."
  @spec minimize_window(window_id :: Command.window_id(), minimized :: boolean()) :: Command.t()
  def minimize_window(window_id, minimized \\ true) do
    %Command{
      type: :window_op,
      payload: %{op: "minimize", window_id: window_id, minimized: minimized}
    }
  end

  @doc "Set window mode (windowed, fullscreen, etc.)."
  @spec set_window_mode(window_id :: Command.window_id(), mode :: atom() | String.t()) ::
          Command.t()
  def set_window_mode(window_id, mode) do
    %Command{
      type: :window_op,
      payload: %{op: "set_mode", window_id: window_id, mode: to_string(mode)}
    }
  end

  @doc "Toggle window maximized state."
  @spec toggle_maximize(window_id :: Command.window_id()) :: Command.t()
  def toggle_maximize(window_id) do
    %Command{type: :window_op, payload: %{op: "toggle_maximize", window_id: window_id}}
  end

  @doc "Toggle window decorations (title bar, borders)."
  @spec toggle_decorations(window_id :: Command.window_id()) :: Command.t()
  def toggle_decorations(window_id) do
    %Command{type: :window_op, payload: %{op: "toggle_decorations", window_id: window_id}}
  end

  @doc "Give focus to a window, bringing it to the front."
  @spec focus_window(window_id :: Command.window_id()) :: Command.t()
  def focus_window(window_id) do
    %Command{type: :window_op, payload: %{op: "gain_focus", window_id: window_id}}
  end

  @doc """
  Set window stacking level (:normal, :always_on_top, :always_on_bottom).

  On Wayland, window stacking is compositor-controlled and this command may
  be silently ignored.
  """
  @spec set_window_level(window_id :: Command.window_id(), level :: atom() | String.t()) ::
          Command.t()
  def set_window_level(window_id, level) do
    %Command{
      type: :window_op,
      payload: %{op: "set_level", window_id: window_id, level: to_string(level)}
    }
  end

  @doc "Start dragging the window."
  @spec drag_window(window_id :: Command.window_id()) :: Command.t()
  def drag_window(window_id) do
    %Command{type: :window_op, payload: %{op: "drag", window_id: window_id}}
  end

  @doc "Start drag-resizing the window from the given edge/corner direction."
  @spec drag_resize_window(window_id :: Command.window_id(), direction :: atom() | String.t()) ::
          Command.t()
  def drag_resize_window(window_id, direction) do
    %Command{
      type: :window_op,
      payload: %{op: "drag_resize", window_id: window_id, direction: to_string(direction)}
    }
  end

  @doc "Request user attention for a window. Urgency can be :informational or :critical."
  @spec request_user_attention(window_id :: Command.window_id(), urgency :: atom() | nil) ::
          Command.t()
  def request_user_attention(window_id, urgency \\ nil) do
    %Command{
      type: :window_op,
      payload: %{
        op: "request_attention",
        window_id: window_id,
        urgency: urgency && to_string(urgency)
      }
    }
  end

  @doc "Take a screenshot of a window. Result arrives as a tagged event."
  @spec screenshot(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def screenshot(window_id, tag) do
    %Command{
      type: :window_op,
      payload: %{op: "screenshot", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc "Set whether a window is resizable."
  @spec set_resizable(window_id :: Command.window_id(), resizable :: boolean()) :: Command.t()
  def set_resizable(window_id, resizable) do
    %Command{
      type: :window_op,
      payload: %{op: "set_resizable", window_id: window_id, resizable: resizable}
    }
  end

  @doc "Set the minimum size of a window."
  @spec set_min_size(window_id :: Command.window_id(), width :: number(), height :: number()) ::
          Command.t()
  def set_min_size(window_id, width, height) do
    %Command{
      type: :window_op,
      payload: %{op: "set_min_size", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Set the maximum size of a window."
  @spec set_max_size(window_id :: Command.window_id(), width :: number(), height :: number()) ::
          Command.t()
  def set_max_size(window_id, width, height) do
    %Command{
      type: :window_op,
      payload: %{op: "set_max_size", window_id: window_id, width: width, height: height}
    }
  end

  @doc "Enable mouse passthrough on a window (clicks pass through to windows below)."
  @spec enable_mouse_passthrough(window_id :: Command.window_id()) :: Command.t()
  def enable_mouse_passthrough(window_id) do
    %Command{
      type: :window_op,
      payload: %{op: "mouse_passthrough", window_id: window_id, enabled: true}
    }
  end

  @doc "Disable mouse passthrough on a window."
  @spec disable_mouse_passthrough(window_id :: Command.window_id()) :: Command.t()
  def disable_mouse_passthrough(window_id) do
    %Command{
      type: :window_op,
      payload: %{op: "mouse_passthrough", window_id: window_id, enabled: false}
    }
  end

  @doc "Show the system menu for a window."
  @spec show_system_menu(window_id :: Command.window_id()) :: Command.t()
  def show_system_menu(window_id) do
    %Command{type: :window_op, payload: %{op: "show_system_menu", window_id: window_id}}
  end

  @doc """
  Sets the resize increment size for a window.

  When set, the window will only resize in multiples of the given width and
  height. Pass `nil` for both to clear the constraint. Useful for terminal
  emulators and grid-aligned apps.
  """
  @spec set_resize_increments(
          window_id :: Command.window_id(),
          width :: number() | nil,
          height :: number() | nil
        ) :: Command.t()
  def set_resize_increments(window_id, width, height) do
    %Command{
      type: :window_op,
      payload: %{
        op: "set_resize_increments",
        window_id: window_id,
        width: width,
        height: height
      }
    }
  end
end
