defmodule Julep.Event.Effect do
  @moduledoc "Platform effect responses (file dialogs, clipboard, etc.)."

  @type t :: %__MODULE__{
          id: String.t(),
          result: {:ok, term()} | {:error, term()}
        }

  defstruct [:id, :result]
end
