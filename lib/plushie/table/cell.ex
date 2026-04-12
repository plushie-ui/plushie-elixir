defmodule Plushie.Table.Cell do
  @moduledoc """
  A cell inside a `Plushie.Table.Row`.

  Each cell declares which column it belongs to via the `column`
  field (must match a column `:key` from the table's `columns`
  prop). Children are any widgets that form the cell content.

      cell "name", text(user.name)

      cell "actions" do
        button("edit", "Edit")
        button("del", "Delete")
      end
  """

  use Plushie.Table.Element

  element :table_cell, container: true do
    field :column, :string, doc: "Column key this cell belongs to."
  end
end
