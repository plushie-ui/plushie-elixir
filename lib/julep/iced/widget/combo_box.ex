defmodule Julep.Iced.Widget.ComboBox do
  @moduledoc """
  Combo box -- searchable dropdown with free-form text input.

  The renderer manages an internal `combo_box::State` cache keyed by node ID.
  Options changes trigger a state rebuild.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value.
  - `placeholder` (string) -- placeholder text.
  - `width` (length) -- widget width. Default: fill. See `Julep.Iced.Length`.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.
  - `icon` (map) -- display an icon inside the text input. Same format as
    `Julep.Iced.Widget.TextInput` icon prop.
  - `on_option_hovered` (boolean) -- when true, emits `{:option_hovered, id, value}`
    when hovering over a dropdown option. Default: false.

  ## Events

  - `{:select, id, value}` -- emitted when an option is selected.
  - `{:input, id, value}` -- emitted on every text input change (for filtering).
  - `{:option_hovered, id, value}` -- emitted on hover (requires `on_option_hovered` prop).
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:selected, String.t()}
          | {:placeholder, String.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:padding, Julep.Iced.Padding.t()}
          | {:size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:menu_height, number()}
          | {:icon, map()}
          | {:on_option_hovered, boolean()}

  @type t :: %__MODULE__{
          id: String.t(),
          options: [String.t()],
          selected: String.t() | nil,
          placeholder: String.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          padding: Julep.Iced.Padding.t() | nil,
          size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          menu_height: number() | nil,
          icon: map() | nil,
          on_option_hovered: boolean() | nil
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
    :on_option_hovered
  ]

  @doc "Creates a new combo box struct with the given options and optional keyword opts."
  @spec new(id :: String.t(), options :: [String.t()], opts :: [option()]) :: t()
  def new(id, options, opts \\ []) when is_list(options) do
    %__MODULE__{id: id, options: options} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing combo box struct."
  @spec with_options(combo_box :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = cb, []), do: cb

  def with_options(%__MODULE__{} = cb, opts) do
    Enum.reduce(opts, cb, fn
      {:selected, v}, acc -> selected(acc, v)
      {:placeholder, v}, acc -> placeholder(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:size, v}, acc -> size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:menu_height, v}, acc -> menu_height(acc, v)
      {:icon, v}, acc -> icon(acc, v)
      {:on_option_hovered, v}, acc -> on_option_hovered(acc, v)
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
  @spec width(combo_box :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = cb, width), do: %{cb | width: width}

  @doc "Sets the internal padding."
  @spec padding(combo_box :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = cb, padding), do: %{cb | padding: padding}

  @doc "Sets the text size in pixels."
  @spec size(combo_box :: t(), size :: number()) :: t()
  def size(%__MODULE__{} = cb, size), do: %{cb | size: size}

  @doc "Sets the font."
  @spec font(combo_box :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = cb, font), do: %{cb | font: font}

  @doc "Sets the text line height."
  @spec line_height(combo_box :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = cb, line_height), do: %{cb | line_height: line_height}

  @doc "Sets the maximum dropdown menu height in pixels."
  @spec menu_height(combo_box :: t(), menu_height :: number()) :: t()
  def menu_height(%__MODULE__{} = cb, menu_height), do: %{cb | menu_height: menu_height}

  @doc "Sets the icon displayed inside the text input."
  @spec icon(combo_box :: t(), icon :: map()) :: t()
  def icon(%__MODULE__{} = cb, icon) when is_map(icon), do: %{cb | icon: icon}

  @doc "Enables or disables option hover event emission."
  @spec on_option_hovered(combo_box :: t(), on_option_hovered :: boolean()) :: t()
  def on_option_hovered(%__MODULE__{} = cb, on_option_hovered),
    do: %{cb | on_option_hovered: on_option_hovered}

  @doc "Converts this combo box struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(combo_box :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = cb), do: Julep.Iced.Widget.to_node(cb)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(cb) do
      props =
        %{}
        |> put_if(cb.options, "options")
        |> put_if(cb.selected, "selected")
        |> put_if(cb.placeholder, "placeholder")
        |> put_if(cb.width, "width")
        |> put_if(cb.padding, "padding")
        |> put_if(cb.size, "size")
        |> put_if(cb.font, "font")
        |> put_if(cb.line_height, "line_height")
        |> put_if(cb.menu_height, "menu_height")
        |> put_if(cb.icon, "icon")
        |> put_if(cb.on_option_hovered, "on_option_hovered")

      %{id: cb.id, type: "combo_box", props: props, children: []}
    end
  end
end
