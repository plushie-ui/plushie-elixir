defmodule Plushie.Widget.Floating do
  @moduledoc """
  Floating overlay, positions child with optional translation and scaling.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :generic_container}

  widget :float, container: :single do
    field :translate_x, :float, doc: "Horizontal translation in pixels. Default: 0."
    field :translate_y, :float, doc: "Vertical translation in pixels. Default: 0."
    field :scale, :float, doc: "Scale factor for the child content."
    field :width, Plushie.Type.Length, doc: "Float width."
    field :height, Plushie.Type.Length, doc: "Float height."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
