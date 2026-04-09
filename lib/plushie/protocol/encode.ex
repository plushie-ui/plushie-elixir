defmodule Plushie.Protocol.Encode do
  @moduledoc false

  # All protocol encoding functions. Each returns wire-format iodata
  # (JSON binary with trailing newline, or msgpack iodata).

  @protocol_version Plushie.Protocol.protocol_version()

  @doc """
  Encodes an arbitrary map as wire-format iodata.

  For `:json`, returns a JSON string with a trailing newline.
  For `:msgpack`, returns msgpack iodata (no length prefix -- the Erlang
  `{:packet, 4}` Port driver handles framing).
  """
  @spec encode(message :: map(), format :: Plushie.Protocol.format()) :: iodata()
  def encode(map, format \\ :msgpack), do: serialize(map, format)

  @doc """
  Encodes application-level settings as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_settings(%{antialiasing: true, default_text_size: 16}, :json)
      #=> ~s({"session":"","settings":{"antialiasing":true,"default_text_size":16,"protocol_version":1},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(settings :: map(), format :: Plushie.Protocol.format()) :: iodata()
  def encode_settings(settings, format \\ :msgpack) when is_map(settings) do
    settings = Map.put_new(settings, :protocol_version, @protocol_version)
    serialize(%{type: "settings", settings: settings}, format)
  end

  @doc """
  Encodes a UI tree snapshot as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_snapshot(%{tag: "text", value: "hello"}, :json)
      #=> ~s({"session":"","tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(tree :: term(), format :: Plushie.Protocol.format()) :: iodata()
  def encode_snapshot(tree, format \\ :msgpack) do
    serialize(%{type: "snapshot", tree: stringify_tree(tree)}, format)
  end

  @doc """
  Encodes a list of patch operations as a protocol message.

  The ops list is encoded as-is into the payload.

  ## Example

      Plushie.Protocol.Encode.encode_patch([], :json)
      #=> ~s({"ops":[],"session":"","type":"patch"}) <> "\\n"
  """
  @spec encode_patch(ops :: list(), format :: Plushie.Protocol.format()) :: iodata()
  def encode_patch(ops, format \\ :msgpack) do
    serialize(%{type: "patch", ops: stringify_patch_ops(ops)}, format)
  end

  @doc """
  Encodes an effect request as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_effect("req_1", "file_open", %{title: "Pick a file"}, :json)
      #=> ~s({"id":"req_1","kind":"file_open","payload":{"title":"Pick a file"},"session":"","type":"effect"}) <> "\\n"
  """
  @spec encode_effect(
          id :: String.t(),
          kind :: String.t(),
          payload :: term(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_effect(id, kind, payload, format \\ :msgpack) do
    serialize(%{type: "effect", id: id, kind: kind, payload: payload}, format)
  end

  @doc """
  Encodes a widget operation as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_widget_op("focus", %{target: "username"})
      #=> ~s({"op":"focus","payload":{"target":"username"},"session":"","type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(op :: String.t(), payload :: map(), format :: Plushie.Protocol.format()) ::
          iodata()
  # Widget op payloads use atom keys (e.g., %{target: "widget_id"}).
  # Both Jason (JSON) and Msgpax (MessagePack) serialize atom keys as
  # strings, so the Rust side receives string-keyed maps. This is an
  # implicit reliance on serializer behavior rather than explicit key
  # conversion, but it's consistent across all message types in this
  # module (all use atom keys and rely on the serializer).
  def encode_widget_op(op, payload, format \\ :msgpack) do
    payload = encode_binary_fields(payload, format, [:data])
    serialize(%{type: "widget_op", op: op, payload: payload}, format)
  end

  @doc """
  Encodes a subscribe message as a protocol message.

  An optional `max_rate` (events per second) can be included to enable
  renderer-side event coalescing for this subscription.

  ## Example

      Plushie.Protocol.Encode.encode_subscribe("on_key_press", "keys")
      #=> ~s({"kind":"on_key_press","session":"","tag":"keys","type":"subscribe"}) <> "\\n"

      Plushie.Protocol.Encode.encode_subscribe("on_pointer_move", "pointer", :json, 30)
      #=> ~s({"kind":"on_pointer_move","max_rate":30,"session":"","tag":"pointer","type":"subscribe"}) <> "\\n"
  """
  @spec encode_subscribe(
          kind :: String.t(),
          tag :: String.t(),
          format :: Plushie.Protocol.format(),
          max_rate :: non_neg_integer() | nil,
          window_id :: String.t() | nil
        ) :: iodata()
  def encode_subscribe(kind, tag, format \\ :msgpack, max_rate \\ nil, window_id \\ nil) do
    msg = %{type: "subscribe", kind: kind, tag: tag}
    msg = if max_rate, do: Map.put(msg, :max_rate, max_rate), else: msg
    msg = if window_id, do: Map.put(msg, :window_id, window_id), else: msg
    serialize(msg, format)
  end

  @doc """
  Encodes an unsubscribe message as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_unsubscribe("on_key_press")
      #=> ~s({"kind":"on_key_press","session":"","type":"unsubscribe"}) <> "\\n"
  """
  @spec encode_unsubscribe(
          kind :: String.t(),
          format :: Plushie.Protocol.format(),
          tag :: String.t() | nil
        ) :: iodata()
  def encode_unsubscribe(kind, format \\ :msgpack, tag \\ nil) do
    msg = %{type: "unsubscribe", kind: kind}
    msg = if tag, do: Map.put(msg, :tag, tag), else: msg
    serialize(msg, format)
  end

  @doc """
  Encodes an image operation as a protocol message.

  Image ops are `create_image`, `update_image`, or `delete_image`. The payload
  map contains the op-specific fields (handle, data/pixels, width, height).

  Binary fields (`data`, `pixels`) are encoded based on the wire format:
  - `:msgpack` -- wrapped in `Msgpax.Bin` for native msgpack binary type (zero overhead)
  - `:json` -- base64-encoded strings (JSON has no binary type)

  ## Example

      Plushie.Protocol.Encode.encode_image_op("create_image", %{handle: "logo", data: <<1, 2, 3>>}, :json)
      #=> ~s({"data":"AQID","handle":"logo","op":"create_image","session":"","type":"image_op"}) <> "\\n"
  """
  @spec encode_image_op(
          op :: String.t(),
          payload :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_image_op(op, payload, format \\ :msgpack) do
    payload = encode_binary_fields(payload, format)
    serialize(Map.merge(%{type: "image_op", op: op}, payload), format)
  end

  @doc """
  Encodes a single widget command as a protocol message.

  Widget commands bypass the normal tree update / diff / patch cycle
  and are delivered directly to the target native widget on the Rust side.
  """
  @spec encode_widget_command(
          node_id :: String.t(),
          op :: String.t(),
          payload :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_widget_command(node_id, op, payload, format \\ :msgpack) do
    serialize(%{type: "widget_command", node_id: node_id, op: op, payload: payload}, format)
  end

  @doc """
  Encodes a batch of widget commands as a protocol message.

  Each command in the list is a `{node_id, op, payload}` tuple.
  All commands in the batch are processed in a single cycle on the Rust side.
  """
  @spec encode_widget_commands(
          commands :: [{String.t(), String.t(), map()}],
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_widget_commands(commands, format \\ :msgpack) when is_list(commands) do
    items =
      Enum.map(commands, fn {node_id, op, payload} ->
        %{node_id: node_id, op: op, payload: payload}
      end)

    serialize(%{type: "widget_commands", commands: items}, format)
  end

  @doc """
  Encodes a window lifecycle operation as a protocol message.

  ## Example

      Plushie.Protocol.Encode.encode_window_op("open", "main", %{title: "My App"})
      #=> ~s({"op":"open","session":"","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(
          op :: String.t(),
          window_id :: String.t(),
          settings :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_window_op(op, window_id, settings, format \\ :msgpack) do
    # Binary fields in window op settings (e.g. icon_data for set_icon) need
    # format-specific encoding, same as image ops.
    settings = encode_binary_fields(settings, format, [:icon_data])
    serialize(%{type: "window_op", op: op, window_id: window_id, settings: settings}, format)
  end

  @doc "Encodes a system-wide operation as a protocol message."
  @spec encode_system_op(
          op :: String.t(),
          settings :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_system_op(op, settings, format \\ :msgpack) do
    serialize(%{type: "system_op", op: op, settings: settings}, format)
  end

  @doc "Encodes a system-wide query as a protocol message."
  @spec encode_system_query(
          op :: String.t(),
          settings :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_system_query(op, settings, format \\ :msgpack) do
    serialize(%{type: "system_query", op: op, settings: settings}, format)
  end

  @doc """
  Encodes an interact request as a protocol message.

  The renderer will process the interaction (click, type_text, etc.) against
  its widget tree and respond with `interact_step` / `interact_response`
  messages containing the resulting events.

  ## Parameters

  - `id` -- unique request identifier for correlating responses.
  - `action` -- the interaction verb (e.g. `"click"`, `"type_text"`).
    See `Plushie.Bridge.send_interact/5` for the full list.
  - `selector` -- target widget lookup map. Example:
    `%{"by" => "id", "value" => "form/email"}`.
  - `payload` -- action-specific data map. Example:
    `%{"text" => "hello"}` for `"type_text"`.

  ## Examples

      iex> iodata = Plushie.Protocol.Encode.encode_interact("req-1", "click", %{"by" => "id", "value" => "btn"}, %{}, :json)
      iex> Jason.decode!(IO.iodata_to_binary(iodata))["action"]
      "click"

      iex> iodata = Plushie.Protocol.Encode.encode_interact("req-2", "type_text", %{"by" => "id", "value" => "input"}, %{"text" => "hi"}, :json)
      iex> Jason.decode!(IO.iodata_to_binary(iodata))["payload"]
      %{"text" => "hi"}
  """
  @spec encode_interact(
          id :: String.t(),
          action :: String.t(),
          selector :: map(),
          payload :: map(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_interact(id, action, selector, payload, format \\ :msgpack) do
    serialize(
      %{type: "interact", id: id, action: action, selector: selector, payload: payload},
      format
    )
  end

  @doc "Encodes an advance_frame message for headless/test mode."
  @spec encode_advance_frame(
          timestamp :: non_neg_integer(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_advance_frame(timestamp, format \\ :msgpack) do
    serialize(%{type: "advance_frame", timestamp: timestamp}, format)
  end

  @doc "Encodes an effect stub registration message."
  @spec encode_register_effect_stub(
          kind :: String.t(),
          response :: term(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_register_effect_stub(kind, response, format \\ :msgpack) do
    serialize(%{type: "register_effect_stub", kind: kind, response: response}, format)
  end

  @doc "Encodes an effect stub removal message."
  @spec encode_unregister_effect_stub(
          kind :: String.t(),
          format :: Plushie.Protocol.format()
        ) :: iodata()
  def encode_unregister_effect_stub(kind, format \\ :msgpack) do
    serialize(%{type: "unregister_effect_stub", kind: kind}, format)
  end

  # ---------------------------------------------------------------------------
  # Serialization helper
  # ---------------------------------------------------------------------------

  @doc false
  def serialize(map, format, session \\ "") do
    # Every wire message carries a session field. Default to empty
    # string (single-session mode). Multiplexed callers set the
    # session before encoding. When an explicit session is given,
    # it overrides any existing value.
    map =
      if session == "" do
        Map.put_new(map, :session, "")
      else
        Map.put(map, :session, session)
      end

    case format do
      :json -> Jason.encode!(map) <> "\n"
      :msgpack -> Msgpax.pack!(map)
    end
  end

  # ---------------------------------------------------------------------------
  # Binary field encoding helpers
  # ---------------------------------------------------------------------------

  # 2-arity version for image ops (hardcoded :data/:pixels keys).
  defp encode_binary_fields(payload, :msgpack) do
    encode_binary_fields(payload, :msgpack, [:data, :pixels])
  end

  defp encode_binary_fields(payload, :json) do
    encode_binary_fields(payload, :json, [:data, :pixels])
  end

  # 3-arity version with explicit key list (used by window ops for icon_data).
  defp encode_binary_fields(payload, :msgpack, keys) do
    Enum.reduce(keys, payload, &maybe_wrap_binary(&2, &1))
  end

  defp encode_binary_fields(payload, :json, keys) do
    Enum.reduce(keys, payload, &maybe_base64_encode(&2, &1))
  end

  # Looks up a field by atom key first, then string key, to handle both
  # atom-keyed and string-keyed payload maps defensively.
  defp get_binary_field(payload, key) when is_atom(key) do
    case Map.get(payload, key) do
      nil -> {Map.get(payload, Atom.to_string(key)), Atom.to_string(key)}
      val -> {val, key}
    end
  end

  defp maybe_wrap_binary(payload, key) do
    case get_binary_field(payload, key) do
      {nil, _} -> payload
      {bin, actual_key} when is_binary(bin) -> Map.put(payload, actual_key, Msgpax.Bin.new(bin))
      _ -> payload
    end
  end

  defp maybe_base64_encode(payload, key) do
    case get_binary_field(payload, key) do
      {nil, _} -> payload
      {bin, actual_key} when is_binary(bin) -> Map.put(payload, actual_key, Base.encode64(bin))
      _ -> payload
    end
  end

  # ---------------------------------------------------------------------------
  # Tree/prop stringification at the wire boundary
  # ---------------------------------------------------------------------------
  #
  # Performance note: both Jason and Msgpax handle atom keys and atom
  # values natively (converting to strings during serialization). The key
  # and value conversion in this pass is therefore redundant from a
  # correctness standpoint. The pass exists for two reasons the
  # serializers cannot handle:
  #
  #   1. Validation: catching structs that bypassed encode_prop_values
  #      in normalization, and rejecting tuples that would serialize
  #      incorrectly.
  #
  # The allocation overhead was benchmarked on a 50-node tree:
  # ~50us per snapshot (infrequent, startup/restart only), noise-level
  # on patches (the hot path, where only changed props are stringified).
  # ---------------------------------------------------------------------------

  @doc """
  Converts atom keys in a map to string keys.

  Recursively stringifies nested map values. Does NOT recurse into
  lists (child nodes are not prop values and must not be treated as such).

  This is the wire boundary function, called just before serialization.
  See the module-level performance note above for why this pass exists
  despite serializers handling atom keys natively.
  """
  @spec stringify_keys(map :: map()) :: %{String.t() => term()}
  def stringify_keys(%{} = map) do
    Map.new(map, fn
      {k, v} when is_atom(k) ->
        {Atom.to_string(k), stringify_value(v)}

      {k, v} when is_binary(k) ->
        {k, stringify_value(v)}

      {k, _v} ->
        raise ArgumentError,
              "protocol payload keys must be atoms or strings, got: #{inspect(k)}"
    end)
  end

  # Structs must be encoded before key stringification -- otherwise they
  # match the bare map clause and get destructured into raw struct fields.
  defp stringify_value(%_{} = v), do: Plushie.Type.encode_value(v)

  # Recurse into nested maps for stringify_keys, but not lists.
  # Lists in props are treated as scalar sequences (e.g. color tuples, ranges),
  # not as child node collections.
  defp stringify_value(%{} = v), do: stringify_keys(v)

  defp stringify_value(list) when is_list(list) do
    Enum.map(list, &stringify_value/1)
  end

  # Tuples leaking this far indicate a caller bypassed the builder layer
  # or supplied malformed payload data. Reject them at the wire boundary
  # instead of silently changing the shape.
  defp stringify_value(tuple) when is_tuple(tuple),
    do: raise(ArgumentError, "protocol payload values must not contain tuples: #{inspect(tuple)}")

  # Atoms that leak through from manually-constructed nodes (not via the
  # builder layer) must be converted to strings for the wire format.
  # true/false/nil are JSON-native and pass through as-is.
  defp stringify_value(true), do: true
  defp stringify_value(false), do: false
  defp stringify_value(nil), do: nil
  defp stringify_value(v) when is_atom(v), do: Atom.to_string(v)

  # Strings, numbers, and booleans are already JSON-safe primitives.
  defp stringify_value(v), do: v

  # Recursively converts atom keys in tree node props to string keys
  # for wire serialization. The internal tree uses atom-keyed props;
  # the wire format requires string keys.
  defp stringify_tree(%{props: props, children: children} = node) do
    node
    |> Map.put(:props, stringify_keys(props))
    |> Map.put(:children, Enum.map(children, &stringify_tree/1))
  end

  defp stringify_tree(other), do: other

  # Converts atom prop keys to strings in patch operations that carry
  # prop data (update_props, replace_node, insert_child).
  defp stringify_patch_ops(ops) when is_list(ops) do
    Enum.map(ops, &stringify_patch_op/1)
  end

  defp stringify_patch_op(%{op: "update_props", props: props} = op) do
    %{op | props: stringify_keys(props)}
  end

  defp stringify_patch_op(%{op: "replace_node", node: node} = op) do
    %{op | node: stringify_tree(node)}
  end

  defp stringify_patch_op(%{op: "insert_child", node: node} = op) do
    %{op | node: stringify_tree(node)}
  end

  defp stringify_patch_op(op), do: op
end
