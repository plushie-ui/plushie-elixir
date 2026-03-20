defmodule Toddy.ProtocolTest do
  use ExUnit.Case, async: true

  alias Toddy.Event.Canvas
  alias Toddy.Event.Effect
  alias Toddy.Event.Ime
  alias Toddy.Event.Key
  alias Toddy.Event.Modifiers
  alias Toddy.Event.MouseArea
  alias Toddy.Event.System, as: SystemEvent
  alias Toddy.Event.Touch
  alias Toddy.Event.Widget

  alias Toddy.Protocol

  doctest Toddy.Protocol

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
  # encode_effect/3
  # ---------------------------------------------------------------------------

  describe "encode_effect/3" do
    test "produces a JSON object with type 'effect'" do
      result =
        Protocol.encode_effect("req_1", "http", %{url: "https://example.com"}, :json)

      parsed = decode_json!(result)
      assert parsed["type"] == "effect"
    end

    test "includes the id, kind, and payload fields" do
      result = Protocol.encode_effect("req_42", "shell", %{cmd: "ls"}, :json)
      parsed = decode_json!(result)
      assert parsed["id"] == "req_42"
      assert parsed["kind"] == "shell"
      assert is_map(parsed["payload"])
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_effect("r", "k", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- event families
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- click events" do
    test "decodes a click event to %Widget{type: :click, id: id}" do
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_save"})
      assert Protocol.decode_message(json, :json) == %Widget{type: :click, id: "btn_save"}
    end

    test "scoped widget id is split into local id and scope" do
      json = Jason.encode!(%{type: "event", family: "click", id: "panel/submit"})

      assert %Widget{type: :click, id: "submit", scope: ["panel"]} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- input events" do
    test "decodes an input event to {:input, id, value}" do
      json = Jason.encode!(%{type: "event", family: "input", id: "search", value: "elixir"})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :input,
               id: "search",
               value: "elixir"
             }
    end

    test "preserves an empty string value" do
      json = Jason.encode!(%{type: "event", family: "input", id: "field", value: ""})
      assert %Widget{type: :input, id: "field", value: ""} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- submit events" do
    test "decodes a submit event to {:submit, id, value}" do
      json = Jason.encode!(%{type: "event", family: "submit", id: "login_form", value: "admin"})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :submit,
               id: "login_form",
               value: "admin"
             }
    end
  end

  describe "decode_message/1 -- toggle events" do
    test "decodes a toggle event to {:toggle, id, value}" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: true})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :toggle,
               id: "dark_mode",
               value: true
             }
    end

    test "decodes a toggle-off correctly" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: false})

      assert %Widget{type: :toggle, id: "dark_mode", value: false} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- select events" do
    test "decodes a select event to {:select, id, value}" do
      json = Jason.encode!(%{type: "event", family: "select", id: "lang_picker", value: "fr"})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :select,
               id: "lang_picker",
               value: "fr"
             }
    end
  end

  describe "decode_message/1 -- slide events" do
    test "decodes a slide event to {:slide, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "volume", value: 0.75})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :slide,
               id: "volume",
               value: 0.75
             }
    end

    test "value can be an integer" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "zoom", value: 100})
      assert %Widget{type: :slide, id: "zoom", value: 100} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- slide_release events" do
    test "decodes a slide_release event to {:slide_release, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide_release", id: "scrubber", value: 42.0})

      assert Protocol.decode_message(json, :json) == %Widget{
               type: :slide_release,
               id: "scrubber",
               value: 42.0
             }
    end
  end

  describe "decode_message/1 -- key events (key in data.key)" do
    test "decodes a named key to %Key{type: :press}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          data: %{key: "Escape"}
        })

      assert %Key{type: :press, key: :escape} = Protocol.decode_message(json, :json)
    end

    test "decodes a character key to %Key{type: :press, key: string}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          data: %{key: "a"}
        })

      assert %Key{type: :press, key: "a"} = Protocol.decode_message(json, :json)
    end

    test "modifiers are a KeyModifiers struct with all fields" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false},
          data: %{key: "s"}
        })

      %Key{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert %Toddy.KeyModifiers{} = mods
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
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false},
          data: %{key: "c"}
        })

      %Key{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert mods.ctrl == true
      assert mods.shift == false
    end

    test "modifiers absent from the wire message default to false" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{},
          data: %{key: "z"}
        })

      %Key{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert mods.ctrl == false
      assert mods.alt == false
    end

    test "decodes a key_release event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          data: %{key: "Enter"}
        })

      assert %Key{type: :release, key: :enter} = Protocol.decode_message(json, :json)
    end

    test "decodes extra key event fields (nested data from Rust)" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: true, alt: false, logo: false, command: false},
          data: %{
            key: "a",
            modified_key: "A",
            physical_key: "KeyA",
            location: "standard",
            text: "A",
            repeat: false
          }
        })

      %Key{type: :press} = evt = Protocol.decode_message(json, :json)
      assert %Key{} = evt
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

      assert %Modifiers{modifiers: %Toddy.KeyModifiers{ctrl: true, command: true}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- IME events (separate families)" do
    test "decodes ime_opened" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_opened",
          id: "editor"
        })

      assert %Ime{type: :opened, id: "editor", scope: [], captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_preedit with cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_preedit",
          id: "editor",
          data: %{text: "hello", cursor: %{start: 2, end: 5}}
        })

      assert %Ime{type: :preedit, id: "editor", text: "hello", cursor: {2, 5}, captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_preedit without cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_preedit",
          id: "editor",
          data: %{text: "hi"}
        })

      assert %Ime{type: :preedit, id: "editor", text: "hi", cursor: nil, captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_commit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_commit",
          id: "editor",
          data: %{text: "final"}
        })

      assert %Ime{type: :commit, id: "editor", text: "final", captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_closed" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_closed",
          id: "editor"
        })

      assert %Ime{type: :closed, id: "editor", captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "scoped ime event splits id and scope" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_opened",
          id: "form/editor"
        })

      assert %Ime{type: :opened, id: "editor", scope: ["form"]} =
               Protocol.decode_message(json, :json)
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

      assert %Effect{request_id: "req_1", result: {:ok, result}} =
               Protocol.decode_message(json, :json)

      assert result["body"] == "hello"
    end

    test "result can be any JSON-decodable value" do
      json = Jason.encode!(%{type: "effect_response", id: "r", status: "ok", result: 99})
      assert %Effect{request_id: "r", result: {:ok, 99}} = Protocol.decode_message(json, :json)
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
               %Effect{request_id: "req_2", result: {:error, "connection refused"}}
    end
  end

  describe "decode_message/1 -- effect_response cancelled" do
    test "decodes a cancelled effect response to :cancelled" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_3",
          status: "cancelled"
        })

      assert Protocol.decode_message(json, :json) ==
               %Effect{request_id: "req_3", result: :cancelled}
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

    test "unknown event family dispatches as generic Widget event" do
      json = Jason.encode!(%{type: "event", family: "levitate", id: "wizard"})

      assert %Toddy.Event.Widget{type: "levitate", id: "wizard"} =
               Protocol.decode_message(json, :json)
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
    test "encodes raw icon_data as base64 in JSON mode" do
      rgba = :crypto.strong_rand_bytes(32 * 32 * 4)

      json =
        Protocol.encode_window_op(
          "set_icon",
          "main",
          %{icon_data: rgba, width: 32, height: 32},
          :json
        )

      assert {:ok, decoded} = Jason.decode(String.trim_trailing(json, "\n"))
      assert decoded["type"] == "window_op"
      assert decoded["op"] == "set_icon"
      assert Base.decode64!(decoded["settings"]["icon_data"]) == rgba
    end

    test "encodes raw icon_data as native binary in msgpack mode" do
      rgba = :crypto.strong_rand_bytes(32 * 32 * 4)

      data =
        Protocol.encode_window_op(
          "set_icon",
          "main",
          %{icon_data: rgba, width: 32, height: 32},
          :msgpack
        )

      assert {:ok, decoded} = Msgpax.unpack(data)
      assert decoded["type"] == "window_op"
      assert decoded["op"] == "set_icon"
      # msgpack native binary roundtrips back to raw binary
      assert decoded["settings"]["icon_data"] == rgba
    end
  end

  # ---------------------------------------------------------------------------
  # encode_subscribe/2
  # ---------------------------------------------------------------------------

  describe "encode_subscribe/2" do
    test "produces a JSON object with type 'subscribe'" do
      result = Protocol.encode_subscribe("on_key_press", "keys", :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "subscribe"
    end

    test "includes kind and tag fields" do
      result = Protocol.encode_subscribe("every", "timer_tick", :json)
      parsed = decode_json!(result)
      assert parsed["kind"] == "every"
      assert parsed["tag"] == "timer_tick"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_subscribe("on_window_close", "close", :json)
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode_unsubscribe/1
  # ---------------------------------------------------------------------------

  describe "encode_unsubscribe/1" do
    test "produces a JSON object with type 'unsubscribe'" do
      result = Protocol.encode_unsubscribe("on_key_press", :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "unsubscribe"
    end

    test "includes the kind field" do
      result = Protocol.encode_unsubscribe("every", :json)
      parsed = decode_json!(result)
      assert parsed["kind"] == "every"
    end

    test "does not include a tag field" do
      result = Protocol.encode_unsubscribe("on_window_event", :json)
      parsed = decode_json!(result)
      refute Map.has_key?(parsed, "tag")
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_unsubscribe("every", :json)
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
      assert %Widget{type: :click, id: "btn_1"} = Protocol.decode_message(json, :json)
    end

    test "input event survives JSON roundtrip" do
      json = Jason.encode!(%{type: "event", family: "input", id: "field", value: "hello"})

      assert %Widget{type: :input, id: "field", value: "hello"} =
               Protocol.decode_message(json, :json)
    end

    test "effect_response ok survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r1", status: "ok", result: %{data: 42}})

      assert %Effect{request_id: "r1", result: {:ok, %{"data" => 42}}} =
               Protocol.decode_message(json, :json)
    end

    test "effect_response error survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r2", status: "error", error: "timeout"})

      assert %Effect{request_id: "r2", result: {:error, "timeout"}} =
               Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- mouse area events
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- mouse_middle_press" do
    test "decodes mouse_middle_press event to {:mouse_middle_press, id}" do
      json = Jason.encode!(%{type: "event", family: "mouse_middle_press", id: "zone"})
      assert Protocol.decode_message(json, :json) == %MouseArea{type: :middle_press, id: "zone"}
    end

    test "decodes mouse_middle_press from msgpack" do
      event = %{"type" => "event", "family" => "mouse_middle_press", "id" => "zone"}
      packed = Msgpax.pack!(event, iodata: false)

      assert %MouseArea{type: :middle_press, id: "zone"} =
               Protocol.decode_message(packed, :msgpack)
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
      assert {:settings, decoded_settings} = Protocol.decode_message(encoded, :msgpack)
      assert decoded_settings["theme"] == "dark"
      assert decoded_settings["protocol_version"] == 1
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

    test "effect roundtrip" do
      encoded =
        Protocol.encode_effect(
          "req_1",
          "http",
          %{"url" => "https://example.com"},
          :msgpack
        )

      assert {:effect, "req_1", "http", %{"url" => "https://example.com"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "widget_op roundtrip" do
      encoded = Protocol.encode_widget_op("focus", %{"target" => "username"}, :msgpack)

      assert {:widget_op, "focus", %{"target" => "username"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "subscribe roundtrip" do
      encoded = Protocol.encode_subscribe("on_key_press", "keys", :msgpack)

      assert {:subscribe, "on_key_press", "keys"} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "unsubscribe roundtrip" do
      encoded = Protocol.encode_unsubscribe("on_key_press", :msgpack)

      assert {:unsubscribe, "on_key_press"} =
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
      assert %Widget{type: :click, id: "btn1"} = Protocol.decode_message(packed, :msgpack)
    end

    test "input event decode from msgpack" do
      event = %{"type" => "event", "family" => "input", "id" => "field", "value" => "hello"}
      packed = Msgpax.pack!(event, iodata: false)

      assert %Widget{type: :input, id: "field", value: "hello"} =
               Protocol.decode_message(packed, :msgpack)
    end

    test "effect_response ok decode from msgpack" do
      msg = %{
        "type" => "effect_response",
        "id" => "r1",
        "status" => "ok",
        "result" => %{"data" => 42}
      }

      packed = Msgpax.pack!(msg, iodata: false)

      assert %Effect{request_id: "r1", result: {:ok, %{"data" => 42}}} =
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

      assert %Effect{request_id: "r2", result: {:error, "timeout"}} =
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
  # hello message
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- hello" do
    test "decodes a hello message with backend and extensions" do
      json =
        Jason.encode!(%{
          type: "hello",
          protocol: 1,
          version: "0.3.2",
          name: "toddy",
          backend: "tiny-skia",
          extensions: ["charts"]
        })

      assert {:hello, 1, "0.3.2", "toddy", "tiny-skia", ["charts"]} =
               Protocol.decode_message(json, :json)
    end

    test "hello defaults backend and extensions when absent" do
      json =
        Jason.encode!(%{
          type: "hello",
          protocol: 1,
          version: "0.3.0",
          name: "toddy"
        })

      assert {:hello, 1, "0.3.0", "toddy", "unknown", []} =
               Protocol.decode_message(json, :json)
    end

    test "decodes hello from msgpack" do
      msg = %{
        "type" => "hello",
        "protocol" => 1,
        "version" => "0.3.2",
        "name" => "toddy",
        "backend" => "wgpu",
        "extensions" => []
      }

      packed = Msgpax.pack!(msg, iodata: false)

      assert {:hello, 1, "0.3.2", "toddy", "wgpu", []} =
               Protocol.decode_message(packed, :msgpack)
    end
  end

  # ---------------------------------------------------------------------------
  # protocol_version/0
  # ---------------------------------------------------------------------------

  describe "protocol_version/0" do
    test "returns a positive integer" do
      version = Protocol.protocol_version()
      assert is_integer(version)
      assert version > 0
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
      assert decoded["type"] == "extension_commands"
      assert length(decoded["commands"]) == 2
      assert Enum.at(decoded["commands"], 0)["node_id"] == "term-1"
      assert Enum.at(decoded["commands"], 1)["op"] == "append"
    end

    test "produces valid msgpack batch message" do
      commands = [{"n1", "op1", %{"k" => "v"}}]
      result = Protocol.encode_extension_commands(commands, :msgpack)
      {:ok, decoded} = Msgpax.unpack(result)
      assert decoded["type"] == "extension_commands"
      assert length(decoded["commands"]) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- touch events (id field rename)
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- touch events (wire id field)" do
    test "decodes finger_pressed with data.id" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_pressed",
          data: %{id: 0, x: 50.0, y: 75.0}
        })

      assert %Touch{type: :pressed, finger_id: 0, x: 50.0, y: 75.0} =
               Protocol.decode_message(json, :json)
    end

    test "decodes finger_moved with data.id" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_moved",
          data: %{id: 1, x: 60.0, y: 80.0}
        })

      assert %Touch{type: :moved, finger_id: 1, x: 60.0, y: 80.0} =
               Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- canvas scroll (cursor_x/cursor_y)
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- canvas_scroll field rename" do
    test "reads cursor_x/cursor_y into x/y struct fields" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "canvas_scroll",
          id: "viewport",
          data: %{cursor_x: 5.0, cursor_y: 10.0, delta_x: 0.0, delta_y: -1.0}
        })

      assert %Canvas{type: :scroll, id: "viewport", x: 5.0, y: 10.0, delta_x: +0.0, delta_y: -1.0} =
               Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- session events
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- session events" do
    test "decodes session_error" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "session_error",
          session: "s1",
          id: "",
          data: %{error: "session panicked"}
        })

      assert {:session_error, "s1", "session panicked"} = Protocol.decode_message(json, :json)
    end

    test "decodes session_closed" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "session_closed",
          session: "s2",
          id: "",
          data: %{reason: "reset"}
        })

      assert {:session_closed, "s2", "reset"} = Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- announce event
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- announce event" do
    test "decodes announce as System event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "announce",
          id: "",
          data: %{text: "Item saved"}
        })

      assert %SystemEvent{type: :announce, data: "Item saved"} =
               Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- duplicate_node_ids error
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- duplicate_node_ids error" do
    test "decodes duplicate_node_ids error as System event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "error",
          id: "duplicate_node_ids",
          data: %{error: "duplicate IDs found", duplicates: ["btn1 (button)", "btn1 (text)"]}
        })

      assert %SystemEvent{type: :error, data: %{error: "duplicate_node_ids", details: details}} =
               Protocol.decode_message(json, :json)

      assert details["duplicates"] == ["btn1 (button)", "btn1 (text)"]
    end
  end
end
