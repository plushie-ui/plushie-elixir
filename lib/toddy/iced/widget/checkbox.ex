defmodule Toddy.Iced.Widget.Checkbox do
  @moduledoc """
  Checkbox -- toggleable boolean input.

  ## Props

  - `checked` (boolean) -- whether the checkbox is checked. Default: false.
  - `label` (string) -- text label displayed next to the checkbox.
  - `spacing` (number) -- space between checkbox and label in pixels.
  - `width` (length) -- widget width. Default: shrink. See `Toddy.Iced.Length`.
  - `size` (number) -- checkbox size in pixels.
  - `text_size` (number) -- label text size in pixels.
  - `font` (string | map) -- label font. See `Toddy.Iced.Font`.
  - `line_height` (number | map) -- label line height.
  - `text_shaping` -- text shaping strategy. See `Toddy.Iced.Shaping`.
  - `wrapping` -- text wrapping mode. See `Toddy.Iced.Wrapping`.
  - `style` -- named preset (`:primary` (default), `:secondary`, `:success`,
    `:danger`) or `StyleMap.t()`. See `Toddy.Iced.StyleMap`.
  - `icon` (map) -- custom icon for the check mark. Map with `:code_point` (required),
    and optional `:size`, `:line_height`, `:font`, `:shaping`.
  - `disabled` (boolean) -- when true, the checkbox cannot be toggled. Default: false.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.

  ## Events

  - `%Widget{type: :toggle, id: id, value: bool}` -- emitted on toggle, `value` is the new boolean state.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.StyleMap
  alias Toddy.Iced.Widget.Build

  @presets [:primary, :secondary, :success, :danger]

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:spacing, number()}
          | {:width, Toddy.Iced.Length.t()}
          | {:size, number()}
          | {:text_size, number()}
          | {:font, Toddy.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:text_shaping, Toddy.Iced.Shaping.t()}
          | {:wrapping, Toddy.Iced.Wrapping.t()}
          | {:style, style()}
          | {:icon, map()}
          | {:disabled, boolean()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          is_toggled: boolean(),
          spacing: number() | nil,
          width: Toddy.Iced.Length.t() | nil,
          size: number() | nil,
          text_size: number() | nil,
          font: Toddy.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          text_shaping: Toddy.Iced.Shaping.t() | nil,
          wrapping: Toddy.Iced.Wrapping.t() | nil,
          style: style() | nil,
          icon: map() | nil,
          disabled: boolean() | nil,
          a11y: Toddy.Iced.A11y.t() | nil
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
    :icon,
    :disabled,
    :a11y
  ]

  @doc "Creates a new checkbox struct with the given label, toggle state, and optional keyword opts."
  @spec new(id :: String.t(), label :: String.t(), is_toggled :: boolean(), opts :: [option()]) ::
          t()
  def new(id, label, is_toggled, opts \\ [])
      when is_binary(id) and is_binary(label) and is_boolean(is_toggled) do
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
      {:icon, v}, acc -> icon(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the spacing between checkbox and label."
  @spec spacing(checkbox :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = cb, spacing) when is_number(spacing), do: %{cb | spacing: spacing}

  @doc "Sets the checkbox width."
  @spec width(checkbox :: t(), width :: Toddy.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = cb, width), do: %{cb | width: width}

  @doc "Sets the checkbox size in pixels."
  @spec size(checkbox :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = cb, size) when is_number(size), do: %{cb | size: size}

  @doc "Sets the label text size in pixels."
  @spec text_size(checkbox :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = cb, text_size) when is_number(text_size), do: %{cb | text_size: text_size}

  @doc "Sets the label font."
  @spec font(checkbox :: t(), font :: Toddy.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = cb, font), do: %{cb | font: font}

  @doc "Sets the label line height."
  @spec line_height(checkbox :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = cb, line_height), do: %{cb | line_height: line_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(checkbox :: t(), text_shaping :: Toddy.Iced.Shaping.t()) :: t()
  def text_shaping(%__MODULE__{} = cb, text_shaping), do: %{cb | text_shaping: text_shaping}

  @doc "Sets the text wrapping mode."
  @spec wrapping(checkbox :: t(), wrapping :: Toddy.Iced.Wrapping.t()) :: t()
  def wrapping(%__MODULE__{} = cb, wrapping), do: %{cb | wrapping: wrapping}

  @doc "Sets the checkbox style."
  @spec style(checkbox :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = cb, %StyleMap{} = style), do: %{cb | style: style}
  def style(%__MODULE__{} = cb, style) when style in @presets, do: %{cb | style: style}

  @doc "Sets a custom icon for the check mark."
  @spec icon(checkbox :: t(), icon :: map()) :: t()
  def icon(%__MODULE__{} = cb, icon) when is_map(icon), do: %{cb | icon: icon}

  @doc "Sets whether the checkbox is disabled."
  @spec disabled(checkbox :: t(), disabled :: boolean()) :: t()
  def disabled(%__MODULE__{} = cb, disabled) when is_boolean(disabled), do: %{cb | disabled: disabled}

  @doc "Sets accessibility annotations."
  @spec a11y(checkbox :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = cb, a11y), do: %{cb | a11y: A11y.cast(a11y)}

  @doc "Converts this checkbox struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(checkbox :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = cb), do: Toddy.Iced.Widget.to_node(cb)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

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
        |> put_if(cb.icon, "icon")
        |> put_if(cb.disabled, "disabled")
        |> put_if(cb.a11y, "a11y")

      %{id: cb.id, type: "checkbox", props: props, children: []}
    end
  end
end
