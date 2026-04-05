defmodule Plushie.Widget.Table.RowValidation do
  @moduledoc false

  # Overrides rows/2 to validate that row maps use string keys.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable rows: 2

      @doc """
      Sets the data rows.

      Row maps must use string keys matching the column `:key` values.
      Raises `ArgumentError` if the first row contains atom keys.
      """
      def rows(%__MODULE__{} = tbl, [first | _] = rows) when is_map(first) do
        case Enum.find(Map.keys(first), &is_atom/1) do
          nil ->
            %{tbl | rows: rows}

          atom_key ->
            raise ArgumentError,
                  "table #{inspect(tbl.id)} row maps must use string keys to match column key values, " <>
                    "got atom key #{inspect(atom_key)}. " <>
                    "Use %{#{inspect(Atom.to_string(atom_key))} => value} instead of %{#{atom_key}: value}"
        end
      end

      def rows(%__MODULE__{} = tbl, rows), do: %{tbl | rows: rows}
    end
  end
end

defmodule Plushie.Widget.Table do
  @moduledoc """
  Data table, composite widget built from columns, rows, and scrollable containers.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Table.RowValidation

  widget :table, container: true do
    field :columns, {:list, :map}, doc: "Column definitions. Maps with `:key`, `:label`, etc."
    field :rows, {:list, :map}, doc: "Data rows. String-keyed maps matching column `:key` values."
    field :header, :boolean, doc: "Show header row. Default: true."
    field :separator, :boolean, doc: "Show separator line below header. Default: true."
    field :width, Plushie.Type.Length, doc: "Table width. Default: fill."
    field :padding, Plushie.Type.Padding, doc: "Table padding."
    field :sort_by, :string, doc: "Key of the currently sorted column."
    field :sort_order, :atom, doc: "Current sort direction: `:asc` or `:desc`."
    field :header_text_size, :float, doc: "Header row text size in pixels."
    field :row_text_size, :float, doc: "Body row text size in pixels."
    field :cell_spacing, :float, doc: "Horizontal spacing between cells in pixels."
    field :row_spacing, :float, doc: "Vertical spacing between rows in pixels."
    field :separator_thickness, :float, doc: "Separator line thickness in pixels."
    field :separator_color, Plushie.Type.Color, doc: "Separator line color."
  end

  event :sort, value: :string, doc: "Emitted when a sortable column header is clicked."
end
