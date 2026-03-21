defmodule Toddy.Canvas.Shape.Path do
  @moduledoc "Canvas arbitrary path shape built from a list of drawing commands."

  @type t :: %__MODULE__{
          commands: [list() | String.t()],
          fill: term(),
          stroke: term(),
          opacity: number() | nil,
          fill_rule: String.t() | nil,
          interactive: Toddy.Canvas.Shape.Interactive.t() | nil
        }

  @enforce_keys [:commands]
  defstruct [:commands, :fill, :stroke, :opacity, :fill_rule, :interactive]
end

defimpl Toddy.Encode, for: Toddy.Canvas.Shape.Path do
  def encode(path) do
    %{type: "path", commands: Enum.map(path.commands, &Toddy.Encode.encode/1)}
    |> put_if(:fill, path.fill)
    |> put_if(:stroke, path.stroke)
    |> put_if(:opacity, path.opacity)
    |> put_if(:fill_rule, path.fill_rule)
    |> put_if(:interactive, path.interactive)
  end

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, val), do: Map.put(map, key, Toddy.Encode.encode(val))
end
