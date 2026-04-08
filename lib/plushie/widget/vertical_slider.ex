defmodule Plushie.Widget.VerticalSlider do
  @moduledoc """
  Vertical slider, vertical range input.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :slider}

  widget :vertical_slider do
    field :range, Plushie.Type.Range, option: false, doc: "`{min, max}` numeric range."
    field :value, :float, option: false, doc: "Current slider value."
    field :step, :float, doc: "Step increment."
    field :shift_step, :float, doc: "Step increment when Shift is held."
    field :default, :float, doc: "Default value (double-click resets to this)."
    field :width, Plushie.Type.Length, doc: "Slider width."
    field :height, Plushie.Type.Length, doc: "Slider height. Default: fill."
    field :rail_color, Plushie.Type.Color, doc: "Color for the slider rail."
    field :rail_width, :float, doc: "Rail thickness in pixels."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :label, :string, doc: "Accessible label for the slider."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:range, :value]
  end

  event :slide, value: :float, doc: "Emitted continuously while dragging."
  event :slide_release, value: :float, doc: "Emitted when drag ends."
end
