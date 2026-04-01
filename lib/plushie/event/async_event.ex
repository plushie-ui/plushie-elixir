defmodule Plushie.Event.AsyncEvent do
  @moduledoc """
  Results from `Plushie.Command.async/2` tasks.

  ## Fields

  - `tag` -- the user-defined atom tag from the command
  - `result` -- `{:ok, value}` on success, `{:error, reason}` on failure

  ## Pattern matching

      def update(model, %AsyncEvent{tag: :fetch, result: {:ok, data}}), do: ...
      def update(model, %AsyncEvent{tag: :fetch, result: {:error, reason}}), do: ...

      # Catch all async errors regardless of tag:
      def update(model, %AsyncEvent{result: {:error, reason}}), do: ...
  """

  @type t :: %__MODULE__{
          tag: atom(),
          result: {:ok, term()} | {:error, term()}
        }

  @enforce_keys [:tag, :result]
  defstruct [:tag, :result]
end
