defmodule Plushie.Widget.Grid do
  @moduledoc """
  Grid layout, arranges children in a fixed-column grid.
  """

  use Plushie.Widget

  @a11y_defaults %{role: :generic_container}

  widget :grid, container: true do
    field :columns, :integer, doc: "Number of columns. Default: 1."
    field :spacing, :float, doc: "Spacing between grid cells in pixels. Default: 0."
    field :width, :float, doc: "Grid width in pixels."
    field :height, :float, doc: "Grid height in pixels."

    field :column_width, Plushie.Type.Length,
      doc: "Width of each column. Accepts `:fill`, `:shrink`, `{:fill_portion, n}`, or a number."

    field :row_height, Plushie.Type.Length,
      doc: "Height of each row. Accepts `:fill`, `:shrink`, `{:fill_portion, n}`, or a number."

    field :fluid, :float,
      doc: "Enables fluid grid mode. Value is max cell width; columns auto-wrap."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end
end
