defmodule Julep.Iced.Widget.Tooltip do
  @moduledoc """
  Tooltip -- shows a popup tip over child content on hover.

  The `tip` argument becomes the `tip` prop.

  ## Props

  - `tip` (string) -- tooltip text (set automatically from the `tip` argument).
  - `position` (string) -- tooltip position: `"top"` (default), `"bottom"`,
    `"left"`, `"right"`, `"follow_cursor"` / `"follow"`.
  - `gap` (number) -- gap between tooltip and content in pixels.
  - `padding` (number) -- tooltip padding in pixels (uniform, not per-side).
  - `snap_within_viewport` (boolean) -- keep tooltip within viewport. Default: true.
  - `style` (string) -- named style (uses container styles). One of:
    `"transparent"`, `"rounded_box"`, `"bordered_box"`, `"dark"`, `"primary"`,
    `"secondary"`, `"success"`, `"danger"`, `"warning"`.
  """

  alias Julep.Iced.Widget.Build

  @type option ::
          {:position, atom()}
          | {:gap, number()}
          | {:padding, number()}
          | {:snap_within_viewport, boolean()}
          | {:style, atom()}

  @type t :: %__MODULE__{
          id: String.t(),
          tip: String.t(),
          position: atom() | nil,
          gap: number() | nil,
          padding: number() | nil,
          snap_within_viewport: boolean() | nil,
          style: atom() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [:id, :tip, :position, :gap, :padding, :snap_within_viewport, :style, children: []]

  @doc "Creates a new tooltip struct with the given tip text and optional keyword opts."
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
      {:style, v}, acc -> style(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the tooltip position."
  @spec position(tooltip :: t(), position :: atom()) :: t()
  def position(%__MODULE__{} = tt, position), do: %{tt | position: position}

  @doc "Sets the gap between tooltip and content."
  @spec gap(tooltip :: t(), gap :: number()) :: t()
  def gap(%__MODULE__{} = tt, gap), do: %{tt | gap: gap}

  @doc "Sets the tooltip padding."
  @spec padding(tooltip :: t(), padding :: number()) :: t()
  def padding(%__MODULE__{} = tt, padding), do: %{tt | padding: padding}

  @doc "Sets whether the tooltip snaps within the viewport."
  @spec snap_within_viewport(tooltip :: t(), snap :: boolean()) :: t()
  def snap_within_viewport(%__MODULE__{} = tt, snap), do: %{tt | snap_within_viewport: snap}

  @doc "Sets the tooltip style."
  @spec style(tooltip :: t(), style :: atom()) :: t()
  def style(%__MODULE__{} = tt, style), do: %{tt | style: style}

  @doc "Appends a child to the tooltip."
  @spec push(tooltip :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = tt, child), do: %{tt | children: tt.children ++ [child]}

  @doc "Appends multiple children to the tooltip."
  @spec extend(tooltip :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = tt, children), do: %{tt | children: tt.children ++ children}

  @doc "Converts this tooltip struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(tooltip :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = tt), do: Julep.Iced.Widget.to_node(tt)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(tt) do
      props =
        %{}
        |> put_if(tt.tip, "tip")
        |> put_if(tt.position, "position", &to_string/1)
        |> put_if(tt.gap, "gap")
        |> put_if(tt.padding, "padding")
        |> put_if(tt.snap_within_viewport, "snap_within_viewport")
        |> put_if(tt.style, "style", &to_string/1)

      %{id: tt.id, type: "tooltip", props: props, children: children_to_nodes(tt.children)}
    end
  end
end
