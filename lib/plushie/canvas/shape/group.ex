defmodule Plushie.Canvas.Shape.Group do
  @moduledoc "Canvas group shape that nests child shapes with optional positioning."

  @type t :: %__MODULE__{
          children: [term()],
          x: number() | nil,
          y: number() | nil,
          interactive: Plushie.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:children]
  defstruct [:children, :x, :y, :interactive]
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.Group do
  def encode(group) do
    %{type: "group", children: Enum.map(group.children, &Plushie.Encode.encode/1)}
    |> put_if(:x, group.x)
    |> put_if(:y, group.y)
    |> put_if(:interactive, group.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Encode.encode(val))
end
