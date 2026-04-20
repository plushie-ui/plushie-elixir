defmodule Plushie.Transport.BufferOverflowError do
  @moduledoc """
  Raised when a single wire frame exceeds the protocol's per-message
  size cap (64 MiB).

  Emitted by `Plushie.Transport.Framing` when a length prefix or a
  JSONL line declares or delivers more bytes than the cap allows.
  Hosts let it propagate out of the framing layer; continuing past
  this point would either corrupt the stream or grow the process's
  memory unboundedly.

  ## Fields

    * `:size` - offending message size in bytes.
    * `:limit` - configured per-message cap in bytes.
  """

  defexception [:size, :limit, :message]

  @type t :: %__MODULE__{
          size: non_neg_integer(),
          limit: non_neg_integer(),
          message: String.t()
        }

  @spec exception(keyword()) :: t()
  def exception(opts) do
    size = Keyword.fetch!(opts, :size)
    limit = Keyword.fetch!(opts, :limit)

    %__MODULE__{
      size: size,
      limit: limit,
      message: "wire frame of #{size} bytes exceeds #{limit} byte limit"
    }
  end
end
