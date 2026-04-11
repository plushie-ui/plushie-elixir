defmodule Plushie.Canvas.Shape.Interactive do
  @moduledoc """
  Interactive canvas element.

  An `interactive` is a named group that responds to user input. It
  requires an explicit `id` (first positional argument) and supports
  click, hover, drag, focus, and accessibility fields.

  On the wire this encodes as `type: "group"` (the renderer has no
  separate interactive type). The split is purely an SDK-side API
  improvement: `group` is structural, `interactive` is for elements
  that respond to user input.

  ## Example

      interactive "btn", on_click: true, cursor: "pointer" do
        rect(0, 0, 100, 40, fill: "#3498db")
      end
  """

  alias Plushie.Canvas.{Clip, DragBounds, HitRect, ShapeStyle}
  alias Plushie.Canvas.Transform.{Rotate, Scale, Translate}

  @type t :: %__MODULE__{
          children: [term()],
          transforms: [Translate.t() | Rotate.t() | Scale.t()] | nil,
          clip: Clip.t() | nil,
          id: String.t(),
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

  @enforce_keys [:children, :id]
  defstruct [
    :children,
    :id,
    :transforms,
    :clip,
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

  @doc false
  def encode(%__MODULE__{} = interactive) do
    base = %{
      type: "group",
      children: Enum.map(interactive.children, &Plushie.Type.encode_value/1),
      id: interactive.id
    }

    base
    |> encode_transforms(interactive.transforms)
    |> put_if(:clip, interactive.clip)
    |> put_if(:on_click, interactive.on_click)
    |> put_if(:on_hover, interactive.on_hover)
    |> put_if(:draggable, interactive.draggable)
    |> put_if(:drag_axis, interactive.drag_axis)
    |> put_if(:drag_bounds, interactive.drag_bounds)
    |> put_if(:cursor, interactive.cursor)
    |> put_if(:hit_rect, interactive.hit_rect)
    |> put_if(:tooltip, interactive.tooltip)
    |> put_if(:hover_style, interactive.hover_style)
    |> put_if(:pressed_style, interactive.pressed_style)
    |> put_if(:focus_style, interactive.focus_style)
    |> put_if(:show_focus_ring, interactive.show_focus_ring)
    |> put_if(:focus_ring_radius, interactive.focus_ring_radius)
    |> put_if(:a11y, default_a11y(interactive))
    |> put_if(:focusable, interactive.focusable)
  end

  # Inject default a11y for interactive elements that don't have explicit a11y.
  # This ensures interactive canvas elements are visible to AT without
  # requiring full manual annotation.
  defp default_a11y(%__MODULE__{a11y: a11y}) when not is_nil(a11y), do: a11y

  defp default_a11y(%__MODULE__{focusable: true} = el) do
    %{role: "group", label: el.tooltip}
  end

  defp default_a11y(%__MODULE__{on_click: true}) do
    %{role: "button"}
  end

  defp default_a11y(%__MODULE__{draggable: true}) do
    %{role: "slider"}
  end

  defp default_a11y(_el), do: nil

  defp encode_transforms(map, nil), do: map
  defp encode_transforms(map, []), do: map

  defp encode_transforms(map, transforms) do
    Map.put(map, :transforms, Enum.map(transforms, &Plushie.Type.encode_value/1))
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Type.encode_value(val))
end
