defmodule Plushie.Canvas.Shape.LinearGradient do
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
      from: Keyword.fetch!(opts, :from),
      to: Keyword.fetch!(opts, :to),
      stops: Keyword.get(opts, :stops, [])
    }
  end
end

defimpl Plushie.Encode, for: Plushie.Canvas.Shape.LinearGradient do
  def encode(grad) do
    {fx, fy} = grad.from
    {tx, ty} = grad.to

    stops =
      Enum.map(grad.stops, fn {offset, color} ->
        [offset, Plushie.Encode.encode(color)]
      end)

    %{type: "linear", start: [fx, fy], end: [tx, ty], stops: stops}
  end
end
