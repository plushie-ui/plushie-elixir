defmodule Toddy.Iced.Widget.PaneGrid do
  @moduledoc """
  Pane grid -- resizable tiled panes.

  Children are keyed by their node ID and rendered as individual panes.
  The renderer manages an internal `pane_grid::State` cache.

  ## Props

  - `spacing` (number) -- space between panes in pixels. Default: 2.
  - `width` (length) -- grid width. Default: fill. See `Toddy.Iced.Length`.
  - `height` (length) -- grid height. Default: fill.
  - `min_size` (number) -- minimum pane size in pixels. Default: 10.
  - `leeway` (number) -- grabbable area around dividers. Defaults to min_size.
  - `divider_color` (hex color) -- color for the split divider.
  - `divider_width` (number) -- divider thickness in pixels.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.

  ## Child pane props

  Each child node can have a `title` prop (string). If present, the pane
  renders a title bar with that text. If absent, no title bar is shown.

  ## Events

  - `%Pane{type: :clicked}` -- pane selected.
  - `%Pane{type: :resized}` -- split divider moved (split, ratio).
  - `%Pane{type: :dragged}` -- pane drag (action: :picked/:dropped/:canceled,
    with optional target, region, edge).
  - `%Pane{type: :focus_cycle}` -- F6/Shift+F6 focus cycling.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.Color
  alias Toddy.Iced.Widget.Build

  @type option ::
          {:spacing, number()}
          | {:width, Toddy.Iced.Length.t()}
          | {:height, Toddy.Iced.Length.t()}
          | {:min_size, number()}
          | {:divider_color, Toddy.Iced.Color.input()}
          | {:divider_width, number()}
          | {:leeway, number()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          spacing: number() | nil,
          width: Toddy.Iced.Length.t() | nil,
          height: Toddy.Iced.Length.t() | nil,
          min_size: number() | nil,
          divider_color: Toddy.Iced.Color.t() | nil,
          divider_width: number() | nil,
          leeway: number() | nil,
          a11y: Toddy.Iced.A11y.t() | nil,
          children: [Toddy.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :spacing,
    :width,
    :height,
    :min_size,
    :divider_color,
    :divider_width,
    :leeway,
    :a11y,
    children: []
  ]

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
      {:divider_color, v}, acc -> divider_color(acc, v)
      {:divider_width, v}, acc -> divider_width(acc, v)
      {:leeway, v}, acc -> leeway(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between panes."
  @spec spacing(pane_grid :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = pg, spacing) when is_number(spacing), do: %{pg | spacing: spacing}

  @doc "Sets the pane grid width."
  @spec width(pane_grid :: t(), width :: Toddy.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = pg, width), do: %{pg | width: width}

  @doc "Sets the pane grid height."
  @spec height(pane_grid :: t(), height :: Toddy.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = pg, height), do: %{pg | height: height}

  @doc "Sets the minimum pane size in pixels."
  @spec min_size(pane_grid :: t(), min_size :: number()) :: t()
  def min_size(%__MODULE__{} = pg, min_size) when is_number(min_size), do: %{pg | min_size: min_size}

  @doc "Sets the divider color."
  @spec divider_color(pane_grid :: t(), divider_color :: Toddy.Iced.Color.input()) :: t()
  def divider_color(%__MODULE__{} = pg, divider_color),
    do: %{pg | divider_color: Color.cast(divider_color)}

  @doc "Sets the divider width in pixels."
  @spec divider_width(pane_grid :: t(), divider_width :: number()) :: t()
  def divider_width(%__MODULE__{} = pg, divider_width) when is_number(divider_width), do: %{pg | divider_width: divider_width}

  @doc "Sets the drag leeway in pixels (how far a pane must be dragged before it detaches)."
  @spec leeway(pane_grid :: t(), leeway :: number()) :: t()
  def leeway(%__MODULE__{} = pg, leeway) when is_number(leeway), do: %{pg | leeway: leeway}

  @doc "Appends a child pane to the grid."
  @spec push(pane_grid :: t(), child :: Toddy.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = pg, child), do: %{pg | children: [child | pg.children]}

  @doc "Appends multiple child panes to the grid."
  @spec extend(pane_grid :: t(), children :: [Toddy.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = pg, children),
    do: %{pg | children: Enum.reverse(children) ++ pg.children}

  @doc "Sets accessibility annotations."
  @spec a11y(pane_grid :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = pg, a11y), do: %{pg | a11y: A11y.cast(a11y)}

  @doc "Converts this pane grid struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(pane_grid :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = pg), do: Toddy.Iced.Widget.to_node(pg)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(pg) do
      props =
        %{}
        |> put_if(pg.spacing, "spacing")
        |> put_if(pg.width, "width")
        |> put_if(pg.height, "height")
        |> put_if(pg.min_size, "min_size")
        |> put_if(pg.divider_color, "divider_color")
        |> put_if(pg.divider_width, "divider_width")
        |> put_if(pg.leeway, "leeway")
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
