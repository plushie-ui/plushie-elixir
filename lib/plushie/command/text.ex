defmodule Plushie.Command.Text do
  @moduledoc """
  Text input commands: selection, cursor movement.
  """

  alias Plushie.Command

  @doc """
  Select all text in the widget identified by `widget_id`.

  Supports window-qualified paths: `"main#email"`.
  """
  @spec select_all(widget_id :: Command.widget_id()) :: Command.t()
  def select_all(widget_id) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :select_all, payload: payload}
  end

  @doc "Move the text cursor to the front of the input. Supports `\"window#path\"`."
  @spec move_cursor_to_front(widget_id :: Command.widget_id()) :: Command.t()
  def move_cursor_to_front(widget_id) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :move_cursor_to_front, payload: payload}
  end

  @doc "Move the text cursor to the end of the input. Supports `\"window#path\"`."
  @spec move_cursor_to_end(widget_id :: Command.widget_id()) :: Command.t()
  def move_cursor_to_end(widget_id) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :move_cursor_to_end, payload: payload}
  end

  @doc "Move the text cursor to a specific position. Supports `\"window#path\"`."
  @spec move_cursor_to(widget_id :: Command.widget_id(), position :: non_neg_integer()) ::
          Command.t()
  def move_cursor_to(widget_id, position) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target, position: position}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :move_cursor_to, payload: payload}
  end

  @doc "Select a range of text in the input. Supports `\"window#path\"`."
  @spec select_range(
          widget_id :: Command.widget_id(),
          start_pos :: non_neg_integer(),
          end_pos :: non_neg_integer()
        ) :: Command.t()
  def select_range(widget_id, start_pos, end_pos) do
    {window_id, target} = Command.parse_target(widget_id)
    payload = %{target: target, start: start_pos, end: end_pos}
    payload = if window_id, do: Map.put(payload, :window_id, window_id), else: payload
    %Command{type: :select_range, payload: payload}
  end
end
