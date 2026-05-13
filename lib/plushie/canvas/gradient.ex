defmodule Plushie.Canvas.Gradient do
  @moduledoc "Linear gradient descriptor usable as a canvas fill value."

  @type t :: %__MODULE__{
          from: {number(), number()},
          to: {number(), number()},
          stops: [{number(), String.t()}]
        }

  @enforce_keys [:from, :to, :stops]
  defstruct [:from, :to, :stops]

  @known_keys ~w(from to stops)a

  def __field_keys__, do: @known_keys

  def __field_types__, do: %{}

  def from_opts(opts) when is_list(opts) do
    %__MODULE__{
      from: validate_point!(Keyword.fetch!(opts, :from), :from),
      to: validate_point!(Keyword.fetch!(opts, :to), :to),
      stops: validate_stops!(Keyword.get(opts, :stops, []))
    }
  end

  @doc false
  def encode(%__MODULE__{} = grad) do
    {fx, fy} = validate_point!(grad.from, :from)
    {tx, ty} = validate_point!(grad.to, :to)

    stops =
      grad.stops
      |> validate_stops!()
      |> Enum.map(fn {offset, color} ->
        [offset, Plushie.Type.encode_value(color)]
      end)

    %{type: "linear", start: [fx, fy], end: [tx, ty], stops: stops}
  end

  @doc false
  @spec validate_point!(point :: term(), field :: :from | :to) :: {number(), number()}
  def validate_point!({x, y}, _field) when is_number(x) and is_number(y), do: {x, y}

  def validate_point!(point, field) do
    raise ArgumentError,
          "expected gradient #{field} to be {number, number}, got: #{inspect(point)}"
  end

  @doc false
  @spec validate_stops!(stops :: term()) :: [{number(), term()}]
  def validate_stops!(stops) when is_list(stops) do
    Enum.map(stops, fn
      {offset, color} when is_number(offset) ->
        {offset, color}

      other ->
        raise ArgumentError,
              "expected gradient stop to be {number, color}, got: #{inspect(other)}"
    end)
  end

  def validate_stops!(stops) do
    raise ArgumentError,
          "expected gradient stops to be a list, got: #{inspect(stops)}"
  end
end
