defmodule Plushie.Event.WidgetCommandError do
  @moduledoc """
  Renderer error for a native widget command.

  Emitted when the renderer cannot deliver or execute an `widget_command`.

  ## Fields

    * `reason` - machine-readable reason from the renderer
    * `node_id` - target widget node ID
    * `op` - command operation name
    * `extension` - native widget type when known
    * `message` - human-readable error text
  """

  @type t :: %__MODULE__{
          reason: String.t(),
          node_id: String.t() | nil,
          op: String.t() | nil,
          extension: String.t() | nil,
          message: String.t() | nil
        }

  @enforce_keys [:reason]
  defstruct [:reason, :node_id, :op, :extension, :message]
end
