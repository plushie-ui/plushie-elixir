defmodule Plushie.Transport do
  @moduledoc """
  Behaviour for renderer transport backends.

  A transport handles the low-level I/O between the bridge and the
  renderer process: opening the connection, sending data, receiving
  incoming messages, and closing the connection.

  Two implementations are provided:

  - `Plushie.Transport.Port` handles `:spawn` (child process via
    Erlang Port) and `:stdio` (BEAM's own stdin/stdout) modes.
  - `Plushie.Transport.IOStream` handles `{:iostream, pid}` mode
    for custom transports (SSH, TCP, WebSocket adapters).
  """

  @type t :: struct()

  @doc """
  Initialize the transport. Returns `{:ok, state}` on success.

  Called once during bridge init to open the connection.
  """
  @callback init(opts :: keyword()) :: {:ok, t()} | {:error, term()}

  @doc """
  Send iodata to the renderer. Returns `{:ok, state}` on success.
  """
  @callback send_data(state :: t(), data :: iodata()) :: {:ok, t()} | {:error, term()}

  @doc """
  Close the transport. Called during terminate.
  """
  @callback close(state :: t()) :: :ok

  @doc """
  Handle an incoming message that may belong to this transport.

  Returns:
  - `{:data, binary, state}` when the message contains renderer data
  - `{:closed, reason, state}` when the transport has closed
  - `:ignore` when the message is not relevant to this transport
  """
  @callback handle_info(message :: term(), state :: t()) ::
              {:data, binary(), t()} | {:closed, term(), t()} | :ignore

  @doc """
  Whether the transport supports restart (e.g. re-spawning the binary).

  Only `:spawn` mode supports this. Stdio and iostream transports
  cannot be restarted because they don't own the renderer lifecycle.
  """
  @callback restartable?(state :: t()) :: boolean()

  @doc """
  Whether the transport is ready to accept outgoing data.
  """
  @callback transport_ready?(state :: t()) :: boolean()

  @doc """
  Re-open the transport connection (e.g. after crash or dev rebuild).

  Only meaningful for transports where `restartable?/1` returns `true`.
  Returns `{:ok, new_state}` or `{:error, reason}`.
  """
  @callback reopen(state :: t()) :: {:ok, t()} | {:error, term()}

  @optional_callbacks [reopen: 1]
end
