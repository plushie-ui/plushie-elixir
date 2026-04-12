defmodule Plushie.Event.CommandError do
  @moduledoc """
  Renderer error for a command.

  Emitted when the renderer cannot deliver or execute a command.

  ## Fields

    * `reason` - machine-readable reason from the renderer
    * `id` - target widget ID
    * `family` - command family name
    * `widget_type` - native widget type when known
    * `message` - human-readable error text

  ## Pattern matching

      def update(model, %CommandError{family: family, id: id, message: msg}) do
        Logger.warning("command \#{family} failed on \#{id}: \#{msg}")
        model
      end
  """

  @type t :: %__MODULE__{
          reason: String.t(),
          id: String.t() | nil,
          family: String.t() | nil,
          widget_type: String.t() | nil,
          message: String.t() | nil
        }

  @enforce_keys [:reason]
  defstruct [:reason, :id, :family, :widget_type, :message]
end
