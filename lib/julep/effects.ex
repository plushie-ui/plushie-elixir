defmodule Julep.Effects do
  @moduledoc """
  Native platform effect requests.

  Effects are asynchronous I/O operations that require the renderer to
  interact with the OS on behalf of the Elixir app -- file dialogs,
  clipboard access, notifications, and similar.

  Each function returns a `{command, effect_id}` tuple. The command is
  dispatched through the runtime like any other `Julep.Command`, and the
  result arrives later as an `{:effect_result, id, result}` event in
  `update/2`. The result is `{:ok, value}` on success or `{:error, reason}`
  on failure.

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
        {cmd, _id} = Julep.Effects.file_open(title: "Pick a file")
        {model, cmd}
      end

      def update(model, {:effect_result, _id, {:ok, result}}) do
        %{model | file: result}
      end
  """

  @typedoc """
  Return value from all effect functions: a command to dispatch through
  the runtime and a unique ID for matching the `{:effect_result, id, result}`
  event that arrives later in `update/2`.
  """
  @type effect_request :: {Julep.Command.t(), effect_id()}

  @typedoc "Unique identifier for tracking an in-flight effect."
  @type effect_id :: String.t()

  @doc """
  Generic effect request. Returns `{command, effect_id}`.

  `kind` is an atom identifying the effect type. `opts` is a keyword list
  of parameters sent as the effect payload.
  """
  @spec request(kind :: atom(), opts :: keyword()) :: effect_request()
  def request(kind, opts \\ []) do
    id = generate_id()
    payload = Map.new(opts)

    cmd = %Julep.Command{
      type: :effect_request,
      payload: %{id: id, kind: to_string(kind), opts: payload}
    }

    {cmd, id}
  end

  @doc "Open-file dialog. Returns `{command, effect_id}`."
  @spec file_open(opts :: keyword()) :: effect_request()
  def file_open(opts \\ []), do: request(:file_open, opts)

  @doc "Save-file dialog. Returns `{command, effect_id}`."
  @spec file_save(opts :: keyword()) :: effect_request()
  def file_save(opts \\ []), do: request(:file_save, opts)

  @doc "Directory picker. Returns `{command, effect_id}`."
  @spec directory_select(opts :: keyword()) :: effect_request()
  def directory_select(opts \\ []), do: request(:directory_select, opts)

  @doc "Read clipboard contents. Returns `{command, effect_id}`."
  @spec clipboard_read() :: effect_request()
  def clipboard_read, do: request(:clipboard_read)

  @doc "Write `text` to the clipboard. Returns `{command, effect_id}`."
  @spec clipboard_write(text :: String.t()) :: effect_request()
  def clipboard_write(text), do: request(:clipboard_write, text: text)

  @doc "Read primary clipboard (middle-click paste on Linux). Returns `{command, effect_id}`."
  @spec clipboard_read_primary() :: effect_request()
  def clipboard_read_primary, do: request(:clipboard_read_primary)

  @doc "Write `text` to the primary clipboard. Returns `{command, effect_id}`."
  @spec clipboard_write_primary(text :: String.t()) :: effect_request()
  def clipboard_write_primary(text), do: request(:clipboard_write_primary, text: text)

  @doc "Show an OS notification. Returns `{command, effect_id}`."
  @spec notification(title :: String.t(), body :: String.t()) :: effect_request()
  def notification(title, body), do: request(:notification, title: title, body: body)

  # Generates a unique, monotonically increasing effect ID.
  defp generate_id do
    "ef_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
