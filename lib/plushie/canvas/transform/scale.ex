defmodule Plushie.Canvas.Transform.Scale do
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
