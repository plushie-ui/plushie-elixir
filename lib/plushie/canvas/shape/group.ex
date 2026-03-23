defmodule Plushie.Canvas.Shape.Group do
  @moduledoc """
  Canvas group -- the only container and interactive unit in the canvas.

  A group with an `id` is an interactive element (referred to as an
  "element" in event names). Groups without an `id` are purely
  structural containers for transforms, clips, and visual grouping.

  ## Transforms and clips

  Groups carry an ordered `transforms` list and an optional `clip` rect.
  These replace the old standalone push_transform/pop_transform and
  push_clip/pop_clip shape commands.

  ## Interactivity

  All interactive fields (`on_click`, `hover_style`, `a11y`, etc.) live
  directly on the group struct -- there is no nested `Interactive`
  sub-struct.
  """

  alias Plushie.Canvas.Shape.{Clip, DragBounds, HitRect, Rotate, Scale, ShapeStyle, Translate}

  @type t :: %__MODULE__{
          children: [term()],
          transforms: [Translate.t() | Rotate.t() | Scale.t()] | nil,
          clip: Clip.t() | nil,
          id: String.t() | nil,
          on_click: boolean() | nil,
          on_hover: boolean() | nil,
          draggable: boolean() | nil,
          drag_axis: String.t() | nil,
          drag_bounds: DragBounds.t() | nil,
          cursor: String.t() | nil,
          hit_rect: HitRect.t() | nil,
          tooltip: String.t() | nil,
          hover_style: ShapeStyle.t() | nil,
          pressed_style: ShapeStyle.t() | nil,
          focus_style: ShapeStyle.t() | nil,
          show_focus_ring: boolean() | nil,
          focus_ring_radius: number() | nil,
          a11y: map() | nil,
          focusable: boolean() | nil
        }

  @enforce_keys [:children]
  defstruct [
    :children,
    :transforms,
    :clip,
    :id,
    :on_click,
    :on_hover,
    :draggable,
    :drag_axis,
    :drag_bounds,
    :cursor,
    :hit_rect,
    :tooltip,
    :hover_style,
    :pressed_style,
    :focus_style,
    :show_focus_ring,
    :focus_ring_radius,
    :a11y,
    :focusable
  ]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Group do
  def encode(group) do
    base = %{type: "group", children: Enum.map(group.children, &Plushie.Encode.encode/1)}

    base
    |> encode_transforms(group.transforms)
    |> put_if(:clip, group.clip)
    |> put_if(:id, group.id)
    |> put_if(:on_click, group.on_click)
    |> put_if(:on_hover, group.on_hover)
    |> put_if(:draggable, group.draggable)
    |> put_if(:drag_axis, group.drag_axis)
    |> put_if(:drag_bounds, group.drag_bounds)
    |> put_if(:cursor, group.cursor)
    |> put_if(:hit_rect, group.hit_rect)
    |> put_if(:tooltip, group.tooltip)
    |> put_if(:hover_style, group.hover_style)
    |> put_if(:pressed_style, group.pressed_style)
    |> put_if(:focus_style, group.focus_style)
    |> put_if(:show_focus_ring, group.show_focus_ring)
    |> put_if(:focus_ring_radius, group.focus_ring_radius)
    |> put_if(:a11y, group.a11y)
    |> put_if(:focusable, group.focusable)
  end

  defp encode_transforms(map, nil), do: map
  defp encode_transforms(map, []), do: map

  defp encode_transforms(map, transforms) do
    Map.put(map, :transforms, Enum.map(transforms, &Plushie.Encode.encode/1))
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
