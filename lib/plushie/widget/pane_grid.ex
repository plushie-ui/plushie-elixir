defmodule Plushie.Widget.PaneGrid.PanesCoercion do
  @moduledoc false

  # Overrides panes/2 to coerce atom pane identifiers to strings.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable panes: 2

      @doc "Sets the list of pane identifiers. Atoms are coerced to strings."
      def panes(%__MODULE__{} = pg, nil), do: %{pg | panes: nil}

      def panes(%__MODULE__{} = pg, panes) when is_list(panes),
        do: %{pg | panes: Enum.map(panes, &normalize_pane_id!(pg.id, &1))}

      def panes(%__MODULE__{} = pg, panes) do
        raise ArgumentError,
              "pane_grid #{inspect(pg.id)}: panes must be a list of strings or atoms, got: #{inspect(panes)}"
      end

      defp normalize_pane_id!(_id, pane) when is_binary(pane), do: pane
      defp normalize_pane_id!(_id, pane) when is_atom(pane), do: Atom.to_string(pane)

      defp normalize_pane_id!(id, pane) do
        raise ArgumentError,
              "pane_grid #{inspect(id)}: pane identifiers must be strings or atoms, got: #{inspect(pane)}"
      end
    end
  end
end

defmodule Plushie.Widget.PaneGrid do
  @moduledoc """
  Pane grid, resizable tiled panes.

  Children are keyed by their node ID and rendered as individual panes.
  The renderer manages an internal `pane_grid::State` cache.

  ## Accessibility

  The pane grid itself does not expose a semantic role to assistive
  technology. To make the grid navigable by screen readers, wrap it
  in a `container` with an explicit role and label:

      container "editor-panes" do
        a11y do
          role :group
          label "Editor panes"
        end

        pane_grid "grid", panes: ["left", "right"] do
          text_input "left", model.left
          text_input "right", model.right
        end
      end

  Individual panes can carry their own `a11y` annotations for
  further context (e.g., `label` describing each pane's purpose).
  The `pane_focus_cycle` event (F6/Shift+F6) provides keyboard
  navigation between panes.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.PaneGrid.PanesCoercion

  @a11y_defaults %{role: :group}

  widget :pane_grid, container: true do
    field :panes, {:list, :string}, doc: "List of pane identifiers."
    field :spacing, :float, doc: "Space between panes in pixels. Default: 2."
    field :width, Plushie.Type.Length, doc: "Grid width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Grid height. Default: fill."
    field :min_size, :float, doc: "Minimum pane size in pixels. Default: 10."
    field :divider_color, Plushie.Type.Color, doc: "Color for the split divider."
    field :divider_width, :float, doc: "Divider thickness in pixels."
    field :leeway, :float, doc: "Grabbable area around dividers in pixels."

    field :split_axis, {:enum, [:horizontal, :vertical]}, doc: "Split axis for initial layout."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, default: @a11y_defaults, doc: "Accessibility annotations."
  end

  event :pane_clicked, doc: "Emitted when a pane is selected."

  event :pane_resized,
    fields: [split: :string, ratio: :float],
    doc: "Emitted when a split divider is moved."

  event :pane_dragged, doc: "Emitted during pane drag operations."
  event :pane_focus_cycle, doc: "Emitted on F6/Shift+F6 focus cycling."
end
