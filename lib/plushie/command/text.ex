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
    %Command{type: :select_all, payload: Command.targeted_payload(widget_id)}
  end

  @doc "Move the text cursor to the front of the input. Supports `\"window#path\"`."
  @spec move_cursor_to_front(widget_id :: Command.widget_id()) :: Command.t()
  def move_cursor_to_front(widget_id) do
    %Command{type: :move_cursor_to_front, payload: Command.targeted_payload(widget_id)}
  end

  @doc "Move the text cursor to the end of the input. Supports `\"window#path\"`."
  @spec move_cursor_to_end(widget_id :: Command.widget_id()) :: Command.t()
  def move_cursor_to_end(widget_id) do
    %Command{type: :move_cursor_to_end, payload: Command.targeted_payload(widget_id)}
  end

  @doc "Move the text cursor to a specific position. Supports `\"window#path\"`."
  @spec move_cursor_to(widget_id :: Command.widget_id(), position :: non_neg_integer()) ::
          Command.t()
  def move_cursor_to(widget_id, position) do
    %Command{
      type: :move_cursor_to,
      payload: Command.targeted_payload(widget_id, %{position: position})
    }
  end

  @doc "Select a range of text in the input. Supports `\"window#path\"`."
  @spec select_range(
          widget_id :: Command.widget_id(),
          start_pos :: non_neg_integer(),
          end_pos :: non_neg_integer()
        ) :: Command.t()
  def select_range(widget_id, start_pos, end_pos) do
    %Command{
      type: :select_range,
      payload: Command.targeted_payload(widget_id, %{start: start_pos, end: end_pos})
    }
  end
end
