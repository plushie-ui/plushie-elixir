defmodule Julep.Iced.Widget.PickList do
  @moduledoc """
  Pick list -- dropdown selection.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value.
  - `placeholder` (string) -- placeholder text when nothing is selected.
  - `width` (length) -- widget width. Default: shrink. See `Julep.Iced.Length`.
  - `padding` (number | map) -- internal padding. See `Julep.Iced.Padding`.
  - `text_size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Julep.Iced.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.
  - `text_shaping` (string) -- text shaping: `"basic"`, `"advanced"`, or `"auto"`.
  - `handle` (map) -- customise the dropdown handle indicator. Map with a `type` key:
    - `%{type: "arrow"}` -- default arrow (optional `size` in pixels).
    - `%{type: "arrow", size: 12}` -- arrow with explicit size.
    - `%{type: "static", icon: icon_map}` -- fixed icon.
    - `%{type: "dynamic", closed: icon_map, open: icon_map}` -- state-dependent icons.
    - `%{type: "none"}` -- no handle.
    Icon maps: `%{code_point: "char", size: n, font: font, spacing: n, line_height: n}`.
  - `style` (string) -- named style. Currently only `"default"`.

  ## Events

  - `{:select, id, value}` -- emitted when an option is selected.
  """

  alias Julep.Iced.Widget.Build

  @type style :: :default

  @type option ::
          {:selected, String.t()}
          | {:placeholder, String.t()}
          | {:width, Julep.Iced.Length.t()}
          | {:padding, Julep.Iced.Padding.t()}
          | {:text_size, number()}
          | {:font, Julep.Iced.Font.t()}
          | {:line_height, number() | map()}
          | {:menu_height, number()}
          | {:text_shaping, Julep.Iced.Shaping.t()}
          | {:handle, map()}
          | {:style, style()}

  @type t :: %__MODULE__{
          id: String.t(),
          options: [String.t()],
          selected: String.t() | nil,
          placeholder: String.t() | nil,
          width: Julep.Iced.Length.t() | nil,
          padding: Julep.Iced.Padding.t() | nil,
          text_size: number() | nil,
          font: Julep.Iced.Font.t() | nil,
          line_height: number() | map() | nil,
          menu_height: number() | nil,
          text_shaping: Julep.Iced.Shaping.t() | nil,
          handle: map() | nil,
          style: style() | nil
        }

  defstruct [
    :id,
    :options,
    :selected,
    :placeholder,
    :width,
    :padding,
    :text_size,
    :font,
    :line_height,
    :menu_height,
    :text_shaping,
    :handle,
    :style
  ]

  @doc "Creates a new pick list struct with the given options and optional keyword opts."
  @spec new(id :: String.t(), options :: [String.t()], opts :: [option()]) :: t()
  def new(id, options, opts \\ []) when is_list(options) do
    %__MODULE__{id: id, options: options} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing pick list struct."
  @spec with_options(pick_list :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = pl, []), do: pl

  def with_options(%__MODULE__{} = pl, opts) do
    Enum.reduce(opts, pl, fn
      {:selected, v}, acc -> selected(acc, v)
      {:placeholder, v}, acc -> placeholder(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:text_size, v}, acc -> text_size(acc, v)
      {:font, v}, acc -> font(acc, v)
      {:line_height, v}, acc -> line_height(acc, v)
      {:menu_height, v}, acc -> menu_height(acc, v)
      {:text_shaping, v}, acc -> text_shaping(acc, v)
      {:handle, v}, acc -> handle(acc, v)
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the currently selected value."
  @spec selected(pick_list :: t(), selected :: String.t()) :: t()
  def selected(%__MODULE__{} = pl, selected), do: %{pl | selected: selected}

  @doc "Sets the placeholder text."
  @spec placeholder(pick_list :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = pl, placeholder), do: %{pl | placeholder: placeholder}

  @doc "Sets the pick list width."
  @spec width(pick_list :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = pl, width), do: %{pl | width: width}

  @doc "Sets the internal padding."
  @spec padding(pick_list :: t(), padding :: Julep.Iced.Padding.t()) :: t()
  def padding(%__MODULE__{} = pl, padding), do: %{pl | padding: padding}

  @doc "Sets the text size in pixels."
  @spec text_size(pick_list :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = pl, text_size), do: %{pl | text_size: text_size}

  @doc "Sets the font."
  @spec font(pick_list :: t(), font :: Julep.Iced.Font.t()) :: t()
  def font(%__MODULE__{} = pl, font), do: %{pl | font: font}

  @doc "Sets the text line height."
  @spec line_height(pick_list :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = pl, line_height), do: %{pl | line_height: line_height}

  @doc "Sets the maximum dropdown menu height in pixels."
  @spec menu_height(pick_list :: t(), menu_height :: number()) :: t()
  def menu_height(%__MODULE__{} = pl, menu_height), do: %{pl | menu_height: menu_height}

  @doc "Sets the text shaping strategy."
  @spec text_shaping(pick_list :: t(), text_shaping :: Julep.Iced.Shaping.t()) :: t()
  def text_shaping(%__MODULE__{} = pl, text_shaping), do: %{pl | text_shaping: text_shaping}

  @doc "Sets the dropdown handle style."
  @spec handle(pick_list :: t(), handle :: map()) :: t()
  def handle(%__MODULE__{} = pl, handle) when is_map(handle), do: %{pl | handle: handle}

  @doc "Sets the pick list style."
  @spec style(pick_list :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = pl, style), do: %{pl | style: style}

  @doc "Converts this pick list struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(pick_list :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = pl), do: Julep.Iced.Widget.to_node(pl)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(pl) do
      props =
        %{}
        |> put_if(pl.options, "options")
        |> put_if(pl.selected, "selected")
        |> put_if(pl.placeholder, "placeholder")
        |> put_if(pl.width, "width")
        |> put_if(pl.padding, "padding")
        |> put_if(pl.text_size, "text_size")
        |> put_if(pl.font, "font")
        |> put_if(pl.line_height, "line_height")
        |> put_if(pl.menu_height, "menu_height")
        |> put_if(pl.text_shaping, "text_shaping")
        |> put_if(pl.handle, "handle")
        |> put_if(pl.style, "style")

      %{id: pl.id, type: "pick_list", props: props, children: []}
    end
  end
end
