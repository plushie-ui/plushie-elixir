defmodule Plushie.Widget.Overlay.ChildValidation do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      defoverridable build: 1

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_children_count!(
          w.id,
          "overlay",
          Enum.reverse(w.children),
          2
        )

        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Overlay do
  @moduledoc """
  Overlay container, positions the second child as a floating overlay
  relative to the first child (anchor).

  Exactly two children are required:
  1. The anchor widget (rendered inline in the layout).
  2. The overlay content (rendered as a floating overlay above everything else).
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Overlay.ChildValidation

  # No a11y defaults: layout containers are transparent to AT

  widget :overlay, container: true do
    field :position, {:enum, [:below, :above, :left, :right]},
      doc: "Overlay position: `:below`, `:above`, `:left`, `:right`."

    field :gap, :float, doc: "Space between anchor and overlay in pixels. Default: 0."
    field :offset_x, :float, doc: "Horizontal offset in pixels after positioning."
    field :offset_y, :float, doc: "Vertical offset in pixels after positioning."
    field :flip, :boolean, doc: "Auto-flip when content overflows viewport. Default: false."

    field :align, {:enum, [:start, :center, :end]},
      doc: "Cross-axis alignment relative to anchor: `:start`, `:center`, `:end`."

    field :width, Plushie.Type.Length, doc: "Width of the overlay node."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
