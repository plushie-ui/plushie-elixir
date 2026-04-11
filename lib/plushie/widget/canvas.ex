defmodule Plushie.Widget.Canvas do
  @moduledoc """
  Canvas for drawing shapes, organized into named layers.

  Canvas is a container widget. Its children are `Plushie.Canvas.Layer`
  elements, each holding shape children. Each layer maps to an iced
  `Cache` on the Rust side; only changed layers are re-tessellated.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :canvas}

  widget :canvas, container: true do
    field :width, Plushie.Type.Length, doc: "Canvas width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Canvas height. Default: 200px."
    field :background, Plushie.Type.Color, doc: "Canvas background color."
    field :interactive, :boolean, doc: "Enable all mouse event handlers. Default: false."
    field :on_press, :boolean, doc: "Enable mouse press events. Default: false."
    field :on_release, :boolean, doc: "Enable mouse release events. Default: false."
    field :on_move, :boolean, doc: "Enable mouse move events. Default: false."
    field :on_scroll, :boolean, doc: "Enable mouse scroll events. Default: false."
    field :alt, :string, doc: "Accessible label for the canvas."
    field :description, :string, doc: "Extended accessible description."
    field :role, :string, doc: "Accessible role (e.g. \"radiogroup\", \"toolbar\")."
    field :arrow_mode, :string, doc: "Arrow key navigation mode: \"wrap\", \"clamp\", etc."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
