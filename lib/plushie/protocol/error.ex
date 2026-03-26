defmodule Plushie.Protocol.Error do
  @moduledoc """
  Raised when the renderer sends a protocol message the SDK considers invalid.

  This exception is for internal bridge/runtime use. Normal application code
  should not need to rescue it. A raised protocol error means the SDK and
  renderer are out of sync or one side emitted malformed wire data.
  """

  defexception [:reason, :format, :data, :message]

  @type t :: %__MODULE__{
          reason: Plushie.Protocol.decode_error_reason(),
          format: Plushie.Protocol.format(),
          data: binary(),
          message: String.t()
        }

  @spec exception(keyword()) :: t()
  def exception(opts) do
    reason = Keyword.fetch!(opts, :reason)
    format = Keyword.fetch!(opts, :format)
    data = Keyword.fetch!(opts, :data)

    %__MODULE__{
      reason: reason,
      format: format,
      data: data,
      message: format_message(reason, format)
    }
  end

  defp format_message({:decode_failed, decode_reason}, format) do
    "protocol decode failed for #{format}: #{inspect(decode_reason)}"
  end

  defp format_message({:unknown_message, msg}, _format) do
    "unknown protocol message: #{inspect(msg)}"
  end

  defp format_message({:unknown_event_family, family, _msg}, _format) do
    "unknown event family #{inspect(family)}"
  end

  defp format_message({:invalid_event_field, family, field, value, reason, _msg}, _format) do
    "invalid #{family} event field #{field}: #{inspect(value)} (#{reason})"
  end
end
