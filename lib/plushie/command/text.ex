defmodule Plushie.Command.Text do
  @moduledoc """
  Text input commands: selection and cursor movement.

  All functions support window-qualified paths (`"window#widget"`).

  ## Example

      def update(model, %WidgetEvent{type: :click, id: "select-all"}) do
        {model, Command.Text.select_all("main#email")}
      end
  """

  use Plushie.Command

  command :select_all
  command :move_cursor_to_front
  command :move_cursor_to_end
  command :move_cursor_to, value: :integer
  command :select_range, fields: [start_pos: :integer, end_pos: :integer]
end
