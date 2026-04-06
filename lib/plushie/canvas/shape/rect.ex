defmodule Plushie.Canvas.Shape.Rect do
  @moduledoc "Canvas rectangle shape with position, size, and optional styling."

  @type radius ::
          number()
          | %{
              top_left: number(),
              top_right: number(),
              bottom_right: number(),
              bottom_left: number()
            }

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          w: number(),
          h: number(),
          fill: term(),
          stroke: term(),
          opacity: number() | nil,
          fill_rule: String.t() | nil,
          radius: radius() | nil
        }

  @enforce_keys [:x, :y, :w, :h]
  defstruct [:x, :y, :w, :h, :fill, :stroke, :opacity, :fill_rule, :radius]

  @doc false
  def encode(%__MODULE__{} = rect) do
    %{type: "rect", x: rect.x, y: rect.y, w: rect.w, h: rect.h}
    |> put_if(:fill, rect.fill)
    |> put_if(:stroke, rect.stroke)
    |> put_if(:opacity, rect.opacity)
    |> put_if(:fill_rule, rect.fill_rule)
    |> put_if(:radius, rect.radius)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Type.encode_value(val))
end
