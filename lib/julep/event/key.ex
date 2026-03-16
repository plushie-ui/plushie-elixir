defmodule Julep.Event.Key do
  @moduledoc """
  Keyboard press and release events.

  ## Pattern matching

      def update(model, %Key{type: :press, key: :escape, captured: false}), do: ...
      def update(model, %Key{type: :press, key: "s", modifiers: %{command: true}}), do: ...
  """

  @type key :: atom() | String.t()
  @type location :: :standard | :left | :right | :numpad

  @type t :: %__MODULE__{
          type: :press | :release,
          key: key(),
          modified_key: key() | nil,
          physical_key: key() | nil,
          location: location(),
          modifiers: Julep.KeyModifiers.t(),
          text: String.t() | nil,
          repeat: boolean(),
          captured: boolean()
        }

  defstruct [
    :type,
    :key,
    :modified_key,
    :physical_key,
    location: :standard,
    modifiers: %Julep.KeyModifiers{},
    text: nil,
    repeat: false,
    captured: false
  ]
end
