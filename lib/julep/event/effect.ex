defmodule Julep.Event.Effect do
  @moduledoc """
  Platform effect responses (file dialogs, clipboard, etc.).

  Returned asynchronously after a platform effect command completes. The
  `request_id` correlates the response to the command that triggered it.

  ## Fields

    * `request_id` - the effect identifier from the originating command
    * `result` - `{:ok, value}` on success or `{:error, reason}` on failure.
      For file dialogs, the ok value is a file path or list of paths.
      For clipboard reads, it is the clipboard text.

  ## Pattern matching

      def update(model, %Effect{request_id: "open-file", result: {:ok, path}}) do
        load_file(model, path)
      end

      def update(model, %Effect{request_id: "paste", result: {:ok, text}}) do
        insert_clipboard(model, text)
      end

      def update(model, %Effect{request_id: _id, result: {:error, reason}}) do
        show_error(model, reason)
      end
  """

  @type t :: %__MODULE__{
          request_id: String.t(),
          result: {:ok, term()} | {:error, term()}
        }

  defstruct [:request_id, :result]
end
