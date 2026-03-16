defmodule Julep.Event.Sensor do
  @moduledoc """
  Sensor (resize observer) events.

  Emitted when a sensor widget detects that its measured dimensions have
  changed. Useful for responsive layouts that need to know their actual
  rendered size.

  ## Fields

    * `type` - always `:resize`
    * `id` - the sensor node ID
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
          width: number(),
          height: number()
        }

  @enforce_keys [:type, :id, :width, :height]
  defstruct [:type, :id, :width, :height]
end
