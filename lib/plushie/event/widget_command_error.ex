defmodule Plushie.Event.WidgetCommandError do
  @moduledoc """
  Renderer error for a native widget command.

  Emitted when the renderer cannot deliver or execute a `widget_command`.

  ## Fields

    * `reason` - machine-readable reason from the renderer
    * `node_id` - target widget node ID
    * `op` - command operation name
    * `widget_type` - native widget type when known
    * `message` - human-readable error text
  """

  @type t :: %__MODULE__{
          reason: String.t(),
          node_id: String.t() | nil,
          op: String.t() | nil,
          widget_type: String.t() | nil,
          message: String.t() | nil
        }

  @enforce_keys [:reason]
  defstruct [:reason, :node_id, :op, :widget_type, :message]
end
