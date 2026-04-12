defmodule Plushie.Widget.TableCell do
  @moduledoc """
  A cell inside a `table_row`.

  Each cell declares which column it belongs to via the `column`
  field. Children are any widgets that form the cell content.

      cell "name", text(user.name)

      cell "actions" do
        button("edit", "Edit")
        button("del", "Delete")
      end
  """

  use Plushie.Canvas.Element

  element :table_cell, container: true do
    field :column, :string, doc: "Column key this cell belongs to."
  end
end
