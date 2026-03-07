defmodule Julep.Iced.Widget.PaneGrid do
  @moduledoc """
  Pane grid -- resizable tiled panes.

  Children are keyed by their node ID and rendered as individual panes.
  The renderer manages an internal `pane_grid::State` cache.

  ## Props

  - `spacing` (number) -- space between panes in pixels. Default: 2.
  - `width` (length) -- grid width. Default: fill. See `Julep.Iced.Length`.
  - `height` (length) -- grid height. Default: fill.

  ## Events

  - `{:pane_clicked, id, pane}` -- emitted when a pane is clicked.
  - `{:pane_resized, id, split, ratio}` -- emitted when a split is resized.
  - `{:pane_dragged, id, pane, target}` -- emitted when a pane is dragged.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:spacing, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:min_size, number()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          spacing: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          min_size: number() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, :spacing, :width, :height, :min_size, :a11y, children: []]

  @doc "Creates a new pane grid struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing pane grid struct."
  @spec with_options(pane_grid :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = pg, []), do: pg

  def with_options(%__MODULE__{} = pg, opts) do
    Enum.reduce(opts, pg, fn
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:min_size, v}, acc -> min_size(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between panes."
  @spec spacing(pane_grid :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = pg, spacing), do: %{pg | spacing: spacing}

  @doc "Sets the pane grid width."
  @spec width(pane_grid :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = pg, width), do: %{pg | width: width}

  @doc "Sets the pane grid height."
  @spec height(pane_grid :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = pg, height), do: %{pg | height: height}

  @doc "Sets the minimum pane size in pixels."
  @spec min_size(pane_grid :: t(), min_size :: number()) :: t()
  def min_size(%__MODULE__{} = pg, min_size), do: %{pg | min_size: min_size}

  @doc "Appends a child pane to the grid."
  @spec push(pane_grid :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = pg, child), do: %{pg | children: [child | pg.children]}

  @doc "Appends multiple child panes to the grid."
  @spec extend(pane_grid :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = pg, children),
    do: %{pg | children: Enum.reverse(children) ++ pg.children}

  @doc "Sets accessibility annotations."
  @spec a11y(pane_grid :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = pg, a11y), do: %{pg | a11y: a11y}

  @doc "Converts this pane grid struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(pane_grid :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = pg), do: Julep.Iced.Widget.to_node(pg)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(pg) do
      props =
        %{}
        |> put_if(pg.spacing, "spacing")
        |> put_if(pg.width, "width")
        |> put_if(pg.height, "height")
        |> put_if(pg.min_size, "min_size")
        |> put_if(pg.a11y, "a11y")

      %{
        id: pg.id,
        type: "pane_grid",
        props: props,
        children: children_to_nodes(Enum.reverse(pg.children))
      }
    end
  end
end
