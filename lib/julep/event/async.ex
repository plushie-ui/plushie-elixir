defmodule Julep.Event.Async do
  @moduledoc """
  Results from `Julep.Command.async/2` tasks.

  ## Fields

  - `tag` -- the user-defined atom tag from the command
  - `result` -- `{:ok, value}` on success, `{:error, reason}` on failure

  ## Pattern matching

      def update(model, %Async{tag: :fetch, result: {:ok, data}}), do: ...
      def update(model, %Async{tag: :fetch, result: {:error, reason}}), do: ...

      # Catch all async errors regardless of tag:
      def update(model, %Async{result: {:error, reason}}), do: ...
  """

  @type t :: %__MODULE__{
          tag: atom(),
          result: {:ok, term()} | {:error, term()}
        }

  @enforce_keys [:tag, :result]
  defstruct [:tag, :result]
end
