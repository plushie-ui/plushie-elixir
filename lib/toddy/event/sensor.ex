defmodule Toddy.Event.Sensor do
  @moduledoc """
  Sensor (resize observer) events.

  Emitted when a sensor widget detects that its measured dimensions have
  changed. Useful for responsive layouts that need to know their actual
  rendered size.

  The `scope` field contains the ancestor scope chain in reverse order
  (nearest parent first). Use `Toddy.Event.target/1` to reconstruct the
  full forward-order scoped path.

  ## Fields

    * `type` - always `:resize`
    * `id` - the sensor node ID
    * `scope` - ancestor scope chain (nearest parent first), default `[]`
    * `width` - measured width in logical pixels
    * `height` - measured height in logical pixels

  ## Pattern matching

      def update(model, %Sensor{type: :resize, id: "content", width: w, height: h}) do
        %{model | content_size: {w, h}}
      end

      def update(model, %Sensor{id: "sidebar", width: w}) when w < 200 do
        %{model | sidebar_collapsed: true}
      end
  """

  @type t :: %__MODULE__{
          type: :resize,
          id: String.t(),
          scope: [String.t()],
          width: number(),
          height: number()
        }

  @enforce_keys [:type, :id, :width, :height]
  defstruct [:type, :id, :width, :height, scope: []]

  defimpl Inspect do
    def inspect(event, _opts) do
      target = Toddy.Event.target(event)

      "#Sensor<#{Kernel.inspect(event.type)} #{Kernel.inspect(target)} #{event.width}x#{event.height}>"
    end
  end
end
