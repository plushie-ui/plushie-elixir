defmodule Plushie.Widget.Toggler do
  @moduledoc """
  Toggler -- on/off switch.

  ## Props

  - `is_toggled` (boolean) -- whether the toggler is on. Default: false.
  - `label` (string) -- text label displayed next to the toggler.
  - `spacing` (number) -- space between toggler and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `size` (number) -- toggler size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- label line height.
  - `shaping` (atom) -- text shaping: `:basic`, `:advanced`, or `:auto`.
    See `Plushie.Type.Shaping`.
  - `wrapping` (atom) -- text wrapping: `:none`, `:word`, `:glyph`, `:word_or_glyph`.
    See `Plushie.Type.Wrapping`.
  - `text_alignment` (atom) -- horizontal label alignment: `:left`, `:center`, `:right`.
    See `Plushie.Type.Alignment`.
  - `style` (atom) -- named style. Currently only `:default`.
  - `disabled` (boolean) -- when true, the toggler cannot be toggled. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%Widget{type: :toggle, id: id, value: bool}` -- emitted on toggle, `value` is the new boolean state.
  """

  alias Plushie.Type.A11y
  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:label, String.t()}
          | {:spacing, number()}
          | {:width, Plushie.Type.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:line_height, number() | map()}
          | {:shaping, Plushie.Type.Shaping.t()}
          | {:wrapping, Plushie.Type.Wrapping.t()}
          | {:text_alignment, Plushie.Type.Alignment.t()}
          | {:style, style()}
          | {:disabled, boolean()}
          | {:a11y, Plushie.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          is_toggled: boolean(),
          label: String.t() | nil,
          spacing: number() | nil,
          width: Plushie.Type.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          line_height: number() | map() | nil,
          shaping: Plushie.Type.Shaping.t() | nil,
          wrapping: Plushie.Type.Wrapping.t() | nil,
          text_alignment: Plushie.Type.Alignment.t() | nil,
          style: style() | nil,
          disabled: boolean() | nil,
          a11y: Plushie.Type.A11y.t() | nil
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
    :shaping,
    :wrapping,
    :text_alignment,
    :style,
    :disabled,
    :a11y
  ]

  @valid_option_keys ~w(label spacing width size text_size font line_height shaping wrapping text_alignment style disabled a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

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
      {:shaping, v}, acc -> shaping(acc, v)
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
  @spec width(toggler :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = tg, width), do: %{tg | width: width}

  @doc "Sets the toggler size in pixels."
  @spec size(toggler :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = tg, size) when is_number(size), do: %{tg | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(toggler :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = tg, text_size) when is_number(text_size),
    do: %{tg | text_size: text_size}

  @doc "Sets the label font."
  @spec font(toggler :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = tg, font), do: %{tg | font: font}

  @doc "Sets the label line height."
  @spec line_height(toggler :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = tg, line_height), do: %{tg | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec shaping(toggler :: t(), shaping :: Plushie.Type.Shaping.t()) :: t()
  def shaping(%__MODULE__{} = tg, shaping), do: %{tg | shaping: shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(toggler :: t(), wrapping :: Plushie.Type.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = tg, wrapping), do: %{tg | wrapping: wrapping}

  @doc "Sets the horizontal label text alignment."
  @spec text_alignment(toggler :: t(), text_alignment :: Plushie.Type.Alignment.t()) :: t()
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
  @spec a11y(toggler :: t(), a11y :: Plushie.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = tg, a11y), do: %{tg | a11y: A11y.cast(a11y)}

  @doc "Converts this toggler struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(toggler :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = tg), do: Plushie.Widget.to_node(tg)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(tg) do
      props =
        %{}
        |> put_if(tg.is_toggled, :is_toggled)
        |> put_if(tg.label, :label)
        |> put_if(tg.spacing, :spacing)
        |> put_if(tg.width, :width)
        |> put_if(tg.size, :size)
        |> put_if(tg.text_size, :text_size)
        |> put_if(tg.font, :font)
        |> put_if(tg.line_height, :line_height)
        |> put_if(tg.shaping, :shaping)
        |> put_if(tg.wrapping, :wrapping)
        |> put_if(tg.text_alignment, :text_alignment)
        |> put_if(tg.style, :style)
        |> put_if(tg.disabled, :disabled)
        |> put_if(tg.a11y, :a11y)

      %{id: tg.id, type: "toggler", props: props, children: []}
    end
  end
end
