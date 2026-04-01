defmodule Plushie.Event.StreamEvent do
  @moduledoc """
  Intermediate values from `Plushie.Command.stream/2` tasks.

  ## Fields

  - `tag` -- the user-defined atom tag from the command
  - `value` -- the intermediate value emitted by the stream

  ## Pattern matching

      def update(model, %StreamEvent{tag: :download, value: %{progress: p}}), do: ...
      def update(model, %StreamEvent{tag: :search, value: result}), do: ...
  """

  @type t :: %__MODULE__{
          tag: atom(),
          value: term()
        }

  @enforce_keys [:tag, :value]
  defstruct [:tag, :value]
end
