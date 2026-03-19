defmodule Toddy.Event.Stream do
  @moduledoc """
  Intermediate values from `Toddy.Command.stream/2` tasks.

  ## Fields

  - `tag` -- the user-defined atom tag from the command
  - `value` -- the intermediate value emitted by the stream

  ## Pattern matching

      def update(model, %Stream{tag: :download, value: %{progress: p}}), do: ...
      def update(model, %Stream{tag: :search, value: result}), do: ...
  """

  @type t :: %__MODULE__{
          tag: atom(),
          value: term()
        }

  @enforce_keys [:tag, :value]
  defstruct [:tag, :value]
end
