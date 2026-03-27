defmodule Plushie.Event.CanvasEvent do
  @moduledoc """
  Canvas widget interaction events.

  Emitted when the user interacts with a canvas widget via mouse actions.
  Coordinates are in the canvas's local coordinate space.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  The `window_id` field identifies which window produced the event. Runtime-
  delivered canvas events always include it.

  ## Fields

    * `type` - `:press`, `:release`, `:move`, or `:scroll`
    * `id` - the canvas node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
    * `x`, `y` - cursor position within the canvas
    * `button` - mouse button name (e.g. `"left"`), present on press/release
    * `delta_x`, `delta_y` - scroll deltas, present on scroll events

  ## Pattern matching

      def update(model, %CanvasEvent{type: :press, id: "drawing", button: "left", x: x, y: y}) do
        start_stroke(model, x, y)
      end

      def update(model, %CanvasEvent{type: :move, id: "drawing", x: x, y: y}) do
        continue_stroke(model, x, y)
      end

      def update(model, %CanvasEvent{type: :scroll, id: "viewport", delta_y: dy}) do
        zoom(model, dy)
      end
  """

  @typedoc """
  Canvas event struct.

  Hand-built test events may leave `window_id` unset. Events decoded from the
  renderer always include it.
  """
  @type t :: %__MODULE__{
          type: :press | :release | :move | :scroll,
          id: String.t(),
          window_id: String.t() | nil,
          scope: [String.t()],
          x: number(),
          y: number(),
          button: String.t() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  @typedoc "Canvas event delivered by the renderer."
  @type delivered_t :: %__MODULE__{
          type: :press | :release | :move | :scroll,
          id: String.t(),
          window_id: String.t(),
          scope: [String.t()],
          x: number(),
          y: number(),
          button: String.t() | nil,
          delta_x: number() | nil,
          delta_y: number() | nil
        }

  @enforce_keys [:type, :id, :x, :y]
  defstruct [:type, :id, :x, :y, :button, :delta_x, :delta_y, :window_id, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)

      window =
        if event.window_id, do: " window=#{Kernel.inspect(event.window_id)}", else: ""

      "#CanvasEvent<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)}#{window} x=#{event.x} y=#{event.y}>"
    end
  end
end
