defmodule Toddy.Canvas.Shape.PushTransform do
  @moduledoc "Pushes the current transform state onto the stack."

  @type t :: %__MODULE__{}

  defstruct []
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.PushTransform do
  def encode(_), do: %{type: "push_transform"}
end

defmodule Toddy.Canvas.Shape.PopTransform do
  @moduledoc "Pops the previously saved transform state from the stack."

  @type t :: %__MODULE__{}

  defstruct []
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.PopTransform do
  def encode(_), do: %{type: "pop_transform"}
end

defmodule Toddy.Canvas.Shape.Translate do
  @moduledoc "Translates the canvas coordinate origin."

  @type t :: %__MODULE__{x: number(), y: number()}

  @enforce_keys [:x, :y]
  defstruct [:x, :y]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Translate do
  def encode(t), do: %{type: "translate", x: t.x, y: t.y}
end

defmodule Toddy.Canvas.Shape.Rotate do
  @moduledoc "Rotates the canvas coordinate system by an angle in radians."

  @type t :: %__MODULE__{angle: number()}

  @enforce_keys [:angle]
  defstruct [:angle]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Rotate do
  def encode(r), do: %{type: "rotate", angle: r.angle}
end

defmodule Toddy.Canvas.Shape.Scale do
  @moduledoc "Scales the canvas coordinate system."

  @type t :: %__MODULE__{x: number(), y: number()}

  @enforce_keys [:x, :y]
  defstruct [:x, :y]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Scale do
  def encode(s), do: %{type: "scale", x: s.x, y: s.y}
end
