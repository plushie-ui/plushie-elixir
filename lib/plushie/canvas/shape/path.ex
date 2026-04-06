defmodule Plushie.Canvas.Shape.Path do
  @moduledoc "Canvas arbitrary path shape built from a list of drawing commands."

  @type t :: %__MODULE__{
          commands: [list() | String.t()],
          fill: term(),
          stroke: term(),
          opacity: number() | nil,
          fill_rule: String.t() | nil
        }

  @enforce_keys [:commands]
  defstruct [:commands, :fill, :stroke, :opacity, :fill_rule]

  @doc false
  def encode(%__MODULE__{} = path) do
    %{type: "path", commands: Enum.map(path.commands, &Plushie.Type.encode_value/1)}
    |> put_if(:fill, path.fill)
    |> put_if(:stroke, path.stroke)
    |> put_if(:opacity, path.opacity)
    |> put_if(:fill_rule, path.fill_rule)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Plushie.Type.encode_value(val))
end
