defmodule Plushie.Canvas.Shape.Translate do
  @moduledoc "Translation transform for canvas groups."

  @type t :: %__MODULE__{x: number(), y: number()}

  @enforce_keys [:x, :y]
  defstruct [:x, :y]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Translate do
  def encode(t), do: %{type: "translate", x: t.x, y: t.y}
end

defmodule Plushie.Canvas.Shape.Rotate do
  @moduledoc "Rotation transform for canvas groups (angle in radians)."

  @type t :: %__MODULE__{angle: number()}

  @enforce_keys [:angle]
  defstruct [:angle]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Rotate do
  def encode(r), do: %{type: "rotate", angle: r.angle}
end

defmodule Plushie.Canvas.Shape.Scale do
  @moduledoc """
  Scale transform for canvas groups.

  Use `factor` for uniform scaling or `x`/`y` for non-uniform.
  """

  @type t :: %__MODULE__{x: number() | nil, y: number() | nil, factor: number() | nil}

  defstruct [:x, :y, :factor]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Scale do
  def encode(%{factor: f}) when is_number(f), do: %{type: "scale", factor: f}
  def encode(s), do: %{type: "scale", x: s.x || 1, y: s.y || 1}
end
