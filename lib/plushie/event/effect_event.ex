defmodule Plushie.Event.EffectEvent do
  @moduledoc """
  Platform effect responses (file dialogs, clipboard, notifications).

  Returned asynchronously after a platform effect command completes.
  The `tag` identifies which effect this response belongs to; it
  matches the tag you provided when creating the effect command.

  ## Fields

    * `tag` - the atom tag from the originating effect command
    * `result` - a typed `Plushie.Effect.Result.*` struct
      (e.g. `%FileOpened{path: ...}`, `%Cancelled{}`,
      `%Timeout{}`, `%Error{message: ...}`)

  See `Plushie.Effect.Result` for the full variant list.

  ## Pattern matching

      alias Plushie.Effect.Result

      def update(model, %EffectEvent{tag: :open, result: %Result.FileOpened{path: path}}) do
        load_file(model, path)
      end

      def update(model, %EffectEvent{tag: :open, result: %Result.Cancelled{}}) do
        model
      end

      def update(model, %EffectEvent{result: %Result.Error{message: msg}}) do
        show_error(model, msg)
      end
  """

  @type t :: %__MODULE__{
          tag: atom(),
          result: Plushie.Effect.Result.t()
        }

  @enforce_keys [:tag, :result]
  defstruct [:tag, :result]
end
