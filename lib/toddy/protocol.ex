defmodule Toddy.Protocol do
  @moduledoc """
  Wire protocol between the Elixir runtime and the Rust renderer.

  Supports two wire formats:

  * `:json` -- newline-delimited JSON. Opt-in for debugging and observability.
    Each encode function returns a JSON string with a trailing newline.
  * `:msgpack` -- MessagePack via `Msgpax` (default). Returns raw binary with no
    length prefix (Erlang's `{:packet, 4}` Port driver handles framing).

  The decode function accepts a binary in either format and returns an
  event struct (see `Toddy.Event.*`) or an internal tuple.

  Implementation is split across internal submodules:

  * `Protocol.Encode` -- all `encode_*` functions and serialization
  * `Protocol.Decode` -- `decode/2`, `decode_message/2`, and dispatch
  * `Protocol.Keys` -- named/physical key maps and `parse_key/1`
  * `Protocol.Parsers` -- shared string-to-atom parsers
  """

  @protocol_version 1

  @typedoc "Wire format for protocol messages."
  @type format :: :json | :msgpack

  @doc "Returns the current protocol version number."
  @spec protocol_version() :: non_neg_integer()
  def protocol_version, do: @protocol_version

  # ---------------------------------------------------------------------------
  # Encoding -- delegated to Protocol.Encode
  # ---------------------------------------------------------------------------

  @doc """
  Encodes an arbitrary map as a wire-format binary.

  For `:json`, returns a JSON string with a trailing newline.
  For `:msgpack`, returns raw msgpack bytes (no length prefix -- the Erlang
  `{:packet, 4}` Port driver handles framing).
  """
  @spec encode(message :: map(), format :: format()) :: binary()
  defdelegate encode(map, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes application-level settings as a protocol message.

  ## Example

      Toddy.Protocol.encode_settings(%{antialiasing: true, default_text_size: 16}, :json)
      #=> ~s({"session":"","settings":{"antialiasing":true,"default_text_size":16,"protocol_version":1},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(settings :: map(), format :: format()) :: binary()
  defdelegate encode_settings(settings, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a UI tree snapshot as a protocol message.

  ## Example

      Toddy.Protocol.encode_snapshot(%{tag: "text", value: "hello"}, :json)
      #=> ~s({"session":"","tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(tree :: term(), format :: format()) :: binary()
  defdelegate encode_snapshot(tree, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a list of patch operations as a protocol message.

  The ops list is encoded as-is into the payload.

  ## Example

      Toddy.Protocol.encode_patch([], :json)
      #=> ~s({"ops":[],"session":"","type":"patch"}) <> "\\n"
  """
  @spec encode_patch(ops :: list(), format :: format()) :: binary()
  defdelegate encode_patch(ops, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes an effect request as a protocol message.

  ## Example

      Toddy.Protocol.encode_effect("req_1", "file_open", %{title: "Pick a file"}, :json)
      #=> ~s({"id":"req_1","kind":"file_open","payload":{"title":"Pick a file"},"session":"","type":"effect"}) <> "\\n"
  """
  @spec encode_effect(
          id :: String.t(),
          kind :: String.t(),
          payload :: term(),
          format :: format()
        ) :: binary()
  defdelegate encode_effect(id, kind, payload, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a widget operation as a protocol message.

  ## Example

      Toddy.Protocol.encode_widget_op("focus", %{target: "username"}, :json)
      #=> ~s({"op":"focus","payload":{"target":"username"},"session":"","type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(op :: String.t(), payload :: map(), format :: format()) :: binary()
  defdelegate encode_widget_op(op, payload, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a subscribe message as a protocol message.

  ## Example

      Toddy.Protocol.encode_subscribe("on_key_press", "keys", :json)
      #=> ~s({"kind":"on_key_press","session":"","tag":"keys","type":"subscribe"}) <> "\\n"
  """
  @spec encode_subscribe(kind :: String.t(), tag :: String.t(), format :: format()) ::
          binary()
  defdelegate encode_subscribe(kind, tag, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes an unsubscribe message as a protocol message.

  ## Example

      Toddy.Protocol.encode_unsubscribe("on_key_press", :json)
      #=> ~s({"kind":"on_key_press","session":"","type":"unsubscribe"}) <> "\\n"
  """
  @spec encode_unsubscribe(kind :: String.t(), format :: format()) :: binary()
  defdelegate encode_unsubscribe(kind, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes an image operation as a protocol message.

  Image ops are `create_image`, `update_image`, or `delete_image`. The payload
  map contains the op-specific fields (handle, data/pixels, width, height).

  Binary fields (`data`, `pixels`) are encoded based on the wire format:
  - `:msgpack` -- wrapped in `Msgpax.Bin` for native msgpack binary type (zero overhead)
  - `:json` -- base64-encoded strings (JSON has no binary type)

  ## Example

      Toddy.Protocol.encode_image_op("create_image", %{handle: "logo", data: <<1, 2, 3>>}, :json)
      #=> ~s({"data":"AQID","handle":"logo","op":"create_image","session":"","type":"image_op"}) <> "\\n"
  """
  @spec encode_image_op(op :: String.t(), payload :: map(), format :: format()) :: binary()
  defdelegate encode_image_op(op, payload, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a single extension command as a protocol message.

  Extension commands bypass the normal tree update / diff / patch cycle
  and are delivered directly to the target extension widget on the Rust side.
  """
  @spec encode_extension_command(
          node_id :: String.t(),
          op :: String.t(),
          payload :: map(),
          format :: format()
        ) :: binary()
  defdelegate encode_extension_command(node_id, op, payload, format \\ :msgpack),
    to: Toddy.Protocol.Encode

  @doc """
  Encodes a batch of extension commands as a protocol message.

  Each command in the list is a `{node_id, op, payload}` tuple.
  All commands in the batch are processed in a single cycle on the Rust side.
  """
  @spec encode_extension_commands(
          commands :: [{String.t(), String.t(), map()}],
          format :: format()
        ) :: binary()
  defdelegate encode_extension_commands(commands, format \\ :msgpack), to: Toddy.Protocol.Encode

  @doc """
  Encodes a window lifecycle operation as a protocol message.

  ## Example

      Toddy.Protocol.encode_window_op("open", "main", %{title: "My App"}, :json)
      #=> ~s({"op":"open","session":"","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(
          op :: String.t(),
          window_id :: String.t(),
          settings :: map(),
          format :: format()
        ) :: binary()
  defdelegate encode_window_op(op, window_id, settings, format \\ :msgpack),
    to: Toddy.Protocol.Encode

  @doc "Encodes an advance_frame message for headless/test mode."
  @spec encode_advance_frame(timestamp :: non_neg_integer(), format :: format()) :: binary()
  defdelegate encode_advance_frame(timestamp, format \\ :msgpack), to: Toddy.Protocol.Encode

  # ---------------------------------------------------------------------------
  # Decoding -- delegated to Protocol.Decode
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a wire-format binary into a string-keyed map without dispatch.

  Unlike `decode_message/2` which dispatches into Elixir event tuples, this
  returns the raw deserialized map. Used by test backends that handle
  renderer responses (query_response, interact_response, etc.) directly.
  """
  @spec decode(data :: binary(), format :: format()) :: {:ok, map()} | {:error, term()}
  defdelegate decode(data, format \\ :msgpack), to: Toddy.Protocol.Decode

  @doc """
  Decodes a protocol message into an event tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Toddy.Protocol.decode_message(~s({"type":"event","family":"click","id":"btn_save"}), :json)
      %Toddy.Event.Widget{type: :click, id: "btn_save", value: nil, data: nil}

      iex> Toddy.Protocol.decode_message("not json")
      {:error, :decode_failed}
  """
  @spec decode_message(data :: binary(), format :: format()) :: tuple() | {:error, term()}
  defdelegate decode_message(data, format \\ :msgpack), to: Toddy.Protocol.Decode

  # ---------------------------------------------------------------------------
  # Key name conversion -- delegated to Protocol.Keys
  # ---------------------------------------------------------------------------

  @doc """
  Converts a key name string to an atom for named keys, or returns the string
  unchanged for single-character keys.

  ## Examples

      iex> Toddy.Protocol.parse_key("Escape")
      :escape

      iex> Toddy.Protocol.parse_key("a")
      "a"
  """
  @spec parse_key(key :: String.t()) :: atom() | String.t()
  defdelegate parse_key(key), to: Toddy.Protocol.Keys
end
