defmodule Julep.Iced.Widget.Toggler do
  @moduledoc """
  Toggler -- on/off switch.

  ## Props

  - `is_toggled` (boolean) -- whether the toggler is on. Default: false.
  - `label` (string) -- text label displayed next to the toggler.
  - `spacing` (number) -- space between toggler and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `size` (number) -- toggler size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `wrapping` (string) -- text wrapping: `"none"`, `"word"`, `"glyph"`, `"word_or_glyph"`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:toggle, id, value}` -- emitted on toggle, `value` is the new boolean state.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:label, String.t()}
          | {:spacing, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:text_shaping, atom()}
          | {:wrapping, atom()}
          | {:style, atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          is_toggled: boolean(),
          label: String.t() | nil,
          spacing: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          text_shaping: atom() | nil,
          wrapping: atom() | nil,
          style: atom() | nil
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
    :style
  ]

  @doc "Creates a new toggler struct with the given toggle state and optional keyword opts."
  @spec new(id :: String.t(), is_toggled :: boolean(), opts :: [option()]) :: t()
  def new(id, is_toggled, opts \\ []) when is_boolean(is_toggled) do
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
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the toggler label."
  @spec label(toggler :: t(), label :: String.t()) :: t()
  def label(%__MODULE__{} = tg, label), do: %{tg | label: label}

  @doc "Sets the spacing between toggler and label."
  @spec spacing(toggler :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = tg, spacing), do: %{tg | spacing: spacing}

  @doc "Sets the toggler width."
  @spec width(toggler :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = tg, width), do: %{tg | width: width}

  @doc "Sets the toggler size in pixels."
  @spec size(toggler :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = tg, size), do: %{tg | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(toggler :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = tg, text_size), do: %{tg | text_size: text_size}

  @doc "Sets the label font."
  @spec font(toggler :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = tg, font), do: %{tg | font: font}

  @doc "Sets the label line height."
  @spec line_height(toggler :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = tg, line_height), do: %{tg | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(toggler :: t(), text_shaping :: atom()) :: t()
  def text_shaping(%__MODULE__{} = tg, text_shaping), do: %{tg | text_shaping: text_shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(toggler :: t(), wrapping :: atom()) :: t()
  def wrapping(%__MODULE__{} = tg, wrapping), do: %{tg | wrapping: wrapping}

  @doc "Sets the toggler style."
  @spec style(toggler :: t(), style :: atom()) :: t()
  def style(%__MODULE__{} = tg, style), do: %{tg | style: style}

  @doc "Converts this toggler struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(toggler :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = tg), do: Julep.Iced.Widget.to_node(tg)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

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
        |> put_if(tg.text_shaping, "text_shaping", &to_string/1)
        |> put_if(tg.wrapping, "wrapping", &to_string/1)
        |> put_if(tg.style, "style", &to_string/1)

      %{id: tg.id, type: "toggler", props: props, children: []}
    end
  end
end
