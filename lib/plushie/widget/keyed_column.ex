defmodule Plushie.Widget.KeyedColumn do
  @moduledoc """
  Keyed column layout, arranges children vertically with stable identity keys.

  Like `Column`, but uses each child's `id` as a key for iced's internal
  widget diffing. This avoids unnecessary rebuilds when items are added,
  removed, or reordered in dynamic lists.
  """

  use Plushie.Widget

  widget :keyed_column, container: true do
    field :spacing, :float, doc: "Vertical space between children in pixels. Default: 0."
    field :padding, Plushie.Type.Padding, doc: "Padding inside the column."
    field :width, Plushie.Type.Length, doc: "Column width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Column height. Default: shrink."
    field :max_width, :float, doc: "Maximum width in pixels."
  end
end
