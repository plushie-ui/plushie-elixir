defmodule Plushie.Protocol do
  @moduledoc """
  Wire protocol between the Elixir runtime and the Rust renderer.

  Supports two wire formats:

  * `:json` -- newline-delimited JSON. Opt-in for debugging and observability.
    Each encode function returns a JSON string with a trailing newline.
  * `:msgpack` -- MessagePack via `Msgpax` (default). Returns iodata with no
    length prefix (Erlang's `{:packet, 4}` Port driver handles framing).

  `decode_message/2` returns a safe tagged result for tests and diagnostics.
  `decode_message!/2` enforces the protocol contract and raises on malformed
  or incompatible payloads. The bridge/runtime path uses the strict variant.

  Implementation is split across internal submodules:

  * Protocol.Encode -- all `encode_*` functions and serialization
  * Protocol.Decode -- `decode/2`, `decode_message/2`, `decode_message!/2`, and dispatch
  * Protocol.Keys -- named/physical key maps and `parse_key/1`
  * Protocol.Parsers -- strict enum parsers and widget-family checks
  """

  @protocol_version 1

  @typedoc "Wire format for protocol messages."
  @type format :: :json | :msgpack

  @typedoc """
  Structured message returned by `decode_message!/2`.

  Event payloads decode to `Plushie.Event.*` structs. Non-event protocol
  messages decode to internal tuples used by the bridge, runtime, and
  test harness.
  """
  @type decoded_message ::
          Plushie.Event.delivered_t()
          | {:hello,
             %{
               protocol: pos_integer(),
               version: String.t(),
               name: String.t(),
               mode: String.t(),
               backend: String.t(),
               transport: String.t(),
               native_widgets: [String.t()],
               widgets: [String.t()]
             }}
          | {:settings, map()}
          | {:snapshot, map()}
          | {:patch, list()}
          | {:effect, String.t(), String.t(), map()}
          | {:widget_op, String.t(), map()}
          | {:subscribe, String.t(), String.t()}
          | {:unsubscribe, String.t()}
          | {:image_op, String.t(), map()}
          | {:widget_command, String.t(), String.t(), map()}
          | {:widget_commands, [map()]}
          | {:window_op, String.t(), String.t(), map()}
          | {:system_op, String.t(), map()}
          | {:system_query, String.t(), map()}
          | {:interact, String.t(), String.t(), map(), map()}
          | {:interact_step, String.t(), [map()]}
          | {:interact_response, String.t(), [map()]}
          | {:screenshot_response, map()}
          | {:advance_frame, non_neg_integer()}
          | {:register_effect_stub, String.t(), term()}
          | {:unregister_effect_stub, String.t()}
          | {:effect_stub_ack, String.t()}
          | {:session_error, String.t(), term()}
          | {:session_closed, String.t(), term()}

  @typedoc """
  Structured decode error returned by `decode_message/2`.

  These errors are intended for tests and diagnostics. The bridge/runtime path
  uses `decode_message!/2` and crashes on protocol violations.
  """
  @type parse_reason :: :unknown | :invalid

  @type decode_error_reason ::
          {:decode_failed, term()}
          | {:unknown_message, map()}
          | {:unknown_event_family, term(), map()}
          | {:invalid_event_field, String.t(), atom(), term(), parse_reason(), map()}

  @typedoc "Safe decode result returned by `decode_message/2`."
  @type decode_result :: decoded_message() | {:error, decode_error_reason()}

  @doc "Returns the current protocol version number."
  @spec protocol_version() :: non_neg_integer()
  def protocol_version, do: @protocol_version

  # ---------------------------------------------------------------------------
  # Encoding -- delegated to Protocol.Encode
  # ---------------------------------------------------------------------------

  @doc """
  Encodes an arbitrary map as wire-format iodata.

  For `:json`, returns a JSON string with a trailing newline.
  For `:msgpack`, returns msgpack iodata (no length prefix -- the Erlang
  `{:packet, 4}` Port driver handles framing).
  """
  @spec encode(message :: map(), format :: format()) :: iodata()
  defdelegate encode(map, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes application-level settings as a protocol message.

  ## Example

      Plushie.Protocol.encode_settings(%{antialiasing: true, default_text_size: 16}, :json)
      #=> ~s({"session":"","settings":{"antialiasing":true,"default_text_size":16,"protocol_version":1},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(settings :: map(), format :: format()) :: iodata()
  defdelegate encode_settings(settings, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a UI tree snapshot as a protocol message.

  ## Example

      Plushie.Protocol.encode_snapshot(%{tag: "text", value: "hello"}, :json)
      #=> ~s({"session":"","tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(tree :: term(), format :: format()) :: iodata()
  defdelegate encode_snapshot(tree, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a list of patch operations as a protocol message.

  The ops list is encoded as-is into the payload.

  ## Example

      Plushie.Protocol.encode_patch([], :json)
      #=> ~s({"ops":[],"session":"","type":"patch"}) <> "\\n"
  """
  @spec encode_patch(ops :: list(), format :: format()) :: iodata()
  defdelegate encode_patch(ops, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes an effect request as a protocol message.

  ## Example

      Plushie.Protocol.encode_effect("req_1", "file_open", %{title: "Pick a file"}, :json)
      #=> ~s({"id":"req_1","kind":"file_open","payload":{"title":"Pick a file"},"session":"","type":"effect"}) <> "\\n"
  """
  @spec encode_effect(
          id :: String.t(),
          kind :: String.t(),
          payload :: term(),
          format :: format()
        ) :: iodata()
  defdelegate encode_effect(id, kind, payload, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a widget operation as a protocol message.

  ## Example

      Plushie.Protocol.encode_widget_op("focus", %{target: "username"}, :json)
      #=> ~s({"op":"focus","payload":{"target":"username"},"session":"","type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(op :: String.t(), payload :: map(), format :: format()) :: iodata()
  defdelegate encode_widget_op(op, payload, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a subscribe message as a protocol message.

  An optional `max_rate` (events per second) can be included to enable
  renderer-side event coalescing for this subscription. An optional
  `window_id` scopes the subscription to a specific window.

  ## Example

      Plushie.Protocol.encode_subscribe("on_key_press", "keys", :json)
      #=> ~s({"kind":"on_key_press","session":"","tag":"keys","type":"subscribe"}) <> "\\n"
  """
  @spec encode_subscribe(
          kind :: String.t(),
          tag :: String.t(),
          format :: format(),
          max_rate :: non_neg_integer() | nil,
          window_id :: String.t() | nil
        ) :: iodata()
  defdelegate encode_subscribe(kind, tag, format \\ :msgpack, max_rate \\ nil, window_id \\ nil),
    to: Plushie.Protocol.Encode

  @doc """
  Encodes an unsubscribe message as a protocol message.

  An optional `tag` identifies the specific subscription to remove
  (when multiple subscriptions share the same kind).

  ## Example

      Plushie.Protocol.encode_unsubscribe("on_key_press", :json)
      #=> ~s({"kind":"on_key_press","session":"","type":"unsubscribe"}) <> "\\n"
  """
  @spec encode_unsubscribe(
          kind :: String.t(),
          format :: format(),
          tag :: String.t() | nil
        ) :: iodata()
  defdelegate encode_unsubscribe(kind, format \\ :msgpack, tag \\ nil),
    to: Plushie.Protocol.Encode

  @doc """
  Encodes an image operation as a protocol message.

  Image ops are `create_image`, `update_image`, or `delete_image`. The payload
  map contains the op-specific fields (handle, data/pixels, width, height).

  Binary fields (`data`, `pixels`) are encoded based on the wire format:
  - `:msgpack` -- wrapped in `Msgpax.Bin` for native msgpack binary type (zero overhead)
  - `:json` -- base64-encoded strings (JSON has no binary type)

  ## Example

      Plushie.Protocol.encode_image_op("create_image", %{handle: "logo", data: <<1, 2, 3>>}, :json)
      #=> ~s({"data":"AQID","handle":"logo","op":"create_image","session":"","type":"image_op"}) <> "\\n"
  """
  @spec encode_image_op(op :: String.t(), payload :: map(), format :: format()) :: iodata()
  defdelegate encode_image_op(op, payload, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a single widget command as a protocol message.

  Widget commands bypass the normal tree update / diff / patch cycle
  and are delivered directly to the target native widget on the Rust side.
  """
  @spec encode_widget_command(
          node_id :: String.t(),
          op :: String.t(),
          payload :: map(),
          format :: format()
        ) :: iodata()
  defdelegate encode_widget_command(node_id, op, payload, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  @doc """
  Encodes a batch of widget commands as a protocol message.

  Each command in the list is a `{node_id, op, payload}` tuple.
  All commands in the batch are processed in a single cycle on the Rust side.
  """
  @spec encode_widget_commands(
          commands :: [{String.t(), String.t(), map()}],
          format :: format()
        ) :: iodata()
  defdelegate encode_widget_commands(commands, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc """
  Encodes a window lifecycle operation as a protocol message.

  ## Example

      Plushie.Protocol.encode_window_op("open", "main", %{title: "My App"}, :json)
      #=> ~s({"op":"open","session":"","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(
          op :: String.t(),
          window_id :: String.t(),
          settings :: map(),
          format :: format()
        ) :: iodata()
  defdelegate encode_window_op(op, window_id, settings, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  @doc "Encodes a system-wide operation as a protocol message."
  @spec encode_system_op(op :: String.t(), settings :: map(), format :: format()) :: iodata()
  defdelegate encode_system_op(op, settings, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc "Encodes a system-wide query as a protocol message."
  @spec encode_system_query(op :: String.t(), settings :: map(), format :: format()) :: iodata()
  defdelegate encode_system_query(op, settings, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  @doc """
  Encodes an interact request as a protocol message.

  The renderer will process the interaction and respond with
  `interact_step` / `interact_response` messages.
  """
  @spec encode_interact(
          id :: String.t(),
          action :: String.t(),
          selector :: map(),
          payload :: map(),
          format :: format()
        ) :: iodata()
  defdelegate encode_interact(id, action, selector, payload, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  @doc "Encodes an advance_frame message for headless/test mode."
  @spec encode_advance_frame(timestamp :: non_neg_integer(), format :: format()) :: iodata()
  defdelegate encode_advance_frame(timestamp, format \\ :msgpack), to: Plushie.Protocol.Encode

  @doc "Encodes an effect stub registration message."
  @spec encode_register_effect_stub(kind :: String.t(), response :: term(), format :: format()) ::
          iodata()
  defdelegate encode_register_effect_stub(kind, response, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  @doc "Encodes an effect stub removal message."
  @spec encode_unregister_effect_stub(kind :: String.t(), format :: format()) :: iodata()
  defdelegate encode_unregister_effect_stub(kind, format \\ :msgpack),
    to: Plushie.Protocol.Encode

  # ---------------------------------------------------------------------------
  # Decoding -- delegated to Protocol.Decode
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a wire-format binary into a string-keyed map without dispatch.

  Unlike `decode_message/2` which dispatches into Elixir event structs and
  internal tuples, this
  returns the raw deserialized map. Used by script and test helpers that
  handle renderer responses (query_response, interact_response, etc.) directly.
  """
  @spec decode(data :: binary(), format :: format()) :: {:ok, map()} | {:error, term()}
  defdelegate decode(data, format \\ :msgpack), to: Plushie.Protocol.Decode

  @doc """
  Decodes a renderer event map into a typed Plushie event struct.

  This is the shared event-map decoder used for interact responses and other
  already-deserialized renderer events. Raises on unknown or malformed events.
  Every event from the renderer must include `window_id`.
  """
  @spec decode_event(event :: map()) :: Plushie.Event.delivered_t()
  defdelegate decode_event(event), to: Plushie.Protocol.Decode

  @doc """
  Decodes a protocol message into an event struct or internal tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.
  Use `decode_message!/2` for the strict runtime path.

  ## Examples

      iex> Plushie.Protocol.decode_message(~s({"type":"event","family":"click","id":"btn_save","window_id":"main"}), :json)
      %Plushie.Event.WidgetEvent{type: :click, id: "btn_save", scope: ["main"], window_id: "main", value: nil}

      iex> match?({:error, {:decode_failed, _}}, Plushie.Protocol.decode_message("not json"))
      true
  """
  @spec decode_message(data :: binary(), format :: format()) :: decode_result()
  defdelegate decode_message(data, format \\ :msgpack), to: Plushie.Protocol.Decode

  @doc """
  Decodes a protocol message into an event struct or internal tuple.

  Raises `Plushie.Protocol.Error` when the payload is malformed or violates
  the SDK's protocol contract.
  """
  @spec decode_message!(data :: binary(), format :: format()) :: decoded_message()
  defdelegate decode_message!(data, format \\ :msgpack), to: Plushie.Protocol.Decode

  # ---------------------------------------------------------------------------
  # Key name conversion -- delegated to Protocol.Keys
  # ---------------------------------------------------------------------------

  @doc """
  Converts a key name string to an atom for named keys, or returns the string
  unchanged for single-character keys.

  ## Examples

      iex> Plushie.Protocol.parse_key("Escape")
      :escape

      iex> Plushie.Protocol.parse_key("a")
      "a"
  """
  @spec parse_key(key :: String.t()) :: atom() | String.t()
  defdelegate parse_key(key), to: Plushie.Protocol.Keys
end
