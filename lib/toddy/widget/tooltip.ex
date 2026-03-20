defmodule Toddy.Widget.Tooltip do
  @moduledoc """
  Tooltip -- shows a popup tip over child content on hover.

  The `tip` argument becomes the `tip` prop.

  ## Props

  - `tip` (string) -- tooltip text (set automatically from the `tip` argument).
  - `position` (atom) -- tooltip position: `:top` (default), `:bottom`,
    `:left`, `:right`, `:follow_cursor` / `:follow`. See `Toddy.Type.Position`.
  - `gap` (number) -- gap between tooltip and content in pixels.
  - `padding` (number) -- tooltip padding in pixels (uniform, not per-side).
  - `snap_within_viewport` (boolean) -- keep tooltip within viewport. Default: true.
  - `delay` (non_neg_integer) -- delay in milliseconds before showing the tooltip.
  - `style` (atom) -- named style (uses container styles). One of:
    `:transparent`, `:rounded_box`, `:bordered_box`, `:dark`, `:primary`,
    `:secondary`, `:success`, `:danger`, `:warning`.
  - `a11y` (map) -- accessibility overrides. See `Toddy.Type.A11y`.
  """

  alias Toddy.Type.A11y
  alias Toddy.Type.StyleMap
  alias Toddy.Widget.{Build, Container}

  # Tooltip uses the same container style presets.
  @presets Container.style_presets()

  @type preset :: Container.preset()
  @type style :: preset() | StyleMap.t()

  @type option ::
          {:position, Toddy.Type.Position.t()}
          | {:gap, number()}
          | {:padding, number()}
          | {:snap_within_viewport, boolean()}
          | {:delay, non_neg_integer()}
          | {:style, style()}
          | {:a11y, Toddy.Type.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          tip: String.t(),
          position: Toddy.Type.Position.t() | nil,
          gap: number() | nil,
          padding: number() | nil,
          snap_within_viewport: boolean() | nil,
          delay: non_neg_integer() | nil,
          style: style() | nil,
          a11y: Toddy.Type.A11y.t() | nil,
          children: [Toddy.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :tip,
    :position,
    :gap,
    :padding,
    :snap_within_viewport,
    :delay,
    :style,
    :a11y,
    children: []
  ]

  @doc """
  Creates a new tooltip struct.

  Accepts either keyword opts (with `:tip` key) or a positional tip string:

      Tooltip.new("tt", tip: "Help", position: :top)
      Tooltip.new("tt", "Help", position: :top)
  """
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts) when is_binary(id) and is_list(opts) do
    {tip, remaining} = Keyword.pop(opts, :tip, "")
    new(id, tip, remaining)
  end

  @spec new(id :: String.t(), tip :: String.t(), opts :: [option()]) :: t()
  def new(id, tip, opts \\ []) when is_binary(id) and is_binary(tip) do
    %__MODULE__{id: id, tip: tip} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing tooltip struct."
  @spec with_options(tooltip :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = tt, []), do: tt

  def with_options(%__MODULE__{} = tt, opts) do
    Enum.reduce(opts, tt, fn
      {:position, v}, acc -> position(acc, v)
      {:gap, v}, acc -> gap(acc, v)
      {:padding, v}, acc -> padding(acc, v)
      {:snap_within_viewport, v}, acc -> snap_within_viewport(acc, v)
      {:delay, v}, acc -> delay(acc, v)
      {:style, v}, acc -> style(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the tooltip position."
  @spec position(tooltip :: t(), position :: Toddy.Type.Position.t()) :: t()
  def position(%__MODULE__{} = tt, position), do: %{tt | position: position}

  @doc "Sets the gap between tooltip and content."
  @spec gap(tooltip :: t(), gap :: number()) :: t()
  def gap(%__MODULE__{} = tt, gap) when is_number(gap), do: %{tt | gap: gap}

  @doc "Sets the tooltip padding."
  @spec padding(tooltip :: t(), padding :: number()) :: t()
  def padding(%__MODULE__{} = tt, padding) when is_number(padding), do: %{tt | padding: padding}

  @doc "Sets whether the tooltip snaps within the viewport."
  @spec snap_within_viewport(tooltip :: t(), snap :: boolean()) :: t()
  def snap_within_viewport(%__MODULE__{} = tt, snap) when is_boolean(snap),
    do: %{tt | snap_within_viewport: snap}

  @doc "Sets the tooltip delay in milliseconds before showing."
  @spec delay(tooltip :: t(), delay :: non_neg_integer()) :: t()
  def delay(%__MODULE__{} = tt, delay) when is_integer(delay) and delay >= 0,
    do: %{tt | delay: delay}

  @doc "Sets the tooltip style."
  @spec style(tooltip :: t(), style :: style()) :: t()
  def style(%__MODULE__{} = tt, %StyleMap{} = style), do: %{tt | style: style}
  def style(%__MODULE__{} = tt, style) when style in @presets, do: %{tt | style: style}

  @doc "Appends a child to the tooltip."
  @spec push(tooltip :: t(), child :: Toddy.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = tt, child), do: %{tt | children: [child | tt.children]}

  @doc "Appends multiple children to the tooltip."
  @spec extend(tooltip :: t(), children :: [Toddy.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = tt, children),
    do: %{tt | children: Enum.reverse(children) ++ tt.children}

  @doc "Sets accessibility annotations."
  @spec a11y(tooltip :: t(), a11y :: Toddy.Type.A11y.t()) :: t()
  def a11y(%__MODULE__{} = tt, a11y), do: %{tt | a11y: A11y.cast(a11y)}

  @doc "Converts this tooltip struct to a `ui_node()` map via the `Toddy.Widget` protocol."
  @spec build(tooltip :: t()) :: Toddy.Widget.ui_node()
  def build(%__MODULE__{} = tt), do: Toddy.Widget.to_node(tt)

  defimpl Toddy.Widget do
    import Toddy.Widget.Build

    def to_node(tt) do
      props =
        %{}
        |> put_if(tt.tip, "tip")
        |> put_if(tt.position, "position")
        |> put_if(tt.gap, "gap")
        |> put_if(tt.padding, "padding")
        |> put_if(tt.snap_within_viewport, "snap_within_viewport")
        |> put_if(tt.delay, "delay")
        |> put_if(tt.style, "style")
        |> put_if(tt.a11y, "a11y")

      %{
        id: tt.id,
        type: "tooltip",
        props: props,
        children: children_to_nodes(Enum.reverse(tt.children))
      }
    end
  end
end
