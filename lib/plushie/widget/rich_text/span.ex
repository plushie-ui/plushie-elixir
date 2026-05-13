defmodule Plushie.Widget.RichText.Span do
  @moduledoc """
  A typed span for `Plushie.Widget.RichText`.

  Each span carries one segment of text with its own optional
  styling. Construct one with `new/1` and chain setters, or pass a
  plain map (the renderer accepts both):

      alias Plushie.Widget.RichText.Span

      Span.new("Hello ")
      |> Span.color("#003366")
      |> Span.size(18.0)
      |> Span.font(Plushie.Type.Font.new(weight: :bold))

  Spans are encoded to the wire as maps with snake_case keys. Unset
  fields are omitted so the renderer falls back to the rich_text
  widget's default styling for that property.
  """

  alias Plushie.Type.{Border, Color, Font, LineHeight, Padding}

  defstruct [
    :text,
    :size,
    :font,
    :color,
    :line_height,
    :link,
    :underline,
    :strikethrough,
    :padding,
    :highlight
  ]

  @type t :: %__MODULE__{
          text: String.t(),
          size: number() | nil,
          font: Font.t() | nil,
          color: Color.t() | nil,
          line_height: LineHeight.t() | nil,
          link: String.t() | nil,
          underline: boolean() | nil,
          strikethrough: boolean() | nil,
          padding: Padding.t() | nil,
          highlight: highlight() | nil
        }

  @typedoc """
  Highlight backdrop drawn behind a span. `background` paints a
  solid colour; `border` adds a stroke around the highlighted
  region.
  """
  @type highlight :: %{optional(:background) => Color.t(), optional(:border) => Border.t()}

  @doc "Build a span with the given text and no style overrides."
  @spec new(String.t()) :: t()
  def new(text) when is_binary(text), do: %__MODULE__{text: text}

  @doc "Set the font size (pixels)."
  @spec size(t(), number()) :: t()
  def size(%__MODULE__{} = span, value) when is_number(value), do: %{span | size: value}

  @doc "Set the font."
  @spec font(t(), Font.t()) :: t()
  def font(%__MODULE__{} = span, value), do: %{span | font: value}

  @doc "Set the text colour."
  @spec color(t(), Color.input()) :: t()
  def color(%__MODULE__{} = span, value) do
    c = cast!(Color, value, "span color")
    %{span | color: c}
  end

  @doc "Set the line height."
  @spec line_height(t(), LineHeight.t() | number() | map()) :: t()
  def line_height(%__MODULE__{} = span, value) do
    lh = cast!(LineHeight, value, "span line_height")
    %{span | line_height: lh}
  end

  @doc "Set a hyperlink URL the renderer emits as `link_click`."
  @spec link(t(), String.t()) :: t()
  def link(%__MODULE__{} = span, url) when is_binary(url), do: %{span | link: url}

  @doc "Toggle the underline decoration."
  @spec underline(t(), boolean()) :: t()
  def underline(%__MODULE__{} = span, value) when is_boolean(value),
    do: %{span | underline: value}

  @doc "Toggle the strikethrough decoration."
  @spec strikethrough(t(), boolean()) :: t()
  def strikethrough(%__MODULE__{} = span, value) when is_boolean(value),
    do: %{span | strikethrough: value}

  @doc "Set the padding around the span's text."
  @spec padding(t(), Padding.t() | number() | map() | list()) :: t()
  def padding(%__MODULE__{} = span, value) do
    p = cast!(Padding, value, "span padding")
    %{span | padding: p}
  end

  @doc """
  Set the highlight backdrop. Accepts a `Plushie.Type.Color`
  (background only) or a map with `:background` and/or `:border`.
  """
  @spec highlight(t(), Color.input() | highlight()) :: t()
  def highlight(%__MODULE__{} = span, %{} = h), do: %{span | highlight: h}

  def highlight(%__MODULE__{} = span, color) do
    c = cast!(Color, color, "span highlight")
    %{span | highlight: %{background: c}}
  end

  @doc "Encode a span (or plain map) to its wire form."
  @spec encode(t() | map()) :: map()
  def encode(%__MODULE__{} = span) do
    span
    |> Map.from_struct()
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new(fn {k, v} -> {k, Plushie.Type.encode_value(v)} end)
  end

  def encode(%{} = map) do
    Map.new(map, fn {k, v} -> {k, Plushie.Type.encode_value(v)} end)
  end

  defp cast!(type, value, label) do
    case type.cast(value) do
      {:ok, casted} ->
        casted

      :error ->
        raise ArgumentError, "#{label} is invalid: #{inspect(value)}"
    end
  end
end
