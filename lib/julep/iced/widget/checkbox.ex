defmodule Julep.Iced.Widget.Checkbox do
  @moduledoc """
  Checkbox -- toggleable boolean input.

  ## Props

  - `checked` (boolean) -- whether the checkbox is checked. Default: false.
  - `label` (string) -- text label displayed next to the checkbox.
  - `spacing` (number) -- space between checkbox and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- checkbox size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. One of: `"primary"` (default), `"secondary"`,
    `"success"`, `"danger"`.
  - `disabled` (boolean) -- when true, the checkbox cannot be toggled. Default: false.

  ## Events

  - `{:toggle, id, value}` -- emitted on toggle, `value` is the new boolean state.
  """

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style :: :primary | :secondary | :success | :danger | StyleMap.t()

  @type option ::
          {:spacing, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:text_shaping, Julep.Iced.Shaping.t()}
          | {:wrapping, Julep.Iced.Wrapping.t()}
          | {:style, style()}
          | {:disabled, boolean()}

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          is_toggled: boolean(),
          spacing: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          text_shaping: Julep.Iced.Shaping.t() | nil,
          wrapping: Julep.Iced.Wrapping.t() | nil,
          style: style() | nil,
          disabled: boolean() | nil
        }

  defstruct [
    :id,
    :label,
    :is_toggled,
    :spacing,
    :width,
    :size,
    :text_size,
    :font,
    :line_height,
    :text_shaping,
    :wrapping,
    :style,
    :disabled
  ]

  @doc "Creates a new checkbox struct with the given label, toggle state, and optional keyword opts."
  @spec new(id :: String.t(), label :: String.t(), is_toggled :: boolean(), opts :: [option()]) ::
          t()
  def new(id, label, is_toggled, opts \\ []) when is_binary(label) and is_boolean(is_toggled) do
    %__MODULE__{id: id, label: label, is_toggled: is_toggled} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing checkbox struct."
  @spec with_options(checkbox :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = cb, []), do: cb

  def with_options(%__MODULE__{} = cb, opts) do
    Enum.reduce(opts, cb, fn
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:text_size, v}, acc -> text_size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:text_shaping, v}, acc -> text_shaping(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between checkbox and label."
  @spec spacing(checkbox :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = cb, spacing), do: %{cb | spacing: spacing}

  @doc "Sets the checkbox width."
  @spec width(checkbox :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = cb, width), do: %{cb | width: width}

  @doc "Sets the checkbox size in pixels."
  @spec size(checkbox :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = cb, size), do: %{cb | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(checkbox :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = cb, text_size), do: %{cb | text_size: text_size}

  @doc "Sets the label font."
  @spec font(checkbox :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = cb, font), do: %{cb | font: font}

  @doc "Sets the label line height."
  @spec line_height(checkbox :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = cb, line_height), do: %{cb | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(checkbox :: t(), text_shaping :: Julep.Iced.Shaping.t()) :: t()
  def text_shaping(%__MODULE__{} = cb, text_shaping), do: %{cb | text_shaping: text_shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(checkbox :: t(), wrapping :: Julep.Iced.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = cb, wrapping), do: %{cb | wrapping: wrapping}

  @doc "Sets the checkbox style."
  @spec style(checkbox :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = cb, style), do: %{cb | style: style}

  @doc "Sets whether the checkbox is disabled."
  @spec disabled(checkbox :: t(), disabled :: boolean()) :: t()
  def disabled(%__MODULE__{} = cb, disabled), do: %{cb | disabled: disabled}

  @doc "Converts this checkbox struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(checkbox :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = cb), do: Julep.Iced.Widget.to_node(cb)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(cb) do
      props =
        %{}
        |> put_if(cb.label, "label")
        |> put_if(cb.is_toggled, "checked")
        |> put_if(cb.spacing, "spacing")
        |> put_if(cb.width, "width")
        |> put_if(cb.size, "size")
        |> put_if(cb.text_size, "text_size")
        |> put_if(cb.font, "font")
        |> put_if(cb.line_height, "line_height")
        |> put_if(cb.text_shaping, "text_shaping")
        |> put_if(cb.wrapping, "wrapping")
        |> put_if(cb.style, "style")
        |> put_if(cb.disabled, "disabled")

      %{id: cb.id, type: "checkbox", props: props, children: []}
    end
  end
end
