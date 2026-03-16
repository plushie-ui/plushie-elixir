defmodule Julep.Event.Sensor do
  @moduledoc "Sensor (resize observer) events."

  @type t :: %__MODULE__{
          type: :resize,
          id: String.t(),
          width: number(),
          height: number()
        }

  defstruct [:type, :id, :width, :height]
end
