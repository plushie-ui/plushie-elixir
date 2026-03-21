defmodule Toddy.Canvas.Shape.PushClip do
  @moduledoc "Pushes a clipping rectangle onto the clip stack."

  @type t :: %__MODULE__{x: number(), y: number(), w: number(), h: number()}

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.PushClip do
  def encode(c), do: %{type: "push_clip", x: c.x, y: c.y, w: c.w, h: c.h}
end

defmodule Toddy.Canvas.Shape.PopClip do
  @moduledoc "Pops the most recent clipping rectangle from the clip stack."

  @type t :: %__MODULE__{}

  defstruct []
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.PopClip do
  def encode(_), do: %{type: "pop_clip"}
end
