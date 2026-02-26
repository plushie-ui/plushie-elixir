defmodule Julep.Iced.Gradient do
  @moduledoc """
  Gradient backgrounds for container widgets.

  Used via the `background` prop on containers. The renderer parses
  gradient maps and converts them to `iced::gradient::Linear`.

  ## Wire format

      %{
        type: "linear",
        angle: 45,
        stops: [
          %{offset: 0.0, color: "#ff0000"},
          %{offset: 1.0, color: "#0000ff"}
        ]
      }

  `angle` is in degrees (converted to radians by the renderer).

  ## Example

      gradient = Julep.Iced.Gradient.linear(90, [
        {0.0, "#ff0000"},
        {0.5, "#00ff00"},
        {1.0, "#0000ff"}
      ])
  """

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
