defmodule Plushie.Canvas.Shape.CanvasSvg do
  @moduledoc "Canvas SVG shape with position and size."

  @type t :: %__MODULE__{
          source: String.t(),
          x: number(),
          y: number(),
          w: number(),
          h: number()
        }

  @enforce_keys [:source, :x, :y, :w, :h]
  defstruct [:source, :x, :y, :w, :h]

  @doc false
  def encode(%__MODULE__{} = svg) do
    %{type: "svg", source: svg.source, x: svg.x, y: svg.y, w: svg.w, h: svg.h}
  end
end
