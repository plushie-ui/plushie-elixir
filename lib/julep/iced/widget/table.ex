defmodule Julep.Iced.Widget.Table do
  @moduledoc """
  Data table -- composite widget built from columns, rows, and scrollable containers.

  ## Props

  - `columns` (list of maps) -- column definitions. Each column is
    `%{key: string, label: string}`. The `key` maps to row data fields.
  - `rows` (list of maps) -- data rows. Each row is a map where keys
    correspond to column `key` values.
  - `header` (boolean) -- show header row. Default: true.
  - `separator` (boolean) -- show separator line below header. Default: true.
  - `width` (length) -- table width. Default: fill. See `Julep.Iced.Length`.
  - `padding` (number | map) -- table padding. See `Julep.Iced.Padding`.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:columns, [map()]}
          | {:rows, [map()]}
          | {:header, boolean()}
          | {:separator, boolean()}
          | {:width, Julep.Iced.Length.t()}
          | {:padding, Julep.Iced.Padding.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: [map()] | nil,
          rows: [map()] | nil,
          header: boolean() | nil,
          separator: boolean() | nil,
          width: Julep.Iced.Length.t() | nil,
          padding: Julep.Iced.Padding.t() | nil
        }

  defstruct [:id, :columns, :rows, :header, :separator, :width, :padding]

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

      %{id: tbl.id, type: "table", props: props, children: []}
    end
  end
end
