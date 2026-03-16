defmodule Julep.Event.Pane do
  @moduledoc """
  Pane grid interaction events.

  Emitted by pane_grid widgets when panes are resized, dragged, or clicked.

  ## Fields

    * `type` - `:resized`, `:dragged`, `:clicked`, or `:focus_cycle`
    * `id` - the pane_grid node ID
    * `pane` - identifier of the affected pane
    * `split` - identifier of the split being resized (resized events)
    * `ratio` - new split ratio after resize (0.0 to 1.0)
    * `target` - drop target pane when dragging
    * `action` - drag action: `"picked"`, `"dropped"`, or `"canceled"`
    * `region` - drop region: `"center"`, `"top"`, `"bottom"`, `"left"`, `"right"`
    * `edge` - edge drop target: `"top"`, `"bottom"`, `"left"`, `"right"`

  ## Pattern matching

      def update(model, %Pane{type: :resized, split: split, ratio: ratio}) do
        update_split_ratio(model, split, ratio)
      end

      def update(model, %Pane{type: :clicked, pane: pane}) do
        %{model | active_pane: pane}
      end

      def update(model, %Pane{type: :dragged, action: "dropped", pane: pane, target: target}) do
        swap_panes(model, pane, target)
      end

      def update(model, %Pane{type: :focus_cycle, pane: pane}) do
        %{model | focused_pane: pane}
      end
  """

  @type t :: %__MODULE__{
          type: :resized | :dragged | :clicked | :focus_cycle,
          id: String.t(),
          pane: term(),
          split: term(),
          ratio: number() | nil,
          target: term(),
          action: String.t() | nil,
          region: String.t() | nil,
          edge: String.t() | nil
        }

  @enforce_keys [:type, :id]
  defstruct [:type, :id, :pane, :split, :ratio, :target, :action, :region, :edge]
end
