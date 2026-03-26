defmodule Plushie.Widget.Radio do
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
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `size` (number) -- radio button size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- label line height.
  - `shaping` -- text shaping strategy. See `Plushie.Type.Shaping`.
  - `wrapping` -- text wrapping mode. See `Plushie.Type.Wrapping`.
  - `style` -- `:default` or `StyleMap.t()` for custom styling. See `Plushie.Type.StyleMap`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :select, id: group_or_id, value: value}` -- emitted when this radio is selected.
    The `id` is the `group` prop if set, otherwise the node ID.
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:label, String.t()}
          | {:group, String.t()}
          | {:spacing, number()}
          | {:width, Plushie.Type.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:line_height, number() | map()}
          | {:shaping, Plushie.Type.Shaping.t()}
          | {:wrapping, Plushie.Type.Wrapping.t()}
          | {:style, style()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          value: String.t(),
          selected: String.t(),
          label: String.t() | nil,
          group: String.t() | nil,
          spacing: number() | nil,
          width: Plushie.Type.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          line_height: number() | map() | nil,
          shaping: Plushie.Type.Shaping.t() | nil,
          wrapping: Plushie.Type.Wrapping.t() | nil,
          style: style() | nil,
          a11y: Plushie.Type.A11y.t() | nil
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
    :shaping,
    :wrapping,
    :style,
    :a11y
  ]

  @valid_option_keys ~w(label group spacing width size text_size font line_height shaping wrapping style a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new radio struct with the given value, selected state, and optional keyword opts."
  @spec new(
          id :: String.t(),
          value :: String.t(),
          selected :: String.t(),
          opts :: [option()]
        ) :: t()
  def new(id, value, selected, opts \\ [])
      when is_binary(id) and is_binary(value) and (is_binary(selected) or is_nil(selected)) do
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
      {:shaping, v}, acc -> shaping(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the radio label text."
  @spec label(radio :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = r, label) when is_binary(label), do: %{r | label: label}

  @doc "Sets the radio group identifier."
  @spec group(radio :: t(), group :: String.t()) :: t()
  def group(%__MODULE__{} = r, group) when is_binary(group), do: %{r | group: group}

  @doc "Sets the spacing between radio and label."
  @spec spacing(radio :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = r, spacing) when is_number(spacing), do: %{r | spacing: spacing}

  @doc "Sets the radio width."
  @spec width(radio :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = r, width), do: %{r | width: width}

  @doc "Sets the radio button size in pixels."
  @spec size(radio :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = r, size) when is_number(size), do: %{r | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(radio :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = r, text_size) when is_number(text_size),
    do: %{r | text_size: text_size}

  @doc "Sets the label font."
  @spec font(radio :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = r, font), do: %{r | font: font}

  @doc "Sets the label line height."
  @spec line_height(radio :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = r, line_height), do: %{r | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec shaping(radio :: t(), shaping :: Plushie.Type.Shaping.t()) :: t()
  def shaping(%__MODULE__{} = r, shaping), do: %{r | shaping: shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(radio :: t(), wrapping :: Plushie.Type.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = r, wrapping), do: %{r | wrapping: wrapping}

  @doc "Sets the radio style."
  @spec style(radio :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = r, %StyleMap{} = style), do: %{r | style: style}
  def style(%__MODULE__{} = r, :default), do: %{r | style: :default}

  @doc "Sets accessibility annotations."
  @spec a11y(radio :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = r, a11y), do: %{r | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this radio struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(radio :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = r), do: Plushie.Widget.to_node(r)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(r) do
      props =
        %{}
        |> put_if(r.value, :value)
        |> put_if(r.selected, :selected)
        |> put_if(r.label, :label)
        |> put_if(r.group, :group)
        |> put_if(r.spacing, :spacing)
        |> put_if(r.width, :width)
        |> put_if(r.size, :size)
        |> put_if(r.text_size, :text_size)
        |> put_if(r.font, :font)
        |> put_if(r.line_height, :line_height)
        |> put_if(r.shaping, :shaping)
        |> put_if(r.wrapping, :wrapping)
        |> put_if(r.style, :style)
        |> put_if(r.a11y, :a11y)

      %{id: r.id, type: "radio", props: props, children: []}
    end
  end
end
