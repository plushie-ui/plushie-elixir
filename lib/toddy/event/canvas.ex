defmodule Toddy.Event.Canvas do
  @moduledoc """
  Canvas widget interaction events.

  Emitted when the user interacts with a canvas widget via mouse actions.
  Coordinates are in the canvas's local coordinate space.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Toddy.Event.target/1` to reconstruct the
  full forward-order scoped path.

  ## Fields

    * `type` - `:press`, `:release`, `:move`, or `:scroll`
    * `id` - the canvas node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
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
          scope: [String.t()],
          x: number(),
          y: number(),
          button: String.t() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  @enforce_keys [:type, :id, :x, :y]
  defstruct [:type, :id, :x, :y, :button, :delta_x, :delta_y, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Toddy.Event.target(event)
      "#Canvas<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)} x=#{event.x} y=#{event.y}>"
    end
  end
end
