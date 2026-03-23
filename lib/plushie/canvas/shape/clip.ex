defmodule Plushie.Canvas.Shape.Clip do
  @moduledoc "Clip rectangle for canvas groups. Children are clipped to this region."

  @type t :: %__MODULE__{x: number(), y: number(), w: number(), h: number()}

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Clip do
  def encode(c), do: %{x: c.x, y: c.y, w: c.w, h: c.h}
end
