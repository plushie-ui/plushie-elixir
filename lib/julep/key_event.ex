defmodule Julep.KeyEvent do
  @moduledoc """
  A keyboard event with all available metadata.

  Wraps the full state of a key press or release as reported by iced. Used
  inside `{:key_press, %KeyEvent{}}` and `{:key_release, %KeyEvent{}}` tuples
  dispatched through `update/2`.

  ## Fields

  - `key` -- the logical key, after layout mapping. Named keys are atoms
    (`:escape`, `:enter`, `:tab`, `:backspace`, etc.); character keys are
    strings (`"a"`, `"A"`, `"1"`, etc.).
  - `modified_key` -- the logical key with modifiers applied. For example,
    Shift+a produces `key: "a"`, `modified_key: "A"`.
  - `physical_key` -- the physical key code, independent of layout. Atoms
    for known codes (e.g. `:key_a`), strings for unknown.
  - `location` -- where the key is on the keyboard: `:standard`, `:left`,
    `:right`, or `:numpad`.
  - `modifiers` -- `%Julep.KeyModifiers{}` snapshot at the time of the event.
  - `text` -- the text produced by this key press, if any. `nil` for
    non-printable keys. Only present on key_press events.
  - `repeat` -- `true` if this is a key repeat (held down). Only present
    on key_press events.
  - `captured` -- `true` if a widget already consumed this event (e.g. a
    TextEditor inserted a Tab character). Use this to avoid double-handling
    events that a focused widget already processed.

  ## Pattern matching

  Match on the key for simple cases:

      def update(model, {:key_press, %KeyEvent{key: :escape, captured: false}}) do
        close(model)
      end

  Use modifiers for shortcuts:

      def update(model, {:key_press, %KeyEvent{key: "s", modifiers: %{command: true}, captured: false}}) do
        save(model)
      end

  Filter out captured events for global hotkeys:

      def update(model, {:key_press, %KeyEvent{captured: true}}) do
        model  # widget already handled it
      end

  Check physical keys for layout-independent bindings (e.g. WASD):

      def update(model, {:key_press, %KeyEvent{physical_key: :key_w}}) do
        move_up(model)
      end
  """

  @type key :: atom() | String.t()
  @type location :: :standard | :left | :right | :numpad

  @type t :: %__MODULE__{
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
