defmodule Julep.Iced.Widget.RichText do
  @moduledoc """
  Rich text display with individually styled spans.

  ## Props

  - `spans` (list of maps) -- list of span descriptors. Each span is a map with:
    - `text` (string) -- the text content.
    - `size` (number) -- font size in pixels.
    - `color` (color) -- text color. See `Julep.Iced.Color`.
    - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
    - `link` (string) -- makes this span a clickable link.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `height` (length) -- widget height. Default: shrink.
  - `size` (number) -- default font size for all spans.
  - `font` (string | map) -- default font for all spans.
  - `color` (color) -- default text color for all spans.
  - `line_height` (number | map) -- line height.

  ## Events

  - `{:click, "id:link_value"}` -- emitted when a span link is clicked.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type option ::
          {:spans, [map()]}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:color, Julep.Iced.Color.t()}
          | {:line_height, number() | map()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          spans: [map()] | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          color: Julep.Iced.Color.t() | nil,
          line_height: number() | map() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [:id, :spans, :width, :height, :size, :font, :color, :line_height, :a11y]

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
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the list of span descriptors."
  @spec spans(rich_text :: t(), spans :: [map()]) :: t()
  def spans(%__MODULE__{} = rt, spans), do: %{rt | spans: spans}

  @doc "Sets the widget width."
  @spec width(rich_text :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = rt, width), do: %{rt | width: width}

  @doc "Sets the widget height."
  @spec height(rich_text :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = rt, height), do: %{rt | height: height}

  @doc "Sets the default font size for all spans."
  @spec size(rich_text :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = rt, size), do: %{rt | size: size}

  @doc "Sets the default font for all spans."
  @spec font(rich_text :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = rt, font), do: %{rt | font: font}

  @doc "Sets the default text color for all spans."
  @spec color(rich_text :: t(), color :: Julep.Iced.Color.t() | atom()) :: t()
  def color(%__MODULE__{} = rt, color), do: %{rt | color: Julep.Iced.Color.cast(color)}

  @doc "Sets the line height."
  @spec line_height(rich_text :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = rt, line_height), do: %{rt | line_height: line_height}

  @doc "Sets accessibility annotations."
  @spec a11y(rich_text :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = rt, a11y), do: %{rt | a11y: A11y.cast(a11y)}

  @doc "Converts this rich text struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(rich_text :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = rt), do: Julep.Iced.Widget.to_node(rt)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(rt) do
      props =
        %{}
        |> put_if(rt.spans, "spans")
        |> put_if(rt.width, "width")
        |> put_if(rt.height, "height")
        |> put_if(rt.size, "size")
        |> put_if(rt.font, "font")
        |> put_if(rt.color, "color")
        |> put_if(rt.line_height, "line_height")
        |> put_if(rt.a11y, "a11y")

      %{id: rt.id, type: "rich_text", props: props, children: []}
    end
  end
end
