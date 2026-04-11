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
    field :transforms, :any
    field :clip, :any
    field :on_click, :boolean
    field :on_hover, :boolean
    field :draggable, :boolean
    field :drag_axis, :string
    field :drag_bounds, :any
    field :cursor, :string
    field :hit_rect, :any
    field :tooltip, :string
    field :hover_style, :any
    field :pressed_style, :any
    field :focus_style, :any
    field :show_focus_ring, :boolean
    field :focus_ring_radius, :float
    field :a11y, :any
    field :focusable, :boolean
  end
end
