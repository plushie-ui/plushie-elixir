defmodule Plushie.Event.ModifiersEvent do
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

      def update(model, %ModifiersEvent{modifiers: %{shift: true}}) do
        %{model | shift_held: true}
      end

      def update(model, %ModifiersEvent{modifiers: mods}) do
        %{model | modifiers: mods}
      end
  """

  @type t :: %__MODULE__{
          modifiers: Plushie.KeyModifiers.t(),
          captured: boolean(),
          window_id: String.t() | nil
        }

  @enforce_keys [:modifiers]
  defstruct [
    :modifiers,
    :window_id,
    captured: false
  ]
end
