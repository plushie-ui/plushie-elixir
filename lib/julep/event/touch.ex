defmodule Julep.Event.Touch do
  @moduledoc "Touch events from subscriptions."

  @type t :: %__MODULE__{
          type: :pressed | :moved | :lifted | :lost,
          finger_id: term(),
          x: number(),
          y: number(),
          captured: boolean()
        }

  defstruct [:type, :finger_id, :x, :y, captured: false]
end
