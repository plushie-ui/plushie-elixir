defmodule Julep.Iced.Widget.Overlay do
  @moduledoc """
  Overlay container -- positions the second child as a floating overlay
  relative to the first child (anchor).

  ## Props

  - `position` (atom) -- overlay position relative to anchor: `:below`, `:above`,
    `:left`, `:right`. Default: `:below`.
  - `gap` (number) -- space in pixels between anchor and overlay. Default: 0.
  - `offset_x` (number) -- horizontal offset in pixels applied after positioning.
  - `offset_y` (number) -- vertical offset in pixels applied after positioning.
  - `width` (length) -- width of the overlay node. See `Julep.Iced.Length`.

  ## Children

  Exactly two children are expected:
  1. The anchor widget (rendered inline in the layout).
  2. The overlay content (rendered as a floating overlay above everything else).
  """

  alias Julep.Iced.A11y
  alias Julep.Iced.Widget.Build

  @type position :: :below | :above | :left | :right

  @type option ::
          {:position, position()}
          | {:gap, number()}
          | {:offset_x, number()}
          | {:offset_y, number()}
          | {:width, Julep.Iced.Length.t()}
          | {:a11y, Julep.Iced.A11y.t()}

  @type t :: %__MODULE__{
          id: String.t(),
          position: position() | nil,
          gap: number() | nil,
          offset_x: number() | nil,
          offset_y: number() | nil,
          width: Julep.Iced.Length.t() | nil,
          a11y: Julep.Iced.A11y.t() | nil,
          children: [Julep.Iced.ui_node() | struct()]
        }

  defstruct [
    :id,
    :position,
    :gap,
    :offset_x,
    :offset_y,
    :width,
    :a11y,
    children: []
  ]

  @doc "Creates a new overlay struct with optional keyword opts."
  @spec new(id :: String.t(), opts :: [option()]) :: t()
  def new(id, opts \\ []) when is_binary(id) do
    %__MODULE__{id: id} |> with_options(opts)
  end

  @doc "Applies keyword options to an existing overlay struct."
  @spec with_options(overlay :: t(), opts :: [option()]) :: t()
  def with_options(%__MODULE__{} = overlay, []), do: overlay

  def with_options(%__MODULE__{} = overlay, opts) do
    Enum.reduce(opts, overlay, fn
      {:position, v}, acc -> position(acc, v)
      {:gap, v}, acc -> gap(acc, v)
      {:offset_x, v}, acc -> offset_x(acc, v)
      {:offset_y, v}, acc -> offset_y(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the overlay position relative to the anchor."
  @spec position(overlay :: t(), position :: position()) :: t()
  def position(%__MODULE__{} = overlay, position), do: %{overlay | position: position}

  @doc "Sets the gap between anchor and overlay in pixels."
  @spec gap(overlay :: t(), gap :: number()) :: t()
  def gap(%__MODULE__{} = overlay, gap), do: %{overlay | gap: gap}

  @doc "Sets the horizontal offset in pixels."
  @spec offset_x(overlay :: t(), offset_x :: number()) :: t()
  def offset_x(%__MODULE__{} = overlay, offset_x), do: %{overlay | offset_x: offset_x}

  @doc "Sets the vertical offset in pixels."
  @spec offset_y(overlay :: t(), offset_y :: number()) :: t()
  def offset_y(%__MODULE__{} = overlay, offset_y), do: %{overlay | offset_y: offset_y}

  @doc "Sets the width of the overlay node."
  @spec width(overlay :: t(), width :: Julep.Iced.Length.t()) :: t()
  def width(%__MODULE__{} = overlay, width), do: %{overlay | width: width}

  @doc "Appends a child to the overlay."
  @spec push(overlay :: t(), child :: Julep.Iced.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = overlay, child), do: %{overlay | children: [child | overlay.children]}

  @doc "Appends multiple children to the overlay."
  @spec extend(overlay :: t(), children :: [Julep.Iced.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = overlay, children),
    do: %{overlay | children: Enum.reverse(children) ++ overlay.children}

  @doc "Sets accessibility annotations."
  @spec a11y(overlay :: t(), a11y :: Julep.Iced.A11y.t()) :: t()
  def a11y(%__MODULE__{} = overlay, a11y), do: %{overlay | a11y: A11y.cast(a11y)}

  @doc "Converts this overlay struct to a `ui_node()` map via the `Julep.Iced.Widget` protocol."
  @spec build(overlay :: t()) :: Julep.Iced.ui_node()
  def build(%__MODULE__{} = overlay), do: Julep.Iced.Widget.to_node(overlay)

  defimpl Julep.Iced.Widget do
    import Julep.Iced.Widget.Build

    def to_node(overlay) do
      props =
        %{}
        |> put_if(overlay.position, "position")
        |> put_if(overlay.gap, "gap")
        |> put_if(overlay.offset_x, "offset_x")
        |> put_if(overlay.offset_y, "offset_y")
        |> put_if(overlay.width, "width")
        |> put_if(overlay.a11y, "a11y")

      %{
        id: overlay.id,
        type: "overlay",
        props: props,
        children: children_to_nodes(Enum.reverse(overlay.children))
      }
    end
  end
end
