defmodule Julep.Iced.Gradient do
  @moduledoc "Gradient backgrounds."

  @doc "Creates a linear gradient with an angle (radians) and a list of `{offset, color}` stops."
  @spec linear(number(), [{number(), term()}]) :: map()
  def linear(angle, stops) when is_number(angle) and is_list(stops) do
    %{
      type: "linear",
      angle: angle,
      stops: Enum.map(stops, fn {offset, color} -> %{offset: offset, color: color} end)
    }
  end

  @doc "Encodes a gradient to the wire format."
  @spec encode(map()) :: map()
  def encode(%{} = gradient), do: gradient
end
