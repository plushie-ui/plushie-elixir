defmodule Plushie.Widget.ProgressBar do
  @moduledoc """
  Progress bar, displays progress within a range.
  """

  use Plushie.Widget

  widget :progress_bar do
    field :range, Plushie.Type.Range, option: false, doc: "`[min, max]` as a two-element list."
    field :value, :float, option: false, doc: "Current progress value."
    field :width, Plushie.Type.Length, doc: "Bar width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Bar height. Default: shrink."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :vertical, :boolean, doc: "When `true`, renders vertically."
    field :label, :string, doc: "Accessible label for the progress bar."

    positional [:range, :value]
  end
end
