defmodule Toddy.Protocol.Encode do
  @moduledoc false

  # All protocol encoding functions. Each returns a wire-format binary
  # (JSON with trailing newline, or raw msgpack bytes).

  @protocol_version Toddy.Protocol.protocol_version()

  @doc """
  Encodes an arbitrary map as a wire-format binary.

  For `:json`, returns a JSON string with a trailing newline.
  For `:msgpack`, returns raw msgpack bytes (no length prefix -- the Erlang
  `{:packet, 4}` Port driver handles framing).
  """
  @spec encode(message :: map(), format :: Toddy.Protocol.format()) :: binary()
  def encode(map, format \\ :msgpack), do: serialize(map, format)

  @doc """
  Encodes application-level settings as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_settings(%{antialiasing: true, default_text_size: 16}, :json)
      #=> ~s({"session":"","settings":{"antialiasing":true,"default_text_size":16,"protocol_version":1},"type":"settings"}) <> "\\n"
  """
  @spec encode_settings(settings :: map(), format :: Toddy.Protocol.format()) :: binary()
  def encode_settings(settings, format \\ :msgpack) when is_map(settings) do
    settings = Map.put_new(settings, :protocol_version, @protocol_version)
    serialize(%{type: "settings", settings: settings}, format)
  end

  @doc """
  Encodes a UI tree snapshot as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_snapshot(%{tag: "text", value: "hello"}, :json)
      #=> ~s({"session":"","tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(tree :: term(), format :: Toddy.Protocol.format()) :: binary()
  def encode_snapshot(tree, format \\ :msgpack) do
    serialize(%{type: "snapshot", tree: stringify_tree(tree)}, format)
  end

  @doc """
  Encodes a list of patch operations as a protocol message.

  The ops list is encoded as-is into the payload.

  ## Example

      Toddy.Protocol.Encode.encode_patch([], :json)
      #=> ~s({"ops":[],"session":"","type":"patch"}) <> "\\n"
  """
  @spec encode_patch(ops :: list(), format :: Toddy.Protocol.format()) :: binary()
  def encode_patch(ops, format \\ :msgpack) do
    serialize(%{type: "patch", ops: stringify_patch_ops(ops)}, format)
  end

  @doc """
  Encodes an effect request as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_effect("req_1", "file_open", %{title: "Pick a file"}, :json)
      #=> ~s({"id":"req_1","kind":"file_open","payload":{"title":"Pick a file"},"session":"","type":"effect"}) <> "\\n"
  """
  @spec encode_effect(
          id :: String.t(),
          kind :: String.t(),
          payload :: term(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_effect(id, kind, payload, format \\ :msgpack) do
    serialize(%{type: "effect", id: id, kind: kind, payload: payload}, format)
  end

  @doc """
  Encodes a widget operation as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_widget_op("focus", %{target: "username"})
      #=> ~s({"op":"focus","payload":{"target":"username"},"session":"","type":"widget_op"}) <> "\\n"
  """
  @spec encode_widget_op(op :: String.t(), payload :: map(), format :: Toddy.Protocol.format()) ::
          binary()
  def encode_widget_op(op, payload, format \\ :msgpack) do
    payload = encode_binary_fields(payload, format, [:data])
    serialize(%{type: "widget_op", op: op, payload: payload}, format)
  end

  @doc """
  Encodes a subscribe message as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_subscribe("on_key_press", "keys")
      #=> ~s({"kind":"on_key_press","session":"","tag":"keys","type":"subscribe"}) <> "\\n"
  """
  @spec encode_subscribe(
          kind :: String.t(),
          tag :: String.t(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_subscribe(kind, tag, format \\ :msgpack) do
    serialize(%{type: "subscribe", kind: kind, tag: tag}, format)
  end

  @doc """
  Encodes an unsubscribe message as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_unsubscribe("on_key_press")
      #=> ~s({"kind":"on_key_press","session":"","type":"unsubscribe"}) <> "\\n"
  """
  @spec encode_unsubscribe(kind :: String.t(), format :: Toddy.Protocol.format()) :: binary()
  def encode_unsubscribe(kind, format \\ :msgpack) do
    serialize(%{type: "unsubscribe", kind: kind}, format)
  end

  @doc """
  Encodes an image operation as a protocol message.

  Image ops are `create_image`, `update_image`, or `delete_image`. The payload
  map contains the op-specific fields (handle, data/pixels, width, height).

  Binary fields (`data`, `pixels`) are encoded based on the wire format:
  - `:msgpack` -- wrapped in `Msgpax.Bin` for native msgpack binary type (zero overhead)
  - `:json` -- base64-encoded strings (JSON has no binary type)

  ## Example

      Toddy.Protocol.Encode.encode_image_op("create_image", %{handle: "logo", data: <<1, 2, 3>>}, :json)
      #=> ~s({"data":"AQID","handle":"logo","op":"create_image","session":"","type":"image_op"}) <> "\\n"
  """
  @spec encode_image_op(
          op :: String.t(),
          payload :: map(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_image_op(op, payload, format \\ :msgpack) do
    payload = encode_binary_fields(payload, format)
    serialize(Map.merge(%{type: "image_op", op: op}, payload), format)
  end

  @doc """
  Encodes a single extension command as a protocol message.

  Extension commands bypass the normal tree update / diff / patch cycle
  and are delivered directly to the target extension widget on the Rust side.
  """
  @spec encode_extension_command(
          node_id :: String.t(),
          op :: String.t(),
          payload :: map(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_extension_command(node_id, op, payload, format \\ :msgpack) do
    serialize(
      %{
        "type" => "extension_command",
        "node_id" => node_id,
        "op" => op,
        "payload" => payload
      },
      format
    )
  end

  @doc """
  Encodes a batch of extension commands as a protocol message.

  Each command in the list is a `{node_id, op, payload}` tuple.
  All commands in the batch are processed in a single cycle on the Rust side.
  """
  @spec encode_extension_commands(
          commands :: [{String.t(), String.t(), map()}],
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_extension_commands(commands, format \\ :msgpack) when is_list(commands) do
    items =
      Enum.map(commands, fn {node_id, op, payload} ->
        %{"node_id" => node_id, "op" => op, "payload" => payload}
      end)

    serialize(%{"type" => "extension_commands", "commands" => items}, format)
  end

  @doc """
  Encodes a window lifecycle operation as a protocol message.

  ## Example

      Toddy.Protocol.Encode.encode_window_op("open", "main", %{title: "My App"})
      #=> ~s({"op":"open","session":"","settings":{"title":"My App"},"type":"window_op","window_id":"main"}) <> "\\n"
  """
  @spec encode_window_op(
          op :: String.t(),
          window_id :: String.t(),
          settings :: map(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_window_op(op, window_id, settings, format \\ :msgpack) do
    # Binary fields in window op settings (e.g. icon_data for set_icon) need
    # format-specific encoding, same as image ops.
    settings = encode_binary_fields(settings, format, [:icon_data])
    serialize(%{type: "window_op", op: op, window_id: window_id, settings: settings}, format)
  end

  @doc "Encodes an advance_frame message for headless/test mode."
  @spec encode_advance_frame(
          timestamp :: non_neg_integer(),
          format :: Toddy.Protocol.format()
        ) :: binary()
  def encode_advance_frame(timestamp, format \\ :msgpack) do
    serialize(%{type: "advance_frame", timestamp: timestamp}, format)
  end

  # ---------------------------------------------------------------------------
  # Serialization helper
  # ---------------------------------------------------------------------------

  @doc false
  def serialize(map, format) do
    # Every wire message carries a session field. Default to empty
    # string (single-session mode). Multiplexed callers set the
    # session before encoding. Use the key style that matches the map
    # (atom keys for most messages, string keys for extension commands).
    map =
      if Map.has_key?(map, "type") do
        Map.put_new(map, "session", "")
      else
        Map.put_new(map, :session, "")
      end

    case format do
      :json -> Jason.encode!(map) <> "\n"
      :msgpack -> Msgpax.pack!(map, iodata: false)
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

  defp maybe_wrap_binary(payload, key) do
    case Map.get(payload, key) do
      nil -> payload
      bin when is_binary(bin) -> Map.put(payload, key, Msgpax.Bin.new(bin))
      _other -> payload
    end
  end

  defp maybe_base64_encode(payload, key) do
    case Map.get(payload, key) do
      nil -> payload
      bin when is_binary(bin) -> Map.put(payload, key, Base.encode64(bin))
      _other -> payload
    end
  end

  # ---------------------------------------------------------------------------
  # Tree/prop key stringification at the wire boundary
  # ---------------------------------------------------------------------------

  @doc """
  Converts atom keys in a map to string keys.

  Recursively stringifies nested map values. Does NOT recurse into
  lists (child nodes are not prop values and must not be treated as such).

  This is the wire boundary function -- called just before serialization
  to convert atom-keyed prop maps into the string-keyed format expected
  by the renderer.
  """
  @spec stringify_keys(map :: map()) :: %{String.t() => term()}
  def stringify_keys(%{} = map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_value(v)}
      {k, v} when is_binary(k) -> {k, stringify_value(v)}
      {k, v} -> {inspect(k), stringify_value(v)}
    end)
  end

  # Structs must be encoded before key stringification -- otherwise they
  # match the bare map clause and get destructured into raw struct fields.
  defp stringify_value(%_{} = v), do: Toddy.Encode.encode(v)

  # Recurse into nested maps for stringify_keys, but not lists.
  # Lists in props are treated as scalar sequences (e.g. color tuples, ranges),
  # not as child node collections.
  defp stringify_value(%{} = v), do: stringify_keys(v)

  defp stringify_value(list) when is_list(list) do
    Enum.map(list, &stringify_value/1)
  end

  # Tuples can leak into props from incorrect function calls (e.g. keyword
  # opts passed as positional args). Convert to list for wire-format compat
  # -- matches the behaviour of Toddy.Encode.Tuple.
  defp stringify_value(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&stringify_value/1)
  end

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
    %{
      node
      | props: stringify_keys(props),
        children: Enum.map(children, &stringify_tree/1)
    }
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
