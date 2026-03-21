defmodule Plushie.Canvas.Shape.CanvasText do
  @moduledoc "Canvas text shape with position, content, and optional font styling."

  @type t :: %__MODULE__{
          x: number(),
          y: number(),
          content: String.t(),
          fill: term(),
          size: number() | nil,
          font: String.t() | nil,
          align_x: String.t() | nil,
          align_y: String.t() | nil,
          opacity: number() | nil,
          interactive: Plushie.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:x, :y, :content]
  defstruct [:x, :y, :content, :fill, :size, :font, :align_x, :align_y, :opacity, :interactive]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.CanvasText do
  def encode(text) do
    %{type: "text", x: text.x, y: text.y, content: text.content}
    |> put_if(:fill, text.fill)
    |> put_if(:size, text.size)
    |> put_if(:font, text.font)
    |> put_if(:align_x, text.align_x)
    |> put_if(:align_y, text.align_y)
    |> put_if(:opacity, text.opacity)
    |> put_if(:interactive, text.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
