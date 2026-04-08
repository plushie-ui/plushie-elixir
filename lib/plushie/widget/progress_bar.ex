defmodule Plushie.Widget.ProgressBar do
  @moduledoc """
  Progress bar, displays progress within a range.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :progress_indicator}

  widget :progress_bar do
    field :range, Plushie.Type.Range, option: false, doc: "`[min, max]` as a two-element list."
    field :value, :float, option: false, doc: "Current progress value."
    field :width, Plushie.Type.Length, doc: "Bar width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Bar height. Default: shrink."
    field :style, Plushie.Type.Style, doc: "Named preset or custom `StyleMap`."
    field :vertical, :boolean, doc: "When `true`, renders vertically."
    field :label, :string, doc: "Accessible label for the progress bar."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."

    positional [:range, :value]
  end
end
