defmodule Plushie.Table.Row do
  @moduledoc """
  A row inside a `table` widget.

  Each row has an explicit ID used for selection events and
  LIS-based wire diffing. Children are `Plushie.Table.Cell`
  elements, one per column.

      table_row "user-1" do
        cell "name", text(user.name)
        cell "email", text(user.email)
      end
  """

  use Plushie.Table.Element

  element :table_row, container: true do
  end
end
