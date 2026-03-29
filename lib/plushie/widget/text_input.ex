defmodule Plushie.Widget.TextInput do
  @moduledoc """
  Text input field -- single-line editable text.

  Emits `%WidgetEvent{type: :input, id: id, value: value}` on every keystroke.

  ## Props

  - `value` (string) -- current text content. Required for controlled input.
  - `placeholder` (string) -- placeholder text shown when value is empty.
  - `padding` (number | map) -- internal padding. See `Plushie.Type.Padding`.
  - `width` (length) -- input width. Default: fill. See `Plushie.Type.Length`.
  - `size` (number) -- font size in pixels.
  - `font` (string | map) -- font specification. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- line height. Number is a relative multiplier;
    map with `%{relative: n}` or `%{absolute: n}` for explicit control.
  - `align_x` (atom) -- text horizontal alignment: `:left`, `:center`, `:right`.
    See `Plushie.Type.Alignment`.
  - `on_submit` (any) -- when present (any truthy value), enables submit on Enter.
    Emits `%WidgetEvent{type: :submit, id: id, value: value}`.
  - `id` (string) -- widget ID for programmatic focus via `Plushie.Command.focus/1`.
  - `style` (atom) -- named style. Currently only `:default`.
  - `icon` (map) -- display an icon inside the input field. Map with keys:
    - `code_point` (string) -- single character to render as the icon. Required.
    - `size` (number) -- icon font size in pixels. Optional.
    - `spacing` (number) -- pixels between icon and text. Default: 4.0.
    - `side` (string) -- `"left"` or `"right"`. Default: `"left"`.
    - `font` (string | map) -- icon font. Default: system default.
  - `on_paste` (boolean) -- when true, emits `%WidgetEvent{type: :paste, id: id, value: text}` when user
    pastes text. Default: false.
  - `secure` (boolean) -- mask input as password dots. Default: false.
  - `ime_purpose` (string) -- IME input purpose hint: `"normal"`, `"secure"`, `"terminal"`.
    Overrides the default derived from `secure`. Default: nil (auto from `secure`).
  - `placeholder_color` (color) -- placeholder text color. See `Plushie.Type.Color`.
  - `selection_color` (color) -- text selection highlight color. See `Plushie.Type.Color`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :input, id: id, value: value}` -- emitted on every text change.
  - `%WidgetEvent{type: :submit, id: id, value: value}` -- emitted on Enter (requires `on_submit` prop).
  - `%WidgetEvent{type: :paste, id: id, value: text}` -- emitted on paste (requires `on_paste` prop).
  """

  alias Plushie.Type.Color
  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:placeholder, String.t()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:line_height, number() | map()}
          | {:align_x, Plushie.Type.Alignment.t()}
          | {:icon, map()}
          | {:on_submit, boolean()}
          | {:on_paste, boolean()}
          | {:secure, boolean()}
          | {:ime_purpose, String.t()}
          | {:style, style()}
          | {:placeholder_color, Plushie.Type.Color.input()}
          | {:selection_color, Plushie.Type.Color.input()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          value: String.t(),
          placeholder: String.t() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          line_height: number() | map() | nil,
          align_x: Plushie.Type.Alignment.t() | nil,
          icon: map() | nil,
          on_submit: boolean() | nil,
          on_paste: boolean() | nil,
          secure: boolean() | nil,
          ime_purpose: String.t() | nil,
          style: style() | nil,
          placeholder_color: Plushie.Type.Color.t() | nil,
          selection_color: Plushie.Type.Color.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :value,
    :placeholder,
    :padding,
    :width,
    :size,
    :font,
    :line_height,
    :align_x,
    :icon,
    :on_submit,
    :on_paste,
    :secure,
    :ime_purpose,
    :style,
    :placeholder_color,
    :selection_color,
    :a11y
  ]

  @valid_option_keys ~w(placeholder padding width size font line_height align_x icon on_submit on_paste secure ime_purpose style placeholder_color selection_color a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Plushie.Type.Padding, font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new text input struct with the given value and optional keyword opts."
  @spec new(id :: String.t(), value :: String.t(), opts :: [option()]) :: t()
  def new(id, value, opts \\ []) when is_binary(id) and is_binary(value) do
    %__MODULE__{id: id, value: value} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing text input struct."
  @spec with_options(text_input :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = ti, []), do: ti

  def with_options(%__MODULE__{} = ti, opts) do
    Enum.reduce(opts, ti, fn
      {:placeholder, v}, acc -> placeholder(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:align_x, v}, acc -> align_x(acc, v)
      {:icon, v}, acc -> icon(acc, v)
      {:on_submit, v}, acc -> on_submit(acc, v)
      {:on_paste, v}, acc -> on_paste(acc, v)
      {:secure, v}, acc -> secure(acc, v)
      {:ime_purpose, v}, acc -> ime_purpose(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:placeholder_color, v}, acc -> placeholder_color(acc, v)
      {:selection_color, v}, acc -> selection_color(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the placeholder text."
  @spec placeholder(text_input :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = ti, placeholder) when is_binary(placeholder),
    do: %{ti | placeholder: placeholder}

  @doc "Sets the internal padding."
  @spec padding(text_input :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = ti, padding), do: %{ti | padding: padding}

  @doc "Sets the input width."
  @spec width(text_input :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = ti, width), do: %{ti | width: width}

  @doc "Sets the font size in pixels."
  @spec size(text_input :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = ti, size) when is_number(size), do: %{ti | size: size}

  @doc "Sets the font."
  @spec font(text_input :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = ti, font), do: %{ti | font: font}

  @doc "Sets the line height."
  @spec line_height(text_input :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = ti, line_height), do: %{ti | line_height: line_height}

  @doc "Sets the horizontal text alignment."
  @spec align_x(text_input :: t(), align_x :: Plushie.Type.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = ti, align_x), do: %{ti | align_x: align_x}

  @doc "Sets the icon displayed inside the input field."
  @spec icon(text_input :: t(), icon :: map()) :: t()
  def icon(%__MODULE__{} = ti, icon) when is_map(icon), do: %{ti | icon: icon}

  @doc "Enables or disables submit on Enter."
  @spec on_submit(text_input :: t(), on_submit :: boolean()) :: t()
  def on_submit(%__MODULE__{} = ti, on_submit) when is_boolean(on_submit),
    do: %{ti | on_submit: on_submit}

  @doc "Enables or disables paste event emission."
  @spec on_paste(text_input :: t(), on_paste :: boolean()) :: t()
  def on_paste(%__MODULE__{} = ti, on_paste) when is_boolean(on_paste),
    do: %{ti | on_paste: on_paste}

  @doc "Sets whether input is masked as a password."
  @spec secure(text_input :: t(), secure :: boolean()) :: t()
  def secure(%__MODULE__{} = ti, secure) when is_boolean(secure), do: %{ti | secure: secure}

  @doc "Sets the IME input purpose hint. Overrides the default derived from `secure`."
  @spec ime_purpose(text_input :: t(), ime_purpose :: String.t()) :: t()
  def ime_purpose(%__MODULE__{} = ti, ime_purpose) when ime_purpose in ~w(normal secure terminal),
    do: %{ti | ime_purpose: ime_purpose}

  @doc "Sets the input style."
  @spec style(text_input :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = ti, %StyleMap{} = style), do: %{ti | style: style}
  def style(%__MODULE__{} = ti, :default), do: %{ti | style: :default}

  @doc "Sets the placeholder text color. Accepts any form `Color.cast/1` supports."
  @spec placeholder_color(text_input :: t(), color :: Plushie.Type.Color.input()) :: t()
  def placeholder_color(%__MODULE__{} = ti, color),
    do: %{ti | placeholder_color: Color.cast(color)}

  @doc "Sets the text selection highlight color. Accepts any form `Color.cast/1` supports."
  @spec selection_color(text_input :: t(), color :: Plushie.Type.Color.input()) :: t()
  def selection_color(%__MODULE__{} = ti, color),
    do: %{ti | selection_color: Color.cast(color)}

  @doc "Sets accessibility annotations."
  @spec a11y(text_input :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = ti, a11y), do: %{ti | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this text input struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(text_input :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = ti), do: Plushie.Widget.to_node(ti)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(ti) do
      props =
        %{}
        |> put_if(ti.value, :value)
        |> put_if(ti.placeholder, :placeholder)
        |> put_if(ti.padding, :padding)
        |> put_if(ti.width, :width)
        |> put_if(ti.size, :size)
        |> put_if(ti.font, :font)
        |> put_if(ti.line_height, :line_height)
        |> put_if(ti.align_x, :align_x)
        |> put_if(ti.icon, :icon)
        |> put_if(ti.on_submit, :on_submit)
        |> put_if(ti.on_paste, :on_paste)
        |> put_if(ti.secure, :secure)
        |> put_if(ti.ime_purpose, :ime_purpose)
        |> put_if(ti.style, :style)
        |> put_if(ti.placeholder_color, :placeholder_color)
        |> put_if(ti.selection_color, :selection_color)
        |> put_if(ti.a11y, :a11y)

      %{id: ti.id, type: "text_input", props: props, children: []}
    end
  end
end
