defmodule Plushie.Event.EffectEvent do
  @moduledoc """
  Platform effect responses (file dialogs, clipboard, etc.).

  Returned asynchronously after a platform effect command completes. The
  `tag` identifies which effect this response belongs to; it matches
  the tag you provided when creating the effect command.

  ## Fields

    * `tag` - the atom tag from the originating effect command
    * `result` - one of:
      * `{:ok, value}` - success. For file dialogs, the value is a map
        with a file path or list of paths. For clipboard reads, it contains
        the clipboard text.
      * `:cancelled` - the user dismissed a dialog without selecting.
        This is a normal outcome, not an error.
      * `{:error, reason}` - a platform error (e.g. clipboard unavailable).

  ## Pattern matching

      def update(model, %EffectEvent{tag: :open_file, result: {:ok, %{path: path}}}) do
        load_file(model, path)
      end

      def update(model, %EffectEvent{tag: :open_file, result: :cancelled}) do
        model  # user changed their mind, nothing to do
      end

      def update(model, %EffectEvent{result: {:error, reason}}) do
        show_error(model, reason)
      end
  """

  @type t :: %__MODULE__{
          tag: atom(),
          result: {:ok, term()} | :cancelled | {:error, term()}
        }

  @enforce_keys [:tag, :result]
  defstruct [:tag, :result]
end
