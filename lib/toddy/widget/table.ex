defmodule Toddy.Widget.Table do
  @moduledoc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  ## Props

  - `columns` (list of maps) -- column definitions. Each column is
    `%{key: string, label: string}`. The `key` maps to row data fields.
    Optional per-column fields:
    - `align` -- horizontal alignment for the column cells (`"left"`,
      `"center"`, `"right"`). Default: `"left"`.
    - `width` -- column width as a `Toddy.Type.Length` value. Default: `:fill`.
    - `sortable` -- whether clicking the header triggers a sort event.
      Default: `false`.
  - `rows` (list of maps) -- data rows. Each row is a map where keys
    correspond to column `key` values.
  - `header` (boolean) -- show header row. Default: true.
  - `separator` (boolean) -- show separator line below header. Default: true.
  - `width` (length) -- table width. Default: fill. See `Toddy.Type.Length`.
  - `padding` (number | map) -- table padding. See `Toddy.Type.Padding`.
  - `sort_by` (string | nil) -- key of the currently sorted column.
  - `sort_order` (`:asc` | `:desc` | nil) -- current sort direction.
  - `header_text_size` (number) -- header row text size in pixels.
  - `row_text_size` (number) -- body row text size in pixels.
  - `cell_spacing` (number) -- horizontal spacing between cells in pixels.
  - `row_spacing` (number) -- vertical spacing between rows in pixels.
  - `separator_thickness` (number) -- separator line thickness in pixels.
  - `separator_color` (color) -- separator line color. See `Toddy.Type.Color`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Type.Color
  alias Toddy.Widget.Build

  @sort_orders [:asc, :desc]

  @type sort_order :: unquote(Enum.reduce([:asc, :desc], &{:|, [], [&1, &2]}))

  @type option ::
          {:columns, [map()]}
          | {:rows, [map()]}
          | {:header, boolean()}
          | {:separator, boolean()}
          | {:width, Toddy.Type.Length.t()}
          | {:padding, Toddy.Type.Padding.t()}
          | {:sort_by, String.t()}
          | {:sort_order, sort_order()}
          | {:header_text_size, number()}
          | {:row_text_size, number()}
          | {:cell_spacing, number()}
          | {:row_spacing, number()}
          | {:separator_thickness, number()}
          | {:separator_color, Toddy.Type.Color.input()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: [map()] | nil,
          rows: [map()] | nil,
          header: boolean() | nil,
          separator: boolean() | nil,
          width: Toddy.Type.Length.t() | nil,
          padding: Toddy.Type.Padding.t() | nil,
          sort_by: String.t() | nil,
          sort_order: sort_order() | nil,
          header_text_size: number() | nil,
          row_text_size: number() | nil,
          cell_spacing: number() | nil,
          row_spacing: number() | nil,
          separator_thickness: number() | nil,
          separator_color: Toddy.Type.Color.t() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
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
    :header_text_size,
    :row_text_size,
    :cell_spacing,
    :row_spacing,
    :separator_thickness,
    :separator_color,
    :a11y,
    children: []
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
      {:header_text_size, v}, acc -> header_text_size(acc, v)
      {:row_text_size, v}, acc -> row_text_size(acc, v)
      {:cell_spacing, v}, acc -> cell_spacing(acc, v)
      {:row_spacing, v}, acc -> row_spacing(acc, v)
      {:separator_thickness, v}, acc -> separator_thickness(acc, v)
      {:separator_color, v}, acc -> separator_color(acc, v)
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
  def header(%__MODULE__{} = tbl, header) when is_boolean(header), do: %{tbl | header: header}

  @doc "Sets whether the separator line is shown."
  @spec separator(table :: t(), separator :: boolean()) :: t()
  def separator(%__MODULE__{} = tbl, separator) when is_boolean(separator),
    do: %{tbl | separator: separator}

  @doc "Sets the table width."
  @spec width(table :: t(), width :: Toddy.Type.Length.t()) :: t()
  def width(%__MODULE__{} = tbl, width), do: %{tbl | width: width}

  @doc "Sets the table padding."
  @spec padding(table :: t(), padding :: Toddy.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = tbl, padding), do: %{tbl | padding: padding}

  @doc "Sets the currently sorted column key."
  @spec sort_by(table :: t(), sort_by :: String.t()) :: t()
  def sort_by(%__MODULE__{} = tbl, sort_by) when is_binary(sort_by), do: %{tbl | sort_by: sort_by}

  @doc "Sets the current sort direction."
  @spec sort_order(table :: t(), sort_order :: sort_order()) :: t()
  def sort_order(%__MODULE__{} = tbl, sort_order) when sort_order in @sort_orders,
    do: %{tbl | sort_order: sort_order}

  @doc "Sets the header text size in pixels."
  @spec header_text_size(table :: t(), header_text_size :: number()) :: t()
  def header_text_size(%__MODULE__{} = tbl, header_text_size) when is_number(header_text_size),
    do: %{tbl | header_text_size: header_text_size}

  @doc "Sets the row text size in pixels."
  @spec row_text_size(table :: t(), row_text_size :: number()) :: t()
  def row_text_size(%__MODULE__{} = tbl, row_text_size) when is_number(row_text_size),
    do: %{tbl | row_text_size: row_text_size}

  @doc "Sets the horizontal spacing between cells in pixels."
  @spec cell_spacing(table :: t(), cell_spacing :: number()) :: t()
  def cell_spacing(%__MODULE__{} = tbl, cell_spacing) when is_number(cell_spacing),
    do: %{tbl | cell_spacing: cell_spacing}

  @doc "Sets the vertical spacing between rows in pixels."
  @spec row_spacing(table :: t(), row_spacing :: number()) :: t()
  def row_spacing(%__MODULE__{} = tbl, row_spacing) when is_number(row_spacing),
    do: %{tbl | row_spacing: row_spacing}

  @doc "Sets the separator line thickness in pixels."
  @spec separator_thickness(table :: t(), separator_thickness :: number()) :: t()
  def separator_thickness(%__MODULE__{} = tbl, separator_thickness)
      when is_number(separator_thickness),
      do: %{tbl | separator_thickness: separator_thickness}

  @doc "Sets the separator line color."
  @spec separator_color(table :: t(), separator_color :: Toddy.Type.Color.input()) :: t()
  def separator_color(%__MODULE__{} = tbl, separator_color),
    do: %{tbl | separator_color: Color.cast(separator_color)}

  @doc "Appends a child to the table."
  @spec push(table :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = tbl, child), do: %{tbl | children: [child | tbl.children]}

  @doc "Appends multiple children to the table."
  @spec extend(table :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = tbl, children),
    do: %{tbl | children: Enum.reverse(children) ++ tbl.children}

  @doc "Sets accessibility annotations."
  @spec a11y(table :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = tbl, a11y), do: %{tbl | a11y: A11y.cast(a11y)}

  @doc "Converts this table struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(table :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = tbl), do: Toddy.Widget.to_node(tbl)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(tbl) do
      props =
        %{}
        |> put_if(tbl.columns, :columns)
        |> put_if(tbl.rows, :rows)
        |> put_if(tbl.header, :header)
        |> put_if(tbl.separator, :separator)
        |> put_if(tbl.width, :width)
        |> put_if(tbl.padding, :padding)
        |> put_if(tbl.sort_by, :sort_by)
        |> put_if(tbl.sort_order, :sort_order)
        |> put_if(tbl.header_text_size, :header_text_size)
        |> put_if(tbl.row_text_size, :row_text_size)
        |> put_if(tbl.cell_spacing, :cell_spacing)
        |> put_if(tbl.row_spacing, :row_spacing)
        |> put_if(tbl.separator_thickness, :separator_thickness)
        |> put_if(tbl.separator_color, :separator_color)
        |> put_if(tbl.a11y, :a11y)

      %{
        id: tbl.id,
        type: "table",
        props: props,
        children: children_to_nodes(Enum.reverse(tbl.children))
      }
    end
  end
end
