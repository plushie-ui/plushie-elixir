defmodule Julep.Event.Pane do
  @moduledoc "Pane grid interaction events."

  @type t :: %__MODULE__{
          type: :resized | :dragged | :clicked,
          id: String.t(),
          pane: term(),
          split: term(),
          ratio: number() | nil,
          target: term()
        }

  defstruct [:type, :id, :pane, :split, :ratio, :target]
end
