defmodule Julep.Command do
  @moduledoc """
  Commands describe side effects that `update/2` wants the runtime to perform.

  They are plain data -- inspectable, testable, serializable. The runtime
  interprets them after `update/2` returns. Nothing executes inside `update`.

  ## Usage

      def update(model, {:click, "save"}) do
        cmd = Julep.Command.async(fn -> save(model) end, :save_result)
        {model, cmd}
      end

      def update(model, {:save_result, :ok}), do: %{model | saved: true}

  Multiple commands can be issued at once via `batch/1`:

      cmd = Julep.Command.batch([
        Julep.Command.focus("name_input"),
        Julep.Command.send_after(5000, :auto_save)
      ])
  """

  @enforce_keys [:type, :payload]
  defstruct [:type, :payload]

  @type t :: %__MODULE__{type: atom(), payload: map()} | [%__MODULE__{}]

  @doc "A no-op command. Returned implicitly when `update/2` returns a bare model."
  @spec none() :: %__MODULE__{}
  def none, do: %__MODULE__{type: :none, payload: %{}}

  @doc """
  Wraps an already-resolved value in a command. The runtime immediately
  dispatches `msg_fn.(value)` through `update/2` without spawning a task.

  Useful for lifting a pure value into the command pipeline.
  """
  @spec done(term(), (term() -> term())) :: %__MODULE__{}
  def done(value, msg_fn) when is_function(msg_fn, 1) do
    %__MODULE__{type: :done, payload: %{value: value, mapper: msg_fn}}
  end

  @doc """
  Run `fun` asynchronously in a Task. When it returns, the runtime dispatches
  `{event_tag, result}` through `update/2`.
  """
  @spec async(fun(), atom()) :: %__MODULE__{}
  def async(fun, event_tag) when is_function(fun) and is_atom(event_tag) do
    %__MODULE__{type: :async, payload: %{fun: fun, tag: event_tag}}
  end

  @doc "Focus the widget identified by `widget_id`."
  @spec focus(term()) :: %__MODULE__{}
  def focus(widget_id) do
    %__MODULE__{type: :focus, payload: %{target: widget_id}}
  end

  @doc "Move focus to the next focusable widget."
  @spec focus_next() :: %__MODULE__{}
  def focus_next, do: %__MODULE__{type: :focus_next, payload: %{}}

  @doc "Move focus to the previous focusable widget."
  @spec focus_previous() :: %__MODULE__{}
  def focus_previous, do: %__MODULE__{type: :focus_previous, payload: %{}}

  @doc "Select all text in the widget identified by `widget_id`."
  @spec select_all(term()) :: %__MODULE__{}
  def select_all(widget_id) do
    %__MODULE__{type: :select_all, payload: %{target: widget_id}}
  end

  @doc "Scroll the widget identified by `widget_id` to `offset`."
  @spec scroll_to(term(), term()) :: %__MODULE__{}
  def scroll_to(widget_id, offset) do
    %__MODULE__{type: :scroll_to, payload: %{target: widget_id, offset: offset}}
  end

  @doc "Send `event` through `update/2` after `delay_ms` milliseconds."
  @spec send_after(non_neg_integer(), term()) :: %__MODULE__{}
  def send_after(delay_ms, event) when is_integer(delay_ms) and delay_ms >= 0 do
    %__MODULE__{type: :send_after, payload: %{delay: delay_ms, event: event}}
  end

  @doc "Close the window identified by `window_id`."
  @spec close_window(term()) :: %__MODULE__{}
  def close_window(window_id) do
    %__MODULE__{type: :close_window, payload: %{window_id: window_id}}
  end

  @doc "Exit the application."
  @spec exit() :: %__MODULE__{}
  def exit, do: %__MODULE__{type: :exit, payload: %{}}

  @doc "Snap the scrollable widget to an absolute offset."
  @spec snap_to(term(), float(), float()) :: %__MODULE__{}
  def snap_to(widget_id, x \\ 0.0, y \\ 0.0) do
    %__MODULE__{type: :snap_to, payload: %{target: widget_id, x: x, y: y}}
  end

  @doc "Snap the scrollable widget to the end of its content."
  @spec snap_to_end(term()) :: %__MODULE__{}
  def snap_to_end(widget_id) do
    %__MODULE__{type: :snap_to_end, payload: %{target: widget_id}}
  end

  @doc "Scroll the widget by a relative offset."
  @spec scroll_by(term(), float(), float()) :: %__MODULE__{}
  def scroll_by(widget_id, x \\ 0.0, y \\ 0.0) do
    %__MODULE__{type: :scroll_by, payload: %{target: widget_id, x: x, y: y}}
  end

  @doc "Move the text cursor to the front of the input."
  @spec move_cursor_to_front(term()) :: %__MODULE__{}
  def move_cursor_to_front(widget_id) do
    %__MODULE__{type: :move_cursor_to_front, payload: %{target: widget_id}}
  end

  @doc "Move the text cursor to the end of the input."
  @spec move_cursor_to_end(term()) :: %__MODULE__{}
  def move_cursor_to_end(widget_id) do
    %__MODULE__{type: :move_cursor_to_end, payload: %{target: widget_id}}
  end

  @doc "Move the text cursor to a specific position."
  @spec move_cursor_to(term(), non_neg_integer()) :: %__MODULE__{}
  def move_cursor_to(widget_id, position) do
    %__MODULE__{type: :move_cursor_to, payload: %{target: widget_id, position: position}}
  end

  @doc "Select a range of text in the input."
  @spec select_range(term(), non_neg_integer(), non_neg_integer()) :: %__MODULE__{}
  def select_range(widget_id, start_pos, end_pos) do
    %__MODULE__{type: :select_range, payload: %{target: widget_id, start: start_pos, end: end_pos}}
  end

  # ---------------------------------------------------------------------------
  # Window operations
  # ---------------------------------------------------------------------------

  @doc "Resize a window to the given dimensions."
  @spec resize_window(term(), number(), number()) :: %__MODULE__{}
  def resize_window(window_id, width, height) do
    %__MODULE__{type: :window_op, payload: %{op: "resize", window_id: window_id, width: width, height: height}}
  end

  @doc "Move a window to the given position."
  @spec move_window(term(), number(), number()) :: %__MODULE__{}
  def move_window(window_id, x, y) do
    %__MODULE__{type: :window_op, payload: %{op: "move", window_id: window_id, x: x, y: y}}
  end

  @doc "Maximize or restore a window."
  @spec maximize_window(term(), boolean()) :: %__MODULE__{}
  def maximize_window(window_id, maximized \\ true) do
    %__MODULE__{type: :window_op, payload: %{op: "maximize", window_id: window_id, value: maximized}}
  end

  @doc "Minimize or restore a window."
  @spec minimize_window(term(), boolean()) :: %__MODULE__{}
  def minimize_window(window_id, minimized \\ true) do
    %__MODULE__{type: :window_op, payload: %{op: "minimize", window_id: window_id, value: minimized}}
  end

  @doc "Set window mode (windowed, fullscreen, etc.)."
  @spec set_window_mode(term(), atom() | String.t()) :: %__MODULE__{}
  def set_window_mode(window_id, mode) do
    %__MODULE__{type: :window_op, payload: %{op: "set_mode", window_id: window_id, mode: to_string(mode)}}
  end

  @doc "Toggle window maximized state."
  @spec toggle_maximize(term()) :: %__MODULE__{}
  def toggle_maximize(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "toggle_maximize", window_id: window_id}}
  end

  @doc "Toggle window decorations (title bar, borders)."
  @spec toggle_decorations(term()) :: %__MODULE__{}
  def toggle_decorations(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "toggle_decorations", window_id: window_id}}
  end

  @doc "Give focus to a window."
  @spec gain_focus(term()) :: %__MODULE__{}
  def gain_focus(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "gain_focus", window_id: window_id}}
  end

  @doc "Set window stacking level (:normal, :always_on_top, :always_on_bottom)."
  @spec set_window_level(term(), atom() | String.t()) :: %__MODULE__{}
  def set_window_level(window_id, level) do
    %__MODULE__{type: :window_op, payload: %{op: "set_level", window_id: window_id, level: to_string(level)}}
  end

  @doc "Start dragging the window."
  @spec drag_window(term()) :: %__MODULE__{}
  def drag_window(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "drag", window_id: window_id}}
  end

  @doc "Start drag-resizing the window from the given edge/corner direction."
  @spec drag_resize_window(term(), atom() | String.t()) :: %__MODULE__{}
  def drag_resize_window(window_id, direction) do
    %__MODULE__{type: :window_op, payload: %{op: "drag_resize", window_id: window_id, direction: to_string(direction)}}
  end

  @doc "Request user attention for a window. Urgency can be :informational or :critical."
  @spec request_user_attention(term(), atom() | nil) :: %__MODULE__{}
  def request_user_attention(window_id, urgency \\ nil) do
    %__MODULE__{type: :window_op, payload: %{op: "request_attention", window_id: window_id, urgency: urgency && to_string(urgency)}}
  end

  @doc "Take a screenshot of a window. Result arrives as a tagged event."
  @spec screenshot(term(), atom() | String.t()) :: %__MODULE__{}
  def screenshot(window_id, tag) do
    %__MODULE__{type: :window_op, payload: %{op: "screenshot", window_id: window_id, tag: to_string(tag)}}
  end

  @doc "Set whether a window is resizable."
  @spec set_resizable(term(), boolean()) :: %__MODULE__{}
  def set_resizable(window_id, resizable) do
    %__MODULE__{type: :window_op, payload: %{op: "set_resizable", window_id: window_id, value: resizable}}
  end

  @doc "Set the minimum size of a window."
  @spec set_min_size(term(), number(), number()) :: %__MODULE__{}
  def set_min_size(window_id, width, height) do
    %__MODULE__{type: :window_op, payload: %{op: "set_min_size", window_id: window_id, width: width, height: height}}
  end

  @doc "Set the maximum size of a window."
  @spec set_max_size(term(), number(), number()) :: %__MODULE__{}
  def set_max_size(window_id, width, height) do
    %__MODULE__{type: :window_op, payload: %{op: "set_max_size", window_id: window_id, width: width, height: height}}
  end

  @doc "Enable mouse passthrough on a window (clicks pass through to windows below)."
  @spec enable_mouse_passthrough(term()) :: %__MODULE__{}
  def enable_mouse_passthrough(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "mouse_passthrough", window_id: window_id, value: true}}
  end

  @doc "Disable mouse passthrough on a window."
  @spec disable_mouse_passthrough(term()) :: %__MODULE__{}
  def disable_mouse_passthrough(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "mouse_passthrough", window_id: window_id, value: false}}
  end

  @doc "Show the system menu for a window."
  @spec show_system_menu(term()) :: %__MODULE__{}
  def show_system_menu(window_id) do
    %__MODULE__{type: :window_op, payload: %{op: "show_system_menu", window_id: window_id}}
  end

  # ---------------------------------------------------------------------------
  # Window queries (results arrive as events)
  # ---------------------------------------------------------------------------

  @doc "Query the size of a window. Result arrives as `{tag, {width, height}}`."
  @spec get_window_size(term(), atom() | String.t()) :: %__MODULE__{}
  def get_window_size(window_id, tag) do
    %__MODULE__{type: :window_query, payload: %{op: "get_size", window_id: window_id, tag: to_string(tag)}}
  end

  @doc "Query the position of a window. Result arrives as `{tag, {x, y}}`."
  @spec get_window_position(term(), atom() | String.t()) :: %__MODULE__{}
  def get_window_position(window_id, tag) do
    %__MODULE__{type: :window_query, payload: %{op: "get_position", window_id: window_id, tag: to_string(tag)}}
  end

  @doc "Query whether a window is maximized. Result arrives as `{tag, boolean}`."
  @spec is_maximized(term(), atom() | String.t()) :: %__MODULE__{}
  def is_maximized(window_id, tag) do
    %__MODULE__{type: :window_query, payload: %{op: "is_maximized", window_id: window_id, tag: to_string(tag)}}
  end

  @doc "Query whether a window is minimized. Result arrives as `{tag, boolean}`."
  @spec is_minimized(term(), atom() | String.t()) :: %__MODULE__{}
  def is_minimized(window_id, tag) do
    %__MODULE__{type: :window_query, payload: %{op: "is_minimized", window_id: window_id, tag: to_string(tag)}}
  end

  @doc """
  Issue multiple commands. Commands in the batch execute concurrently.

  Accepts a single command, a list of commands, or a nested list -- anything
  `List.wrap/1` can normalize.
  """
  @spec batch(t()) :: %__MODULE__{}
  def batch(commands) do
    %__MODULE__{type: :batch, payload: %{commands: List.wrap(commands)}}
  end
end
