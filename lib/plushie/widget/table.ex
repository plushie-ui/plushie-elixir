defmodule Plushie.Widget.Table.Validation do
  @moduledoc false

  # Validates table column and row key type consistency.
  #
  # Column `key` values can be atoms or strings, but all columns must
  # use the same type. Row maps must use the same key type as the
  # columns. Structs are accepted as rows and converted to atom-keyed
  # maps automatically.

  # -- Column validation -------------------------------------------------------

  @doc false
  def validate_columns!(_id, []), do: :ok

  def validate_columns!(id, columns) do
    key_types =
      Enum.map(columns, fn
        %{key: k} when is_atom(k) -> :atom
        %{key: k} when is_binary(k) -> :string
        col -> raise ArgumentError, error(id, "column is missing a :key field: #{inspect(col)}")
      end)

    unless Enum.count(Enum.uniq(key_types)) <= 1 do
      raise ArgumentError,
            error(
              id,
              "all column :key values must be the same type (all atoms or all strings), got a mix"
            )
    end
  end

  # -- Row validation ----------------------------------------------------------

  @doc false
  def coerce_struct_rows(rows) do
    Enum.map(rows, fn
      %{__struct__: _} = struct -> Map.from_struct(struct)
      other -> other
    end)
  end

  @doc false
  def validate_rows!(id, columns, rows) do
    expected = column_key_type(columns)

    Enum.with_index(rows, fn row, index ->
      case row_key_type(id, row, index) do
        nil -> :ok
        actual -> validate_key_type_match!(id, expected, actual, index)
      end
    end)
  end

  defp row_key_type(id, row, index) do
    types =
      row
      |> Map.keys()
      |> Enum.map(fn
        k when is_atom(k) ->
          :atom

        k when is_binary(k) ->
          :string

        k ->
          raise ArgumentError, error(id, "row #{index} has unsupported key type: #{inspect(k)}")
      end)
      |> Enum.uniq()

    case types do
      [] -> nil
      [single] -> single
      _ -> raise ArgumentError, error(id, "row #{index} has mixed atom and string keys")
    end
  end

  defp column_key_type(nil), do: nil
  defp column_key_type([]), do: nil
  defp column_key_type([%{key: k} | _]) when is_atom(k), do: :atom
  defp column_key_type([%{key: k} | _]) when is_binary(k), do: :string
  defp column_key_type(_), do: nil

  defp validate_key_type_match!(_id, nil, _actual, _index), do: :ok
  defp validate_key_type_match!(_id, same, same, _index), do: :ok

  defp validate_key_type_match!(id, expected, _actual, index) do
    hint =
      if expected == :string do
        "columns use string keys, but row #{index} uses atom keys. " <>
          "Use string keys (%{\"field\" => value}) or change column keys to atoms (key: :field)"
      else
        "columns use atom keys, but row #{index} uses string keys. " <>
          "Use atom keys (%{field: value}) or change column keys to strings (key: \"field\")"
      end

    raise ArgumentError, error(id, hint)
  end

  defp error(id, message), do: "table #{inspect(id)}: #{message}"

  # -- @before_compile hook ----------------------------------------------------

  # Generates thin overrides for columns/2 and rows/2 that delegate
  # to the validation functions above.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable columns: 2, rows: 2

      def columns(%__MODULE__{} = tbl, columns) when is_list(columns) do
        Plushie.Widget.Table.Validation.validate_columns!(tbl.id, columns)
        Plushie.Widget.Table.Validation.validate_rows!(tbl.id, columns, tbl.rows || [])
        %{tbl | columns: columns}
      end

      def rows(%__MODULE__{} = tbl, rows) when is_list(rows) do
        rows = Plushie.Widget.Table.Validation.coerce_struct_rows(rows)
        Plushie.Widget.Table.Validation.validate_rows!(tbl.id, tbl.columns, rows)
        %{tbl | rows: rows}
      end
    end
  end
end

defmodule Plushie.Widget.Table do
  @moduledoc """
  Data table, composite widget built from columns, rows, and scrollable containers.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Table.Validation

  @a11y_defaults %{role: :table}

  widget :table do
    field :columns, {:list, :map}, doc: "Column definitions. Maps with `:key`, `:label`, etc."

    field :rows, {:list, :map},
      doc: "Data rows. Maps or structs with keys matching column `:key` values."

    field :header, :boolean, doc: "Show header row. Default: true."
    field :separator, :boolean, doc: "Show separator line below header. Default: true."
    field :width, Plushie.Type.Length, doc: "Table width. Default: fill."
    field :padding, Plushie.Type.Padding, doc: "Table padding."
    field :sort_by, :string, doc: "Key of the currently sorted column."
    field :sort_order, {:enum, [:asc, :desc]}, doc: "Current sort direction: `:asc` or `:desc`."
    field :header_text_size, :float, doc: "Header row text size in pixels."
    field :row_text_size, :float, doc: "Body row text size in pixels."
    field :cell_spacing, :float, doc: "Horizontal spacing between cells in pixels."
    field :row_spacing, :float, doc: "Vertical spacing between rows in pixels."
    field :separator_thickness, :float, doc: "Separator line thickness in pixels."
    field :separator_color, Plushie.Type.Color, doc: "Separator line color."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end

  event :sort, value: :string, doc: "Emitted when a sortable column header is clicked."
end
