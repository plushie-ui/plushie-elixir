defmodule Plushie.Canvas.Interactive do
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

  use Plushie.Canvas.Element

  element :interactive, container: true, wire_type: :group do
    field :transforms, :any, doc: "List of transform descriptors."
    field :clip, :any, doc: "Clip rectangle."
    field :on_click, :boolean, doc: "Enable click events."
    field :on_hover, :boolean, doc: "Enable hover events."
    field :draggable, :boolean, doc: "Enable drag events."
    field :drag_axis, {:enum, [:x, :y, :both]}, doc: "Constrain drag to an axis."
    field :drag_bounds, Plushie.Canvas.DragBounds, doc: "Drag boundary constraints."
    field :cursor, :string, doc: "CSS cursor on hover (e.g. \"pointer\", \"grab\")."
    field :hit_rect, Plushie.Canvas.HitRect, doc: "Explicit hit test rectangle."
    field :tooltip, :string, doc: "Tooltip text on hover."
    field :hover_style, Plushie.Canvas.ShapeStyle, doc: "Style overrides on hover."
    field :pressed_style, Plushie.Canvas.ShapeStyle, doc: "Style overrides when pressed."
    field :focus_style, Plushie.Canvas.ShapeStyle, doc: "Style overrides when focused."
    field :show_focus_ring, :boolean, doc: "Show the default focus ring."
    field :focus_ring_radius, :float, doc: "Focus ring corner radius in pixels."
    field :a11y, :any, doc: "Accessibility annotations (role, label, etc.)."
    field :focusable, :boolean, doc: "Add to the Tab focus order."
  end
end
