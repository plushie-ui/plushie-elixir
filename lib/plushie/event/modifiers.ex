defmodule Plushie.Event.Modifiers do
  @moduledoc """
  Keyboard modifier state change event.

  Emitted when the set of held modifier keys changes (e.g. pressing or
  releasing Shift, Ctrl, Alt, or Command/Super). Useful for updating UI
  hints that depend on modifier state without waiting for a key event.

  ## Fields

    * `modifiers` - a `Plushie.KeyModifiers` struct with boolean fields for
      `shift`, `ctrl`, `alt`, `command`, and `logo`
    * `captured` - whether a subscription captured this event

  ## Pattern matching

      def update(model, %Modifiers{modifiers: %{shift: true}}) do
        %{model | shift_held: true}
      end

      def update(model, %Modifiers{modifiers: mods}) do
        %{model | modifiers: mods}
      end
  """

  @type t :: %__MODULE__{
          modifiers: Plushie.KeyModifiers.t(),
          captured: boolean()
        }

  @enforce_keys [:modifiers]
  defstruct [
    :modifiers,
    captured: false
  ]
end
