defmodule Toddy.Effects do
  @moduledoc """
  Native platform effect requests.

  Effects are asynchronous I/O operations that require the renderer to
  interact with the OS on behalf of the Elixir app -- file dialogs,
  clipboard access, notifications, and similar.

  Each function returns a `Toddy.Command` struct. Dispatch it from
  `update/2` like any other command. The result arrives later as a
  `%Toddy.Event.Effect{request_id: id, result: result}` event in
  `update/2`. The `request_id` is auto-generated internally and embedded
  in the command payload. Match on it in the result event if you need to
  correlate requests and responses.

  The result is `{:ok, value}` on success or `{:error, reason}` on failure.

  ## Example

      def update(model, %Toddy.Event.Widget{type: :click, id: "open"}) do
        cmd = Toddy.Effects.file_open(title: "Pick a file")
        {model, cmd}
      end

      def update(model, %Toddy.Event.Effect{result: {:ok, result}}) do
        %{model | file: result}
      end
  """

  @valid_kinds ~w(
    file_open file_open_multiple file_save
    directory_select directory_select_multiple
    clipboard_read clipboard_write clipboard_read_html clipboard_write_html
    clipboard_clear clipboard_read_primary clipboard_write_primary
    notification
  )a

  @doc """
  Generic effect request. Returns a command struct.

  `kind` must be one of the supported effect types. `opts` is a keyword
  list of parameters sent as the effect payload. The effect ID is
  auto-generated and stored in the command's payload as `:id`.
  """
  @spec request(kind :: atom(), opts :: keyword()) :: Toddy.Command.t()
  def request(kind, opts \\ []) when kind in @valid_kinds do
    id = generate_id()
    payload = Map.new(opts)

    %Toddy.Command{
      type: :effect,
      payload: %{id: id, kind: to_string(kind), opts: payload}
    }
  end

  @doc """
  Open-file dialog. Returns a command.

  Filter format is `{"Label", "*.ext"}`. The renderer translates to
  platform-native format: glob patterns on Linux (GTK), UTIs on macOS,
  and filter patterns on Windows.
  """
  @spec file_open(opts :: keyword()) :: Toddy.Command.t()
  def file_open(opts \\ []), do: request(:file_open, opts)

  @doc "Multi-file open dialog. Returns a command."
  @spec file_open_multiple(opts :: keyword()) :: Toddy.Command.t()
  def file_open_multiple(opts \\ []), do: request(:file_open_multiple, opts)

  @doc "Save-file dialog. Returns a command."
  @spec file_save(opts :: keyword()) :: Toddy.Command.t()
  def file_save(opts \\ []), do: request(:file_save, opts)

  @doc "Directory picker. Returns a command."
  @spec directory_select(opts :: keyword()) :: Toddy.Command.t()
  def directory_select(opts \\ []), do: request(:directory_select, opts)

  @doc "Multi-directory picker. Returns a command."
  @spec directory_select_multiple(opts :: keyword()) :: Toddy.Command.t()
  def directory_select_multiple(opts \\ []), do: request(:directory_select_multiple, opts)

  @doc "Read clipboard contents. Returns a command."
  @spec clipboard_read() :: Toddy.Command.t()
  def clipboard_read, do: request(:clipboard_read)

  @doc "Write `text` to the clipboard. Returns a command."
  @spec clipboard_write(text :: String.t()) :: Toddy.Command.t()
  def clipboard_write(text), do: request(:clipboard_write, text: text)

  @doc "Read HTML content from the clipboard. Returns a command."
  @spec clipboard_read_html() :: Toddy.Command.t()
  def clipboard_read_html, do: request(:clipboard_read_html)

  @doc "Write HTML content to the clipboard. Returns a command."
  @spec clipboard_write_html(html :: String.t(), alt_text :: String.t() | nil) ::
          Toddy.Command.t()
  def clipboard_write_html(html, alt_text \\ nil) do
    opts = [html: html]
    opts = if alt_text, do: Keyword.put(opts, :alt_text, alt_text), else: opts
    request(:clipboard_write_html, opts)
  end

  @doc "Clear the clipboard. Returns a command."
  @spec clipboard_clear() :: Toddy.Command.t()
  def clipboard_clear, do: request(:clipboard_clear)

  @doc "Read primary clipboard (middle-click paste on Linux). Returns a command."
  @spec clipboard_read_primary() :: Toddy.Command.t()
  def clipboard_read_primary, do: request(:clipboard_read_primary)

  @doc "Write `text` to the primary clipboard. Returns a command."
  @spec clipboard_write_primary(text :: String.t()) :: Toddy.Command.t()
  def clipboard_write_primary(text), do: request(:clipboard_write_primary, text: text)

  @doc """
  Show an OS notification. Returns a command.

  On macOS, notifications may require the app to be bundled (.app) or have
  notification entitlements to display.

  ## Options

    * `:icon` - Icon name or path (string).
    * `:timeout` - Auto-dismiss timeout in milliseconds (integer).
    * `:urgency` - `:low`, `:normal`, or `:critical` (atom).
    * `:sound` - Sound name to play (string).
  """
  @spec notification(title :: String.t(), body :: String.t(), opts :: keyword()) ::
          Toddy.Command.t()
  def notification(title, body, opts \\ []) do
    payload = [title: title, body: body]

    payload =
      if opts[:icon], do: Keyword.put(payload, :icon, opts[:icon]), else: payload

    payload =
      if opts[:timeout], do: Keyword.put(payload, :timeout, opts[:timeout]), else: payload

    payload =
      if opts[:urgency],
        do: Keyword.put(payload, :urgency, Atom.to_string(opts[:urgency])),
        else: payload

    payload =
      if opts[:sound], do: Keyword.put(payload, :sound, opts[:sound]), else: payload

    request(:notification, payload)
  end

  # Default timeouts per effect kind (milliseconds). File dialogs get longer
  # because users interact with them; clipboard/notification ops are fast.
  @default_timeouts %{
    "clipboard_read" => 5_000,
    "clipboard_write" => 5_000,
    "clipboard_read_html" => 5_000,
    "clipboard_write_html" => 5_000,
    "clipboard_clear" => 5_000,
    "clipboard_read_primary" => 5_000,
    "clipboard_write_primary" => 5_000,
    "file_open" => 120_000,
    "file_open_multiple" => 120_000,
    "file_save" => 120_000,
    "directory_select" => 120_000,
    "directory_select_multiple" => 120_000,
    "notification" => 5_000
  }

  @doc """
  Returns the default timeout (in ms) for the given effect kind, or nil
  if no specific default is configured.
  """
  @spec default_timeout(kind :: String.t()) :: non_neg_integer() | nil
  def default_timeout(kind) when is_binary(kind) do
    Map.get(@default_timeouts, kind)
  end

  # Generates a unique, monotonically increasing effect ID.
  defp generate_id do
    "ef_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
