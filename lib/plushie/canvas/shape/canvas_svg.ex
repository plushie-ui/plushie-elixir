defmodule Plushie.Canvas.Shape.CanvasSvg do
  @moduledoc "Canvas SVG shape with position and size."

  @type t :: %__MODULE__{
          source: String.t(),
          x: number(),
          y: number(),
          w: number(),
          h: number(),
          interactive: Plushie.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:source, :x, :y, :w, :h]
  defstruct [:source, :x, :y, :w, :h, :interactive]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.CanvasSvg do
  def encode(svg) do
    %{type: "svg", source: svg.source, x: svg.x, y: svg.y, w: svg.w, h: svg.h}
    |> put_if(:interactive, svg.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
