defmodule Plushie.Type.Gradient do
  @moduledoc """
  Gradient type for container and style backgrounds.

  Build gradients with `linear/2`:

      Plushie.Type.Gradient.linear(90, [
        {0.0, "#ff0000"},
        {0.5, "#00ff00"},
        {1.0, "#0000ff"}
      ])

  Stop colors accept any form `Plushie.Type.Color.cast/1` supports
  (named atoms, hex strings, RGBA maps). They are normalized to
  canonical hex strings during construction.

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
  """

  use Plushie.Type

  @typedoc "A gradient color stop with offset (0.0-1.0) and color (canonical hex string)."
  @type stop :: %{offset: float(), color: String.t()}

  @typedoc "Color input for gradient stops: any form `Color.cast/1` supports."
  @type stop_color :: Plushie.Type.Color.input()

  @type t :: %__MODULE__{
          type: String.t(),
          angle: number(),
          stops: [stop()]
        }

  defstruct type: "linear", angle: 0, stops: []

  @doc """
  Creates a linear gradient with an angle (degrees) and a list of
  `{offset, color}` stops.
  """
  @spec linear(angle :: number(), stops :: [{number(), stop_color()}]) :: t()
  def linear(angle, stops) when is_number(angle) and is_list(stops) do
    %__MODULE__{
      type: "linear",
      angle: angle,
      stops:
        Enum.map(stops, fn {offset, color} when is_number(offset) ->
          %{offset: offset, color: cast_stop_color(color)}
        end)
    }
  end

  defp cast_stop_color(color) do
    case Plushie.Type.Color.cast(color) do
      {:ok, hex} -> hex
      :error -> raise ArgumentError, "invalid gradient stop color: #{inspect(color)}"
    end
  end

  @doc """
  Validates a gradient value.

  Accepts `%Gradient{}` structs directly, or plain maps with
  `type: "linear"`, `angle: number`, and `stops: [%{offset, color}]`.
  """
  @impl Plushie.Type
  def cast(%__MODULE__{} = v), do: {:ok, v}

  def cast(%{type: "linear", angle: angle, stops: stops})
      when is_number(angle) and is_list(stops) do
    case validate_stops(stops) do
      {:ok, validated} -> {:ok, %__MODULE__{type: "linear", angle: angle, stops: validated}}
      :error -> :error
    end
  end

  def cast(_), do: :error

  defp validate_stops(stops) do
    validated =
      Enum.reduce_while(stops, {:ok, []}, fn
        %{offset: offset, color: color}, {:ok, acc}
        when is_number(offset) and is_binary(color) ->
          {:cont, {:ok, [%{offset: offset, color: color} | acc]}}

        _, _ ->
          {:halt, :error}
      end)

    case validated do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      :error -> :error
    end
  end

  @impl Plushie.Type
  def typespec, do: quote(do: %__MODULE__{})

  @impl Plushie.Type
  def guard(var) do
    mod = __MODULE__
    quote(do: is_struct(unquote(var), unquote(mod)))
  end

  @impl Plushie.Type
  def encode(%__MODULE__{type: type, angle: angle, stops: stops}) do
    %{type: type, angle: angle, stops: stops}
  end
end
