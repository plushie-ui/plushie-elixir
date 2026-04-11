defmodule Plushie.Canvas.Path do
  @moduledoc "Canvas arbitrary path element built from a list of drawing commands."

  use Plushie.Canvas.Element

  element :path do
    field :commands, {:list, :any}, doc: "List of path commands (move_to, line_to, etc.)."
    field :fill, :any, doc: "Fill color or gradient."
    field :stroke, Plushie.Canvas.Stroke, doc: "Stroke descriptor."
    field :opacity, :float, doc: "Opacity from 0.0 to 1.0."
    field :fill_rule, :string, doc: "Fill rule: \"non_zero\" or \"even_odd\"."
  end
end
