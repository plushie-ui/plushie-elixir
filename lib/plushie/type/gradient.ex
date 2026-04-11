defmodule Plushie.Type.Gradient do
  @moduledoc """
  Gradient type for container and style backgrounds.

  Build gradients with `linear/3`:

      Plushie.Type.Gradient.linear({0, 0}, {100, 100}, [
        {0.0, "#ff0000"},
        {0.5, "#00ff00"},
        {1.0, "#0000ff"}
      ])

  Or from an angle with `linear_from_angle/2`:

      Plushie.Type.Gradient.linear_from_angle(90, [
        {0.0, "#ff0000"},
        {1.0, "#0000ff"}
      ])

  Stop colors accept any form `Plushie.Type.Color.cast/1` supports
  (named atoms, hex strings, RGBA maps). They are normalized to
  canonical hex strings during construction.

  ## Wire format

  Uses the same coordinate-based format as `Plushie.Canvas.Gradient`:

      %{
        type: "linear",
        start: [0, 0],
        end: [100, 100],
        stops: [[0.0, "#ff0000"], [1.0, "#0000ff"]]
      }
  """

  use Plushie.Type

  @typedoc "A gradient color stop: `{offset, color}` where offset is 0.0-1.0."
  @type stop :: {float(), String.t()}

  @typedoc "Color input for gradient stops: any form `Color.cast/1` supports."
  @type stop_color :: Plushie.Type.Color.input()

  @type t :: %__MODULE__{
          from: {number(), number()},
          to: {number(), number()},
          stops: [stop()]
        }

  @enforce_keys [:from, :to, :stops]
  defstruct [:from, :to, :stops]

  @doc """
  Creates a linear gradient between two coordinate points.
  """
  @spec linear(
          from :: {number(), number()},
          to :: {number(), number()},
          stops :: [{number(), stop_color()}]
        ) :: t()
  def linear(from, to, stops)
      when is_tuple(from) and is_tuple(to) and is_list(stops) do
    %__MODULE__{
      from: from,
      to: to,
      stops: Enum.map(stops, &cast_stop/1)
    }
  end

  @doc """
  Creates a linear gradient from an angle (degrees) and stops.

  The angle is converted to start/end coordinates on a unit square
  (0,0 to 1,1). Use this when you want angle-based gradients without
  computing coordinates manually.
  """
  @spec linear_from_angle(angle :: number(), stops :: [{number(), stop_color()}]) :: t()
  def linear_from_angle(angle, stops) when is_number(angle) and is_list(stops) do
    radians = angle * :math.pi() / 180

    # Project angle onto unit square edges
    dx = :math.cos(radians)
    dy = :math.sin(radians)

    # Center at (0.5, 0.5), extend to edges
    half_len = abs(dx) / 2 + abs(dy) / 2
    cx = 0.5
    cy = 0.5

    from = {cx - dx * half_len, cy - dy * half_len}
    to = {cx + dx * half_len, cy + dy * half_len}

    linear(from, to, stops)
  end

  defp cast_stop({offset, color}) when is_number(offset) do
    {offset, cast_stop_color(color)}
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
  `from`/`to` coordinate tuples and `stops`.
  """
  @impl Plushie.Type
  def cast(%__MODULE__{} = v), do: {:ok, v}

  def cast(%{from: from, to: to, stops: stops})
      when is_tuple(from) and is_tuple(to) and is_list(stops) do
    case validate_stops(stops) do
      {:ok, validated} -> {:ok, %__MODULE__{from: from, to: to, stops: validated}}
      :error -> :error
    end
  end

  def cast(_), do: :error

  defp validate_stops(stops) do
    validated =
      Enum.reduce_while(stops, {:ok, []}, fn
        {offset, color}, {:ok, acc}
        when is_number(offset) and is_binary(color) ->
          {:cont, {:ok, [{offset, color} | acc]}}

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
  def encode(%__MODULE__{} = grad) do
    {fx, fy} = grad.from
    {tx, ty} = grad.to

    stops =
      Enum.map(grad.stops, fn {offset, color} ->
        [offset, Plushie.Type.encode_value(color)]
      end)

    %{type: "linear", start: [fx, fy], end: [tx, ty], stops: stops}
  end
end
