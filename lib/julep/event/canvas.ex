defmodule Julep.Event.Canvas do
  @moduledoc "Canvas widget interaction events."

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
