defmodule Plushie.Widget.ComboBox do
  @moduledoc """
  Combo box -- searchable dropdown with free-form text input.

  The renderer manages an internal `combo_box::State` cache keyed by node ID.
  Options changes trigger a state rebuild.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value. Also accepts
    `:value` as an alias.
  - `placeholder` (string) -- placeholder text.
  - `width` (length) -- widget width. Default: fill. See `Plushie.Type.Length`.
  - `padding` (number | map) -- internal padding. See `Plushie.Type.Padding`.
  - `size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.
  - `icon` (map) -- display an icon inside the text input. Same format as
    `Plushie.Widget.TextInput` icon prop.
  - `on_option_hovered` (boolean) -- when true, emits `%Widget{type: :option_hovered, id: id, value: value}`
    when hovering over a dropdown option. Default: false.
  - `shaping` -- text shaping strategy. See `Plushie.Type.Shaping`.
  - `ellipsis` (string) -- text ellipsis strategy: `"none"`, `"start"`, `"middle"`, or `"end"`.
    Default: `"end"`.
  - `menu_style` (map) -- inline style for the dropdown menu. Map with optional keys:
    `background`, `text_color`, `selected_text_color`, `selected_background`, `border`, `shadow`.
  - `style` -- named preset atom (`:default`) or `StyleMap.t()` for custom styling.
    See `Plushie.Type.StyleMap`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%Widget{type: :select, id: id, value: value}` -- emitted when an option is selected.
  - `%Widget{type: :input, id: id, value: value}` -- emitted on every text input change (for filtering).
  - `%Widget{type: :option_hovered, id: id, value: value}` -- emitted on hover (requires `on_option_hovered` prop).
  - `%Widget{type: :open, id: id}` -- emitted when the dropdown menu is opened (requires `on_open: true`).
  - `%Widget{type: :close, id: id}` -- emitted when the dropdown menu is closed (requires `on_close: true`).
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:selected, String.t()}
          | {:value, String.t()}
          | {:placeholder, String.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:line_height, number() | map()}
          | {:menu_height, number()}
          | {:icon, map()}
          | {:on_option_hovered, boolean()}
          | {:on_open, boolean()}
          | {:on_close, boolean()}
          | {:shaping, Plushie.Type.Shaping.t()}
          | {:ellipsis, String.t()}
          | {:menu_style, map()}
          | {:style, style()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          options: [String.t()],
          selected: String.t() | nil,
          placeholder: String.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          line_height: number() | map() | nil,
          menu_height: number() | nil,
          icon: map() | nil,
          on_option_hovered: boolean() | nil,
          on_open: boolean() | nil,
          on_close: boolean() | nil,
          shaping: Plushie.Type.Shaping.t() | nil,
          ellipsis: String.t() | nil,
          menu_style: map() | nil,
          style: style() | nil,
          a11y: Plushie.Type.A11y.t() | nil
        }

  defstruct [
    :id,
    :options,
    :selected,
    :placeholder,
    :width,
    :padding,
    :size,
    :font,
    :line_height,
    :menu_height,
    :icon,
    :on_option_hovered,
    :on_open,
    :on_close,
    :shaping,
    :ellipsis,
    :menu_style,
    :style,
    :a11y
  ]

  @valid_option_keys ~w(selected value placeholder width padding size font line_height menu_height icon on_option_hovered on_open on_close shaping ellipsis menu_style style a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{padding: Plushie.Type.Padding, font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new combo box struct with the given options and optional keyword opts."
  @spec new(id :: String.t(), options :: [String.t()], opts :: [option()]) :: t()
  def new(id, options, opts \\ []) when is_binary(id) and is_list(options) do
    %__MODULE__{id: id, options: options} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing combo box struct."
  @spec with_options(combo_box :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = cb, []), do: cb

  def with_options(%__MODULE__{} = cb, opts) do
    Enum.reduce(opts, cb, fn
      {:selected, v}, acc -> selected(acc, v)
      {:value, v}, acc -> selected(acc, v)
      {:placeholder, v}, acc -> placeholder(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:menu_height, v}, acc -> menu_height(acc, v)
      {:icon, v}, acc -> icon(acc, v)
      {:on_option_hovered, v}, acc -> on_option_hovered(acc, v)
      {:on_open, v}, acc -> on_open(acc, v)
      {:on_close, v}, acc -> on_close(acc, v)
      {:shaping, v}, acc -> shaping(acc, v)
      {:ellipsis, v}, acc -> ellipsis(acc, v)
      {:menu_style, v}, acc -> menu_style(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the currently selected value."
  @spec selected(combo_box :: t(), selected :: String.t()) :: t()
  def selected(%__MODULE__{} = cb, selected), do: %{cb | selected: selected}

  @doc "Sets the placeholder text."
  @spec placeholder(combo_box :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = cb, placeholder), do: %{cb | placeholder: placeholder}

  @doc "Sets the combo box width."
  @spec width(combo_box :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = cb, width), do: %{cb | width: width}

  @doc "Sets the internal padding."
  @spec padding(combo_box :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = cb, padding), do: %{cb | padding: padding}

  @doc "Sets the text size in pixels."
  @spec size(combo_box :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = cb, size) when is_number(size), do: %{cb | size: size}

  @doc "Sets the font."
  @spec font(combo_box :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = cb, font), do: %{cb | font: font}

  @doc "Sets the text line height."
  @spec line_height(combo_box :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = cb, line_height), do: %{cb | line_height: line_height}

  @doc "Sets the maximum dropdown menu height in pixels."
  @spec menu_height(combo_box :: t(), menu_height :: number()) :: t()
  def menu_height(%__MODULE__{} = cb, menu_height) when is_number(menu_height),
    do: %{cb | menu_height: menu_height}

  @doc "Sets the icon displayed inside the text input."
  @spec icon(combo_box :: t(), icon :: map()) :: t()
  def icon(%__MODULE__{} = cb, icon) when is_map(icon), do: %{cb | icon: icon}

  @doc "Enables or disables option hover event emission."
  @spec on_option_hovered(combo_box :: t(), on_option_hovered :: boolean()) :: t()
  def on_option_hovered(%__MODULE__{} = cb, v) when is_boolean(v),
    do: %{cb | on_option_hovered: v}

  @doc "Enables or disables the open event when the dropdown menu opens."
  @spec on_open(combo_box :: t(), on_open :: boolean()) :: t()
  def on_open(%__MODULE__{} = cb, v) when is_boolean(v), do: %{cb | on_open: v}

  @doc "Enables or disables the close event when the dropdown menu closes."
  @spec on_close(combo_box :: t(), on_close :: boolean()) :: t()
  def on_close(%__MODULE__{} = cb, v) when is_boolean(v), do: %{cb | on_close: v}

  @doc "Sets the text shaping strategy."
  @spec shaping(combo_box :: t(), shaping :: Plushie.Type.Shaping.t()) :: t()
  def shaping(%__MODULE__{} = cb, shaping), do: %{cb | shaping: shaping}

  @doc "Sets the text ellipsis strategy."
  @spec ellipsis(combo_box :: t(), ellipsis :: String.t()) :: t()
  def ellipsis(%__MODULE__{} = cb, ellipsis), do: %{cb | ellipsis: ellipsis}

  @doc "Sets the dropdown menu style overrides."
  @spec menu_style(combo_box :: t(), menu_style :: map()) :: t()
  def menu_style(%__MODULE__{} = cb, menu_style) when is_map(menu_style),
    do: %{cb | menu_style: menu_style}

  @doc "Sets the combo box style. Accepts `:default` or a `StyleMap`."
  @spec style(combo_box :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = cb, %StyleMap{} = style), do: %{cb | style: style}
  def style(%__MODULE__{} = cb, :default), do: %{cb | style: :default}

  @doc "Sets accessibility annotations."
  @spec a11y(combo_box :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = cb, a11y), do: %{cb | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this combo box struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(combo_box :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = cb), do: Plushie.Widget.to_node(cb)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(cb) do
      props =
        %{}
        |> put_if(cb.options, :options)
        |> put_if(cb.selected, :selected)
        |> put_if(cb.placeholder, :placeholder)
        |> put_if(cb.width, :width)
        |> put_if(cb.padding, :padding)
        |> put_if(cb.size, :size)
        |> put_if(cb.font, :font)
        |> put_if(cb.line_height, :line_height)
        |> put_if(cb.menu_height, :menu_height)
        |> put_if(cb.icon, :icon)
        |> put_if(cb.on_option_hovered, :on_option_hovered)
        |> put_if(cb.on_open, :on_open)
        |> put_if(cb.on_close, :on_close)
        |> put_if(cb.shaping, :shaping)
        |> put_if(cb.ellipsis, :ellipsis)
        |> put_if(cb.menu_style, :menu_style)
        |> put_if(cb.style, :style)
        |> put_if(cb.a11y, :a11y)

      %{id: cb.id, type: "combo_box", props: props, children: []}
    end
  end
end
