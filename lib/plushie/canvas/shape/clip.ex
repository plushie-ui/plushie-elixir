defmodule Plushie.Canvas.Shape.PushClip do
  @moduledoc "Pushes a clipping rectangle onto the clip stack."

  @type t :: %__MODULE__{x: number(), y: number(), w: number(), h: number()}

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.PushClip do
  def encode(c), do: %{type: "push_clip", x: c.x, y: c.y, w: c.w, h: c.h}
end

defmodule Plushie.Canvas.Shape.PopClip do
  @moduledoc "Pops the most recent clipping rectangle from the clip stack."

  @type t :: %__MODULE__{}

  defstruct []
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.PopClip do
  def encode(_), do: %{type: "pop_clip"}
end
