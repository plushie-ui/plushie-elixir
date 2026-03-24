defmodule Plushie.Widget.Overlay do
  @moduledoc """
  Overlay container -- positions the second child as a floating overlay
  relative to the first child (anchor).

  ## Props

  - `position` (atom) -- overlay position relative to anchor: `:below`, `:above`,
    `:left`, `:right`. Default: `:below`.
  - `gap` (number) -- space in pixels between anchor and overlay. Default: 0.
  - `offset_x` (number) -- horizontal offset in pixels applied after positioning.
  - `offset_y` (number) -- vertical offset in pixels applied after positioning.
  - `flip` (boolean) -- when true, auto-flip the position when the content would
    overflow the viewport. Default: false.
  - `align` (atom) -- cross-axis alignment relative to the anchor: `:start`,
    `:center`, `:end`. Default: `:center`.
  - `width` (length) -- width of the overlay node. See `Plushie.Type.Length`.
  - `a11y` (map) -- accessibility overrides. See `Plushie.Type.A11y`.

  ## Children

  Exactly two children are expected:
  1. The anchor widget (rendered inline in the layout).
  2. The overlay content (rendered as a floating overlay above everything else).
  """

  alias Plushie.Widget.Build

  @positions [:below, :above, :left, :right]
  @alignments [:start, :center, :end]

  @type position :: unquote(Enum.reduce([:below, :above, :left, :right], &{:|, [], [&1, &2]}))
  @type align :: :start | :center | :end

  @type option ::
          {:position, position()}
          | {:gap, number()}
          | {:offset_x, number()}
          | {:offset_y, number()}
          | {:flip, boolean()}
          | {:align, align()}
          | {:width, Plushie.Type.Length.t()}
          | {:a11y, Plushie.Type.A11y.t() | map() | keyword()}

  @type t :: %__MODULE__{
          id: String.t(),
          position: position() | nil,
          gap: number() | nil,
          offset_x: number() | nil,
          offset_y: number() | nil,
          flip: boolean() | nil,
          align: align() | nil,
          width: Plushie.Type.Length.t() | nil,
          a11y: Plushie.Type.A11y.t() | nil,
          children: [Plushie.Widget.ui_node() | struct()]
        }

  defstruct [
    :id,
    :position,
    :gap,
    :offset_x,
    :offset_y,
    :flip,
    :align,
    :width,
    :a11y,
    children: []
  ]

  @valid_option_keys ~w(position gap offset_x offset_y flip align width a11y)a

  @doc false
  def __option_keys__, do: @valid_option_keys

  @doc false
  def __option_types__ do
    %{a11y: Plushie.Type.A11y}
  end

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
      {:flip, v}, acc -> flip(acc, v)
      {:align, v}, acc -> align(acc, v)
      {:width, v}, acc -> width(acc, v)
      {:a11y, v}, acc -> a11y(acc, v)
      {key, _v}, _acc -> Build.unknown_option!(__MODULE__, key)
    end)
  end

  @doc "Sets the overlay position relative to the anchor."
  @spec position(overlay :: t(), position :: position()) :: t()
  def position(%__MODULE__{} = overlay, position) when position in @positions,
    do: %{overlay | position: position}

  @doc "Sets the gap between anchor and overlay in pixels."
  @spec gap(overlay :: t(), gap :: number()) :: t()
  def gap(%__MODULE__{} = overlay, gap) when is_number(gap), do: %{overlay | gap: gap}

  @doc "Sets the horizontal offset in pixels."
  @spec offset_x(overlay :: t(), offset_x :: number()) :: t()
  def offset_x(%__MODULE__{} = overlay, offset_x) when is_number(offset_x),
    do: %{overlay | offset_x: offset_x}

  @doc "Sets the vertical offset in pixels."
  @spec offset_y(overlay :: t(), offset_y :: number()) :: t()
  def offset_y(%__MODULE__{} = overlay, offset_y) when is_number(offset_y),
    do: %{overlay | offset_y: offset_y}

  @doc "Enables auto-flip when the overlay would overflow the viewport."
  @spec flip(overlay :: t(), flip :: boolean()) :: t()
  def flip(%__MODULE__{} = overlay, flip) when is_boolean(flip),
    do: %{overlay | flip: flip}

  @doc "Sets the cross-axis alignment relative to the anchor."
  @spec align(overlay :: t(), align :: align()) :: t()
  def align(%__MODULE__{} = overlay, align) when align in @alignments,
    do: %{overlay | align: align}

  @doc "Sets the width of the overlay node."
  @spec width(overlay :: t(), width :: Plushie.Type.Length.t()) :: t()
  def width(%__MODULE__{} = overlay, width), do: %{overlay | width: width}

  @doc "Appends a child to the overlay."
  @spec push(overlay :: t(), child :: Plushie.Widget.ui_node() | struct()) :: t()
  def push(%__MODULE__{} = overlay, child), do: %{overlay | children: [child | overlay.children]}

  @doc "Appends multiple children to the overlay."
  @spec extend(overlay :: t(), children :: [Plushie.Widget.ui_node() | struct()]) :: t()
  def extend(%__MODULE__{} = overlay, children),
    do: %{overlay | children: Enum.reverse(children) ++ overlay.children}

  @doc "Sets accessibility annotations."
  @spec a11y(overlay :: t(), a11y :: Plushie.Type.A11y.t() | map() | keyword()) :: t()
  def a11y(%__MODULE__{} = overlay, a11y), do: %{overlay | a11y: Plushie.Type.A11y.cast(a11y)}

  @doc "Converts this overlay struct to a `ui_node()` map via the `Plushie.Widget` protocol."
  @spec build(overlay :: t()) :: Plushie.Widget.ui_node()
  def build(%__MODULE__{} = overlay), do: Plushie.Widget.to_node(overlay)

  defimpl Plushie.Widget do
    import Plushie.Widget.Build

    def to_node(overlay) do
      props =
        %{}
        |> put_if(overlay.position, :position)
        |> put_if(overlay.gap, :gap)
        |> put_if(overlay.offset_x, :offset_x)
        |> put_if(overlay.offset_y, :offset_y)
        |> put_if(overlay.flip, :flip)
        |> put_if(overlay.align, :align)
        |> put_if(overlay.width, :width)
        |> put_if(overlay.a11y, :a11y)

      %{
        id: overlay.id,
        type: "overlay",
        props: props,
        children: children_to_nodes(Enum.reverse(overlay.children))
      }
    end
  end
end
