defmodule Plushie.Widget.Table do
  @moduledoc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  ## Props

  - `columns` (list of maps) -- column definitions. Each column is a map
    with atom keys from a fixed schema:

        %{key: "name", label: "Name", sortable: true}

    Required fields:
    - `key` (string) -- lookup key into row data maps.
    - `label` (string) -- display text for the column header.

    Optional fields:
    - `align` -- horizontal alignment for column cells (`"left"`,
      `"center"`, `"right"`). Default: `"left"`.
    - `width` -- column width as a `Plushie.Type.Length` value. Default: `:fill`.
    - `sortable` -- whether clicking the header triggers a sort event.
      Default: `false`.

  - `rows` (list of maps) -- data rows. Each row is a string-keyed map
    where keys match the column `key` values:

        %{"name" => "Alice", "email" => "alice@example.com"}

    String keys are the convention because row schemas are typically
    user-defined or come from external data (JSON, database queries).
    Atom keys also work (the wire protocol stringifies all keys), but
    string keys avoid dynamic atom creation when data comes from
    external sources.
  - `header` (boolean) -- show header row. Default: true.
  - `separator` (boolean) -- show separator line below header. Default: true.
  - `width` (length) -- table width. Default: fill. See `Plushie.Type.Length`.
  - `padding` (number | map) -- table padding. See `Plushie.Type.Padding`.
  - `sort_by` (string | nil) -- key of the currently sorted column.
  - `sort_order` (`:asc` | `:desc` | nil) -- current sort direction.
  - `header_text_size` (number) -- header row text size in pixels.
  - `row_text_size` (number) -- body row text size in pixels.
  - `cell_spacing` (number) -- horizontal spacing between cells in pixels.
  - `row_spacing` (number) -- vertical spacing between rows in pixels.
  - `separator_thickness` (number) -- separator line thickness in pixels.
  - `separator_color` (color) -- separator line color. See `Plushie.Type.Color`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.Color
  alias Plushie.Widget.Build

  @sort_orders [:asc, :desc]

  @type sort_order :: unquote(Enum.reduce([:asc, :desc], &{:|, [], [&1, &2]}))

  @typedoc """
  A column definition map. Uses atom keys from the fixed SDK schema:
  `:key`, `:label`, `:align`, `:width`, `:sortable`.
  """
  @type column :: %{
          required(:key) => String.t(),
          required(:label) => String.t(),
          optional(:align) => String.t(),
          optional(:width) => Plushie.Type.Length.t(),
          optional(:sortable) => boolean()
        }

  @typedoc """
  A data row map. Keys are strings matching column `:key` values.
  Values are any term (rendered as text via `to_string/1`).
  """
  @type row :: %{optional(String.t()) => term()}

  @type option ::
          {:columns, [column()]}
          | {:rows, [row()]}
          | {:header, boolean()}
          | {:separator, boolean()}
          | {:width, Plushie.Type.Length.t()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:sort_by, String.t()}
          | {:sort_order, sort_order()}
          | {:header_text_size, number()}
          | {:row_text_size, number()}
          | {:cell_spacing, number()}
          | {:row_spacing, number()}
          | {:separator_thickness, number()}
          | {:separator_color, Plushie.Type.Color.input()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: [column()] | nil,
          rows: [row()] | nil,
          header: boolean() | nil,
          separator: boolean() | nil,
          width: Plushie.Type.Length.t() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          sort_by: String.t() | nil,
          sort_order: sort_order() | nil,
          header_text_size: number() | nil,
          row_text_size: number() | nil,
          cell_spacing: number() | nil,
          row_spacing: number() | nil,
          separator_thickness: number() | nil,
          separator_color: Plushie.Type.Color.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.child()]
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

  @valid_option_keys ~w(columns rows header separator width padding sort_by sort_order header_text_size row_text_size cell_spacing row_spacing separator_thickness separator_color a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Plushie.Type.Padding, a11y: Plushie.Type.A11y}
  end

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
  @spec columns(table :: t(), columns :: [column()]) :: t()
  def columns(%__MODULE__{} = tbl, columns), do: %{tbl | columns: columns}

  @doc """
  Sets the data rows.

  Row maps must use string keys matching the column `:key` values.
  Raises `ArgumentError` if the first row contains atom keys.
  """
  @spec rows(table :: t(), rows :: [row()]) :: t()
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

  @doc "Sets whether the header row is shown."
  @spec header(table :: t(), header :: boolean()) :: t()
  def header(%__MODULE__{} = tbl, header) when is_boolean(header), do: %{tbl | header: header}

  @doc "Sets whether the separator line is shown."
  @spec separator(table :: t(), separator :: boolean()) :: t()
  def separator(%__MODULE__{} = tbl, separator) when is_boolean(separator),
    do: %{tbl | separator: separator}

  @doc "Sets the table width."
  @spec width(table :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = tbl, width), do: %{tbl | width: width}

  @doc "Sets the table padding."
  @spec padding(table :: t(), padding :: Plushie.Type.Padding.t()) :: t()
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
  @spec separator_color(table :: t(), separator_color :: Plushie.Type.Color.input()) :: t()
  def separator_color(%__MODULE__{} = tbl, separator_color),
    do: %{tbl | separator_color: Color.cast(separator_color)}

  @doc "Appends a child to the table."
  @spec push(table :: t(), child :: Plushie.Widget.child()) :: t()
  def push(%__MODULE__{} = tbl, child), do: %{tbl | children: [child | tbl.children]}

  @doc "Appends multiple children to the table."
  @spec extend(table :: t(), children :: [Plushie.Widget.child()]) ::
          t()
  def extend(%__MODULE__{} = tbl, children),
    do: %{tbl | children: Enum.reverse(children) ++ tbl.children}

  @doc "Sets accessibility annotations."
  @spec a11y(table :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = tbl, a11y), do: %{tbl | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this table struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(table :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = tbl), do: Plushie.Widget.to_node(tbl)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

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
