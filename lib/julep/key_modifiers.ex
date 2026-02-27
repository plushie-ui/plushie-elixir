defmodule Julep.KeyModifiers do
  @moduledoc """
  Keyboard modifier state at the time of a key event.

  Each field is a boolean indicating whether that modifier was held.

  ## Fields

  - `ctrl` -- Control key (Ctrl on Windows/Linux).
  - `shift` -- Shift key.
  - `alt` -- Alt key (Option on macOS).
  - `logo` -- Logo/Super key (Windows key, Command symbol on macOS).
  - `command` -- Platform command key (Ctrl on Windows/Linux, Cmd on macOS).

  ## Example

      %Julep.KeyModifiers{ctrl: true, shift: false, alt: false, logo: false, command: true}

  Use the query functions for readable conditional logic:

      if KeyModifiers.ctrl?(event.modifiers) do
        handle_shortcut(event)
      end
  """

  @type t :: %__MODULE__{
          ctrl: boolean(),
          shift: boolean(),
          alt: boolean(),
          logo: boolean(),
          command: boolean()
        }

  defstruct ctrl: false, shift: false, alt: false, logo: false, command: false

  @doc "Returns true if the Ctrl modifier is active."
  @spec ctrl?(modifiers :: t()) :: boolean()
  def ctrl?(%__MODULE__{ctrl: v}), do: v

  @doc "Returns true if the Shift modifier is active."
  @spec shift?(modifiers :: t()) :: boolean()
  def shift?(%__MODULE__{shift: v}), do: v

  @doc "Returns true if the Alt modifier is active."
  @spec alt?(modifiers :: t()) :: boolean()
  def alt?(%__MODULE__{alt: v}), do: v

  @doc "Returns true if the Logo/Super modifier is active."
  @spec logo?(modifiers :: t()) :: boolean()
  def logo?(%__MODULE__{logo: v}), do: v

  @doc "Returns true if the platform Command modifier is active."
  @spec command?(modifiers :: t()) :: boolean()
  def command?(%__MODULE__{command: v}), do: v
end
