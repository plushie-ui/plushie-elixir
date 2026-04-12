defmodule Plushie.Widget.TableRow do
  @moduledoc """
  A row inside a `table` widget.

  Each `table_row` has an explicit ID used for selection events and
  LIS-based wire diffing. Children are `table_cell` elements, one
  per column.

      table_row "user-1" do
        cell "name", text(user.name)
        cell "email", text(user.email)
      end
  """

  use Plushie.Canvas.Element

  element :table_row, container: true do
  end
end
