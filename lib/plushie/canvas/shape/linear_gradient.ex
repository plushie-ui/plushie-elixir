defmodule Plushie.Canvas.Shape.LinearGradient do
  @moduledoc "Linear gradient descriptor usable as a canvas fill value."

  @type t :: %__MODULE__{
          from: {number(), number()},
          to: {number(), number()},
          stops: [{number(), String.t()}]
        }

  @enforce_keys [:from, :to, :stops]
  defstruct [:from, :to, :stops]
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
