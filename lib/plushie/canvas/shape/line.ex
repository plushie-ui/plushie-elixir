defmodule Plushie.Canvas.Shape.Line do
  @moduledoc "Canvas line shape between two points with optional stroke and opacity."

  @type t :: %__MODULE__{
          x1: number(),
          y1: number(),
          x2: number(),
          y2: number(),
          stroke: term(),
          opacity: number() | nil,
          interactive: Plushie.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:x1, :y1, :x2, :y2]
  defstruct [:x1, :y1, :x2, :y2, :stroke, :opacity, :interactive]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Line do
  def encode(line) do
    %{type: "line", x1: line.x1, y1: line.y1, x2: line.x2, y2: line.y2}
    |> put_if(:stroke, line.stroke)
    |> put_if(:opacity, line.opacity)
    |> put_if(:interactive, line.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
