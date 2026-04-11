defmodule Plushie.Canvas.Transform.Rotate do
  @moduledoc "Rotation transform for canvas groups. Stored as radians internally."

  @type t :: %__MODULE__{angle: number()}

  @enforce_keys [:angle]
  defstruct [:angle]

  @doc false
  def encode(%__MODULE__{} = r), do: %{type: "rotate", angle: r.angle}
end
