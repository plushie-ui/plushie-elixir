defmodule Plushie.Widget.PaneGrid.PanesCoercion do
  @moduledoc false

  # Overrides panes/2 to coerce atom pane identifiers to strings.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable panes: 2

      @doc "Sets the list of pane identifiers. Atoms are coerced to strings."
      def panes(%__MODULE__{} = pg, panes) when is_list(panes),
        do: %{pg | panes: Enum.map(panes, &to_string/1)}
    end
  end
end

defmodule Plushie.Widget.PaneGrid do
  @moduledoc """
  Pane grid, resizable tiled panes.

  Children are keyed by their node ID and rendered as individual panes.
  The renderer manages an internal `pane_grid::State` cache.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.PaneGrid.PanesCoercion

  widget :pane_grid, container: true do
    field :panes, {:list, :string}, doc: "List of pane identifiers."
    field :spacing, :float, doc: "Space between panes in pixels. Default: 2."
    field :width, Plushie.Type.Length, doc: "Grid width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Grid height. Default: fill."
    field :min_size, :float, doc: "Minimum pane size in pixels. Default: 10."
    field :divider_color, Plushie.Type.Color, doc: "Color for the split divider."
    field :divider_width, :float, doc: "Divider thickness in pixels."
    field :leeway, :float, doc: "Grabbable area around dividers in pixels."
  end

  event :pane_clicked, doc: "Emitted when a pane is selected."

  event :pane_resized,
    fields: [split: :string, ratio: :float],
    doc: "Emitted when a split divider is moved."

  event :pane_dragged, doc: "Emitted during pane drag operations."
  event :pane_focus_cycle, doc: "Emitted on F6/Shift+F6 focus cycling."
end
