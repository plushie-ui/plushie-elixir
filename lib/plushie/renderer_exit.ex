defmodule Plushie.RendererExit do
  @moduledoc "Structured renderer exit reason for handle_renderer_exit/2."

  defexception [:type, :message, :details]

  @type exit_type :: :crash | :connection_lost | :shutdown | :heartbeat_timeout
  @type t :: %__MODULE__{type: exit_type(), message: String.t(), details: term()}
end
