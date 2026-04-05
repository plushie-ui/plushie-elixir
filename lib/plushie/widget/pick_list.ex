defmodule Plushie.Widget.PickList do
  @moduledoc """
  Pick list -- dropdown selection.

  ## Props

  - `options` (list of strings) -- the available choices.
  - `selected` (string | nil) -- the currently selected value.
  - `placeholder` (string) -- placeholder text when nothing is selected.
  - `width` (length) -- widget width. Default: shrink. See `Plushie.Type.Length`.
  - `padding` (number | map) -- internal padding. See `Plushie.Type.Padding`.
  - `text_size` (number) -- text size in pixels.
  - `font` (string | map) -- font specification. See `Plushie.Type.Font`.
  - `line_height` (number | map) -- text line height.
  - `menu_height` (number) -- maximum height of the dropdown menu in pixels.
  - `shaping` -- text shaping strategy. See `Plushie.Type.Shaping`.
  - `handle` (map) -- customise the dropdown handle indicator. Map with a `type` key:
    - `%{type: "arrow"}` -- default arrow (optional `size` in pixels).
    - `%{type: "arrow", size: 12}` -- arrow with explicit size.
    - `%{type: "static", icon: icon_map}` -- fixed icon.
    - `%{type: "dynamic", closed: icon_map, open: icon_map}` -- state-dependent icons.
    - `%{type: "none"}` -- no handle.
    Icon maps: `%{code_point: "char", size: n, font: font, spacing: n, line_height: n}`.
  - `ellipsis` (string) -- text ellipsis strategy: `"none"`, `"start"`, `"middle"`, or `"end"`.
    Default: `"end"`.
  - `menu_style` (map) -- inline style for the dropdown menu. Map with optional keys:
    `background`, `text_color`, `selected_text_color`, `selected_background`, `border`, `shadow`.
  - `style` -- `:default` or `StyleMap.t()` for custom styling. See `Plushie.Type.StyleMap`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Events

  - `%WidgetEvent{type: :select, id: id, value: value}` -- emitted when an option is selected.
  - `%WidgetEvent{type: :open, id: id}` -- emitted when the dropdown menu is opened (requires `on_open: true`).
  - `%WidgetEvent{type: :close, id: id}` -- emitted when the dropdown menu is closed (requires `on_close: true`).
  """

  alias Plushie.Type.StyleMap
  alias Plushie.Widget.Build

  @type style :: :default | StyleMap.t()

  @type option ::
          {:selected, String.t()}
          | {:placeholder, String.t()}
          | {:width, Plushie.Type.Length.t()}
          | {:padding, Plushie.Type.Padding.t()}
          | {:text_size, number()}
          | {:font, Plushie.Type.Font.t()}
          | {:line_height, number() | map()}
          | {:menu_height, number()}
          | {:shaping, Plushie.Type.Shaping.t()}
          | {:handle, map()}
          | {:ellipsis, String.t()}
          | {:menu_style, map()}
          | {:style, style()}
          | {:on_open, boolean()}
          | {:on_close, boolean()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          options: [String.t()],
          selected: String.t() | nil,
          placeholder: String.t() | nil,
          width: Plushie.Type.Length.t() | nil,
          padding: Plushie.Type.Padding.t() | nil,
          text_size: number() | nil,
          font: Plushie.Type.Font.t() | nil,
          line_height: number() | map() | nil,
          menu_height: number() | nil,
          shaping: Plushie.Type.Shaping.t() | nil,
          handle: map() | nil,
          ellipsis: String.t() | nil,
          menu_style: map() | nil,
          style: style() | nil,
          on_open: boolean() | nil,
          on_close: boolean() | nil,
          a11y: Plushie.Type.A11y.t() | nil
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
    :shaping,
    :handle,
    :ellipsis,
    :menu_style,
    :style,
    :on_open,
    :on_close,
    :a11y
  ]

  @valid_option_keys ~w(selected placeholder width padding text_size font line_height menu_height shaping handle ellipsis menu_style style on_open on_close a11y)a

  @doc false
  def __field_keys__, do: @valid_option_keys

  @doc false
  def __field_types__ do
    %{padding: Plushie.Type.Padding, font: Plushie.Type.Font, a11y: Plushie.Type.A11y}
  end

  @doc "Creates a new pick list struct with the given options and optional keyword opts."
  @spec new(id :: String.t(), options :: [String.t()], opts :: [option()]) :: t()
  def new(id, options, opts \\ []) when is_binary(id) and is_list(options) do
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
      {:shaping, v}, acc -> shaping(acc, v)
      {:handle, v}, acc -> handle(acc, v)
      {:ellipsis, v}, acc -> ellipsis(acc, v)
      {:menu_style, v}, acc -> menu_style(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:on_open, v}, acc -> on_open(acc, v)
      {:on_close, v}, acc -> on_close(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the currently selected value."
  @spec selected(pick_list :: t(), selected :: String.t() | nil) :: t()
  def selected(%__MODULE__{} = pl, nil), do: %{pl | selected: nil}

  def selected(%__MODULE__{} = pl, selected) when is_binary(selected),
    do: %{pl | selected: selected}

  @doc "Sets the placeholder text."
  @spec placeholder(pick_list :: t(), placeholder :: String.t()) :: t()
  def placeholder(%__MODULE__{} = pl, placeholder) when is_binary(placeholder),
    do: %{pl | placeholder: placeholder}

  @doc "Sets the pick list width."
  @spec width(pick_list :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = pl, width), do: %{pl | width: width}

  @doc "Sets the internal padding."
  @spec padding(pick_list :: t(), padding :: Plushie.Type.Padding.t()) :: t()
  def padding(%__MODULE__{} = pl, padding), do: %{pl | padding: padding}

  @doc "Sets the text size in pixels."
  @spec text_size(pick_list :: t(), text_size :: number()) :: t()
  def text_size(%__MODULE__{} = pl, text_size) when is_number(text_size),
    do: %{pl | text_size: text_size}

  @doc "Sets the font."
  @spec font(pick_list :: t(), font :: Plushie.Type.Font.t()) :: t()
  def font(%__MODULE__{} = pl, font), do: %{pl | font: font}

  @doc "Sets the text line height."
  @spec line_height(pick_list :: t(), line_height :: number() | map()) :: t()
  def line_height(%__MODULE__{} = pl, line_height), do: %{pl | line_height: line_height}

  @doc "Sets the maximum dropdown menu height in pixels."
  @spec menu_height(pick_list :: t(), menu_height :: number()) :: t()
  def menu_height(%__MODULE__{} = pl, menu_height) when is_number(menu_height),
    do: %{pl | menu_height: menu_height}

  @doc "Sets the text shaping strategy."
  @spec shaping(pick_list :: t(), shaping :: Plushie.Type.Shaping.t()) :: t()
  def shaping(%__MODULE__{} = pl, shaping), do: %{pl | shaping: shaping}

  @doc "Sets the dropdown handle style."
  @spec handle(pick_list :: t(), handle :: map()) :: t()
  def handle(%__MODULE__{} = pl, handle) when is_map(handle), do: %{pl | handle: handle}

  @doc "Sets the text ellipsis strategy."
  @spec ellipsis(pick_list :: t(), ellipsis :: String.t()) :: t()
  def ellipsis(%__MODULE__{} = pl, ellipsis) when is_binary(ellipsis),
    do: %{pl | ellipsis: ellipsis}

  @doc "Sets the dropdown menu style overrides."
  @spec menu_style(pick_list :: t(), menu_style :: map()) :: t()
  def menu_style(%__MODULE__{} = pl, menu_style) when is_map(menu_style),
    do: %{pl | menu_style: menu_style}

  @doc "Sets the pick list style. Accepts `:default` or a `StyleMap`."
  @spec style(pick_list :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = pl, %StyleMap{} = style), do: %{pl | style: style}
  def style(%__MODULE__{} = pl, :default), do: %{pl | style: :default}

  @doc "Enables or disables the open event when the dropdown menu opens."
  @spec on_open(pick_list :: t(), on_open :: boolean()) :: t()
  def on_open(%__MODULE__{} = pl, on_open) when is_boolean(on_open), do: %{pl | on_open: on_open}

  @doc "Enables or disables the close event when the dropdown menu closes."
  @spec on_close(pick_list :: t(), on_close :: boolean()) :: t()
  def on_close(%__MODULE__{} = pl, on_close) when is_boolean(on_close),
    do: %{pl | on_close: on_close}

  @doc "Sets accessibility annotations."
  @spec a11y(pick_list :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = pl, a11y),
    do: %{
      pl
      | a11y:
          (fn a ->
             {:ok, v} = Plushie.Type.A11y.cast(a)
             v
           end).(a11y)
    }

  @doc "Converts this pick list struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(pick_list :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = pl), do: Plushie.Widget.to_node(pl)

  defimpl Plushie.Widget.WidgetProtocol do
    import Plushie.Widget.Build

    def to_node(pl) do
      props =
        %{}
        |> put_if(pl.options, :options)
        |> put_if(pl.selected, :selected)
        |> put_if(pl.placeholder, :placeholder)
        |> put_if(pl.width, :width)
        |> put_if(pl.padding, :padding)
        |> put_if(pl.text_size, :text_size)
        |> put_if(pl.font, :font)
        |> put_if(pl.line_height, :line_height)
        |> put_if(pl.menu_height, :menu_height)
        |> put_if(pl.shaping, :shaping)
        |> put_if(pl.handle, :handle)
        |> put_if(pl.ellipsis, :ellipsis)
        |> put_if(pl.menu_style, :menu_style)
        |> put_if(pl.style, :style)
        |> put_if(pl.on_open, :on_open)
        |> put_if(pl.on_close, :on_close)
        |> put_if(pl.a11y, :a11y)

      %{id: pl.id, type: "pick_list", props: props, children: []}
    end
  end
end
