defmodule Plushie.Type.Gradient do
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

      gradient = Plushie.Type.Gradient.linear(90, [
        {0.0, "#ff0000"},
        {0.5, "#00ff00"},
        {1.0, "#0000ff"}
      ])
  """

  @typedoc "A gradient color stop with offset (0.0-1.0) and color (canonical hex string)."
  @type stop :: %{offset: float(), color: String.t()}

  @typedoc "Gradient specification with type, angle, and color stops."
  @type t :: %{type: String.t(), angle: number(), stops: [stop()]}

  @typedoc "Color input for gradient stops: any `Color.input()` form, or a float RGBA map."
  @type stop_color ::
          Plushie.Type.Color.input() | %{r: float(), g: float(), b: float(), a: float()}

  @doc """
  Creates a linear gradient with an angle (degrees) and a list of
  `{offset, color}` stops. Colors accept any form `Color.cast/1`
  supports (hex strings or named atoms).
  """
  @spec linear(angle :: number(), stops :: [{number(), stop_color()}]) :: t()
  def linear(angle, stops) when is_number(angle) and is_list(stops) do
    %{
      type: "linear",
      angle: angle,
      stops:
        Enum.map(stops, fn {offset, color} when is_number(offset) ->
          %{offset: offset, color: cast_stop_color(color)}
        end)
    }
  end

  # All stop colors are normalized to canonical hex strings via Color.cast.
  # This covers hex strings, named atoms, and float RGBA maps.
  defp cast_stop_color(color), do: Plushie.Type.Color.cast(color)

  @doc "Encodes a gradient to the wire format."
  @spec encode(gradient :: t()) :: t()
  def encode(%{} = gradient), do: gradient
end
