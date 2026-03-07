defmodule Julep.Effects do
  @moduledoc """
  Native platform effect requests.

  Effects are asynchronous I/O operations that require the renderer to
  interact with the OS on behalf of the Elixir app -- file dialogs,
  clipboard access, notifications, and similar.

  Each function returns a `Julep.Command` struct. Dispatch it from
  `update/2` like any other command. The result arrives later as an
  `{:effect_result, id, result}` event in `update/2`. The `id` is
  auto-generated internally and embedded in the command payload. Match
  on it in the result event if you need to correlate requests and
  responses.

  The result is `{:ok, value}` on success or `{:error, reason}` on failure.

  ## Cargo feature gates

  Effect support in the Rust renderer is gated behind Cargo features.
  By default, all features are enabled. To build a minimal renderer
  without OS-level features, disable them at build time:

  - `dialogs` -- file open/save/directory dialogs (uses `rfd` crate).
  - `clipboard` -- clipboard read/write (uses `arboard` crate).
  - `notifications` -- OS notifications (uses `notify-rust` crate).

  If a feature is disabled, the renderer returns `{:error, "unsupported"}`
  for the corresponding effect requests.

  ## Example

      def update(model, {:click, "open"}) do
        cmd = Julep.Effects.file_open(title: "Pick a file")
        {model, cmd}
      end

      def update(model, {:effect_result, _id, {:ok, result}}) do
        %{model | file: result}
      end
  """

  @doc """
  Generic effect request. Returns a command struct.

  `kind` is an atom identifying the effect type. `opts` is a keyword list
  of parameters sent as the effect payload. The effect ID is auto-generated
  and stored in the command's payload as `:id`.
  """
  @spec request(kind :: atom(), opts :: keyword()) :: Julep.Command.t()
  def request(kind, opts \\ []) do
    id = generate_id()
    payload = Map.new(opts)

    %Julep.Command{
      type: :effect_request,
      payload: %{id: id, kind: to_string(kind), opts: payload}
    }
  end

  @doc "Open-file dialog. Returns a command."
  @spec file_open(opts :: keyword()) :: Julep.Command.t()
  def file_open(opts \\ []), do: request(:file_open, opts)

  @doc "Save-file dialog. Returns a command."
  @spec file_save(opts :: keyword()) :: Julep.Command.t()
  def file_save(opts \\ []), do: request(:file_save, opts)

  @doc "Directory picker. Returns a command."
  @spec directory_select(opts :: keyword()) :: Julep.Command.t()
  def directory_select(opts \\ []), do: request(:directory_select, opts)

  @doc "Read clipboard contents. Returns a command."
  @spec clipboard_read() :: Julep.Command.t()
  def clipboard_read, do: request(:clipboard_read)

  @doc "Write `text` to the clipboard. Returns a command."
  @spec clipboard_write(text :: String.t()) :: Julep.Command.t()
  def clipboard_write(text), do: request(:clipboard_write, text: text)

  @doc "Read primary clipboard (middle-click paste on Linux). Returns a command."
  @spec clipboard_read_primary() :: Julep.Command.t()
  def clipboard_read_primary, do: request(:clipboard_read_primary)

  @doc "Write `text` to the primary clipboard. Returns a command."
  @spec clipboard_write_primary(text :: String.t()) :: Julep.Command.t()
  def clipboard_write_primary(text), do: request(:clipboard_write_primary, text: text)

  @doc "Show an OS notification. Returns a command."
  @spec notification(title :: String.t(), body :: String.t()) :: Julep.Command.t()
  def notification(title, body), do: request(:notification, title: title, body: body)

  # Generates a unique, monotonically increasing effect ID.
  defp generate_id do
    "ef_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
