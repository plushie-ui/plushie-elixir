defmodule Plushie.Effect.Result do
  @moduledoc """
  Typed results for platform effect responses.

  Every `Plushie.Event.EffectEvent` carries a `result` field whose
  shape is one of the structs defined here. Apps pattern-match on
  the struct module for richly typed access to the effect outcome,
  rather than digging into a generic map.

  ## Variants

  Success:

    * `%FileOpened{path: path}` - `file_open`
    * `%FilesOpened{paths: paths}` - `file_open_multiple`
    * `%FileSaved{path: path}` - `file_save`
    * `%DirectorySelected{path: path}` - `directory_select`
    * `%DirectoriesSelected{paths: paths}` - `directory_select_multiple`
    * `%ClipboardText{text: text}` - `clipboard_read` / `clipboard_read_primary`
    * `%ClipboardHtml{html: html, alt_text: alt_text}` - `clipboard_read_html`
    * `%ClipboardWritten{}` - any clipboard write
    * `%ClipboardCleared{}` - `clipboard_clear`
    * `%NotificationShown{}` - `notification`

  Non-success:

    * `%Cancelled{}` - the user dismissed the dialog
    * `%Timeout{}` - no response within the kind's timeout
    * `%Error{message: message}` - platform error
    * `%Unsupported{}` - this backend doesn't support the effect
    * `%RendererRestarted{}` - the renderer was restarted while the
      effect was pending

  ## Pattern matching

      def update(model, %Plushie.Event.EffectEvent{
        tag: :import,
        result: %Plushie.Effect.Result.FileOpened{path: path}
      }) do
        load_file(model, path)
      end

      def update(model, %Plushie.Event.EffectEvent{
        tag: :import,
        result: %Plushie.Effect.Result.Cancelled{}
      }) do
        model
      end

  The legacy tuple shape `{:ok, value}` / `:cancelled` / `{:error, reason}`
  is no longer emitted. Pre-1.0, there is no back-compat layer.
  """

  defmodule FileOpened do
    @moduledoc "A file was selected from an open-file dialog."
    @enforce_keys [:path]
    defstruct [:path]
    @type t :: %__MODULE__{path: String.t()}
  end

  defmodule FilesOpened do
    @moduledoc "Multiple files were selected from a multi-file open dialog."
    @enforce_keys [:paths]
    defstruct [:paths]
    @type t :: %__MODULE__{paths: [String.t()]}
  end

  defmodule FileSaved do
    @moduledoc "A file path was chosen in a save dialog."
    @enforce_keys [:path]
    defstruct [:path]
    @type t :: %__MODULE__{path: String.t()}
  end

  defmodule DirectorySelected do
    @moduledoc "A directory was selected from a directory picker."
    @enforce_keys [:path]
    defstruct [:path]
    @type t :: %__MODULE__{path: String.t()}
  end

  defmodule DirectoriesSelected do
    @moduledoc "Multiple directories were selected from a multi-directory picker."
    @enforce_keys [:paths]
    defstruct [:paths]
    @type t :: %__MODULE__{paths: [String.t()]}
  end

  defmodule ClipboardText do
    @moduledoc "Clipboard text was read."
    @enforce_keys [:text]
    defstruct [:text]
    @type t :: %__MODULE__{text: String.t()}
  end

  defmodule ClipboardHtml do
    @moduledoc "Clipboard HTML was read. `alt_text` may be nil."
    @enforce_keys [:html]
    defstruct [:html, alt_text: nil]
    @type t :: %__MODULE__{html: String.t(), alt_text: String.t() | nil}
  end

  defmodule ClipboardWritten do
    @moduledoc "Clipboard write completed."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule ClipboardCleared do
    @moduledoc "Clipboard was cleared."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule NotificationShown do
    @moduledoc "An OS notification was shown."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Cancelled do
    @moduledoc "The user dismissed a dialog."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Timeout do
    @moduledoc "The effect did not receive a response within its timeout."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule Error do
    @moduledoc "A platform error occurred. `message` is renderer-supplied."
    @enforce_keys [:message]
    defstruct [:message]
    @type t :: %__MODULE__{message: String.t()}
  end

  defmodule Unsupported do
    @moduledoc "The backend does not support this effect."
    defstruct []
    @type t :: %__MODULE__{}
  end

  defmodule RendererRestarted do
    @moduledoc "The renderer restarted while this effect was in flight."
    defstruct []
    @type t :: %__MODULE__{}
  end

  @typedoc """
  Union of every typed effect result.
  """
  @type t ::
          FileOpened.t()
          | FilesOpened.t()
          | FileSaved.t()
          | DirectorySelected.t()
          | DirectoriesSelected.t()
          | ClipboardText.t()
          | ClipboardHtml.t()
          | ClipboardWritten.t()
          | ClipboardCleared.t()
          | NotificationShown.t()
          | Cancelled.t()
          | Timeout.t()
          | Error.t()
          | Unsupported.t()
          | RendererRestarted.t()

  @doc """
  Decode a renderer-supplied `(kind, status, result_or_reason)` triple
  into the appropriate struct.

  `kind` is the effect kind string (e.g. `"file_open"`) used at send
  time. `status` is the wire status. For `"ok"`, `payload` is the
  decoded result map. For `"error"`, `payload` is the reason string.
  Otherwise `payload` is ignored.
  """
  @spec decode(kind :: String.t(), status :: String.t(), payload :: term()) :: t()
  def decode(_kind, "cancelled", _payload), do: %Cancelled{}
  def decode(_kind, "unsupported", _payload), do: %Unsupported{}
  def decode(_kind, "error", reason), do: %Error{message: to_string_safe(reason)}

  def decode(kind, "ok", result) when is_map(result) do
    decode_ok(kind, result)
  end

  def decode(kind, "ok", _result), do: decode_ok(kind, %{})

  def decode(_kind, _status, _payload), do: %Error{message: "unknown effect status"}

  @doc """
  Constructor used by the runtime for the timeout path.
  """
  @spec timeout() :: Timeout.t()
  def timeout, do: %Timeout{}

  @doc """
  Constructor used by the runtime when the renderer restarts with
  effects in flight.
  """
  @spec renderer_restarted() :: RendererRestarted.t()
  def renderer_restarted, do: %RendererRestarted{}

  # -- Per-kind decoders --------------------------------------------------

  defp decode_ok("file_open", result) do
    with_string("file_open", result, :path, fn path -> %FileOpened{path: path} end)
  end

  defp decode_ok("file_open_multiple", result) do
    with_paths("file_open_multiple", result, :paths, fn paths -> %FilesOpened{paths: paths} end)
  end

  defp decode_ok("file_save", result) do
    with_string("file_save", result, :path, fn path -> %FileSaved{path: path} end)
  end

  defp decode_ok("directory_select", result) do
    with_string("directory_select", result, :path, fn path -> %DirectorySelected{path: path} end)
  end

  defp decode_ok("directory_select_multiple", result) do
    with_paths("directory_select_multiple", result, :paths, fn paths ->
      %DirectoriesSelected{paths: paths}
    end)
  end

  defp decode_ok(kind, result) when kind in ["clipboard_read", "clipboard_read_primary"] do
    with_string(kind, result, :text, fn text -> %ClipboardText{text: text} end)
  end

  defp decode_ok("clipboard_read_html", result) do
    with {:ok, html} <- fetch_string(result, :html),
         {:ok, alt_text} <- fetch_optional_string(result, :alt_text) do
      %ClipboardHtml{html: html, alt_text: alt_text}
    else
      :error -> malformed_result("clipboard_read_html")
    end
  end

  defp decode_ok(kind, _result)
       when kind in [
              "clipboard_write",
              "clipboard_write_html",
              "clipboard_write_primary"
            ] do
    %ClipboardWritten{}
  end

  defp decode_ok("clipboard_clear", _result), do: %ClipboardCleared{}
  defp decode_ok("notification", _result), do: %NotificationShown{}

  # Fallback: unknown effect kind. Surface as Error so apps don't
  # silently miss a typed match.
  defp decode_ok(kind, _result) do
    %Error{message: "unknown effect kind: #{kind}"}
  end

  # Accept both atom and string keys. The decode pipeline
  # safe_atomize_keys may or may not have run; callers have been
  # seen to pass either shape.
  defp with_string(kind, result, key, fun) do
    case fetch_string(result, key) do
      {:ok, value} -> fun.(value)
      :error -> malformed_result(kind)
    end
  end

  defp with_paths(kind, result, key, fun) do
    case fetch_paths(result, key) do
      {:ok, value} -> fun.(value)
      :error -> malformed_result(kind)
    end
  end

  defp malformed_result(kind) do
    %Error{message: "malformed effect result for #{kind}"}
  end

  defp fetch_value(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(map, to_string(key))
    end
  end

  defp fetch_string(map, key) do
    case fetch_value(map, key) do
      {:ok, v} when is_binary(v) -> {:ok, v}
      _ -> :error
    end
  end

  defp fetch_optional_string(map, key) do
    case fetch_value(map, key) do
      {:ok, nil} -> {:ok, nil}
      {:ok, v} when is_binary(v) -> {:ok, v}
      :error -> {:ok, nil}
      _ -> :error
    end
  end

  defp fetch_paths(map, key) do
    case fetch_value(map, key) do
      {:ok, paths} when is_list(paths) ->
        if Enum.all?(paths, &is_binary/1), do: {:ok, paths}, else: :error

      _ ->
        :error
    end
  end

  defp to_string_safe(v) when is_binary(v), do: v
  defp to_string_safe(v) when is_atom(v), do: Atom.to_string(v)
  defp to_string_safe(v), do: inspect(v)
end
