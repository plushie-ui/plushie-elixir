defmodule Plushie.Canvas.Transform.Translate do
  @moduledoc "Translation transform for canvas groups."

  @type t :: %__MODULE__{x: number(), y: number()}

  @enforce_keys [:x, :y]
  defstruct [:x, :y]

  @doc false
  def encode(%__MODULE__{} = t), do: %{type: "translate", x: t.x, y: t.y}
end
