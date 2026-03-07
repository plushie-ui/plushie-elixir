defmodule Julep.Iced.Widget.Container do
  @moduledoc """
  Container layout -- wraps a single child with padding, sizing, and styling.

  ## Props

  - `padding` (number | map) -- padding inside the container. See `Julep.Iced.Padding`.
  - `width` (length) -- container width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- container height. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `center` (boolean) -- center child in both axes. Default: false.
  - `clip` (boolean) -- clip child that overflows. Default: false.
  - `align_x` (string) -- horizontal alignment: `"left"`, `"center"`, `"right"`.
  - `align_y` (string) -- vertical alignment: `"top"`, `"center"`, `"bottom"`.
  - `background` (color | gradient) -- background fill. Accepts a hex color string,
    `%{r, g, b, a}` map, or a gradient map. See `Julep.Iced.Color`, `Julep.Iced.Gradient`.
  - `color` (color) -- text color override. See `Julep.Iced.Color`.
  - `border` (map) -- border specification: `%{color, width, radius}`. See `Julep.Iced.Border`.
  - `shadow` (map) -- shadow specification: `%{color, offset, blur_radius}`. See `Julep.Iced.Shadow`.
  - `style` (string) -- named style. One of: `"transparent"`, `"rounded_box"`,
    `"bordered_box"`, `"dark"`, `"primary"`, `"secondary"`, `"success"`,
    `"danger"`, `"warning"`. Overrides inline style props if both are set.
  """

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style ::
          :transparent
          | :rounded_box
          | :bordered_box
          | :dark
          | :primary
          | :secondary
          | :success
          | :danger
          | :warning
          | StyleMap.t()

  @type option ::
          {:padding, Julep.Iced.Padding.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:max_width, number()}
          | {:max_height, number()}
          | {:center, boolean()}
          | {:clip, boolean()}
          | {:align_x, Julep.Iced.Alignment.t()}
          | {:align_y, Julep.Iced.Alignment.t()}
          | {:background, Julep.Iced.Color.t() | Julep.Iced.Gradient.t()}
          | {:color, Julep.Iced.Color.t()}
          | {:border, Julep.Iced.Border.t()}
          | {:shadow, Julep.Iced.Shadow.t()}
          | {:style, style()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          padding: Julep.Iced.Padding.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          max_width: number() | nil,
          max_height: number() | nil,
          center: boolean() | nil,
          clip: boolean() | nil,
          align_x: Julep.Iced.Alignment.t() | nil,
          align_y: Julep.Iced.Alignment.t() | nil,
          background: Julep.Iced.Color.t() | Julep.Iced.Gradient.t() | nil,
          color: Julep.Iced.Color.t() | nil,
          border: Julep.Iced.Border.t() | nil,
          shadow: Julep.Iced.Shadow.t() | nil,
          style: style() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :padding,
    :width,
    :height,
    :max_width,
    :max_height,
    :center,
    :clip,
    :align_x,
    :align_y,
    :background,
    :color,
    :border,
    :shadow,
    :style,
    :a11y,
    children: []
  ]

  @doc "Creates a new container struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing container struct."
  @spec with_options(container :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = c, []), do: c

  def with_options(%__MODULE__{} = c, opts) do
    Enum.reduce(opts, c, fn
      {:padding, v}, acc -> padding(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:max_width, v}, acc -> max_width(acc, v)
      {:max_height, v}, acc -> max_height(acc, v)
      {:center, v}, acc -> center(acc, v)
      {:clip, v}, acc -> clip(acc, v)
      {:align_x, v}, acc -> align_x(acc, v)
      {:align_y, v}, acc -> align_y(acc, v)
      {:background, v}, acc -> background(acc, v)
      {:color, v}, acc -> color(acc, v)
      {:border, v}, acc -> border(acc, v)
      {:shadow, v}, acc -> shadow(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the container padding."
  @spec padding(container :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = c, padding), do: %{c | padding: padding}

  @doc "Sets the container width."
  @spec width(container :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = c, width), do: %{c | width: width}

  @doc "Sets the container height."
  @spec height(container :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = c, height), do: %{c | height: height}

  @doc "Sets the maximum width in pixels."
  @spec max_width(container :: t(), max_width :: number()) :: t()
  def max_width(%__MODULE__{} = c, max_width), do: %{c | max_width: max_width}

  @doc "Sets the maximum height in pixels."
  @spec max_height(container :: t(), max_height :: number()) :: t()
  def max_height(%__MODULE__{} = c, max_height), do: %{c | max_height: max_height}

  @doc "Centers the child in both axes."
  @spec center(container :: t(), center :: boolean()) :: t()
  def center(%__MODULE__{} = c, center \\ true), do: %{c | center: center}

  @doc "Sets whether the child is clipped on overflow."
  @spec clip(container :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = c, clip), do: %{c | clip: clip}

  @doc "Sets the horizontal alignment of the child."
  @spec align_x(container :: t(), align_x :: Julep.Iced.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = c, align_x), do: %{c | align_x: align_x}

  @doc "Sets the vertical alignment of the child."
  @spec align_y(container :: t(), align_y :: Julep.Iced.Alignment.t()) :: t()
  def align_y(%__MODULE__{} = c, align_y), do: %{c | align_y: align_y}

  @doc "Centers content horizontally. Sets width and align_x: :center."
  @spec center_x(container :: t(), width :: Julep.Iced.Length.t()) :: t()
  def center_x(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :center}

  @doc "Centers content vertically. Sets height and align_y: :center."
  @spec center_y(container :: t(), height :: Julep.Iced.Length.t()) :: t()
  def center_y(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :center}

  @doc "Aligns content to the left. Sets width and align_x: :left."
  @spec align_left(container :: t(), width :: Julep.Iced.Length.t()) :: t()
  def align_left(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :left}

  @doc "Aligns content to the right. Sets width and align_x: :right."
  @spec align_right(container :: t(), width :: Julep.Iced.Length.t()) :: t()
  def align_right(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :right}

  @doc "Aligns content to the top. Sets height and align_y: :top."
  @spec align_top(container :: t(), height :: Julep.Iced.Length.t()) :: t()
  def align_top(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :top}

  @doc "Aligns content to the bottom. Sets height and align_y: :bottom."
  @spec align_bottom(container :: t(), height :: Julep.Iced.Length.t()) :: t()
  def align_bottom(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :bottom}

  @doc "Sets the background fill (color or gradient)."
  @spec background(container :: t(), background :: Julep.Iced.Color.t() | Julep.Iced.Gradient.t()) ::
          t()
  def background(%__MODULE__{} = c, background), do: %{c | background: background}

  @doc "Sets the text color override."
  @spec color(container :: t(), color :: Julep.Iced.Color.t() | atom()) :: t()
  def color(%__MODULE__{} = c, color), do: %{c | color: Julep.Iced.Color.cast(color)}

  @doc "Sets the border specification."
  @spec border(container :: t(), border :: Julep.Iced.Border.t()) :: t()
  def border(%__MODULE__{} = c, border), do: %{c | border: border}

  @doc "Sets the shadow specification."
  @spec shadow(container :: t(), shadow :: Julep.Iced.Shadow.t()) :: t()
  def shadow(%__MODULE__{} = c, shadow), do: %{c | shadow: shadow}

  @doc "Sets the named style."
  @spec style(container :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = c, style), do: %{c | style: style}

  @doc "Appends a child to the container."
  @spec push(container :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = c, child), do: %{c | children: [child | c.children]}

  @doc "Appends multiple children to the container."
  @spec extend(container :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = c, children),
    do: %{c | children: Enum.reverse(children) ++ c.children}

  @doc "Sets accessibility annotations."
  @spec a11y(container :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = c, a11y), do: %{c | a11y: a11y}

  @doc "Converts this container struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(container :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = c), do: Julep.Iced.Widget.to_node(c)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(c) do
      props =
        %{}
        |> put_if(c.padding, "padding")
        |> put_if(c.width, "width")
        |> put_if(c.height, "height")
        |> put_if(c.max_width, "max_width")
        |> put_if(c.max_height, "max_height")
        |> put_if(c.center, "center")
        |> put_if(c.clip, "clip")
        |> put_if(c.align_x, "align_x")
        |> put_if(c.align_y, "align_y")
        |> put_if(c.background, "background")
        |> put_if(c.color, "color")
        |> put_if(c.border, "border")
        |> put_if(c.shadow, "shadow")
        |> put_if(c.style, "style")
        |> put_if(c.a11y, "a11y")

      %{
        id: c.id,
        type: "container",
        props: props,
        children: children_to_nodes(Enum.reverse(c.children))
      }
    end
  end
end
