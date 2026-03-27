defmodule Plushie.Event.PaneEvent do
  @moduledoc """
  Pane grid interaction events.

  Emitted by pane_grid widgets when panes are resized, dragged, or clicked.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  The `window_id` field identifies which window produced the event. Runtime-
  delivered pane events always include it.

  ## Fields

    * `type` - `:resized`, `:dragged`, `:clicked`, or `:focus_cycle`
    * `id` - the pane_grid node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
    * `pane` - identifier of the affected pane
    * `split` - identifier of the split being resized (resized events)
    * `ratio` - new split ratio after resize (0.0 to 1.0)
    * `target` - drop target pane when dragging
    * `action` - drag action: `:picked`, `:dropped`, or `:canceled`
    * `region` - drop region: `:center`, `:top`, `:bottom`, `:left`, or `:right`
    * `edge` - edge drop target: `:top`, `:bottom`, `:left`, or `:right`

  ## Pattern matching

      def update(model, %PaneEvent{type: :resized, split: split, ratio: ratio}) do
        update_split_ratio(model, split, ratio)
      end

      def update(model, %PaneEvent{type: :clicked, pane: pane}) do
        %{model | active_pane: pane}
      end

      def update(model, %PaneEvent{type: :dragged, action: :dropped, pane: pane, target: target}) do
        swap_panes(model, pane, target)
      end

      def update(model, %PaneEvent{type: :focus_cycle, pane: pane}) do
        %{model | focused_pane: pane}
      end
  """

  @type action :: :picked | :dropped | :canceled
  @type region :: :center | :top | :bottom | :left | :right

  @typedoc """
  Pane event struct.

  Hand-built test events may leave `window_id` unset. Events decoded from the
  renderer always include it.
  """
  @type t :: %__MODULE__{
          type: :resized | :dragged | :clicked | :focus_cycle,
          id: String.t(),
          window_id: String.t() | nil,
          scope: [String.t()],
          pane: term(),
          split: term(),
          ratio: number() | nil,
          target: term(),
          action: action() | nil,
          region: region() | nil,
          edge: :top | :bottom | :left | :right | nil
        }

  @typedoc "Pane event delivered by the renderer."
  @type delivered_t :: %__MODULE__{
          type: :resized | :dragged | :clicked | :focus_cycle,
          id: String.t(),
          window_id: String.t(),
          scope: [String.t()],
          pane: term(),
          split: term(),
          ratio: number() | nil,
          target: term(),
          action: action() | nil,
          region: region() | nil,
          edge: :top | :bottom | :left | :right | nil
        }

  @enforce_keys [:type, :id]
  defstruct [
    :type,
    :id,
    :pane,
    :split,
    :ratio,
    :target,
    :action,
    :region,
    :edge,
    :window_id,
    scope: []
  ]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)

      window =
        if event.window_id, do: " window=#{Kernel.inspect(event.window_id)}", else: ""

      "#PaneEvent<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)}#{window}>"
    end
  end
end
