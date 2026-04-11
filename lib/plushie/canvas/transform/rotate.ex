defmodule Plushie.Canvas.Transform.Rotate do
  @moduledoc "Rotation transform for canvas groups. Stores radians (converted from degrees by the builder)."

  @type t :: %__MODULE__{angle: number()}

  @enforce_keys [:angle]
  defstruct [:angle]

  @doc false
  def encode(%__MODULE__{} = r), do: %{type: "rotate", angle: r.angle}
end
