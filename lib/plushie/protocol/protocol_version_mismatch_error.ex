defmodule Plushie.Protocol.ProtocolVersionMismatchError do
  @moduledoc """
  Raised when the renderer's advertised protocol version differs from
  the version the SDK was built against.

  The bridge stops on this condition so the app observes a clean
  shutdown with structured context instead of a raw tuple in a
  GenServer `:stop` reason.

  ## Fields

    * `:expected` - protocol version the SDK was built for.
    * `:got` - protocol version the renderer advertised (may be `nil`
      when the renderer sent no version).
  """

  defexception [:expected, :got, :message]

  @type t :: %__MODULE__{
          expected: non_neg_integer(),
          got: non_neg_integer() | nil,
          message: String.t()
        }

  @spec exception(keyword()) :: t()
  def exception(opts) do
    expected = Keyword.fetch!(opts, :expected)
    got = Keyword.get(opts, :got)

    %__MODULE__{
      expected: expected,
      got: got,
      message: "protocol version mismatch: expected #{expected}, got #{inspect(got)}"
    }
  end
end
