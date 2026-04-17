defmodule Plushie.Command.WindowQuery do
  @moduledoc """
  Window query commands. Results arrive as `%Plushie.Event.SystemEvent{}` in `update/2`.
  """

  alias Plushie.Command

  @doc """
  Query the size of a window.

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: data}`
  where `data` is `%{width: width, height: height}`.
  """
  @spec window_size(window_id :: Command.window_id(), tag :: Command.event_tag()) ::
          Command.t()
  def window_size(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "get_size", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the position of a window.

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: data}`
  where `data` is `%{x: x, y: y}` or `nil` if unavailable.
  """
  @spec window_position(window_id :: Command.window_id(), tag :: Command.event_tag()) ::
          Command.t()
  def window_position(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "get_position", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query whether a window is maximized.

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: boolean}`.
  """
  @spec is_maximized(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def is_maximized(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "is_maximized", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query whether a window is minimized.

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: boolean}`.
  """
  @spec is_minimized(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def is_minimized(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "is_minimized", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the current window mode (windowed, fullscreen, hidden).

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: mode}`.
  """
  @spec window_mode(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def window_mode(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "get_mode", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the window's current scale factor (DPI scaling).

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: factor}`.
  """
  @spec scale_factor(window_id :: Command.window_id(), tag :: Command.event_tag()) ::
          Command.t()
  def scale_factor(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "get_scale_factor", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the raw platform window ID (e.g. X11 window ID, HWND).

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: platform_id}`.
  """
  @spec raw_id(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def raw_id(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "raw_id", window_id: window_id, tag: to_string(tag)}
    }
  end

  @doc """
  Query the monitor size for the display containing a window.

  Result arrives as `%Plushie.Event.SystemEvent{tag: tag, value: data}`
  where `data` is `%{width: width, height: height}` or `nil` if the
  monitor cannot be determined.
  """
  @spec monitor_size(window_id :: Command.window_id(), tag :: Command.event_tag()) :: Command.t()
  def monitor_size(window_id, tag) do
    %Command{
      type: :window_query,
      payload: %{op: "monitor_size", window_id: window_id, tag: to_string(tag)}
    }
  end
end
