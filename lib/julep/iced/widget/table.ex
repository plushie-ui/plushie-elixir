defmodule Julep.Iced.Widget.Table do
  @moduledoc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  ## Props

  - `columns` (list of maps) -- column definitions. Each column is
    `%{key: string, label: string}`. The `key` maps to row data fields.
    Optional per-column fields:
    - `align` -- horizontal alignment for the column cells (`"left"`,
      `"center"`, `"right"`). Default: `"left"`.
    - `width` -- column width as a `Julep.Iced.Length` value. Default: `:fill`.
    - `sortable` -- whether clicking the header triggers a sort event.
      Default: `false`.
  - `rows` (list of maps) -- data rows. Each row is a map where keys
    correspond to column `key` values.
  - `header` (boolean) -- show header row. Default: true.
  - `separator` (boolean) -- show separator line below header. Default: true.
  - `width` (length) -- table width. Default: fill. See `Julep.Iced.Length`.
  - `padding` (number | map) -- table padding. See `Julep.Iced.Padding`.
  - `sort_by` (string | nil) -- key of the currently sorted column.
  - `sort_order` (`:asc` | `:desc` | nil) -- current sort direction.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type sort_order :: :asc | :desc

  @type option ::
          {:columns, [map()]}
          | {:rows, [map()]}
          | {:header, boolean()}
          | {:separator, boolean()}
          | {:width, Julep.Iced.Length.t()}
          | {:padding, Julep.Iced.Padding.t()}
          | {:sort_by, String.t()}
          | {:sort_order, sort_order()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: [map()] | nil,
          rows: [map()] | nil,
          header: boolean() | nil,
          separator: boolean() | nil,
          width: Julep.Iced.Length.t() | nil,
          padding: Julep.Iced.Padding.t() | nil,
          sort_by: String.t() | nil,
          sort_order: sort_order() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :columns,
    :rows,
    :header,
    :separator,
    :width,
    :padding,
    :sort_by,
    :sort_order,
    :a11y
  ]

  @doc "Creates a new table struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing table struct."
  @spec with_options(table :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = tbl, []), do: tbl

  def with_options(%__MODULE__{} = tbl, opts) do
    Enum.reduce(opts, tbl, fn
      {:columns, v}, acc -> columns(acc, v)
      {:rows, v}, acc -> rows(acc, v)
      {:header, v}, acc -> header(acc, v)
      {:separator, v}, acc -> separator(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:sort_by, v}, acc -> sort_by(acc, v)
      {:sort_order, v}, acc -> sort_order(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the column definitions."
  @spec columns(table :: t(), columns :: [map()]) :: t()
  def columns(%__MODULE__{} = tbl, columns), do: %{tbl | columns: columns}

  @doc "Sets the data rows."
  @spec rows(table :: t(), rows :: [map()]) :: t()
  def rows(%__MODULE__{} = tbl, rows), do: %{tbl | rows: rows}

  @doc "Sets whether the header row is shown."
  @spec header(table :: t(), header :: boolean()) :: t()
  def header(%__MODULE__{} = tbl, header), do: %{tbl | header: header}

  @doc "Sets whether the separator line is shown."
  @spec separator(table :: t(), separator :: boolean()) :: t()
  def separator(%__MODULE__{} = tbl, separator), do: %{tbl | separator: separator}

  @doc "Sets the table width."
  @spec width(table :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = tbl, width), do: %{tbl | width: width}

  @doc "Sets the table padding."
  @spec padding(table :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = tbl, padding), do: %{tbl | padding: padding}

  @doc "Sets the currently sorted column key."
  @spec sort_by(table :: t(), sort_by :: String.t()) :: t()
  def sort_by(%__MODULE__{} = tbl, sort_by), do: %{tbl | sort_by: sort_by}

  @doc "Sets the current sort direction."
  @spec sort_order(table :: t(), sort_order :: sort_order()) :: t()
  def sort_order(%__MODULE__{} = tbl, sort_order), do: %{tbl | sort_order: sort_order}

  @doc "Sets accessibility annotations."
  @spec a11y(table :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = tbl, a11y), do: %{tbl | a11y: A11y.cast(a11y)}

  @doc "Converts this table struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(table :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = tbl), do: Julep.Iced.Widget.to_node(tbl)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(tbl) do
      props =
        %{}
        |> put_if(tbl.columns, "columns")
        |> put_if(tbl.rows, "rows")
        |> put_if(tbl.header, "header")
        |> put_if(tbl.separator, "separator")
        |> put_if(tbl.width, "width")
        |> put_if(tbl.padding, "padding")
        |> put_if(tbl.sort_by, "sort_by")
        |> put_if(tbl.sort_order, "sort_order")
        |> put_if(tbl.a11y, "a11y")

      %{id: tbl.id, type: "table", props: props, children: []}
    end
  end
end
