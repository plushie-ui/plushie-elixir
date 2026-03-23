defmodule Plushie.Canvas.Shape.Circle do
  @moduledoc "Canvas circle shape with center, radius, and optional styling."

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          r: number(),
          fill: term(),
          stroke: term(),
          opacity: number() | nil,
          fill_rule: String.t() | nil
        }

  @enforce_keys [:x, :y, :r]
  defstruct [:x, :y, :r, :fill, :stroke, :opacity, :fill_rule]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Circle do
  def encode(circle) do
    %{type: "circle", x: circle.x, y: circle.y, r: circle.r}
    |> put_if(:fill, circle.fill)
    |> put_if(:stroke, circle.stroke)
    |> put_if(:opacity, circle.opacity)
    |> put_if(:fill_rule, circle.fill_rule)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
