defmodule Julep.Iced.Widget.TextInput do
  @moduledoc """
  Text input field -- single-line editable text.

  Emits `{:input, id, value}` on every keystroke.

  ## Props

  - `value` (string) -- current text content. Required for controlled input.
  - `placeholder` (string) -- placeholder text shown when value is empty.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `width` (length) -- input width. Default: fill. See `Julep.Iced.Length`.
  - `size` (number) -- font size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- line height. Number is a relative multiplier;
    map with `%{relative: n}` or `%{absolute: n}` for explicit control.
  - `align_x` (string) -- text horizontal alignment: `"left"`, `"center"`, `"right"`.
  - `on_submit` (any) -- when present (any truthy value), enables submit on Enter.
    Emits `{:submit, id, value}`.
  - `id` (string) -- widget ID for programmatic focus via `Julep.Command.focus/1`.
  - `style` (string) -- named style. Currently only `"default"`.
  - `icon` (map) -- display an icon inside the input field. Map with keys:
    - `code_point` (string) -- single character to render as the icon. Required.
    - `size` (number) -- icon font size in pixels. Optional.
    - `spacing` (number) -- pixels between icon and text. Default: 4.0.
    - `side` (string) -- `"left"` or `"right"`. Default: `"left"`.
    - `font` (string | map) -- icon font. Default: system default.
  - `on_paste` (boolean) -- when true, emits `{:paste, id, text}` when user
    pastes text. Default: false.
  - `secure` (boolean) -- mask input as password dots. Default: false.

  ## Events

  - `{:input, id, value}` -- emitted on every text change.
  - `{:submit, id, value}` -- emitted on Enter (requires `on_submit` prop).
  - `{:paste, id, text}` -- emitted on paste (requires `on_paste` prop).
  """

  alias Julep.Iced.StyleMap
  alias Julep.Iced.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:placeholder, String.t()}
          | {:padding, Julep.Iced.Padding.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:align_x, Julep.Iced.Alignment.t()}
          | {:icon, map()}
          | {:on_submit, boolean()}
          | {:on_paste, boolean()}
          | {:secure, boolean()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          value: String.t(),
          placeholder: String.t() | nil,
          padding: Julep.Iced.Padding.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          align_x: Julep.Iced.Alignment.t() | nil,
          icon: map() | nil,
          on_submit: boolean() | nil,
          on_paste: boolean() | nil,
          secure: boolean() | nil,
          style: style() | nil
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
    :style
  ]

  @doc "Creates a new text input struct with the given value and optional keyword opts."
  @spec new(id :: String.t(), value :: String.t(), opts :: [option()]) :: t()
  def new(id, value, opts \\ []) when is_binary(value) do
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
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the placeholder text."
  @spec placeholder(text_input :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = ti, placeholder), do: %{ti | placeholder: placeholder}

  @doc "Sets the internal padding."
  @spec padding(text_input :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = ti, padding), do: %{ti | padding: padding}

  @doc "Sets the input width."
  @spec width(text_input :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = ti, width), do: %{ti | width: width}

  @doc "Sets the font size in pixels."
  @spec size(text_input :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = ti, size), do: %{ti | size: size}

  @doc "Sets the font."
  @spec font(text_input :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = ti, font), do: %{ti | font: font}

  @doc "Sets the line height."
  @spec line_height(text_input :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = ti, line_height), do: %{ti | line_height: line_height}

  @doc "Sets the horizontal text alignment."
  @spec align_x(text_input :: t(), align_x :: Julep.Iced.Alignment.t()) :: t()
  def align_x(%__MODULE__{} = ti, align_x), do: %{ti | align_x: align_x}

  @doc "Sets the icon displayed inside the input field."
  @spec icon(text_input :: t(), icon :: map()) :: t()
  def icon(%__MODULE__{} = ti, icon) when is_map(icon), do: %{ti | icon: icon}

  @doc "Enables or disables submit on Enter."
  @spec on_submit(text_input :: t(), on_submit :: boolean()) :: t()
  def on_submit(%__MODULE__{} = ti, on_submit), do: %{ti | on_submit: on_submit}

  @doc "Enables or disables paste event emission."
  @spec on_paste(text_input :: t(), on_paste :: boolean()) :: t()
  def on_paste(%__MODULE__{} = ti, on_paste), do: %{ti | on_paste: on_paste}

  @doc "Sets whether input is masked as a password."
  @spec secure(text_input :: t(), secure :: boolean()) :: t()
  def secure(%__MODULE__{} = ti, secure), do: %{ti | secure: secure}

  @doc "Sets the input style."
  @spec style(text_input :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = ti, style), do: %{ti | style: style}

  @doc "Converts this text input struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(text_input :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = ti), do: Julep.Iced.Widget.to_node(ti)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(ti) do
      props =
        %{}
        |> put_if(ti.value, "value")
        |> put_if(ti.placeholder, "placeholder")
        |> put_if(ti.padding, "padding")
        |> put_if(ti.width, "width")
        |> put_if(ti.size, "size")
        |> put_if(ti.font, "font")
        |> put_if(ti.line_height, "line_height")
        |> put_if(ti.align_x, "align_x")
        |> put_if(ti.icon, "icon")
        |> put_if(ti.on_submit, "on_submit")
        |> put_if(ti.on_paste, "on_paste")
        |> put_if(ti.secure, "secure")
        |> put_if(ti.style, "style")

      %{id: ti.id, type: "text_input", props: props, children: []}
    end
  end
end
