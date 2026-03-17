defmodule Julep.Iced.Widget.Text do
  @moduledoc """
  Text display -- renders static text.

  ## Props

  - `content` (string) -- the text string to display.
  - `size` (number) -- font size in pixels.
  - `color` (color) -- text color. See `Julep.Iced.Color`.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `width` (length) -- text widget width. See `Julep.Iced.Length`.
  - `height` (length) -- text widget height.
  - `line_height` (number | map) -- line height. Number is a relative multiplier;
    map with `%{relative: n}` or `%{absolute: n}` for explicit control.
  - `align_x` (string) -- horizontal text alignment: `"left"`, `"center"`, `"right"`.
  - `align_y` (string) -- vertical text alignment: `"top"`, `"center"`, `"bottom"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `ellipsis` (string) -- text ellipsis mode: `"none"`, `"start"`, `"middle"`, `"end"`.
    Truncates text that overflows and inserts an ellipsis character at the given position.
  - `style` (string) -- named style. One of: `"default"`, `"primary"`, `"secondary"`,
    `"success"`, `"danger"`, `"warning"`.
  - `shaping` (string) -- text shaping strategy: `"basic"` or `"advanced"`. See `Julep.Iced.Shaping`.
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type style :: :default | :primary | :secondary | :success | :danger | :warning

  @type option ::
          {:size, number()}
          | {:color, Julep.Iced.Color.t()}
          | {:font, Julep.Iced.Font.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:height, Julep.Iced.Length.t()}
          | {:line_height, number() | map()}
          | {:align_x, Julep.Iced.Alignment.t()}
          | {:align_y, Julep.Iced.Alignment.t()}
          | {:wrapping, Julep.Iced.Wrapping.t()}
          | {:ellipsis, String.t()}
          | {:shaping, Julep.Iced.Shaping.t()}
          | {:style, style()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          content: String.t(),
          size: number() | nil,
          color: Julep.Iced.Color.t() | nil,
          font: Julep.Iced.Font.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          height: Julep.Iced.Length.t() | nil,
          line_height: number() | map() | nil,
          align_x: Julep.Iced.Alignment.t() | nil,
          align_y: Julep.Iced.Alignment.t() | nil,
          wrapping: Julep.Iced.Wrapping.t() | nil,
          ellipsis: String.t() | nil,
          shaping: Julep.Iced.Shaping.t() | nil,
          style: style() | nil,
          a11y: Julep.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :content,
    :size,
    :color,
    :font,
    :width,
    :height,
    :line_height,
    :align_x,
    :align_y,
    :wrapping,
    :ellipsis,
    :shaping,
    :style,
    :a11y
  ]

  @doc "Creates a new text widget struct with the given content and optional keyword opts."
  @spec new(id :: String.t(), content :: String.t(), opts :: [option()]) :: t()
  def new(id, content, opts \\ []) when is_binary(content) do
    %__MODULE__{id: id, content: content} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing text struct."
  @spec with_options(text :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = txt, []), do: txt

  def with_options(%__MODULE__{} = txt, opts) do
    Enum.reduce(opts, txt, fn
      {:size, v}, acc -> size(acc, v)
      {:color, v}, acc -> color(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:align_x, v}, acc -> align_x(acc, v)
      {:align_y, v}, acc -> align_y(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:ellipsis, v}, acc -> ellipsis(acc, v)
      {:shaping, v}, acc -> shaping(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the font size in pixels."
  @spec size(text :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = txt, size), do: %{txt | size: size}

  @doc "Sets the text color."
  @spec color(text :: t(), color :: Julep.Iced.Color.t() | atom()) :: t()
  def color(%__MODULE__{} = txt, color), do: %{txt | color: Julep.Iced.Color.cast(color)}

  @doc "Sets the font."
  @spec font(text :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = txt, font), do: %{txt | font: font}

  @doc "Sets the text widget width."
  @spec width(text :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = txt, width), do: %{txt | width: width}

  @doc "Sets the text widget height."
  @spec height(text :: t(), height :: Julep.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = txt, height), do: %{txt | height: height}

  @doc "Sets the line height."
  @spec line_height(text :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = txt, line_height), do: %{txt | line_height: line_height}

  @doc "Sets the horizontal text alignment."
  @spec align_x(text :: t(), align_x :: Julep.Iced.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = txt, align_x), do: %{txt | align_x: align_x}

  @doc "Sets the vertical text alignment."
  @spec align_y(text :: t(), align_y :: Julep.Iced.Alignment.t()) :: t()
  def align_y(%__MODULE__{} = txt, align_y), do: %{txt | align_y: align_y}

  @doc "Sets the text wrapping mode."
  @spec wrapping(text :: t(), wrapping :: Julep.Iced.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = txt, wrapping), do: %{txt | wrapping: wrapping}

  @doc ~S'Sets the text ellipsis mode. One of: `"none"`, `"start"`, `"middle"`, `"end"`.'
  @spec ellipsis(text :: t(), ellipsis :: String.t()) :: t()
  def ellipsis(%__MODULE__{} = txt, ellipsis), do: %{txt | ellipsis: ellipsis}

  @doc "Sets the text shaping strategy."
  @spec shaping(text :: t(), shaping :: Julep.Iced.Shaping.t()) :: t()
  def shaping(%__MODULE__{} = txt, shaping), do: %{txt | shaping: shaping}

  @doc "Sets the text style."
  @spec style(text :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = txt, style), do: %{txt | style: style}

  @doc "Sets accessibility annotations."
  @spec a11y(text :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = txt, a11y), do: %{txt | a11y: A11y.cast(a11y)}

  @doc "Converts this text struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(text :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = txt), do: Julep.Iced.Widget.to_node(txt)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(txt) do
      props =
        %{}
        |> put_if(txt.content, "content")
        |> put_if(txt.size, "size")
        |> put_if(txt.color, "color")
        |> put_if(txt.font, "font")
        |> put_if(txt.width, "width")
        |> put_if(txt.height, "height")
        |> put_if(txt.line_height, "line_height")
        |> put_if(txt.align_x, "align_x")
        |> put_if(txt.align_y, "align_y")
        |> put_if(txt.wrapping, "wrapping")
        |> put_if(txt.ellipsis, "ellipsis")
        |> put_if(txt.shaping, "text_shaping")
        |> put_if(txt.style, "style")
        |> put_if(txt.a11y, "a11y")

      %{id: txt.id, type: "text", props: props, children: []}
    end
  end
end
