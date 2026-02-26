defmodule Julep.Protocol do
  @moduledoc """
  Wire protocol encoding and decoding between the Elixir runtime and the iced
  renderer process.

  Messages are newline-delimited JSON. Each encode function returns a JSON
  string with a trailing newline ready to be written to the port. The decode
  function accepts a single JSON string (without the newline) and returns an
  Elixir event tuple.
  """

  # ---------------------------------------------------------------------------
  # Encoding
  # ---------------------------------------------------------------------------

  @doc """
  Encodes a UI tree snapshot as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_snapshot(%{tag: "text", value: "hello"})
      ~s({"tree":{"tag":"text","value":"hello"},"type":"snapshot"}) <> "\\n"
  """
  @spec encode_snapshot(term()) :: String.t()
  def encode_snapshot(tree) do
    Jason.encode!(%{type: "snapshot", tree: tree}) <> "\n"
  end

  @doc """
  Encodes a list of patch operations as a JSON message followed by a newline.

  Stubbed for future use -- the ops list is encoded as-is.

  ## Example

      iex> Julep.Protocol.encode_patch([])
      ~s({"ops":[],"type":"patch"}) <> "\\n"
  """
  @spec encode_patch(list()) :: String.t()
  def encode_patch(ops) do
    Jason.encode!(%{type: "patch", ops: ops}) <> "\n"
  end

  @doc """
  Encodes an effect request as a JSON message followed by a newline.

  ## Example

      iex> Julep.Protocol.encode_effect_request("req_1", "http", %{url: "https://example.com"})
      ~s({"id":"req_1","kind":"http","payload":{"url":"https://example.com"},"type":"effect_request"}) <> "\\n"
  """
  @spec encode_effect_request(String.t(), String.t(), term()) :: String.t()
  def encode_effect_request(id, kind, payload) do
    Jason.encode!(%{type: "effect_request", id: id, kind: kind, payload: payload}) <> "\n"
  end

  # ---------------------------------------------------------------------------
  # Decoding
  # ---------------------------------------------------------------------------

  @doc """
  Decodes a JSON string into an event tuple.

  Returns `{:error, reason}` on parse failure or an unrecognised message shape.

  ## Examples

      iex> Julep.Protocol.decode_message(~s({"type":"event","family":"click","id":"btn_save"}))
      {:click, "btn_save"}

      iex> Julep.Protocol.decode_message("not json")
      {:error, :invalid_json}
  """
  @spec decode_message(String.t()) ::
          {:click, String.t()}
          | {:input, String.t(), String.t()}
          | {:submit, String.t(), String.t()}
          | {:toggle, String.t(), boolean()}
          | {:select, String.t(), String.t()}
          | {:slide, String.t(), number()}
          | {:slide_release, String.t(), number()}
          | {:window, atom(), String.t()}
          | {:key_press, atom() | String.t(), map()}
          | {:effect_result, String.t(), {:ok, term()} | {:error, String.t()}}
          | {:error, term()}
  def decode_message(json_string) do
    case Jason.decode(json_string) do
      {:ok, msg} -> dispatch(msg)
      {:error, _} -> {:error, :invalid_json}
    end
  end

  # ---------------------------------------------------------------------------
  # Key name conversion
  # ---------------------------------------------------------------------------

  @named_keys %{
    "Escape"     => :escape,
    "Enter"      => :enter,
    "Tab"        => :tab,
    "Backspace"  => :backspace,
    "Delete"     => :delete,
    "ArrowUp"    => :arrow_up,
    "ArrowDown"  => :arrow_down,
    "ArrowLeft"  => :arrow_left,
    "ArrowRight" => :arrow_right,
    "Home"       => :home,
    "End"        => :end,
    "PageUp"     => :page_up,
    "PageDown"   => :page_down,
    "Space"      => :space,
    "F1"         => :f1,
    "F2"         => :f2,
    "F3"         => :f3,
    "F4"         => :f4,
    "F5"         => :f5,
    "F6"         => :f6,
    "F7"         => :f7,
    "F8"         => :f8,
    "F9"         => :f9,
    "F10"        => :f10,
    "F11"        => :f11,
    "F12"        => :f12
  }

  @doc """
  Converts a key name string to an atom for named keys, or returns the string
  unchanged for single-character keys.

  ## Examples

      iex> Julep.Protocol.parse_key("Escape")
      :escape

      iex> Julep.Protocol.parse_key("a")
      "a"
  """
  @spec parse_key(String.t()) :: atom() | String.t()
  def parse_key(key) when is_binary(key) do
    Map.get(@named_keys, key, key)
  end

  # ---------------------------------------------------------------------------
  # Private dispatch
  # ---------------------------------------------------------------------------

  defp dispatch(%{"type" => "event", "family" => "click", "id" => id}) do
    {:click, id}
  end

  defp dispatch(%{"type" => "event", "family" => "input", "id" => id, "value" => value}) do
    {:input, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "submit", "id" => id, "value" => value}) do
    {:submit, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "toggle", "id" => id, "value" => value}) do
    {:toggle, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "select", "id" => id, "value" => value}) do
    {:select, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide", "id" => id, "value" => value}) do
    {:slide, id, value}
  end

  defp dispatch(%{"type" => "event", "family" => "slide_release", "id" => id, "value" => value}) do
    {:slide_release, id, value}
  end

  defp dispatch(%{
    "type"      => "event",
    "family"    => "window",
    "action"    => action,
    "window_id" => window_id
  }) do
    {:window, String.to_atom(action), window_id}
  end

  defp dispatch(%{
    "type"      => "event",
    "family"    => "key",
    "key"       => key,
    "modifiers" => mods
  }) do
    modifiers = %{
      ctrl:    Map.get(mods, "ctrl", false),
      shift:   Map.get(mods, "shift", false),
      alt:     Map.get(mods, "alt", false),
      logo:    Map.get(mods, "logo", false),
      command: Map.get(mods, "command", false)
    }

    {:key_press, parse_key(key), modifiers}
  end

  defp dispatch(%{
    "type"   => "effect_response",
    "id"     => id,
    "status" => "ok",
    "result" => result
  }) do
    {:effect_result, id, {:ok, result}}
  end

  defp dispatch(%{
    "type"   => "effect_response",
    "id"     => id,
    "status" => "error",
    "error"  => reason
  }) do
    {:effect_result, id, {:error, reason}}
  end

  defp dispatch(msg) do
    {:error, {:unknown_message, msg}}
  end
end
