defmodule Plushie.Canvas.Shape.Translate do
  @moduledoc "Translation transform for canvas groups."

  @type t :: %__MODULE__{x: number(), y: number()}

  @enforce_keys [:x, :y]
  defstruct [:x, :y]

  @doc false
  def encode(%__MODULE__{} = t), do: %{type: "translate", x: t.x, y: t.y}
end

defmodule Plushie.Canvas.Shape.Rotate do
  @moduledoc "Rotation transform for canvas groups. Stored as radians internally."

  @type t :: %__MODULE__{angle: number()}

  @enforce_keys [:angle]
  defstruct [:angle]

  @doc false
  def encode(%__MODULE__{} = r), do: %{type: "rotate", angle: r.angle}
end

defmodule Plushie.Canvas.Shape.Scale do
  @moduledoc """
  Scale transform for canvas groups.

  Use `factor` for uniform scaling or `x`/`y` for non-uniform.
  """

  @type t :: %__MODULE__{x: number() | nil, y: number() | nil, factor: number() | nil}

  defstruct [:x, :y, :factor]

  @doc false
  def encode(%{factor: f}) when is_number(f), do: %{type: "scale", factor: f}
  def encode(%__MODULE__{} = s), do: %{type: "scale", x: s.x || 1, y: s.y || 1}
end
