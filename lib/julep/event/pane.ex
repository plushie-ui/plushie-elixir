defmodule Julep.Event.Pane do
  @moduledoc """
  Pane grid interaction events.

  Emitted by pane_grid widgets when panes are resized, dragged, or clicked.

  ## Fields

    * `type` - `:resized`, `:dragged`, or `:clicked`
    * `id` - the pane_grid node ID
    * `pane` - identifier of the affected pane
    * `split` - identifier of the split being resized (resized events)
    * `ratio` - new split ratio after resize (0.0 to 1.0)
    * `target` - drop target pane when dragging

  ## Pattern matching

      def update(model, %Pane{type: :resized, id: "editor", split: split, ratio: ratio}) do
        update_split_ratio(model, split, ratio)
      end

      def update(model, %Pane{type: :clicked, id: "editor", pane: pane}) do
        %{model | active_pane: pane}
      end

      def update(model, %Pane{type: :dragged, pane: pane, target: target}) do
        swap_panes(model, pane, target)
      end
  """

  @type t :: %__MODULE__{
          type: :resized | :dragged | :clicked,
          id: String.t(),
          pane: term(),
          split: term(),
          ratio: number() | nil,
          target: term()
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :pane, :split, :ratio, :target]
end
