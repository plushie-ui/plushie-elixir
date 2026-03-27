defmodule Plushie.Event.SensorEvent do
  @moduledoc """
  Sensor (resize observer) events.

  Emitted when a sensor widget detects that its measured dimensions have
  changed. Useful for responsive layouts that need to know their actual
  rendered size.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Plushie.Event.target/1` to reconstruct the
  full forward-order scoped path.

  The `window_id` field identifies which window produced the event. Runtime-
  delivered sensor events always include it.

  ## Fields

    * `type` - always `:resize`
    * `id` - the sensor node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
    * `width` - measured width in logical pixels
    * `height` - measured height in logical pixels

  ## Pattern matching

      def update(model, %SensorEvent{type: :resize, id: "content", width: w, height: h}) do
        %{model | content_size: {w, h}}
      end

      def update(model, %SensorEvent{id: "sidebar", width: w}) when w < 200 do
        %{model | sidebar_collapsed: true}
      end
  """

  @typedoc """
  Sensor event struct.

  Hand-built test events may leave `window_id` unset. Events decoded from the
  renderer always include it.
  """
  @type t :: %__MODULE__{
          type: :resize,
          id: String.t(),
          window_id: String.t() | nil,
          scope: [String.t()],
          width: number(),
          height: number()
        }

  @typedoc "Sensor event delivered by the renderer."
  @type delivered_t :: %__MODULE__{
          type: :resize,
          id: String.t(),
          window_id: String.t(),
          scope: [String.t()],
          width: number(),
          height: number()
        }

  @enforce_keys [:type, :id, :width, :height]
  defstruct [:type, :id, :width, :height, :window_id, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Plushie.Event.target(event)

      window =
        if event.window_id, do: " window=#{Kernel.inspect(event.window_id)}", else: ""

      "#SensorEvent<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)}#{window} #{event.width}x#{event.height}>"
    end
  end
end
