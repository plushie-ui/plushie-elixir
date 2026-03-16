defmodule Julep.Event.Effect do
  @moduledoc """
  Platform effect responses (file dialogs, clipboard, etc.).

  Returned asynchronously after a platform effect command completes. The
  `id` correlates the response to the command that triggered it.

  ## Fields

    * `id` - the effect identifier from the originating command
    * `result` - `{:ok, value}` on success or `{:error, reason}` on failure.
      For file dialogs, the ok value is a file path or list of paths.
      For clipboard reads, it is the clipboard text.

  ## Pattern matching

      def update(model, %Effect{id: "open-file", result: {:ok, path}}) do
        load_file(model, path)
      end

      def update(model, %Effect{id: "paste", result: {:ok, text}}) do
        insert_clipboard(model, text)
      end

      def update(model, %Effect{id: _id, result: {:error, reason}}) do
        show_error(model, reason)
      end
  """

  @type t :: %__MODULE__{
          id: String.t(),
          result: {:ok, term()} | {:error, term()}
        }

  defstruct [:id, :result]
end
