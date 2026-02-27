defmodule Julep.Iced.Widget.Scrollable do
  @moduledoc """
  Scrollable container -- wraps child content in a scrollable viewport.

  ## Props

  - `width` (length) -- width of the scrollable area. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- height of the scrollable area. Default: shrink.
  - `direction` (string) -- scroll direction: `"vertical"` (default), `"horizontal"`, or `"both"`.
  - `spacing` (number) -- spacing between scrollbar and content.
  - `scrollbar_width` (number) -- width of the scrollbar track in pixels.
  - `scrollbar_margin` (number) -- margin around the scrollbar in pixels.
  - `scroller_width` (number) -- width of the scroller handle in pixels.
  - `id` (string) -- widget ID for programmatic scroll control via `Julep.Command`.
  - `anchor` (string) -- scroll anchor: `"start"` (default) or `"end"` / `"bottom"` / `"right"`.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:direction, atom() | String.t()}
          | {:spacing, number()}
          | {:scrollbar_width, number()}
          | {:scrollbar_margin, number()}
          | {:scroller_width, number()}
          | {:anchor, atom() | String.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          direction: atom() | String.t() | nil,
          spacing: number() | nil,
          scrollbar_width: number() | nil,
          scrollbar_margin: number() | nil,
          scroller_width: number() | nil,
          anchor: atom() | String.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
    :direction,
    :spacing,
    :scrollbar_width,
    :scrollbar_margin,
    :scroller_width,
    :anchor,
    children: []
  ]

  @doc "Creates a new scrollable struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing scrollable struct."
  @spec with_options(scrollable :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = s, []), do: s

  def with_options(%__MODULE__{} = s, opts) do
    Enum.reduce(opts, s, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:direction, v}, acc -> direction(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:scrollbar_width, v}, acc -> scrollbar_width(acc, v)
      {:scrollbar_margin, v}, acc -> scrollbar_margin(acc, v)
      {:scroller_width, v}, acc -> scroller_width(acc, v)
      {:anchor, v}, acc -> anchor(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the scrollable width."
  @spec width(scrollable :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = s, width), do: %{s | width: width}

  @doc "Sets the scrollable height."
  @spec height(scrollable :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = s, height), do: %{s | height: height}

  @doc "Sets the scroll direction."
  @spec direction(scrollable :: t(), direction :: atom() | String.t()) :: t()
  def direction(%__MODULE__{} = s, direction), do: %{s | direction: direction}

  @doc "Sets the spacing between scrollbar and content."
  @spec spacing(scrollable :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = s, spacing), do: %{s | spacing: spacing}

  @doc "Sets the scrollbar track width in pixels."
  @spec scrollbar_width(scrollable :: t(), scrollbar_width :: number()) :: t()
  def scrollbar_width(%__MODULE__{} = s, scrollbar_width),
    do: %{s | scrollbar_width: scrollbar_width}

  @doc "Sets the scrollbar margin in pixels."
  @spec scrollbar_margin(scrollable :: t(), scrollbar_margin :: number()) :: t()
  def scrollbar_margin(%__MODULE__{} = s, scrollbar_margin),
    do: %{s | scrollbar_margin: scrollbar_margin}

  @doc "Sets the scroller handle width in pixels."
  @spec scroller_width(scrollable :: t(), scroller_width :: number()) :: t()
  def scroller_width(%__MODULE__{} = s, scroller_width), do: %{s | scroller_width: scroller_width}

  @doc "Sets the scroll anchor."
  @spec anchor(scrollable :: t(), anchor :: atom() | String.t()) :: t()
  def anchor(%__MODULE__{} = s, anchor), do: %{s | anchor: anchor}

  @doc "Appends a child to the scrollable."
  @spec push(scrollable :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = s, child), do: %{s | children: s.children ++ [child]}

  @doc "Appends multiple children to the scrollable."
  @spec extend(scrollable :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = s, children), do: %{s | children: s.children ++ children}

  @doc "Converts this scrollable struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(scrollable :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = s), do: Julep.Iced.Widget.to_node(s)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(s) do
      props =
        %{}
        |> put_if(s.width, "width")
        |> put_if(s.height, "height")
        |> put_if(s.direction, "direction", &to_string/1)
        |> put_if(s.spacing, "spacing")
        |> put_if(s.scrollbar_width, "scrollbar_width")
        |> put_if(s.scrollbar_margin, "scrollbar_margin")
        |> put_if(s.scroller_width, "scroller_width")
        |> put_if(s.anchor, "anchor", &to_string/1)

      %{id: s.id, type: "scrollable", props: props, children: children_to_nodes(s.children)}
    end
  end
end
