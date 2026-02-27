defmodule Julep.Iced.Widget.Grid do
  @moduledoc """
  Grid layout -- arranges children in a fixed-column grid.

  ## Props

  - `columns` (integer) -- number of columns. Default: 1.
  - `spacing` (number) -- spacing between grid cells in pixels. Default: 0.
  - `width` (number) -- grid width in pixels.
  - `height` (number) -- grid height in pixels.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:columns, integer()}
          | {:spacing, number()}
          | {:width, number()}
          | {:height, number()}

  @type t :: %__MODULE__{
          id: String.t(),
          columns: integer() | nil,
          spacing: number() | nil,
          width: number() | nil,
          height: number() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :columns,
    :spacing,
    :width,
    :height,
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
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the number of columns."
  @spec columns(grid :: t(), columns :: integer()) :: t()
  def columns(%__MODULE__{} = grid, columns), do: %{grid | columns: columns}

  @doc "Sets the spacing between grid cells in pixels."
  @spec spacing(grid :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = grid, spacing), do: %{grid | spacing: spacing}

  @doc "Sets the grid width."
  @spec width(grid :: t(), width :: number()) :: t()
  def width(%__MODULE__{} = grid, width), do: %{grid | width: width}

  @doc "Sets the grid height."
  @spec height(grid :: t(), height :: number()) :: t()
  def height(%__MODULE__{} = grid, height), do: %{grid | height: height}

  @doc "Appends a child to the grid."
  @spec push(grid :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = grid, child), do: %{grid | children: grid.children ++ [child]}

  @doc "Appends multiple children to the grid."
  @spec extend(grid :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = grid, children), do: %{grid | children: grid.children ++ children}

  @doc "Converts this grid struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(grid :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = grid), do: Julep.Iced.Widget.to_node(grid)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(grid) do
      props =
        %{}
        |> put_if(grid.columns, "columns")
        |> put_if(grid.spacing, "spacing")
        |> put_if(grid.width, "width")
        |> put_if(grid.height, "height")

      %{id: grid.id, type: "grid", props: props, children: children_to_nodes(grid.children)}
    end
  end
end
