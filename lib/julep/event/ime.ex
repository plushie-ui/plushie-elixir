defmodule Julep.Event.Ime do
  @moduledoc "Input Method Editor events from subscriptions."

  @type t :: %__MODULE__{
          type: :opened | :preedit | :commit | :closed,
          text: String.t() | nil,
          cursor: {non_neg_integer(), non_neg_integer()} | nil,
          captured: boolean()
        }

  defstruct [:type, :text, :cursor, captured: false]
end
