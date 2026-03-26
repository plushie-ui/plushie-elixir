defmodule Plushie.Widget.Button do
  @moduledoc """
  Button -- clickable widget that emits `%WidgetEvent{type: :click, id: id}` events.

  The button can contain either a text label (via the `label` or `content` prop)
  or arbitrary child content (if children are provided, the first child is rendered).

  ## Props

  - `label` (string) -- text label displayed on the button. Also accepts `content` as an alias.
  - `style` -- named preset atom (`:primary` (default), `:secondary`, `:success`,
    `:warning`, `:danger`, `:text`, `:background`, `:subtle`) or `StyleMap.t()`
    for custom styling. See `Plushie.Type.StyleMap`.
  - `width` (length) -- button width. Default: shrink. See `Plushie.Type.Length`.
  - `height` (length) -- button height. Default: shrink.
  - `padding` (number | map) -- internal padding. See `Plushie.Type.Padding`.
  - `clip` (boolean) -- clip child content that overflows. Default: false.
  - `disabled` (boolean) -- disable the button (no click events). Default: false.
  - `enabled` (boolean) -- inverse of disabled. Default: true.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :click, id: id}` -- emitted on press (unless disabled).
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @presets [:primary, :secondary, :success, :warning, :danger, :text, :background, :subtle]

  @type preset :: unquote(Enum.reduce(@presets, &{:|, [], [&1, &2]}))
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:width, Plushie.Type.Length.t()}
          | {:height, Plushie.Type.Length.t()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:clip, boolean()}
          | {:style, style()}
          | {:disabled, boolean()}
          | {:enabled, boolean()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          label: String.t(),
          width: Plushie.Type.Length.t() | nil,
          height: Plushie.Type.Length.t() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          clip: boolean() | nil,
          style: style() | nil,
          disabled: boolean() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [:id, :label, :width, :height, :padding, :clip, :style, :disabled, :a11y]

  @valid_option_keys ~w(width height padding clip style disabled enabled a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Plushie.Type.Padding, style: Plushie.Type.StyleMap, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new button struct with the given label and optional keyword opts."
  @spec new(id :: String.t(), label :: String.t(), opts :: [option()]) :: t()
  def new(id, label, opts \\ []) when is_binary(id) and is_binary(label) do
    %__MODULE__{id: id, label: label} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing button struct."
  @spec with_options(button :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = btn, []), do: btn

  def with_options(%__MODULE__{} = btn, opts) do
    Enum.reduce(opts, btn, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:clip, v}, acc -> clip(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:disabled, v}, acc -> disabled(acc, v)
      {:enabled, v}, acc -> disabled(acc, !v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the button width."
  @spec width(button :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = btn, width), do: %{btn | width: width}

  @doc "Sets the button height."
  @spec height(button :: t(), height :: Plushie.Type.Length.t()) :: t()
  def height(%__MODULE__{} = btn, height), do: %{btn | height: height}

  @doc "Sets the button padding."
  @spec padding(button :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = btn, padding), do: %{btn | padding: padding}

  @doc "Sets whether child content is clipped on overflow."
  @spec clip(button :: t(), clip :: boolean()) :: t()
  def clip(%__MODULE__{} = btn, clip) when is_boolean(clip), do: %{btn | clip: clip}

  @doc "Sets the button style. Accepts a preset atom or `StyleMap`."
  @spec style(button :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = btn, %StyleMap{} = style), do: %{btn | style: style}
  def style(%__MODULE__{} = btn, style) when style in @presets, do: %{btn | style: style}

  @doc "Sets whether the button is disabled."
  @spec disabled(button :: t(), disabled :: boolean()) :: t()
  def disabled(%__MODULE__{} = btn, disabled) when is_boolean(disabled),
    do: %{btn | disabled: disabled}

  @doc "Sets accessibility annotations."
  @spec a11y(button :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = btn, a11y), do: %{btn | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this button struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(button :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = btn), do: Plushie.Widget.to_node(btn)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(btn) do
      props =
        %{}
        |> put_if(btn.label, :label)
        |> put_if(btn.width, :width)
        |> put_if(btn.height, :height)
        |> put_if(btn.padding, :padding)
        |> put_if(btn.clip, :clip)
        |> put_if(btn.style, :style)
        |> put_if(btn.disabled, :disabled)
        |> put_if(btn.a11y, :a11y)

      %{id: btn.id, type: "button", props: props, children: []}
    end
  end
end
