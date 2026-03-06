defmodule Julep.ProtocolTest do
  use ExUnit.Case, async: true

  alias Julep.Protocol

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp decode_json!(str) do
    str |> String.trim_trailing("\n") |> Jason.decode!()
  end

  # ---------------------------------------------------------------------------
  # encode_snapshot/1
  # ---------------------------------------------------------------------------

  describe "encode_snapshot/1" do
    test "produces a JSON object with type 'snapshot' and a 'tree' key" do
      tree = %{tag: "text", value: "hello"}
      result = Protocol.encode_snapshot(tree, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "snapshot"
      assert is_map(parsed["tree"])
    end

    test "the 'tree' value matches the input" do
      tree = %{tag: "column", children: []}
      result = Protocol.encode_snapshot(tree, :json)
      parsed = decode_json!(result)
      assert parsed["tree"]["tag"] == "column"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_snapshot(%{}, :json)
      assert String.ends_with?(result, "\n")
    end

    test "output is valid JSON before the trailing newline" do
      result = Protocol.encode_snapshot(%{tag: "button"}, :json)
      assert {:ok, _} = Jason.decode(String.trim_trailing(result, "\n"))
    end
  end

  # ---------------------------------------------------------------------------
  # encode_patch/1
  # ---------------------------------------------------------------------------

  describe "encode_patch/1" do
    test "produces a JSON object with type 'patch' and an 'ops' key" do
      result = Protocol.encode_patch([], :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "patch"
      assert parsed["ops"] == []
    end

    test "encodes the ops list as-is" do
      ops = [%{"op" => "replace", "path" => "/label", "value" => "Save"}]
      result = Protocol.encode_patch(ops, :json)
      parsed = decode_json!(result)
      assert length(parsed["ops"]) == 1
      assert hd(parsed["ops"])["op"] == "replace"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_patch([], :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode_effect_request/3
  # ---------------------------------------------------------------------------

  describe "encode_effect_request/3" do
    test "produces a JSON object with type 'effect_request'" do
      result =
        Protocol.encode_effect_request("req_1", "http", %{url: "https://example.com"}, :json)

      parsed = decode_json!(result)
      assert parsed["type"] == "effect_request"
    end

    test "includes the id, kind, and payload fields" do
      result = Protocol.encode_effect_request("req_42", "shell", %{cmd: "ls"}, :json)
      parsed = decode_json!(result)
      assert parsed["id"] == "req_42"
      assert parsed["kind"] == "shell"
      assert is_map(parsed["payload"])
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_effect_request("r", "k", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- event families
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- click events" do
    test "decodes a click event to {:click, id}" do
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_save"})
      assert Protocol.decode_message(json, :json) == {:click, "btn_save"}
    end

    test "widget id is preserved exactly" do
      json = Jason.encode!(%{type: "event", family: "click", id: "panel/submit"})
      assert {:click, "panel/submit"} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- input events" do
    test "decodes an input event to {:input, id, value}" do
      json = Jason.encode!(%{type: "event", family: "input", id: "search", value: "elixir"})
      assert Protocol.decode_message(json, :json) == {:input, "search", "elixir"}
    end

    test "preserves an empty string value" do
      json = Jason.encode!(%{type: "event", family: "input", id: "field", value: ""})
      assert {:input, "field", ""} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- submit events" do
    test "decodes a submit event to {:submit, id, value}" do
      json = Jason.encode!(%{type: "event", family: "submit", id: "login_form", value: "admin"})
      assert Protocol.decode_message(json, :json) == {:submit, "login_form", "admin"}
    end
  end

  describe "decode_message/1 -- toggle events" do
    test "decodes a toggle event to {:toggle, id, value}" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: true})
      assert Protocol.decode_message(json, :json) == {:toggle, "dark_mode", true}
    end

    test "decodes a toggle-off correctly" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: false})
      assert {:toggle, "dark_mode", false} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- select events" do
    test "decodes a select event to {:select, id, value}" do
      json = Jason.encode!(%{type: "event", family: "select", id: "lang_picker", value: "fr"})
      assert Protocol.decode_message(json, :json) == {:select, "lang_picker", "fr"}
    end
  end

  describe "decode_message/1 -- slide events" do
    test "decodes a slide event to {:slide, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "volume", value: 0.75})
      assert Protocol.decode_message(json, :json) == {:slide, "volume", 0.75}
    end

    test "value can be an integer" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "zoom", value: 100})
      assert {:slide, "zoom", 100} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- slide_release events" do
    test "decodes a slide_release event to {:slide_release, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide_release", id: "scrubber", value: 42.0})
      assert Protocol.decode_message(json, :json) == {:slide_release, "scrubber", 42.0}
    end
  end

  describe "decode_message/1 -- window events" do
    test "decodes a window event to {:window, action_atom, window_id}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window",
          action: "close",
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == {:window, :close, "main"}
    end

    test "converts the action string to an atom" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "window",
          action: "minimize",
          window_id: "settings"
        })

      {:window, action, _} = Protocol.decode_message(json, :json)
      assert is_atom(action)
      assert action == :minimize
    end
  end

  describe "decode_message/1 -- key events" do
    test "decodes a named key to {:key_press, %KeyEvent{}}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "Escape",
          tag: "keys",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_press, %Julep.KeyEvent{key: :escape}} = Protocol.decode_message(json, :json)
    end

    test "decodes a character key to {:key_press, %KeyEvent{key: string}}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "a",
          tag: "keys",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_press, %Julep.KeyEvent{key: "a"}} = Protocol.decode_message(json, :json)
    end

    test "modifiers are a KeyModifiers struct with all fields" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "s",
          tag: "keys",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
        })

      {:key_press, %Julep.KeyEvent{modifiers: mods}} = Protocol.decode_message(json, :json)
      assert %Julep.KeyModifiers{} = mods
      assert Map.has_key?(mods, :ctrl)
      assert Map.has_key?(mods, :shift)
      assert Map.has_key?(mods, :alt)
      assert Map.has_key?(mods, :logo)
      assert Map.has_key?(mods, :command)
    end

    test "modifiers present in the wire message are set correctly" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "c",
          tag: "keys",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
        })

      {:key_press, %Julep.KeyEvent{modifiers: mods}} = Protocol.decode_message(json, :json)
      assert mods.ctrl == true
      assert mods.shift == false
    end

    test "modifiers absent from the wire message default to false" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "z",
          tag: "keys",
          modifiers: %{}
        })

      {:key_press, %Julep.KeyEvent{modifiers: mods}} = Protocol.decode_message(json, :json)
      assert mods.ctrl == false
      assert mods.alt == false
    end

    test "decodes a key_release event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          id: "",
          value: "Enter",
          tag: "keys",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false}
        })

      assert {:key_release, %Julep.KeyEvent{key: :enter}} = Protocol.decode_message(json, :json)
    end

    test "decodes extra key event fields (nested data from Rust)" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "",
          value: "a",
          tag: "keys",
          modifiers: %{ctrl: false, shift: true, alt: false, logo: false, command: false},
          data: %{
            modified_key: "A",
            physical_key: "KeyA",
            location: "standard",
            text: "A",
            repeat: false
          }
        })

      {:key_press, evt} = Protocol.decode_message(json, :json)
      assert %Julep.KeyEvent{} = evt
      assert evt.key == "a"
      assert evt.modified_key == "A"
      assert evt.physical_key == :key_a
      assert evt.location == :standard
      assert evt.text == "A"
      assert evt.repeat == false
      assert evt.modifiers.shift == true
    end

    test "modifiers_changed returns KeyModifiers struct" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "modifiers_changed",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: true}
        })

      assert {:modifiers_changed, %Julep.KeyModifiers{ctrl: true, command: true}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- IME events" do
    test "decodes ime opened" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime",
          tag: "ime_tag",
          data: %{kind: "opened"}
        })

      assert {:ime_opened} = Protocol.decode_message(json, :json)
    end

    test "decodes ime preedit with cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime",
          tag: "ime_tag",
          data: %{kind: "preedit", text: "hello", cursor: %{start: 2, end: 5}}
        })

      assert {:ime_preedit, "hello", {2, 5}} = Protocol.decode_message(json, :json)
    end

    test "decodes ime preedit without cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime",
          tag: "ime_tag",
          data: %{kind: "preedit", text: "hi", cursor: nil}
        })

      assert {:ime_preedit, "hi", nil} = Protocol.decode_message(json, :json)
    end

    test "decodes ime commit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime",
          tag: "ime_tag",
          data: %{kind: "commit", text: "final"}
        })

      assert {:ime_commit, "final"} = Protocol.decode_message(json, :json)
    end

    test "decodes ime closed" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime",
          tag: "ime_tag",
          data: %{kind: "closed"}
        })

      assert {:ime_closed} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- effect_response ok" do
    test "decodes an ok effect response to {:effect_result, id, {:ok, result}}" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_1",
          status: "ok",
          result: %{body: "hello"}
        })

      assert {:effect_result, "req_1", {:ok, result}} = Protocol.decode_message(json, :json)
      assert result["body"] == "hello"
    end

    test "result can be any JSON-decodable value" do
      json = Jason.encode!(%{type: "effect_response", id: "r", status: "ok", result: 99})
      assert {:effect_result, "r", {:ok, 99}} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- effect_response error" do
    test "decodes an error effect response to {:effect_result, id, {:error, reason}}" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_2",
          status: "error",
          error: "connection refused"
        })

      assert Protocol.decode_message(json, :json) ==
               {:effect_result, "req_2", {:error, "connection refused"}}
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- error cases
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- error cases" do
    test "returns {:error, :decode_failed} for non-JSON input" do
      assert Protocol.decode_message("not json", :json) == {:error, :decode_failed}
    end

    test "returns {:error, :decode_failed} for empty string" do
      assert Protocol.decode_message("", :json) == {:error, :decode_failed}
    end

    test "returns {:error, {:unknown_message, _}} for a JSON object with an unrecognised type" do
      json = Jason.encode!(%{type: "poke", target: "the_bear"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end

    test "returns {:error, {:unknown_message, _}} for a known type with an unknown family" do
      json = Jason.encode!(%{type: "event", family: "levitate", id: "wizard"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end

    test "the unknown_message tuple carries the decoded map" do
      json = Jason.encode!(%{type: "mystery"})
      {:error, {:unknown_message, msg}} = Protocol.decode_message(json, :json)
      assert is_map(msg)
      assert msg["type"] == "mystery"
    end
  end

  # ---------------------------------------------------------------------------
  # parse_key/1
  # ---------------------------------------------------------------------------

  describe "parse_key/1 -- named keys" do
    test "converts 'Escape' to :escape" do
      assert Protocol.parse_key("Escape") == :escape
    end

    test "converts 'Enter' to :enter" do
      assert Protocol.parse_key("Enter") == :enter
    end

    test "converts 'Tab' to :tab" do
      assert Protocol.parse_key("Tab") == :tab
    end

    test "converts 'Backspace' to :backspace" do
      assert Protocol.parse_key("Backspace") == :backspace
    end

    test "converts 'Delete' to :delete" do
      assert Protocol.parse_key("Delete") == :delete
    end

    test "converts arrow keys to atoms" do
      assert Protocol.parse_key("ArrowUp") == :arrow_up
      assert Protocol.parse_key("ArrowDown") == :arrow_down
      assert Protocol.parse_key("ArrowLeft") == :arrow_left
      assert Protocol.parse_key("ArrowRight") == :arrow_right
    end

    test "converts navigation keys to atoms" do
      assert Protocol.parse_key("Home") == :home
      assert Protocol.parse_key("End") == :end
      assert Protocol.parse_key("PageUp") == :page_up
      assert Protocol.parse_key("PageDown") == :page_down
    end

    test "converts 'Space' to :space" do
      assert Protocol.parse_key("Space") == :space
    end

    test "converts function keys F1 through F12 to atoms" do
      for n <- 1..12 do
        key_string = "F#{n}"
        expected_atom = :"f#{n}"

        assert Protocol.parse_key(key_string) == expected_atom,
               "expected parse_key(#{inspect(key_string)}) == #{inspect(expected_atom)}"
      end
    end
  end

  describe "parse_key/1 -- single character keys" do
    test "passes a lowercase letter through unchanged" do
      assert Protocol.parse_key("a") == "a"
    end

    test "passes an uppercase letter through unchanged" do
      assert Protocol.parse_key("A") == "A"
    end

    test "passes a digit character through unchanged" do
      assert Protocol.parse_key("5") == "5"
    end

    test "passes a punctuation character through unchanged" do
      assert Protocol.parse_key(".") == "."
    end

    test "an unrecognised multi-character string also passes through unchanged" do
      assert Protocol.parse_key("SomeFutureKey") == "SomeFutureKey"
    end

    test "Hyper is now a known named key" do
      assert Protocol.parse_key("Hyper") == :hyper
    end
  end

  # ---------------------------------------------------------------------------
  # encode_widget_op/2
  # ---------------------------------------------------------------------------

  describe "encode_widget_op/2" do
    test "produces a JSON object with type 'widget_op'" do
      result = Protocol.encode_widget_op("focus", %{target: "username"}, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "widget_op"
    end

    test "includes the op and payload fields" do
      result = Protocol.encode_widget_op("scroll_to", %{target: "feed", offset: 42}, :json)
      parsed = decode_json!(result)
      assert parsed["op"] == "scroll_to"
      assert parsed["payload"]["target"] == "feed"
      assert parsed["payload"]["offset"] == 42
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_widget_op("focus_next", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode_window_op/3
  # ---------------------------------------------------------------------------

  describe "encode_window_op/3" do
    test "produces a JSON object with type 'window_op'" do
      result = Protocol.encode_window_op("open", "main", %{title: "App"}, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "window_op"
    end

    test "includes op, window_id, and settings fields" do
      result = Protocol.encode_window_op("close", "settings", %{}, :json)
      parsed = decode_json!(result)
      assert parsed["op"] == "close"
      assert parsed["window_id"] == "settings"
      assert parsed["settings"] == %{}
    end

    test "settings map is preserved" do
      settings = %{title: "Preferences", width: 800, height: 600}
      result = Protocol.encode_window_op("open", "prefs", settings, :json)
      parsed = decode_json!(result)
      assert parsed["settings"]["title"] == "Preferences"
      assert parsed["settings"]["width"] == 800
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_window_op("open", "main", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # Binary data roundtrips (set_icon)
  # ---------------------------------------------------------------------------

  describe "window_op with binary data (set_icon)" do
    test "roundtrips icon_data through JSON as base64 string" do
      rgba = :crypto.strong_rand_bytes(32 * 32 * 4)
      encoded = Base.encode64(rgba)

      json =
        Protocol.encode_window_op(
          "set_icon",
          "main",
          %{
            "icon_data" => encoded,
            "width" => 32,
            "height" => 32
          },
          :json
        )

      assert {:ok, decoded} = Jason.decode(String.trim_trailing(json, "\n"))
      assert decoded["type"] == "window_op"
      assert decoded["op"] == "set_icon"
      assert decoded["settings"]["icon_data"] == encoded
      assert Base.decode64!(decoded["settings"]["icon_data"]) == rgba
    end

    test "roundtrips icon_data through msgpack as base64 string" do
      rgba = :crypto.strong_rand_bytes(32 * 32 * 4)
      encoded = Base.encode64(rgba)

      data =
        Protocol.encode_window_op(
          "set_icon",
          "main",
          %{
            "icon_data" => encoded,
            "width" => 32,
            "height" => 32
          },
          :msgpack
        )

      assert {:ok, decoded} = Msgpax.unpack(data)
      assert decoded["type"] == "window_op"
      assert decoded["op"] == "set_icon"
      assert decoded["settings"]["icon_data"] == encoded
      assert Base.decode64!(decoded["settings"]["icon_data"]) == rgba
    end
  end

  # ---------------------------------------------------------------------------
  # encode_subscription_register/2
  # ---------------------------------------------------------------------------

  describe "encode_subscription_register/2" do
    test "produces a JSON object with type 'subscription_register'" do
      result = Protocol.encode_subscription_register("on_key_press", "keys", :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "subscription_register"
    end

    test "includes kind and tag fields" do
      result = Protocol.encode_subscription_register("every", "timer_tick", :json)
      parsed = decode_json!(result)
      assert parsed["kind"] == "every"
      assert parsed["tag"] == "timer_tick"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_subscription_register("on_window_close", "close", :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode_subscription_unregister/1
  # ---------------------------------------------------------------------------

  describe "encode_subscription_unregister/1" do
    test "produces a JSON object with type 'subscription_unregister'" do
      result = Protocol.encode_subscription_unregister("on_key_press", :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "subscription_unregister"
    end

    test "includes the kind field" do
      result = Protocol.encode_subscription_unregister("every", :json)
      parsed = decode_json!(result)
      assert parsed["kind"] == "every"
    end

    test "does not include a tag field" do
      result = Protocol.encode_subscription_unregister("on_window_event", :json)
      parsed = decode_json!(result)
      refute Map.has_key?(parsed, "tag")
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_subscription_unregister("every", :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode/decode roundtrip
  # ---------------------------------------------------------------------------

  describe "encode -> decode roundtrip for events" do
    test "click event survives JSON roundtrip" do
      # Simulate what the renderer would send back
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_1"})
      assert {:click, "btn_1"} = Protocol.decode_message(json, :json)
    end

    test "input event survives JSON roundtrip" do
      json = Jason.encode!(%{type: "event", family: "input", id: "field", value: "hello"})
      assert {:input, "field", "hello"} = Protocol.decode_message(json, :json)
    end

    test "effect_response ok survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r1", status: "ok", result: %{data: 42}})

      assert {:effect_result, "r1", {:ok, %{"data" => 42}}} = Protocol.decode_message(json, :json)
    end

    test "effect_response error survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r2", status: "error", error: "timeout"})

      assert {:effect_result, "r2", {:error, "timeout"}} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- mouse area events
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- mouse_middle_press" do
    test "decodes mouse_middle_press event to {:mouse_middle_press, id}" do
      json = Jason.encode!(%{type: "event", family: "mouse_middle_press", id: "zone"})
      assert Protocol.decode_message(json, :json) == {:mouse_middle_press, "zone"}
    end

    test "decodes mouse_middle_press from msgpack" do
      event = %{"type" => "event", "family" => "mouse_middle_press", "id" => "zone"}
      packed = Msgpax.pack!(event, iodata: false)
      assert {:mouse_middle_press, "zone"} = Protocol.decode_message(packed, :msgpack)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- key_release events (if supported)
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- edge cases" do
    test "JSON array (not object) is treated as unknown message" do
      json = Jason.encode!([1, 2, 3])
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end

    test "JSON null is treated as unknown message" do
      assert {:error, {:unknown_message, _}} = Protocol.decode_message("null", :json)
    end

    test "JSON number is treated as unknown message" do
      assert {:error, {:unknown_message, _}} = Protocol.decode_message("42", :json)
    end

    test "JSON string is treated as unknown message" do
      assert {:error, {:unknown_message, _}} = Protocol.decode_message("\"hello\"", :json)
    end

    test "event with missing required fields treated as unknown" do
      # click without id
      json = Jason.encode!(%{type: "event", family: "click"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end

    test "effect_response with unknown status treated as unknown" do
      json = Jason.encode!(%{type: "effect_response", id: "r", status: "pending", result: nil})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # msgpack encode/decode roundtrips
  # ---------------------------------------------------------------------------

  describe "msgpack encode/decode roundtrips" do
    test "settings roundtrip" do
      settings = %{"theme" => "dark"}
      encoded = Protocol.encode_settings(settings, :msgpack)
      assert {:settings, ^settings} = Protocol.decode_message(encoded, :msgpack)
    end

    test "snapshot roundtrip" do
      tree = %{"id" => "root", "type" => "column", "props" => %{}, "children" => []}
      encoded = Protocol.encode_snapshot(tree, :msgpack)
      assert {:snapshot, ^tree} = Protocol.decode_message(encoded, :msgpack)
    end

    test "patch roundtrip" do
      ops = [%{"op" => "replace", "path" => "/label", "value" => "Save"}]
      encoded = Protocol.encode_patch(ops, :msgpack)
      assert {:patch, ^ops} = Protocol.decode_message(encoded, :msgpack)
    end

    test "effect_request roundtrip" do
      encoded =
        Protocol.encode_effect_request(
          "req_1",
          "http",
          %{"url" => "https://example.com"},
          :msgpack
        )

      assert {:effect_request, "req_1", "http", %{"url" => "https://example.com"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "widget_op roundtrip" do
      encoded = Protocol.encode_widget_op("focus", %{"target" => "username"}, :msgpack)

      assert {:widget_op, "focus", %{"target" => "username"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "subscription_register roundtrip" do
      encoded = Protocol.encode_subscription_register("on_key_press", "keys", :msgpack)

      assert {:subscription_register, "on_key_press", "keys"} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "subscription_unregister roundtrip" do
      encoded = Protocol.encode_subscription_unregister("on_key_press", :msgpack)

      assert {:subscription_unregister, "on_key_press"} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "window_op roundtrip" do
      encoded = Protocol.encode_window_op("open", "main", %{"title" => "My App"}, :msgpack)

      assert {:window_op, "open", "main", %{"title" => "My App"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "event decode from msgpack" do
      event = %{"type" => "event", "family" => "click", "id" => "btn1"}
      packed = Msgpax.pack!(event, iodata: false)
      assert {:click, "btn1"} = Protocol.decode_message(packed, :msgpack)
    end

    test "input event decode from msgpack" do
      event = %{"type" => "event", "family" => "input", "id" => "field", "value" => "hello"}
      packed = Msgpax.pack!(event, iodata: false)
      assert {:input, "field", "hello"} = Protocol.decode_message(packed, :msgpack)
    end

    test "effect_response ok decode from msgpack" do
      msg = %{
        "type" => "effect_response",
        "id" => "r1",
        "status" => "ok",
        "result" => %{"data" => 42}
      }

      packed = Msgpax.pack!(msg, iodata: false)

      assert {:effect_result, "r1", {:ok, %{"data" => 42}}} =
               Protocol.decode_message(packed, :msgpack)
    end

    test "effect_response error decode from msgpack" do
      msg = %{
        "type" => "effect_response",
        "id" => "r2",
        "status" => "error",
        "error" => "timeout"
      }

      packed = Msgpax.pack!(msg, iodata: false)

      assert {:effect_result, "r2", {:error, "timeout"}} =
               Protocol.decode_message(packed, :msgpack)
    end

    test "invalid msgpack returns {:error, :decode_failed}" do
      assert {:error, :decode_failed} = Protocol.decode_message(<<0xFF, 0xFF>>, :msgpack)
    end
  end

  # ---------------------------------------------------------------------------
  # encode_extension_command/4
  # ---------------------------------------------------------------------------

  describe "encode_extension_command/4" do
    test "produces valid JSON message" do
      result = Protocol.encode_extension_command("term-1", "write", %{"data" => "hello"}, :json)
      decoded = decode_json!(result)
      assert decoded["type"] == "extension_command"
      assert decoded["node_id"] == "term-1"
      assert decoded["op"] == "write"
      assert decoded["payload"]["data"] == "hello"
    end

    test "produces valid msgpack message" do
      result = Protocol.encode_extension_command("ext-1", "reset", %{}, :msgpack)
      {:ok, decoded} = Msgpax.unpack(result)
      assert decoded["type"] == "extension_command"
      assert decoded["node_id"] == "ext-1"
      assert decoded["op"] == "reset"
    end
  end

  # ---------------------------------------------------------------------------
  # encode_extension_commands/2
  # ---------------------------------------------------------------------------

  describe "encode_extension_commands/2" do
    test "produces valid JSON batch message" do
      commands = [
        {"term-1", "write", %{"data" => "a"}},
        {"log-1", "append", %{"line" => "x"}}
      ]

      result = Protocol.encode_extension_commands(commands, :json)
      decoded = decode_json!(result)
      assert decoded["type"] == "extension_command_batch"
      assert length(decoded["commands"]) == 2
      assert Enum.at(decoded["commands"], 0)["node_id"] == "term-1"
      assert Enum.at(decoded["commands"], 1)["op"] == "append"
    end

    test "produces valid msgpack batch message" do
      commands = [{"n1", "op1", %{"k" => "v"}}]
      result = Protocol.encode_extension_commands(commands, :msgpack)
      {:ok, decoded} = Msgpax.unpack(result)
      assert decoded["type"] == "extension_command_batch"
      assert length(decoded["commands"]) == 1
    end
  end
end
