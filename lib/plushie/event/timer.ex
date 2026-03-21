defmodule Plushie.Event.Timer do
  @moduledoc """
  Timer tick events from `Plushie.Subscription.every/2`.

  ## Fields

  - `tag` -- the user-defined atom tag from the subscription registration
  - `timestamp` -- monotonic timestamp in milliseconds

  ## Pattern matching

      def update(model, %Timer{tag: :tick}), do: %{model | ticks: model.ticks + 1}
      def update(model, %Timer{tag: :animate, timestamp: ts}), do: animate(model, ts)
  """

  @type t :: %__MODULE__{
          tag: atom(),
          timestamp: integer()
        }

  @enforce_keys [:tag, :timestamp]
  defstruct [:tag, :timestamp]
end
