defmodule Toddy.Widget.Grid do
  @moduledoc """
  Grid layout -- arranges children in a fixed-column grid.

  ## Props

  - `columns` (integer) -- number of columns. Default: 1.
  - `column_count` (integer) -- alias for `columns`, used by the UI macro.
  - `spacing` (number) -- spacing between grid cells in pixels. Default: 0.
  - `width` (number) -- grid width in pixels.
  - `height` (number) -- grid height in pixels.
  - `column_width` (Length) -- width of each column. Accepts `:fill`, `:shrink`,
    `{:fill_portion, n}`, or a fixed pixel number.
  - `row_height` (Length) -- height of each row. Accepts `:fill`, `:shrink`,
    `{:fill_portion, n}`, or a fixed pixel number.
  - `fluid` (number) -- enables fluid grid mode. The value is the max cell width
    in pixels; columns auto-wrap to fit the available width.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Widget.Build

  @type option ::
          {:columns, pos_integer()}
          | {:column_count, pos_integer()}
          | {:spacing, number()}
          | {:width, number()}
          | {:height, number()}
          | {:column_width, Toddy.Type.Length.t()}
          | {:row_height, Toddy.Type.Length.t()}
          | {:fluid, number()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: pos_integer() | nil,
          column_count: pos_integer() | nil,
          spacing: number() | nil,
          width: number() | nil,
          height: number() | nil,
          column_width: Toddy.Type.Length.t() | nil,
          row_height: Toddy.Type.Length.t() | nil,
          fluid: number() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :columns,
    :column_count,
    :spacing,
    :width,
    :height,
    :column_width,
    :row_height,
    :fluid,
    :a11y,
    children: []
  ]

  @doc "Creates a new grid struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing grid struct."
  @spec with_options(grid :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = grid, []), do: grid

  def with_options(%__MODULE__{} = grid, opts) do
    Enum.reduce(opts, grid, fn
      {:columns, v}, acc -> columns(acc, v)
      {:column_count, v}, acc -> column_count(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:column_width, v}, acc -> column_width(acc, v)
      {:row_height, v}, acc -> row_height(acc, v)
      {:fluid, v}, acc -> fluid(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the number of columns."
  @spec columns(grid :: t(), columns :: pos_integer()) :: t()
  def columns(%__MODULE__{} = grid, columns) when is_integer(columns) and columns > 0,
    do: %{grid | columns: columns}

  @doc "Sets the column count (alias for the UI macro's `:column_count` option)."
  @spec column_count(grid :: t(), column_count :: pos_integer()) :: t()
  def column_count(%__MODULE__{} = grid, column_count)
      when is_integer(column_count) and column_count > 0,
      do: %{grid | column_count: column_count}

  @doc "Sets the spacing between grid cells in pixels."
  @spec spacing(grid :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = grid, spacing) when is_number(spacing),
    do: %{grid | spacing: spacing}

  @doc "Sets the grid width in pixels."
  @spec width(grid :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = grid, width) when is_number(width), do: %{grid | width: width}

  @doc "Sets the grid height in pixels."
  @spec height(grid :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = grid, height) when is_number(height), do: %{grid | height: height}

  @doc "Sets the column width using a Length value (fill/shrink/fixed/fill_portion)."
  @spec column_width(grid :: t(), column_width :: Toddy.Type.Length.t()) :: t()
  def column_width(%__MODULE__{} = grid, column_width), do: %{grid | column_width: column_width}

  @doc "Sets the row height using a Length value (fill/shrink/fixed/fill_portion)."
  @spec row_height(grid :: t(), row_height :: Toddy.Type.Length.t()) :: t()
  def row_height(%__MODULE__{} = grid, row_height), do: %{grid | row_height: row_height}

  @doc "Enables fluid grid mode. The value is the max cell width in pixels; columns auto-wrap."
  @spec fluid(grid :: t(), max_width :: number()) :: t()
  def fluid(%__MODULE__{} = grid, max_width) when is_number(max_width),
    do: %{grid | fluid: max_width}

  @doc "Appends a child to the grid."
  @spec push(grid :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = grid, child), do: %{grid | children: [child | grid.children]}

  @doc "Appends multiple children to the grid."
  @spec extend(grid :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = grid, children),
    do: %{grid | children: Enum.reverse(children) ++ grid.children}

  @doc "Sets accessibility annotations."
  @spec a11y(grid :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = grid, a11y), do: %{grid | a11y: A11y.cast(a11y)}

  @doc "Converts this grid struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(grid :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = grid), do: Toddy.Widget.to_node(grid)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(grid) do
      props =
        %{}
        |> put_if(grid.columns, :columns)
        |> put_if(grid.column_count, :column_count)
        |> put_if(grid.spacing, :spacing)
        |> put_if(grid.width, :width)
        |> put_if(grid.height, :height)
        |> put_if(grid.column_width, :column_width)
        |> put_if(grid.row_height, :row_height)
        |> put_if(grid.fluid, :fluid)
        |> put_if(grid.a11y, :a11y)

      %{
        id: grid.id,
        type: "grid",
        props: props,
        children: children_to_nodes(Enum.reverse(grid.children))
      }
    end
  end
end
