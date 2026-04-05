defmodule Plushie.Widget.RichText do
  @moduledoc """
  Rich text display with individually styled spans.

  ## Props

  - `spans` (list of maps) -- list of span descriptors. Each span is a map with:
    - `text` (string) -- the text content.
    - `size` (number) -- font size in pixels.
    - `color` (color) -- text color. See `Plushie.Type.Color`.
    - `font` (string | map) -- font specification. See `Plushie.Type.Font`.
    - `link` (string) -- makes this span a clickable link.
    - `underline` (boolean) -- renders the span with an underline.
    - `strikethrough` (boolean) -- renders the span with a strikethrough line.
    - `line_height` (number) -- relative line height for this span.
    - `padding` (number | map) -- padding around the span. A number applies
      uniformly; a map with `top`, `right`, `bottom`, `left` keys sets per-side.
    - `highlight` (map) -- visual highlight behind the span text. Accepts:
      - `background` (color) -- background color. See `Plushie.Type.Color`.
      - `border` (map) -- border around the highlight. Accepts `color` (color),
        `width` (number), and `radius` (number or list of 4 numbers).
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- widget height. Default: shrink.
  - `size` (number) -- default font size for all spans.
  - `font` (string | map) -- default font for all spans.
  - `color` (color) -- default text color for all spans.
  - `line_height` (number | map) -- line height.
  - `wrapping` -- text wrapping mode. See `Plushie.Type.Wrapping`.
  - `ellipsis` (string) -- text ellipsis mode: `"none"`, `"start"`, `"middle"`, `"end"`.
    Truncates text that overflows and inserts an ellipsis character at the given position.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :click, id: "id:link_value"}` -- emitted when a span link is clicked.
  """

  alias Plushie.Widget.Build

  @type option ::
          {:spans, [map()]}
          | {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:color, Plushie.Type.Color.input()}
          | {:line_height, number() | map()}
          | {:wrapping, Plushie.Type.Wrapping.t()}
          | {:ellipsis, String.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          spans: [map()] | nil,
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          color: Plushie.Type.Color.t() | nil,
          line_height: number() | map() | nil,
          wrapping: Plushie.Type.Wrapping.t() | nil,
          ellipsis: String.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :spans,
    :width,
    :height,
    :size,
    :font,
    :color,
    :line_height,
    :wrapping,
    :ellipsis,
    :a11y
  ]

  @valid_option_keys ~w(spans width height size font color line_height wrapping ellipsis a11y)a

  @doc false
  def __field_keys__, do: @valid_option_keys

  @doc false
  def __field_types__ do
    %{font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new rich text struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing rich text struct."
  @spec with_options(rich_text :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = rt, []), do: rt

  def with_options(%__MODULE__{} = rt, opts) do
    Enum.reduce(opts, rt, fn
      {:spans, v}, acc -> spans(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:color, v}, acc -> color(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:ellipsis, v}, acc -> ellipsis(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the list of span descriptors."
  @spec spans(rich_text :: t(), spans :: [map()]) :: t()
  def spans(%__MODULE__{} = rt, spans), do: %{rt | spans: spans}

  @doc "Sets the widget width."
  @spec width(rich_text :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = rt, width), do: %{rt | width: width}

  @doc "Sets the widget height."
  @spec height(rich_text :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = rt, height), do: %{rt | height: height}

  @doc "Sets the default font size for all spans."
  @spec size(rich_text :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = rt, size) when is_number(size), do: %{rt | size: size}

  @doc "Sets the default font for all spans."
  @spec font(rich_text :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = rt, font), do: %{rt | font: font}

  @doc "Sets the default text color for all spans."
  @spec color(rich_text :: t(), color :: Plushie.Type.Color.input()) :: t()
  def color(%__MODULE__{} = rt, color), do: %{rt | color: elem(Plushie.Type.Color.cast(color), 1)}

  @doc "Sets the line height."
  @spec line_height(rich_text :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = rt, line_height), do: %{rt | line_height: line_height}

  @doc "Sets the text wrapping mode."
  @spec wrapping(rich_text :: t(), wrapping :: Plushie.Type.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = rt, wrapping), do: %{rt | wrapping: wrapping}

  @doc ~S'Sets the text ellipsis mode. One of: `"none"`, `"start"`, `"middle"`, `"end"`.'
  @spec ellipsis(rich_text :: t(), ellipsis :: String.t()) :: t()
  def ellipsis(%__MODULE__{} = rt, ellipsis) when is_binary(ellipsis),
    do: %{rt | ellipsis: ellipsis}

  @doc "Sets accessibility annotations."
  @spec a11y(rich_text :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = rt, a11y),
    do: %{
      rt
      | a11y:
          (fn a ->
             {:ok, v} = Plushie.Type.A11y.cast(a)
             v
           end).(a11y)
    }

  @doc "Converts this rich text struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(rich_text :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = rt), do: Plushie.Widget.to_node(rt)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(rt) do
      props =
        %{}
        |> put_if(rt.spans, :spans)
        |> put_if(rt.width, :width)
        |> put_if(rt.height, :height)
        |> put_if(rt.size, :size)
        |> put_if(rt.font, :font)
        |> put_if(rt.color, :color)
        |> put_if(rt.line_height, :line_height)
        |> put_if(rt.wrapping, :wrapping)
        |> put_if(rt.ellipsis, :ellipsis)
        |> put_if(rt.a11y, :a11y)

      %{id: rt.id, type: "rich_text", props: props, children: []}
    end
  end
end
