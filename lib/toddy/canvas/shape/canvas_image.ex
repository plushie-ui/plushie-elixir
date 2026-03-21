defmodule Toddy.Canvas.Shape.CanvasImage do
  @moduledoc "Canvas raster image shape with position, size, and optional rotation."

  @type t :: %__MODULE__{
          source: String.t(),
          x: number(),
          y: number(),
          w: number(),
          h: number(),
          rotation: number() | nil,
          opacity: number() | nil,
          interactive: Toddy.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:source, :x, :y, :w, :h]
  defstruct [:source, :x, :y, :w, :h, :rotation, :opacity, :interactive]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.CanvasImage do
  def encode(image) do
    %{type: "image", source: image.source, x: image.x, y: image.y, w: image.w, h: image.h}
    |> put_if(:rotation, image.rotation)
    |> put_if(:opacity, image.opacity)
    |> put_if(:interactive, image.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Toddy.Encode.encode(val))
end
