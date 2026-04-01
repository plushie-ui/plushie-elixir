defmodule Plushie.Effects do
  @moduledoc """
  Native platform effect requests.

  Effects are asynchronous I/O operations that require the renderer to
  interact with the OS on behalf of the Elixir app -- file dialogs,
  clipboard access, notifications, and similar.

  Each function takes an atom `tag` as the first argument and returns a
  `Plushie.Command` struct. Dispatch it from `update/2` like any other
  command. The result arrives later as a `%Plushie.Event.EffectEvent{tag: tag,
  result: result}` event in `update/2`. Pattern match on the tag to
  identify which effect the response belongs to.

  Only one effect per tag can be in flight at a time. Starting a new
  effect with a tag that already has a pending request discards the
  previous one.

  ## Example

      def update(model, %Plushie.Event.WidgetEvent{type: :click, id: "open"}) do
        {model, Plushie.Effects.file_open(:import, title: "Pick a file")}
      end

      def update(model, %Plushie.Event.EffectEvent{tag: :import, result: {:ok, %{path: path}}}) do
        %{model | file: path}
      end

      def update(model, %Plushie.Event.EffectEvent{tag: :import, result: :cancelled}) do
        model
      end

  ## Timeouts

  Each effect has a default timeout. If the renderer does not respond in time,
  `%Plushie.Event.EffectEvent{tag: tag, result: {:error, :timeout}}` arrives
  in `update/2`.

  Default timeouts:

  - File dialogs (`file_open`, `file_open_multiple`, `file_save`,
    `directory_select`, `directory_select_multiple`): 120 seconds
  - Clipboard operations: 5 seconds
  - Notifications: 5 seconds

  Override the default by passing a `:timeout` option (milliseconds):

      Plushie.Effects.file_open(:import, title: "Pick a file", timeout: 300_000)
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

  `tag` is an atom that identifies this effect -- it appears in the
  `%EffectEvent{tag: tag}` result event. `kind` must be one of the supported
  effect types. `opts` is a keyword list of parameters sent as the effect
  payload.
  """
  @spec request(tag :: atom(), kind :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def request(tag, kind, opts \\ []) when is_atom(tag) and kind in @valid_kinds do
    id = generate_id()
    payload = Map.new(opts)

    %Plushie.Command{
      type: :effect,
      payload: %{id: id, tag: tag, kind: to_string(kind), opts: payload}
    }
  end

  @doc """
  Open-file dialog. Returns a command.

  Filter format is `{"Label", "*.ext"}`. The renderer translates to
  platform-native format: glob patterns on Linux (GTK), UTIs on macOS,
  and filter patterns on Windows.
  """
  @spec file_open(tag :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def file_open(tag, opts \\ []), do: request(tag, :file_open, opts)

  @doc "Multi-file open dialog. Returns a command."
  @spec file_open_multiple(tag :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def file_open_multiple(tag, opts \\ []), do: request(tag, :file_open_multiple, opts)

  @doc "Save-file dialog. Returns a command."
  @spec file_save(tag :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def file_save(tag, opts \\ []), do: request(tag, :file_save, opts)

  @doc "Directory picker. Returns a command."
  @spec directory_select(tag :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def directory_select(tag, opts \\ []), do: request(tag, :directory_select, opts)

  @doc "Multi-directory picker. Returns a command."
  @spec directory_select_multiple(tag :: atom(), opts :: keyword()) :: Plushie.Command.t()
  def directory_select_multiple(tag, opts \\ []),
    do: request(tag, :directory_select_multiple, opts)

  @doc "Read clipboard contents. Returns a command."
  @spec clipboard_read(tag :: atom()) :: Plushie.Command.t()
  def clipboard_read(tag), do: request(tag, :clipboard_read)

  @doc "Write `text` to the clipboard. Returns a command."
  @spec clipboard_write(tag :: atom(), text :: String.t()) :: Plushie.Command.t()
  def clipboard_write(tag, text), do: request(tag, :clipboard_write, text: text)

  @doc "Read HTML content from the clipboard. Returns a command."
  @spec clipboard_read_html(tag :: atom()) :: Plushie.Command.t()
  def clipboard_read_html(tag), do: request(tag, :clipboard_read_html)

  @doc "Write HTML content to the clipboard. Returns a command."
  @spec clipboard_write_html(tag :: atom(), html :: String.t(), alt_text :: String.t() | nil) ::
          Plushie.Command.t()
  def clipboard_write_html(tag, html, alt_text \\ nil) do
    opts = [html: html]
    opts = if alt_text, do: Keyword.put(opts, :alt_text, alt_text), else: opts
    request(tag, :clipboard_write_html, opts)
  end

  @doc "Clear the clipboard. Returns a command."
  @spec clipboard_clear(tag :: atom()) :: Plushie.Command.t()
  def clipboard_clear(tag), do: request(tag, :clipboard_clear)

  @doc "Read primary clipboard (middle-click paste on Linux). Returns a command."
  @spec clipboard_read_primary(tag :: atom()) :: Plushie.Command.t()
  def clipboard_read_primary(tag), do: request(tag, :clipboard_read_primary)

  @doc "Write `text` to the primary clipboard. Returns a command."
  @spec clipboard_write_primary(tag :: atom(), text :: String.t()) :: Plushie.Command.t()
  def clipboard_write_primary(tag, text), do: request(tag, :clipboard_write_primary, text: text)

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
  @spec notification(tag :: atom(), title :: String.t(), body :: String.t(), opts :: keyword()) ::
          Plushie.Command.t()
  def notification(tag, title, body, opts \\ []) do
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

    request(tag, :notification, payload)
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

  # Generates a unique, monotonically increasing effect ID for wire correlation.
  @doc false
  defp generate_id do
    "ef_" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
