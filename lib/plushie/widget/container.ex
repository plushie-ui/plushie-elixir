defmodule Plushie.Widget.Container do
  @moduledoc """
  Container layout -- wraps a single child with padding, sizing, and styling.

  ## Props

  - `padding` (number | map) -- padding inside the container. See `Plushie.Type.Padding`.
  - `width` (length) -- container width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- container height. Default: shrink.
  - `max_width` (number) -- maximum width in pixels.
  - `max_height` (number) -- maximum height in pixels.
  - `center` (boolean) -- center child in both axes. Default: false.
  - `clip` (boolean) -- clip child that overflows. Default: false.
  - `align_x` -- horizontal alignment: `:left`, `:center`, `:right`. See `Plushie.Type.Alignment`.
  - `align_y` -- vertical alignment: `:top`, `:center`, `:bottom`. See `Plushie.Type.Alignment`.
  - `background` (color | gradient) -- background fill. Accepts a hex color string,
    `%{r, g, b, a}` map, or a gradient map. See `Plushie.Type.Color`, `Plushie.Type.Gradient`.
  - `color` (color) -- text color override. See `Plushie.Type.Color`.
  - `border` (map) -- border specification: `%{color, width, radius}`. See `Plushie.Type.Border`.
  - `shadow` (map) -- shadow specification: `%{color, offset, blur_radius}`. See `Plushie.Type.Shadow`.
  - `style` -- named preset (`:transparent`, `:rounded_box`, `:bordered_box`,
    `:dark`, `:primary`, `:secondary`, `:success`, `:danger`, `:warning`)
    or `StyleMap.t()`. Overrides inline style props if both are set.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @presets [
    :transparent,
    :rounded_box,
    :bordered_box,
    :dark,
    :primary,
    :secondary,
    :success,
    :danger,
    :warning
  ]

  @doc false
  def style_presets, do: @presets

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:padding, Plushie.Type.Padding.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:max_width, number()}
          | {:max_height, number()}
          | {:center, boolean()}
          | {:clip, boolean()}
          | {:align_x, Plushie.Type.Alignment.t()}
          | {:align_y, Plushie.Type.Alignment.t()}
          | {:background, Plushie.Type.Color.input() | Plushie.Type.Gradient.t()}
          | {:color, Plushie.Type.Color.input()}
          | {:border, Plushie.Type.Border.t()}
          | {:shadow, Plushie.Type.Shadow.t()}
          | {:style, style()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          padding: Plushie.Type.Padding.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          max_width: number() | nil,
          max_height: number() | nil,
          center: boolean() | nil,
          clip: boolean() | nil,
          align_x: Plushie.Type.Alignment.t() | nil,
          align_y: Plushie.Type.Alignment.t() | nil,
          background: Plushie.Type.Color.t() | Plushie.Type.Gradient.t() | nil,
          color: Plushie.Type.Color.t() | nil,
          border: Plushie.Type.Border.t() | nil,
          shadow: Plushie.Type.Shadow.t() | nil,
          style: style() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.child()]
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

  @valid_option_keys ~w(padding width height max_width max_height center clip align_x align_y background color border shadow style a11y)a

  @doc false
  def __field_keys__, do: @valid_option_keys

  @doc false
  def __field_types__ do
    %{
      padding: Plushie.Type.Padding,
      border: Plushie.Type.Border,
      shadow: Plushie.Type.Shadow,
      style: Plushie.Type.StyleMap,
      a11y: Plushie.Type.A11y
    }
  end

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
  @spec padding(container :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = c, padding), do: %{c | padding: padding}

  @doc "Sets the container width."
  @spec width(container :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = c, width), do: %{c | width: width}

  @doc "Sets the container height."
  @spec height(container :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = c, height), do: %{c | height: height}

  @doc "Sets the maximum width in pixels."
  @spec max_width(container :: t(), max_width :: number()) :: t()
  def max_width(%__MODULE__{} = c, max_width) when is_number(max_width),
    do: %{c | max_width: max_width}

  @doc "Sets the maximum height in pixels."
  @spec max_height(container :: t(), max_height :: number()) :: t()
  def max_height(%__MODULE__{} = c, max_height) when is_number(max_height),
    do: %{c | max_height: max_height}

  @doc "Centers the child in both axes."
  @spec center(container :: t(), center :: boolean()) :: t()
  def center(%__MODULE__{} = c, center \\ true) when is_boolean(center),
    do: %{c | center: center}

  @doc "Sets whether the child is clipped on overflow."
  @spec clip(container :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = c, clip) when is_boolean(clip), do: %{c | clip: clip}

  @doc "Sets the horizontal alignment of the child."
  @spec align_x(container :: t(), align_x :: Plushie.Type.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = c, align_x), do: %{c | align_x: align_x}

  @doc "Sets the vertical alignment of the child."
  @spec align_y(container :: t(), align_y :: Plushie.Type.Alignment.t()) :: t()
  def align_y(%__MODULE__{} = c, align_y), do: %{c | align_y: align_y}

  @doc "Centers content horizontally. Sets width and align_x: :center."
  @spec center_x(container :: t(), width :: Plushie.Type.Length.t()) :: t()
  def center_x(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :center}

  @doc "Centers content vertically. Sets height and align_y: :center."
  @spec center_y(container :: t(), height :: Plushie.Type.Length.t()) :: t()
  def center_y(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :center}

  @doc "Aligns content to the left. Sets width and align_x: :left."
  @spec align_left(container :: t(), width :: Plushie.Type.Length.t()) :: t()
  def align_left(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :left}

  @doc "Aligns content to the right. Sets width and align_x: :right."
  @spec align_right(container :: t(), width :: Plushie.Type.Length.t()) :: t()
  def align_right(%__MODULE__{} = container, width \\ :fill),
    do: %{container | width: width, align_x: :right}

  @doc "Aligns content to the top. Sets height and align_y: :top."
  @spec align_top(container :: t(), height :: Plushie.Type.Length.t()) :: t()
  def align_top(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :top}

  @doc "Aligns content to the bottom. Sets height and align_y: :bottom."
  @spec align_bottom(container :: t(), height :: Plushie.Type.Length.t()) :: t()
  def align_bottom(%__MODULE__{} = container, height \\ :fill),
    do: %{container | height: height, align_y: :bottom}

  @doc "Sets the background fill (color or gradient)."
  @spec background(
          container :: t(),
          background :: Plushie.Type.Color.input() | Plushie.Type.Gradient.t()
        ) ::
          t()
  def background(%__MODULE__{} = c, %{type: "linear"} = gradient),
    do: %{c | background: gradient}

  def background(%__MODULE__{} = c, background),
    do: %{c | background: Plushie.Type.Color.cast(background)}

  @doc "Sets the text color override."
  @spec color(container :: t(), color :: Plushie.Type.Color.input()) :: t()
  def color(%__MODULE__{} = c, color), do: %{c | color: Plushie.Type.Color.cast(color)}

  @doc "Sets the border specification."
  @spec border(container :: t(), border :: Plushie.Type.Border.t()) :: t()
  def border(%__MODULE__{} = c, border), do: %{c | border: border}

  @doc "Sets the shadow specification."
  @spec shadow(container :: t(), shadow :: Plushie.Type.Shadow.t()) :: t()
  def shadow(%__MODULE__{} = c, shadow), do: %{c | shadow: shadow}

  @doc "Sets the named style."
  @spec style(container :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = c, %StyleMap{} = style), do: %{c | style: style}
  def style(%__MODULE__{} = c, style) when style in @presets, do: %{c | style: style}

  @doc "Appends a child to the container."
  @spec push(container :: t(), child :: Plushie.Widget.child()) :: t()
  def push(%__MODULE__{} = c, child), do: %{c | children: [child | c.children]}

  @doc "Appends multiple children to the container."
  @spec extend(container :: t(), children :: [Plushie.Widget.child()]) ::
          t()
  def extend(%__MODULE__{} = c, children),
    do: %{c | children: Enum.reverse(children) ++ c.children}

  @doc "Sets accessibility annotations."
  @spec a11y(container :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = c, a11y), do: %{c | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this container struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(container :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = c), do: Plushie.Widget.to_node(c)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(c) do
      children = Enum.reverse(c.children)
      validate_single_child!(c.id, "container", children)

      props =
        %{}
        |> put_if(c.padding, :padding)
        |> put_if(c.width, :width)
        |> put_if(c.height, :height)
        |> put_if(c.max_width, :max_width)
        |> put_if(c.max_height, :max_height)
        |> put_if(c.center, :center)
        |> put_if(c.clip, :clip)
        |> put_if(c.align_x, :align_x)
        |> put_if(c.align_y, :align_y)
        |> put_if(c.background, :background)
        |> put_if(c.color, :color)
        |> put_if(c.border, :border)
        |> put_if(c.shadow, :shadow)
        |> put_if(c.style, :style)
        |> put_if(c.a11y, :a11y)

      %{
        id: c.id,
        type: "container",
        props: props,
        children: children_to_nodes(children)
      }
    end
  end
end
