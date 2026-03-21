defmodule Plushie.Event.Effect do
  @moduledoc """
  Platform effect responses (file dialogs, clipboard, etc.).

  Returned asynchronously after a platform effect command completes. The
  `request_id` correlates the response to the command that triggered it.

  ## Fields

    * `request_id` - the effect identifier from the originating command
    * `result` - one of:
      * `{:ok, value}` -- success. For file dialogs, the value is a map
        with a file path or list of paths. For clipboard reads, it contains
        the clipboard text.
      * `:cancelled` -- the user dismissed a dialog without selecting.
        This is a normal outcome, not an error.
      * `{:error, reason}` -- a platform error (e.g. clipboard unavailable).

  ## Pattern matching

      def update(model, %Effect{request_id: "open-file", result: {:ok, %{"path" => path}}}) do
        load_file(model, path)
      end

      def update(model, %Effect{request_id: "open-file", result: :cancelled}) do
        model  # user changed their mind, nothing to do
      end

      def update(model, %Effect{request_id: _id, result: {:error, reason}}) do
        show_error(model, reason)
      end
  """

  @type t :: %__MODULE__{
          request_id: String.t(),
          result: {:ok, term()} | :cancelled | {:error, term()}
        }

  @enforce_keys [:request_id, :result]
  defstruct [:request_id, :result]
end
