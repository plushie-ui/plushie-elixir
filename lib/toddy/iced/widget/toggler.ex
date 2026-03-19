defmodule Toddy.Iced.Widget.Toggler do
  @moduledoc """
  Toggler -- on/off switch.

  ## Props

  - `is_toggled` (boolean) -- whether the toggler is on. Default: false.
  - `label` (string) -- text label displayed next to the toggler.
  - `spacing` (number) -- space between toggler and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Toddy.Iced.Length`.
  - `size` (number) -- toggler size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Toddy.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (atom) -- text shaping: `:basic`, `:advanced`, or `:auto`.
    See `Toddy.Iced.Shaping`.
  - `wrapping` (atom) -- text wrapping: `:none`, `:word`, `:glyph`, `:word_or_glyph`.
    See `Toddy.Iced.Wrapping`.
  - `text_alignment` (atom) -- horizontal label alignment: `:left`, `:center`, `:right`.
    See `Toddy.Iced.Alignment`.
  - `style` (atom) -- named style. Currently only `:default`.
  - `disabled` (boolean) -- when true, the toggler cannot be toggled. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.

  ## Events

  - `%Widget{type: :toggle, id: id, value: bool}` -- emitted on toggle, `value` is the new boolean state.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.StyleMap
  alias Toddy.Iced.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:label, String.t()}
          | {:spacing, number()}
          | {:width, Toddy.Iced.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Toddy.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:text_shaping, Toddy.Iced.Shaping.t()}
          | {:wrapping, Toddy.Iced.Wrapping.t()}
          | {:text_alignment, Toddy.Iced.Alignment.t()}
          | {:style, style()}
          | {:disabled, boolean()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          is_toggled: boolean(),
          label: String.t() | nil,
          spacing: number() | nil,
          width: Toddy.Iced.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Toddy.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          text_shaping: Toddy.Iced.Shaping.t() | nil,
          wrapping: Toddy.Iced.Wrapping.t() | nil,
          text_alignment: Toddy.Iced.Alignment.t() | nil,
          style: style() | nil,
          disabled: boolean() | nil,
          a11y: Toddy.Iced.A11y.t() | nil
        }

  defstruct [
    :id,
    :is_toggled,
    :label,
    :spacing,
    :width,
    :size,
    :text_size,
    :font,
    :line_height,
    :text_shaping,
    :wrapping,
    :text_alignment,
    :style,
    :disabled,
    :a11y
  ]

  @doc "Creates a new toggler struct with the given toggle state and optional keyword opts."
  @spec new(id :: String.t(), is_toggled :: boolean(), opts :: [option()]) :: t()
  def new(id, is_toggled, opts \\ []) when is_binary(id) and is_boolean(is_toggled) do
    %__MODULE__{id: id, is_toggled: is_toggled} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing toggler struct."
  @spec with_options(toggler :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = tg, []), do: tg

  def with_options(%__MODULE__{} = tg, opts) do
    Enum.reduce(opts, tg, fn
      {:label, v}, acc -> label(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:text_size, v}, acc -> text_size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:text_shaping, v}, acc -> text_shaping(acc, v)
      {:wrapping, v}, acc -> wrapping(acc, v)
      {:text_alignment, v}, acc -> text_alignment(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the toggler label."
  @spec label(toggler :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = tg, label) when is_binary(label), do: %{tg | label: label}

  @doc "Sets the spacing between toggler and label."
  @spec spacing(toggler :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = tg, spacing) when is_number(spacing), do: %{tg | spacing: spacing}

  @doc "Sets the toggler width."
  @spec width(toggler :: t(), width :: Toddy.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = tg, width), do: %{tg | width: width}

  @doc "Sets the toggler size in pixels."
  @spec size(toggler :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = tg, size) when is_number(size), do: %{tg | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(toggler :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = tg, text_size) when is_number(text_size),
    do: %{tg | text_size: text_size}

  @doc "Sets the label font."
  @spec font(toggler :: t(), font :: Toddy.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = tg, font), do: %{tg | font: font}

  @doc "Sets the label line height."
  @spec line_height(toggler :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = tg, line_height), do: %{tg | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(toggler :: t(), text_shaping :: Toddy.Iced.Shaping.t()) :: t()
  def text_shaping(%__MODULE__{} = tg, text_shaping), do: %{tg | text_shaping: text_shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(toggler :: t(), wrapping :: Toddy.Iced.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = tg, wrapping), do: %{tg | wrapping: wrapping}

  @doc "Sets the horizontal label text alignment."
  @spec text_alignment(toggler :: t(), text_alignment :: Toddy.Iced.Alignment.t()) :: t()
  def text_alignment(%__MODULE__{} = tg, text_alignment),
    do: %{tg | text_alignment: text_alignment}

  @doc "Sets the toggler style."
  @spec style(toggler :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = tg, %StyleMap{} = style), do: %{tg | style: style}
  def style(%__MODULE__{} = tg, :default), do: %{tg | style: :default}

  @doc "Sets whether the toggler is disabled."
  @spec disabled(toggler :: t(), disabled :: boolean()) :: t()
  def disabled(%__MODULE__{} = tg, disabled) when is_boolean(disabled),
    do: %{tg | disabled: disabled}

  @doc "Sets accessibility annotations."
  @spec a11y(toggler :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = tg, a11y), do: %{tg | a11y: A11y.cast(a11y)}

  @doc "Converts this toggler struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(toggler :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = tg), do: Toddy.Iced.Widget.to_node(tg)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(tg) do
      props =
        %{}
        |> put_if(tg.is_toggled, "is_toggled")
        |> put_if(tg.label, "label")
        |> put_if(tg.spacing, "spacing")
        |> put_if(tg.width, "width")
        |> put_if(tg.size, "size")
        |> put_if(tg.text_size, "text_size")
        |> put_if(tg.font, "font")
        |> put_if(tg.line_height, "line_height")
        |> put_if(tg.text_shaping, "text_shaping")
        |> put_if(tg.wrapping, "wrapping")
        |> put_if(tg.text_alignment, "text_alignment")
        |> put_if(tg.style, "style")
        |> put_if(tg.disabled, "disabled")
        |> put_if(tg.a11y, "a11y")

      %{id: tg.id, type: "toggler", props: props, children: []}
    end
  end
end
