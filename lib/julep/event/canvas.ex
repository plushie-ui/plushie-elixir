defmodule Julep.Event.Canvas do
  @moduledoc """
  Canvas widget interaction events.

  Emitted when the user interacts with a canvas widget via mouse actions.
  Coordinates are in the canvas's local coordinate space.

  ## Fields

    * `type` - `:press`, `:release`, `:move`, or `:scroll`
    * `id` - the canvas node ID
    * `x`, `y` - cursor position within the canvas
    * `button` - mouse button name (e.g. `"left"`), present on press/release
    * `delta_x`, `delta_y` - scroll deltas, present on scroll events

  ## Pattern matching

      def update(model, %Canvas{type: :press, id: "drawing", button: "left", x: x, y: y}) do
        start_stroke(model, x, y)
      end

      def update(model, %Canvas{type: :move, id: "drawing", x: x, y: y}) do
        continue_stroke(model, x, y)
      end

      def update(model, %Canvas{type: :scroll, id: "viewport", delta_y: dy}) do
        zoom(model, dy)
      end
  """

  @type t :: %__MODULE__{
          type: :press | :release | :move | :scroll,
          id: String.t(),
          x: number(),
          y: number(),
          button: String.t() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  defstruct [:type, :id, :x, :y, :button, :delta_x, :delta_y]
end
