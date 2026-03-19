defmodule Toddy.Iced.Widget.Scrollable do
  @moduledoc """
  Scrollable container -- wraps child content in a scrollable viewport.

  ## Props

  - `width` (length) -- width of the scrollable area. Default: shrink. See `Toddy.Iced.Length`.
  - `height` (length) -- height of the scrollable area. Default: shrink.
  - `direction` (atom) -- scroll direction: `:vertical` (default), `:horizontal`, or `:both`.
    See `Toddy.Iced.Direction`. Setting `:both` enables bidirectional scrolling,
    but per-axis scrollbar customization (independent widths, margins per axis)
    is not yet supported.
  - `spacing` (number) -- spacing between scrollbar and content.
  - `scrollbar_width` (number) -- width of the scrollbar track in pixels.
  - `scrollbar_margin` (number) -- margin around the scrollbar in pixels.
  - `scroller_width` (number) -- width of the scroller handle in pixels.
  - `scrollbar_color` (hex color) -- color for the scrollbar track background.
  - `scroller_color` (hex color) -- color for the scroller thumb.
  - `id` (string) -- widget ID for programmatic scroll control via `Toddy.Command`.
  - `anchor` (atom) -- scroll anchor: `:start` (default) or `:end` / `:bottom` / `:right`.
    See `Toddy.Iced.Anchor`.
  - `on_scroll` (boolean) -- when `true`, emits `%Widget{type: :scroll, id: id, data: viewport}` events on scroll.
    The viewport map contains `absolute_x`, `absolute_y`, `relative_x`, `relative_y`,
    `bounds` (as `{width, height}`), and `content_bounds` (as `{width, height}`).
  - `auto_scroll` (boolean) -- when `true`, automatically scrolls to show new content.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Iced.A11y`.
  """

  alias Toddy.Iced.A11y
  alias Toddy.Iced.Color
  alias Toddy.Iced.Widget.Build

  @type option ::
          {:width, Toddy.Iced.Length.t()}
          | {:height, Toddy.Iced.Length.t()}
          | {:direction, Toddy.Iced.Direction.t()}
          | {:spacing, number()}
          | {:scrollbar_width, number()}
          | {:scrollbar_margin, number()}
          | {:scroller_width, number()}
          | {:anchor, Toddy.Iced.Anchor.t()}
          | {:on_scroll, boolean()}
          | {:auto_scroll, boolean()}
          | {:scrollbar_color, Toddy.Iced.Color.input()}
          | {:scroller_color, Toddy.Iced.Color.input()}
          | {:a11y, Toddy.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          width: Toddy.Iced.Length.t() | nil,
          height: Toddy.Iced.Length.t() | nil,
          direction: Toddy.Iced.Direction.t() | nil,
          spacing: number() | nil,
          scrollbar_width: number() | nil,
          scrollbar_margin: number() | nil,
          scroller_width: number() | nil,
          anchor: Toddy.Iced.Anchor.t() | nil,
          on_scroll: boolean() | nil,
          auto_scroll: boolean() | nil,
          scrollbar_color: Toddy.Iced.Color.t() | nil,
          scroller_color: Toddy.Iced.Color.t() | nil,
          a11y: Toddy.Iced.A11y.t() | nil,
          children: [Toddy.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :width,
    :height,
    :direction,
    :spacing,
    :scrollbar_width,
    :scrollbar_margin,
    :scroller_width,
    :anchor,
    :on_scroll,
    :auto_scroll,
    :scrollbar_color,
    :scroller_color,
    :a11y,
    children: []
  ]

  @doc "Creates a new scrollable struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing scrollable struct."
  @spec with_options(scrollable :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = s, []), do: s

  def with_options(%__MODULE__{} = s, opts) do
    Enum.reduce(opts, s, fn
      {:width, v}, acc -> width(acc, v)
      {:height, v}, acc -> height(acc, v)
      {:direction, v}, acc -> direction(acc, v)
      {:spacing, v}, acc -> spacing(acc, v)
      {:scrollbar_width, v}, acc -> scrollbar_width(acc, v)
      {:scrollbar_margin, v}, acc -> scrollbar_margin(acc, v)
      {:scroller_width, v}, acc -> scroller_width(acc, v)
      {:anchor, v}, acc -> anchor(acc, v)
      {:on_scroll, v}, acc -> on_scroll(acc, v)
      {:auto_scroll, v}, acc -> auto_scroll(acc, v)
      {:scrollbar_color, v}, acc -> scrollbar_color(acc, v)
      {:scroller_color, v}, acc -> scroller_color(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the scrollable width."
  @spec width(scrollable :: t(), width :: Toddy.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = s, width), do: %{s | width: width}

  @doc "Sets the scrollable height."
  @spec height(scrollable :: t(), height :: Toddy.Iced.Length.t()) :: t()
  def height(%__MODULE__{} = s, height), do: %{s | height: height}

  @doc "Sets the scroll direction."
  @spec direction(scrollable :: t(), direction :: Toddy.Iced.Direction.t()) :: t()
  def direction(%__MODULE__{} = s, direction), do: %{s | direction: direction}

  @doc "Sets the spacing between scrollbar and content."
  @spec spacing(scrollable :: t(), spacing :: number()) :: t()
  def spacing(%__MODULE__{} = s, spacing) when is_number(spacing), do: %{s | spacing: spacing}

  @doc "Sets the scrollbar track width in pixels."
  @spec scrollbar_width(scrollable :: t(), scrollbar_width :: number()) :: t()
  def scrollbar_width(%__MODULE__{} = s, scrollbar_width) when is_number(scrollbar_width),
    do: %{s | scrollbar_width: scrollbar_width}

  @doc "Sets the scrollbar margin in pixels."
  @spec scrollbar_margin(scrollable :: t(), scrollbar_margin :: number()) :: t()
  def scrollbar_margin(%__MODULE__{} = s, scrollbar_margin) when is_number(scrollbar_margin),
    do: %{s | scrollbar_margin: scrollbar_margin}

  @doc "Sets the scroller handle width in pixels."
  @spec scroller_width(scrollable :: t(), scroller_width :: number()) :: t()
  def scroller_width(%__MODULE__{} = s, scroller_width) when is_number(scroller_width), do: %{s | scroller_width: scroller_width}

  @doc "Sets the scroll anchor."
  @spec anchor(scrollable :: t(), anchor :: Toddy.Iced.Anchor.t()) :: t()
  def anchor(%__MODULE__{} = s, anchor), do: %{s | anchor: anchor}

  @doc "Enables scroll position change events."
  @spec on_scroll(scrollable :: t(), on_scroll :: boolean()) :: t()
  def on_scroll(%__MODULE__{} = s, on_scroll) when is_boolean(on_scroll), do: %{s | on_scroll: on_scroll}

  @doc "Enables automatic scrolling to show new content."
  @spec auto_scroll(scrollable :: t(), auto_scroll :: boolean()) :: t()
  def auto_scroll(%__MODULE__{} = s, auto_scroll) when is_boolean(auto_scroll), do: %{s | auto_scroll: auto_scroll}

  @doc "Sets the scrollbar track color."
  @spec scrollbar_color(scrollable :: t(), scrollbar_color :: Toddy.Iced.Color.input()) :: t()
  def scrollbar_color(%__MODULE__{} = s, scrollbar_color),
    do: %{s | scrollbar_color: Color.cast(scrollbar_color)}

  @doc "Sets the scroller handle color."
  @spec scroller_color(scrollable :: t(), scroller_color :: Toddy.Iced.Color.input()) :: t()
  def scroller_color(%__MODULE__{} = s, scroller_color),
    do: %{s | scroller_color: Color.cast(scroller_color)}

  @doc "Appends a child to the scrollable."
  @spec push(scrollable :: t(), child :: Toddy.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = s, child), do: %{s | children: [child | s.children]}

  @doc "Appends multiple children to the scrollable."
  @spec extend(scrollable :: t(), children :: [Toddy.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = s, children),
    do: %{s | children: Enum.reverse(children) ++ s.children}

  @doc "Sets accessibility annotations."
  @spec a11y(scrollable :: t(), a11y :: Toddy.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = s, a11y), do: %{s | a11y: A11y.cast(a11y)}

  @doc "Converts this scrollable struct to a `ui_node()` map via the `Toddy.Iced.Widget` protocol."
  @spec build(scrollable :: t()) :: Toddy.Iced.ui_node()
  def build(%__MODULE__{} = s), do: Toddy.Iced.Widget.to_node(s)

  defimpl Toddy.Iced.Widget do
    import Toddy.Iced.Widget.Build

    def to_node(s) do
      props =
        %{}
        |> put_if(s.width, "width")
        |> put_if(s.height, "height")
        |> put_if(s.direction, "direction")
        |> put_if(s.spacing, "spacing")
        |> put_if(s.scrollbar_width, "scrollbar_width")
        |> put_if(s.scrollbar_margin, "scrollbar_margin")
        |> put_if(s.scroller_width, "scroller_width")
        |> put_if(s.anchor, "anchor")
        |> put_if(s.on_scroll, "on_scroll")
        |> put_if(s.auto_scroll, "auto_scroll")
        |> put_if(s.scrollbar_color, "scrollbar_color")
        |> put_if(s.scroller_color, "scroller_color")
        |> put_if(s.a11y, "a11y")

      %{
        id: s.id,
        type: "scrollable",
        props: props,
        children: children_to_nodes(Enum.reverse(s.children))
      }
    end
  end
end
