defmodule Toddy.Canvas.Shape.Stroke do
  @moduledoc "Canvas stroke descriptor with color, width, and optional cap/join/dash."

  @type t :: %__MODULE__{
          color: String.t(),
          width: number(),
          cap: String.t() | nil,
          join: String.t() | nil,
          dash: map() | nil
        }

  @enforce_keys [:color, :width]
  defstruct [:color, :width, :cap, :join, :dash]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Stroke do
  def encode(stroke) do
    %{color: Toddy.Encode.encode(stroke.color), width: stroke.width}
    |> put_if(:cap, stroke.cap)
    |> put_if(:join, stroke.join)
    |> put_if(:dash, stroke.dash)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Toddy.Encode.encode(val))
end
