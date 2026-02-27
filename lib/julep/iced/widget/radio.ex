defmodule Julep.Iced.Widget.Radio do
  @moduledoc """
  Radio button -- one-of-many selection.

  All radios in a group should share the same `group` prop value. The
  `selected` prop should be set to the currently selected value across
  all radios in the group.

  ## Props

  - `value` (string) -- the value this radio represents.
  - `selected` (string) -- the currently selected value in the group.
  - `label` (string) -- label text. Defaults to `value` if omitted.
  - `group` (string) -- group identifier. All radios with the same group
    emit events with the group name as the event ID.
  - `spacing` (number) -- space between radio and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- radio button size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:select, group_or_id, value}` -- emitted when this radio is selected.
    The first element is the `group` prop if set, otherwise the node ID.
  """

  alias Julep.Iced.Widget.Build

  @type style :: :default

  @type option ::
          {:label, String.t()}
          | {:group, String.t()}
          | {:spacing, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:text_shaping, Julep.Iced.Shaping.t()}
          | {:wrapping, Julep.Iced.Wrapping.t()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          value: String.t(),
          selected: String.t(),
          label: String.t() | nil,
          group: String.t() | nil,
          spacing: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          text_shaping: Julep.Iced.Shaping.t() | nil,
          wrapping: Julep.Iced.Wrapping.t() | nil,
          style: style() | nil
        }

  defstruct [
    :id,
    :value,
    :selected,
    :label,
    :group,
    :spacing,
    :width,
    :size,
    :text_size,
    :font,
    :line_height,
    :text_shaping,
    :wrapping,
    :style
  ]

  @doc "Creates a new radio struct with the given value, selected state, and optional keyword opts."
  @spec new(
          id :: String.t(),
          value :: String.t(),
          selected :: String.t(),
          opts :: [option()]
        ) :: t()
  def new(id, value, selected, opts \\ []) when is_binary(value) and is_binary(selected) do
    %__MODULE__{id: id, value: value, selected: selected} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing radio struct."
  @spec with_options(radio :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = r, []), do: r

  def with_options(%__MODULE__{} = r, opts) do
    Enum.reduce(opts, r, fn
      {:label, v}, acc -> label(acc, v)
      {:group, v}, acc -> group(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:text_size, v}, acc -> text_size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:text_shaping, v}, acc -> text_shaping(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the radio label text."
  @spec label(radio :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = r, label), do: %{r | label: label}

  @doc "Sets the radio group identifier."
  @spec group(radio :: t(), group :: String.t()) :: t()
  def group(%__MODULE__{} = r, group), do: %{r | group: group}

  @doc "Sets the spacing between radio and label."
  @spec spacing(radio :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = r, spacing), do: %{r | spacing: spacing}

  @doc "Sets the radio width."
  @spec width(radio :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = r, width), do: %{r | width: width}

  @doc "Sets the radio button size in pixels."
  @spec size(radio :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = r, size), do: %{r | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(radio :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = r, text_size), do: %{r | text_size: text_size}

  @doc "Sets the label font."
  @spec font(radio :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = r, font), do: %{r | font: font}

  @doc "Sets the label line height."
  @spec line_height(radio :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = r, line_height), do: %{r | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(radio :: t(), text_shaping :: Julep.Iced.Shaping.t()) :: t()
  def text_shaping(%__MODULE__{} = r, text_shaping), do: %{r | text_shaping: text_shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(radio :: t(), wrapping :: Julep.Iced.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = r, wrapping), do: %{r | wrapping: wrapping}

  @doc "Sets the radio style."
  @spec style(radio :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = r, style), do: %{r | style: style}

  @doc "Converts this radio struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(radio :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = r), do: Julep.Iced.Widget.to_node(r)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(r) do
      props =
        %{}
        |> put_if(r.value, "value")
        |> put_if(r.selected, "selected")
        |> put_if(r.label, "label")
        |> put_if(r.group, "group")
        |> put_if(r.spacing, "spacing")
        |> put_if(r.width, "width")
        |> put_if(r.size, "size")
        |> put_if(r.text_size, "text_size")
        |> put_if(r.font, "font")
        |> put_if(r.line_height, "line_height")
        |> put_if(r.text_shaping, "text_shaping")
        |> put_if(r.wrapping, "wrapping")
        |> put_if(r.style, "style")

      %{id: r.id, type: "radio", props: props, children: []}
    end
  end
end
