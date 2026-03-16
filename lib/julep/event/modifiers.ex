defmodule Julep.Event.Modifiers do
  @moduledoc "Keyboard modifier state change event."

  @type t :: %__MODULE__{
          modifiers: Julep.KeyModifiers.t(),
          captured: boolean()
        }

  defstruct [
    modifiers: %Julep.KeyModifiers{},
    captured: false
  ]
end
