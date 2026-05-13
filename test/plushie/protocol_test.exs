defmodule Plushie.ProtocolTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Diagnostic
  alias Plushie.Event.DiagnosticMessage
  alias Plushie.Event.ImeEvent
  alias Plushie.Event.KeyEvent
  alias Plushie.Event.ModifiersEvent
  alias Plushie.Event.SystemEvent
  alias Plushie.Event.WidgetEvent

  alias Plushie.Protocol

  doctest Plushie.Protocol

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp decode_json!(str) do
    str |> String.trim_trailing("\n") |> Jason.decode!()
  end

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
  # decode_message/1: event families
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- click events" do
    test "decodes a click event to %WidgetEvent{type: :click, id: id}" do
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_save", window_id: "main"})

      assert Protocol.decode_message(json, :json) ==
               %WidgetEvent{type: :click, id: "btn_save", scope: ["main"], window_id: "main"}
    end

    test "scoped widget id is split into local id and scope" do
      json =
        Jason.encode!(%{type: "event", family: "click", id: "panel/submit", window_id: "main"})

      assert %WidgetEvent{type: :click, id: "submit", scope: ["panel", "main"], window_id: "main"} =
               Protocol.decode_message(json, :json)
    end

    test "preserves window_id on widget events" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "click",
          id: "save",
          window_id: "main"
        })

      assert %WidgetEvent{type: :click, id: "save", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- input events" do
    test "decodes an input event to {:input, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "input",
          id: "search",
          value: "elixir",
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :input,
               id: "search",
               value: "elixir",
               scope: ["main"],
               window_id: "main"
             }
    end

    test "preserves an empty string value" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "input",
          id: "field",
          value: "",
          window_id: "main"
        })

      assert %WidgetEvent{type: :input, id: "field", value: "", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- submit events" do
    test "decodes a submit event to {:submit, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "submit",
          id: "login_form",
          value: "admin",
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :submit,
               id: "login_form",
               value: "admin",
               scope: ["main"],
               window_id: "main"
             }
    end
  end

  describe "decode_message/1 -- toggle events" do
    test "decodes a toggle event to {:toggle, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "toggle",
          id: "dark_mode",
          value: true,
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :toggle,
               id: "dark_mode",
               value: true,
               scope: ["main"],
               window_id: "main"
             }
    end

    test "decodes a toggle-off correctly" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "toggle",
          id: "dark_mode",
          value: false,
          window_id: "main"
        })

      assert %WidgetEvent{type: :toggle, id: "dark_mode", value: false, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- select events" do
    test "decodes a select event to {:select, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "select",
          id: "lang_picker",
          value: "fr",
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :select,
               id: "lang_picker",
               value: "fr",
               scope: ["main"],
               window_id: "main"
             }
    end
  end

  describe "decode_message/1 -- slide events" do
    test "decodes a slide event to {:slide, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "slide",
          id: "volume",
          value: 0.75,
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :slide,
               id: "volume",
               value: 0.75,
               scope: ["main"],
               window_id: "main"
             }
    end

    test "value can be an integer" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "slide",
          id: "zoom",
          value: 100,
          window_id: "main"
        })

      assert %WidgetEvent{type: :slide, id: "zoom", value: 100, window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- slide_release events" do
    test "decodes a slide_release event to {:slide_release, id, value}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "slide_release",
          id: "scrubber",
          value: 42.0,
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :slide_release,
               id: "scrubber",
               value: 42.0,
               scope: ["main"],
               window_id: "main"
             }
    end
  end

  describe "decode_message/1 -- link_click events" do
    test "decodes a link_click event with the link URL as value" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "link_click",
          id: "article",
          value: %{link: "https://example.com/article"},
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :link_click,
               id: "article",
               value: "https://example.com/article",
               scope: ["main"],
               window_id: "main"
             }
    end
  end

  describe "decode_message/1 -- sort events" do
    test "decodes sort value as the column key string" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "sort",
          id: "users",
          value: "name",
          window_id: "main"
        })

      assert Protocol.decode_message(json, :json) == %WidgetEvent{
               type: :sort,
               id: "users",
               value: "name",
               scope: ["main"],
               window_id: "main"
             }
    end

    test "rejects malformed sort values" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "sort",
          id: "users",
          value: %{column: "name"}
        })

      assert {:error, {:invalid_event_field, "sort", :value, _, :expected_binary, _}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- key_binding events" do
    test "decodes dynamic key binding data as a map" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_binding",
          id: "editor",
          value: %{action: "save", key: "s"},
          window_id: "main"
        })

      assert %WidgetEvent{
               type: :key_binding,
               id: "editor",
               value: %{action: "save", key: "s"}
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- key events (key in value.key)" do
    test "decodes a named key to %KeyEvent{type: :press}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{key: "Escape"}
        })

      assert %KeyEvent{type: :press, key: :escape} = Protocol.decode_message(json, :json)
    end

    test "decodes a character key to %KeyEvent{type: :press, key: string}" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{key: "a"}
        })

      assert %KeyEvent{type: :press, key: "a"} = Protocol.decode_message(json, :json)
    end

    test "modifiers are a KeyModifiers struct with all fields" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false},
          value: %{key: "s"}
        })

      %KeyEvent{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert %Plushie.KeyModifiers{} = mods
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
          value: %{key: "c"}
        })

      %KeyEvent{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert mods.ctrl == true
      assert mods.shift == false
    end

    test "modifiers absent from the wire message default to false" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{},
          value: %{key: "z"}
        })

      %KeyEvent{type: :press, modifiers: mods} = Protocol.decode_message(json, :json)
      assert mods.ctrl == false
      assert mods.alt == false
    end

    test "decodes a key_release event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{key: "Enter"}
        })

      assert %KeyEvent{type: :release, key: :enter} = Protocol.decode_message(json, :json)
    end

    test "rejects key event with scalar value instead of value.key map" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: "Escape"
        })

      assert {:error, {:invalid_event_field, "key_press", :data, _, :required, _}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes modifiers nested under value" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          value: %{
            key: "s",
            modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
          }
        })

      assert %KeyEvent{type: :press, key: "s", modifiers: %Plushie.KeyModifiers{ctrl: true}} =
               Protocol.decode_message(json, :json)
    end

    test "rejects malformed key event without a key" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: false, alt: false, logo: false, command: false},
          value: %{}
        })

      assert {:error, {:invalid_event_field, "key_press", :key, nil, :required, _}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes extra key event fields (nested value from Rust)" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          modifiers: %{ctrl: false, shift: true, alt: false, logo: false, command: false},
          value: %{
            key: "a",
            modified_key: "A",
            physical_key: "KeyA",
            location: "standard",
            text: "A",
            repeat: false
          }
        })

      %KeyEvent{type: :press} = evt = Protocol.decode_message(json, :json)
      assert %KeyEvent{} = evt
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

      assert %ModifiersEvent{modifiers: %Plushie.KeyModifiers{ctrl: true, command: true}} =
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

      assert %ImeEvent{type: :opened, id: "editor", scope: [], captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_preedit with cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_preedit",
          id: "editor",
          value: %{text: "hello", cursor: %{start: 2, end: 5}}
        })

      assert %ImeEvent{
               type: :preedit,
               id: "editor",
               text: "hello",
               cursor: {2, 5},
               captured: false
             } =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_preedit without cursor" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_preedit",
          id: "editor",
          value: %{text: "hi"}
        })

      assert %ImeEvent{type: :preedit, id: "editor", text: "hi", cursor: nil, captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_commit" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_commit",
          id: "editor",
          value: %{text: "final"}
        })

      assert %ImeEvent{type: :commit, id: "editor", text: "final", captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "decodes ime_closed" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_closed",
          id: "editor"
        })

      assert %ImeEvent{type: :closed, id: "editor", captured: false} =
               Protocol.decode_message(json, :json)
    end

    test "scoped ime event splits id and scope" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "ime_opened",
          id: "form/editor"
        })

      assert %ImeEvent{type: :opened, id: "editor", scope: ["form"]} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- effect_response ok" do
    test "decodes an ok effect response to {:effect_response, id, status, result}" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_1",
          status: "ok",
          result: %{body: "hello"}
        })

      assert {:effect_response, "req_1", "ok", result} =
               Protocol.decode_message(json, :json)

      assert result[:body] == "hello"
    end

    test "result can be any JSON-decodable value" do
      json = Jason.encode!(%{type: "effect_response", id: "r", status: "ok", result: 99})
      assert {:effect_response, "r", "ok", 99} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- effect_response error" do
    test "decodes an error effect response to {:effect_response, id, \"error\", reason}" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_2",
          status: "error",
          error: "connection refused"
        })

      assert {:effect_response, "req_2", "error", "connection refused"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- effect_response cancelled" do
    test "decodes a cancelled effect response to {:effect_response, id, \"cancelled\", nil}" do
      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "req_3",
          status: "cancelled"
        })

      assert {:effect_response, "req_3", "cancelled", nil} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- error cases" do
    test "returns detailed decode error for non-JSON input" do
      assert {:error, {:decode_failed, %Jason.DecodeError{}}} =
               Protocol.decode_message("not json", :json)
    end

    test "returns detailed decode error for empty string" do
      assert {:error, {:decode_failed, %Jason.DecodeError{}}} =
               Protocol.decode_message("", :json)
    end

    test "returns {:error, {:unknown_message, _}} for a JSON object with an unrecognised type" do
      json = Jason.encode!(%{type: "poke", target: "the_bear"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
    end

    test "unknown built-in event family returns protocol error" do
      json = Jason.encode!(%{type: "event", family: "levitate", id: "wizard"})

      assert {:error, {:unknown_event_family, "levitate", _}} =
               Protocol.decode_message(json, :json)
    end

    test "non-binary event family returns protocol error" do
      json = Jason.encode!(%{type: "event", family: 123, id: "wizard"})

      assert {:error, {:unknown_event_family, 123, _}} = Protocol.decode_message(json, :json)
    end

    test "custom event family dispatches as widget event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wizard:levitate",
          id: "wizard",
          window_id: "main",
          value: %{speed: "fast"}
        })

      assert %Plushie.Event.WidgetEvent{
               type: "wizard:levitate",
               id: "wizard",
               window_id: "main",
               value: %{speed: "fast"}
             } =
               Protocol.decode_message(json, :json)
    end

    test "malformed widget id returns a structured decode error" do
      json = Jason.encode!(%{type: "event", family: "click", id: 123})

      assert {:error, {:invalid_event_field, "click", "id", 123, :expected_binary, _}} =
               Protocol.decode_message(json, :json)
    end

    test "non-binary window_id falls through from separate field" do
      json = Jason.encode!(%{type: "event", family: "click", id: "save", window_id: 123})

      assert %Plushie.Event.WidgetEvent{type: :click, id: "save", window_id: 123} =
               Protocol.decode_message(json, :json)
    end

    test "decode_message! raises protocol error for invalid known enum" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "wheel_scrolled",
          value: %{delta_x: 1, delta_y: 2, unit: "row"}
        })

      assert_raise Plushie.Protocol.Error, ~r/invalid wheel_scrolled event field unit/, fn ->
        Protocol.decode_message!(json, :json)
      end
    end

    test "the unknown_message tuple carries the decoded map" do
      json = Jason.encode!(%{type: "mystery"})
      {:error, {:unknown_message, msg}} = Protocol.decode_message(json, :json)
      assert is_map(msg)
      assert msg["type"] == "mystery"
    end
  end

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

  describe "encode_widget_op/2" do
    test "produces a JSON object with type 'widget_op'" do
      result = Protocol.encode_widget_op("focus", %{target: "username"}, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "widget_op"
    end

    test "includes the op and payload fields" do
      result = Protocol.encode_widget_op("scroll_to", %{target: "feed", offset_y: 42}, :json)
      parsed = decode_json!(result)
      assert parsed["op"] == "scroll_to"
      assert parsed["payload"]["target"] == "feed"
      assert parsed["payload"]["offset_y"] == 42
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_widget_op("focus_next", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

  describe "encode_window_op/3" do
    test "produces a JSON object with type 'window_op'" do
      result = Protocol.encode_window_op("open", "main", %{title: "App"}, :json)
      parsed = decode_json!(result)
      assert parsed["type"] == "window_op"
    end

    test "includes op, window_id, and payload fields" do
      result = Protocol.encode_window_op("close", "settings", %{}, :json)
      parsed = decode_json!(result)
      assert parsed["op"] == "close"
      assert parsed["window_id"] == "settings"
      assert parsed["payload"] == %{}
    end

    test "payload map is preserved" do
      payload = %{title: "Preferences", width: 800, height: 600}
      result = Protocol.encode_window_op("open", "prefs", payload, :json)
      parsed = decode_json!(result)
      assert parsed["payload"]["title"] == "Preferences"
      assert parsed["payload"]["width"] == 800
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_window_op("open", "main", %{}, :json)
      assert String.ends_with?(result, "\n")
    end
  end

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
      assert Base.decode64!(decoded["payload"]["icon_data"]) == rgba
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
      assert decoded["payload"]["icon_data"] == rgba
    end
  end

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

  describe "encode_subscribe with max_rate" do
    test "includes max_rate field in JSON when set" do
      result = Protocol.encode_subscribe("on_pointer_move", "mouse", :json, 30)
      parsed = decode_json!(result)
      assert parsed["type"] == "subscribe"
      assert parsed["kind"] == "on_pointer_move"
      assert parsed["tag"] == "mouse"
      assert parsed["max_rate"] == 30
    end

    test "omits max_rate field in JSON when nil" do
      result = Protocol.encode_subscribe("on_key_press", "keys", :json, nil)
      parsed = decode_json!(result)
      assert parsed["type"] == "subscribe"
      refute Map.has_key?(parsed, "max_rate")
    end

    test "omits max_rate when using default (no 4th arg)" do
      result = Protocol.encode_subscribe("on_key_press", "keys", :json)
      parsed = decode_json!(result)
      refute Map.has_key?(parsed, "max_rate")
    end

    test "includes max_rate of 0 in JSON (subscribe but never emit)" do
      result = Protocol.encode_subscribe("on_pointer_move", "mouse", :json, 0)
      parsed = decode_json!(result)
      assert parsed["max_rate"] == 0
    end

    test "max_rate roundtrips through msgpack" do
      encoded = Protocol.encode_subscribe("on_pointer_move", "mouse", :msgpack, 30)
      {:ok, decoded} = Msgpax.unpack(encoded)
      assert decoded["type"] == "subscribe"
      assert decoded["kind"] == "on_pointer_move"
      assert decoded["tag"] == "mouse"
      assert decoded["max_rate"] == 30
    end

    test "msgpack omits max_rate when nil" do
      encoded = Protocol.encode_subscribe("on_key_press", "keys", :msgpack, nil)
      {:ok, decoded} = Msgpax.unpack(encoded)
      refute Map.has_key?(decoded, "max_rate")
    end
  end

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

  describe "encode -> decode roundtrip for events" do
    test "click event survives JSON roundtrip" do
      # Simulate what the renderer would send back
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_1", window_id: "main"})

      assert %WidgetEvent{type: :click, id: "btn_1", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end

    test "input event survives JSON roundtrip" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "input",
          id: "field",
          value: "hello",
          window_id: "main"
        })

      assert %WidgetEvent{type: :input, id: "field", value: "hello", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end

    test "effect_response ok survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r1", status: "ok", result: %{data: 42}})

      assert {:effect_response, "r1", "ok", %{data: 42}} =
               Protocol.decode_message(json, :json)
    end

    test "effect_response error survives JSON roundtrip" do
      json =
        Jason.encode!(%{type: "effect_response", id: "r2", status: "error", error: "timeout"})

      assert {:effect_response, "r2", "error", "timeout"} =
               Protocol.decode_message(json, :json)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1: pointer press events (mouse area)
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- pointer press (middle button)" do
    test "decodes pointer press with middle button from json" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "zone",
          window_id: "main",
          value: %{
            x: 10.0,
            y: 20.0,
            button: "middle",
            pointer: "mouse",
            modifiers: %{}
          }
        })

      assert %WidgetEvent{
               type: :press,
               id: "zone",
               window_id: "main",
               value: %{button: :middle, pointer: :mouse}
             } = Protocol.decode_message(json, :json)
    end

    test "decodes pointer press with middle button from msgpack" do
      event = %{
        "type" => "event",
        "family" => "press",
        "id" => "zone",
        "window_id" => "main",
        "value" => %{
          "x" => 10.0,
          "y" => 20.0,
          "button" => "middle",
          "pointer" => "mouse",
          "modifiers" => %{}
        }
      }

      packed = Msgpax.pack!(event, iodata: false)

      assert %WidgetEvent{type: :press, id: "zone", window_id: "main", value: %{button: :middle}} =
               Protocol.decode_message(packed, :msgpack)
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1: key_release events (if supported)
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

    test "effect stub ack with malformed kind returns a protocol error" do
      json = Jason.encode!(%{type: "effect_stub_register_ack", kind: 42})

      assert {:error,
              {:invalid_event_field, "effect_stub_register_ack", :kind, 42, :expected_binary, _}} =
               Protocol.decode_message(json, :json)
    end

    test "widget events without window_id produce nil window" do
      json = Jason.encode!(%{type: "event", family: "click", id: "save"})

      assert %Plushie.Event.WidgetEvent{type: :click, id: "save", window_id: nil} =
               Protocol.decode_message(json, :json)
    end

    test "diagnostic with unknown level returns a protocol error" do
      json =
        Jason.encode!(%{
          type: "diagnostic",
          level: "trace",
          diagnostic: %{kind: "prop_unknown", node_id: "n", widget_type: "text", prop: "foo"}
        })

      assert {:error, {:invalid_event_field, "diagnostic", :level, "trace", :invalid, _}} =
               Protocol.decode_message(json, :json)
    end

    test "Protocol.Error reports missing required options as ArgumentError" do
      assert_raise ArgumentError, ~r/missing required :format option/, fn ->
        Plushie.Protocol.Error.exception(reason: :bad, data: <<>>)
      end
    end
  end

  describe "encode_settings default_font normalisation" do
    # The renderer parses default_font strictly as an object with a
    # `family` key; it silently drops a bare string and falls back to
    # the platform default font. The encoder normalises every accepted
    # input shape (atom shorthand, family-name string, struct, plain
    # map) into the canonical object form so the renderer always sees
    # the same wire shape.

    test "wraps the :default atom into a family object" do
      encoded = Protocol.encode_settings(%{default_font: :default}, :json)
      decoded = Jason.decode!(encoded)
      assert decoded["settings"]["default_font"] == %{"family" => "default"}
    end

    test "wraps the :monospace atom into a family object" do
      encoded = Protocol.encode_settings(%{default_font: :monospace}, :json)
      decoded = Jason.decode!(encoded)
      assert decoded["settings"]["default_font"] == %{"family" => "monospace"}
    end

    test "wraps a bare family-name string into a family object" do
      encoded = Protocol.encode_settings(%{default_font: "Fira Code"}, :json)
      decoded = Jason.decode!(encoded)
      assert decoded["settings"]["default_font"] == %{"family" => "Fira Code"}
    end

    test "passes a map default_font through unchanged" do
      font = %{family: "Inter", weight: :bold}
      encoded = Protocol.encode_settings(%{default_font: font}, :json)
      decoded = Jason.decode!(encoded)
      assert decoded["settings"]["default_font"] == %{"family" => "Inter", "weight" => "bold"}
    end

    test "encodes a Plushie.Type.Font struct as a family object" do
      font = %Plushie.Type.Font{family: "Cascadia", style: :italic}
      encoded = Protocol.encode_settings(%{default_font: font}, :json)
      decoded = Jason.decode!(encoded)

      assert decoded["settings"]["default_font"] == %{
               "family" => "Cascadia",
               "style" => "italic"
             }
    end

    test "supports string-keyed settings maps" do
      encoded = Protocol.encode_settings(%{"default_font" => :monospace}, :json)
      decoded = Jason.decode!(encoded)
      assert decoded["settings"]["default_font"] == %{"family" => "monospace"}
    end

    test "default_font shape is the same in msgpack and json" do
      settings = %{default_font: :monospace}

      json = Jason.decode!(Protocol.encode_settings(settings, :json))
      msgpack_iodata = Protocol.encode_settings(settings, :msgpack)
      {:ok, msgpack} = Msgpax.unpack(IO.iodata_to_binary(msgpack_iodata))

      assert json["settings"]["default_font"] == msgpack["settings"]["default_font"]
      assert json["settings"]["default_font"] == %{"family" => "monospace"}
    end

    test "leaves settings without default_font alone" do
      encoded = Protocol.encode_settings(%{antialiasing: true}, :json)
      decoded = Jason.decode!(encoded)
      refute Map.has_key?(decoded["settings"], "default_font")
    end
  end

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
      event = %{"type" => "event", "family" => "click", "id" => "btn1", "window_id" => "main"}
      packed = Msgpax.pack!(event, iodata: false)

      assert %WidgetEvent{type: :click, id: "btn1", window_id: "main"} =
               Protocol.decode_message(packed, :msgpack)
    end

    test "input event decode from msgpack" do
      event = %{
        "type" => "event",
        "family" => "input",
        "id" => "field",
        "value" => "hello",
        "window_id" => "main"
      }

      packed = Msgpax.pack!(event, iodata: false)

      assert %WidgetEvent{type: :input, id: "field", value: "hello", window_id: "main"} =
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

      assert {:effect_response, "r1", "ok", %{data: 42}} =
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

      assert {:effect_response, "r2", "error", "timeout"} =
               Protocol.decode_message(packed, :msgpack)
    end

    test "invalid msgpack returns detailed decode error" do
      assert {:error, {:decode_failed, _}} = Protocol.decode_message(<<0xFF, 0xFF>>, :msgpack)
    end
  end

  describe "encode_command/4" do
    test "produces valid JSON message" do
      result = Protocol.encode_command("term-1", "write", %{"data" => "hello"}, :json)
      decoded = decode_json!(result)
      assert decoded["type"] == "command"
      assert decoded["id"] == "term-1"
      assert decoded["family"] == "write"
      assert decoded["value"]["data"] == "hello"
    end

    test "produces valid msgpack message" do
      result = Protocol.encode_command("wgt-1", "reset", nil, :msgpack)
      {:ok, decoded} = Msgpax.unpack(result)
      assert decoded["type"] == "command"
      assert decoded["id"] == "wgt-1"
      assert decoded["family"] == "reset"
    end

    test "round-trips through decode_message" do
      encoded =
        Protocol.encode_command("term-1", "write", %{"data" => "hello"}, :msgpack)

      assert {:command, "term-1", "write", %{"data" => "hello"}} =
               Protocol.decode_message(encoded, :msgpack)
    end
  end

  describe "decode_message/1 -- hello" do
    @hello_fields %{
      type: "hello",
      protocol: 1,
      version: "0.3.2",
      name: "plushie",
      mode: "headless",
      backend: "tiny-skia",
      transport: "stdio",
      native_widgets: ["charts"],
      widgets: ["button", "text", "charts"]
    }

    test "decodes a complete hello message" do
      json = Jason.encode!(@hello_fields)

      assert {:hello,
              %{
                protocol: 1,
                version: "0.3.2",
                name: "plushie",
                mode: "headless",
                backend: "tiny-skia",
                transport: "stdio",
                native_widgets: ["charts"],
                widget_sets: [],
                widgets: ["button", "text", "charts"]
              }} = Protocol.decode_message(json, :json)
    end

    test "hello with missing fields is treated as unknown message" do
      for field <- ~w(protocol version name mode backend transport native_widgets widgets) do
        incomplete = Map.delete(@hello_fields, String.to_existing_atom(field))
        json = Jason.encode!(incomplete)
        assert {:error, {:unknown_message, _}} = Protocol.decode_message(json, :json)
      end
    end

    test "decodes hello from msgpack" do
      msg =
        @hello_fields
        |> Enum.map(fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.new()

      packed = Msgpax.pack!(msg, iodata: false)

      assert {:hello,
              %{
                protocol: 1,
                version: "0.3.2",
                name: "plushie",
                mode: "headless",
                backend: "tiny-skia",
                native_widgets: ["charts"],
                widget_sets: [],
                widgets: ["button", "text", "charts"]
              }} = Protocol.decode_message(packed, :msgpack)
    end
  end

  describe "decode_message/1 -- error events" do
    test "decodes command errors as typed events" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "error",
          id: "command",
          value: %{
            kind: "command",
            reason: "unknown_node",
            id: "g1",
            family: "set_value",
            message: "no widget handles node `g1`"
          }
        })

      assert %Plushie.Event.CommandError{
               reason: "unknown_node",
               id: "g1",
               family: "set_value",
               widget_type: nil,
               message: "no widget handles node `g1`"
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "protocol_version/0" do
    test "returns a positive integer" do
      version = Protocol.protocol_version()
      assert is_integer(version)
      assert version > 0
    end
  end

  describe "encode_commands/2" do
    test "produces valid JSON batch message" do
      commands = [
        {"term-1", "write", %{"data" => "a"}},
        {"log-1", "append", %{"line" => "x"}}
      ]

      result = Protocol.encode_commands(commands, :json)
      decoded = decode_json!(result)
      assert decoded["type"] == "commands"
      assert length(decoded["commands"]) == 2
      assert Enum.at(decoded["commands"], 0)["id"] == "term-1"
      assert Enum.at(decoded["commands"], 1)["family"] == "append"
    end

    test "produces valid msgpack batch message" do
      commands = [{"n1", "op1", %{"k" => "v"}}]
      result = Protocol.encode_commands(commands, :msgpack)
      {:ok, decoded} = Msgpax.unpack(result)
      assert decoded["type"] == "commands"
      assert length(decoded["commands"]) == 1
    end

    test "round-trips through decode_message" do
      commands = [{"n1", "op1", %{"k" => "v"}}]
      encoded = Protocol.encode_commands(commands, :msgpack)

      assert {:commands, [{"n1", "op1", %{"k" => "v"}}]} =
               Protocol.decode_message(encoded, :msgpack)
    end
  end

  describe "decode_message/1 -- outbound protocol messages" do
    test "decodes image_op messages" do
      encoded = Protocol.encode_image_op("delete_image", %{handle: "logo"}, :msgpack)

      assert {:image_op, "delete_image", %{"handle" => "logo"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "decodes interact messages" do
      encoded =
        Protocol.encode_interact(
          "req-1",
          "click",
          %{"by" => "id", "value" => "save"},
          %{"button" => "left"},
          :msgpack
        )

      assert {:interact, "req-1", "click", %{"by" => "id", "value" => "save"},
              %{"button" => "left"}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "decodes advance_frame messages" do
      encoded = Protocol.encode_advance_frame(123, :msgpack)
      assert {:advance_frame, 123} = Protocol.decode_message(encoded, :msgpack)
    end

    test "decodes effect stub registration messages" do
      encoded = Protocol.encode_register_effect_stub("clipboard", %{"ok" => true}, :msgpack)

      assert {:register_effect_stub, "clipboard", %{"ok" => true}} =
               Protocol.decode_message(encoded, :msgpack)
    end

    test "decodes effect stub removal messages" do
      encoded = Protocol.encode_unregister_effect_stub("clipboard", :msgpack)
      assert {:unregister_effect_stub, "clipboard"} = Protocol.decode_message(encoded, :msgpack)
    end
  end

  describe "decode_message/1 -- touch events (wire id field)" do
    test "decodes finger_pressed with value.id" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_pressed",
          value: %{id: 0, x: 50.0, y: 75.0}
        })

      assert %WidgetEvent{type: :press, value: %{pointer: :touch, finger: 0, x: 50.0, y: 75.0}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes finger_moved with value.id" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "finger_moved",
          value: %{id: 1, x: 60.0, y: 80.0}
        })

      assert %WidgetEvent{type: :move, value: %{pointer: :touch, finger: 1, x: 60.0, y: 80.0}} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- scroll (pointer)" do
    test "reads x/y and deltas into struct fields" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "scroll",
          id: "viewport",
          window_id: "main",
          value: %{
            x: 5.0,
            y: 10.0,
            delta_x: 0.0,
            delta_y: -1.0,
            pointer: "mouse",
            modifiers: %{}
          }
        })

      assert %WidgetEvent{
               type: :scroll,
               id: "viewport",
               window_id: "main",
               value: %{x: 5.0, y: 10.0, delta_x: +0.0, delta_y: -1.0, pointer: :mouse}
             } =
               Protocol.decode_message(json, :json)
    end

    test "preserves window_id on pointer press events" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "press",
          id: "viewport",
          window_id: "main",
          value: %{
            x: 5.0,
            y: 10.0,
            button: "left",
            pointer: "mouse",
            modifiers: %{}
          }
        })

      assert %WidgetEvent{type: :press, id: "viewport", window_id: "main"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- generic element events" do
    test "decodes focused" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "focused",
          id: "my_canvas",
          window_id: "main"
        })

      assert %WidgetEvent{
               type: :focused,
               id: "my_canvas",
               window_id: "main"
             } = Protocol.decode_message(json, :json)
    end

    test "decodes blurred" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "blurred",
          id: "my_canvas",
          window_id: "main"
        })

      assert %WidgetEvent{
               type: :blurred,
               id: "my_canvas",
               window_id: "main"
             } = Protocol.decode_message(json, :json)
    end

    test "decodes drag" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "drag",
          id: "my_canvas",
          window_id: "main",
          value: %{x: 50.0, y: 60.0, delta_x: 5.0, delta_y: -3.0}
        })

      assert %WidgetEvent{
               type: :drag,
               id: "my_canvas",
               window_id: "main",
               value: data
             } =
               Protocol.decode_message(json, :json)

      assert data.x == 50.0
      assert data.delta_x == 5.0
    end

    test "decodes drag_end" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "drag_end",
          id: "my_canvas",
          window_id: "main",
          value: %{x: 55.0, y: 57.0}
        })

      assert %WidgetEvent{
               type: :drag_end,
               id: "my_canvas",
               window_id: "main",
               value: data
             } =
               Protocol.decode_message(json, :json)

      assert data.x == 55.0
      assert data.y == 57.0
    end

    test "decodes key_press" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_press",
          id: "my_input",
          window_id: "main",
          value: %{
            key: "a",
            modifiers: %{ctrl: false, shift: false, alt: false, logo: false},
            text: "a"
          }
        })

      assert %WidgetEvent{
               type: :key_press,
               id: "my_input",
               window_id: "main",
               value: data
             } =
               Protocol.decode_message(json, :json)

      assert data.text == "a"
    end

    test "decodes key_release" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "key_release",
          id: "my_input",
          window_id: "main",
          value: %{key: "a", modifiers: %{ctrl: false, shift: false, alt: false, logo: false}}
        })

      assert %WidgetEvent{
               type: :key_release,
               id: "my_input",
               window_id: "main",
               value: data
             } =
               Protocol.decode_message(json, :json)

      assert data.key != nil
    end

    test "generic element event with scoped id splits correctly" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "focused",
          id: "panel/my_canvas",
          window_id: "main"
        })

      assert %WidgetEvent{
               type: :focused,
               id: "my_canvas",
               scope: ["panel", "main"],
               window_id: "main"
             } = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- session events" do
    test "decodes session_error with code" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "session_error",
          session: "s1",
          id: "",
          value: %{code: "session_panic", error: "session panicked"}
        })

      assert {:session_error, "s1", "session_panic", "session panicked"} =
               Protocol.decode_message(json, :json)
    end

    test "decodes session_error when code is absent" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "session_error",
          session: "s1",
          id: "",
          value: %{error: "session panicked"}
        })

      assert {:session_error, "s1", nil, "session panicked"} =
               Protocol.decode_message(json, :json)
    end

    test "decodes session_closed" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "session_closed",
          session: "s2",
          id: "",
          value: %{}
        })

      assert {:session_closed, "s2", nil} = Protocol.decode_message(json, :json)
    end
  end

  describe "decode_message/1 -- announce event" do
    test "decodes announce as System event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "announce",
          id: "",
          value: %{text: "Item saved"}
        })

      assert %SystemEvent{type: :announce, value: "Item saved"} =
               Protocol.decode_message(json, :json)
    end
  end

  describe "cross-format round-trip (JSON to msgpack)" do
    test "click event round-trips through both codecs" do
      msg = %{
        "type" => "event",
        "family" => "click",
        "id" => "save_btn",
        "window_id" => "main"
      }

      json_encoded = Protocol.encode(msg, :json)
      from_json = Protocol.decode_message(json_encoded, :json)

      msgpack_encoded = Protocol.encode(msg, :msgpack)
      from_msgpack = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert %WidgetEvent{type: :click, id: "save_btn", window_id: "main"} = from_json
      assert from_json == from_msgpack
    end

    test "key_press event round-trips through both codecs" do
      msg = %{
        "type" => "event",
        "family" => "key_press",
        "modifiers" => %{
          "ctrl" => true,
          "shift" => false,
          "alt" => false,
          "logo" => false,
          "command" => false
        },
        "value" => %{"key" => "Enter"}
      }

      json_encoded = Protocol.encode(msg, :json)
      from_json = Protocol.decode_message(json_encoded, :json)

      msgpack_encoded = Protocol.encode(msg, :msgpack)
      from_msgpack = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert %KeyEvent{type: :press, key: :enter, modifiers: %{ctrl: true}} = from_json
      assert from_json == from_msgpack
    end

    test "window_resized event round-trips through both codecs" do
      msg = %{
        "type" => "event",
        "family" => "window_resized",
        "value" => %{"window_id" => "main", "width" => 1024, "height" => 768}
      }

      json_encoded = Protocol.encode(msg, :json)
      from_json = Protocol.decode_message(json_encoded, :json)

      msgpack_encoded = Protocol.encode(msg, :msgpack)
      from_msgpack = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert %Plushie.Event.WindowEvent{type: :resized, width: 1024, height: 768} = from_json
      assert from_json == from_msgpack
    end

    test "snapshot message round-trips through both codecs" do
      tree = %{
        "id" => "root",
        "type" => "text",
        "props" => %{"content" => "hi"},
        "children" => []
      }

      json_encoded = Protocol.encode_snapshot(tree, :json)
      from_json = Protocol.decode_message(json_encoded, :json)

      msgpack_encoded = Protocol.encode_snapshot(tree, :msgpack)
      from_msgpack = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert {:snapshot, json_tree} = from_json
      assert {:snapshot, msgpack_tree} = from_msgpack
      assert json_tree == msgpack_tree
    end

    test "settings message round-trips through both codecs" do
      settings = %{antialiasing: true, default_text_size: 14}

      json_encoded = Protocol.encode_settings(settings, :json)
      from_json = Protocol.decode_message(json_encoded, :json)

      msgpack_encoded = Protocol.encode_settings(settings, :msgpack)
      from_msgpack = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert {:settings, json_settings} = from_json
      assert {:settings, msgpack_settings} = from_msgpack
      assert json_settings == msgpack_settings
    end
  end

  describe "decode_message/1 -- duplicate_node_ids error" do
    test "decodes duplicate_node_ids error as System event" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "error",
          id: "duplicate_node_ids",
          value: %{error: "duplicate IDs found", duplicates: ["btn1 (button)", "btn1 (text)"]}
        })

      assert %SystemEvent{type: :error, value: %{error: "duplicate_node_ids", details: details}} =
               Protocol.decode_message(json, :json)

      assert details["duplicates"] == ["btn1 (button)", "btn1 (text)"]
    end
  end

  describe "cross-format round-trip" do
    test "click event encodes in JSON, decodes, re-encodes in msgpack, decodes equivalently" do
      original = %{
        "type" => "event",
        "family" => "click",
        "id" => "btn_save",
        "window_id" => "main"
      }

      json_wire = Jason.encode!(original) <> "\n"
      json_decoded = Protocol.decode_message(json_wire, :json)

      msgpack_wire = Msgpax.pack!(original) |> IO.iodata_to_binary()
      msgpack_decoded = Protocol.decode_message(msgpack_wire, :msgpack)

      assert json_decoded == msgpack_decoded
      assert %WidgetEvent{type: :click, id: "btn_save", window_id: "main"} = json_decoded
    end

    test "key_press event round-trips identically across formats" do
      original = %{
        "type" => "event",
        "family" => "key_press",
        "modifiers" => %{
          "ctrl" => true,
          "shift" => false,
          "alt" => false,
          "logo" => false,
          "command" => false
        },
        "value" => %{"key" => "Tab"}
      }

      json_wire = Jason.encode!(original) <> "\n"
      json_decoded = Protocol.decode_message(json_wire, :json)

      msgpack_wire = Msgpax.pack!(original) |> IO.iodata_to_binary()
      msgpack_decoded = Protocol.decode_message(msgpack_wire, :msgpack)

      assert json_decoded == msgpack_decoded
      assert %KeyEvent{type: :press, key: :tab, modifiers: %{ctrl: true}} = json_decoded
    end

    test "window_resized event round-trips identically across formats" do
      original = %{
        "type" => "event",
        "family" => "window_resized",
        "value" => %{"window_id" => "main", "width" => 1920, "height" => 1080}
      }

      json_wire = Jason.encode!(original) <> "\n"
      json_decoded = Protocol.decode_message(json_wire, :json)

      msgpack_wire = Msgpax.pack!(original) |> IO.iodata_to_binary()
      msgpack_decoded = Protocol.decode_message(msgpack_wire, :msgpack)

      assert json_decoded == msgpack_decoded

      assert %Plushie.Event.WindowEvent{
               type: :resized,
               window_id: "main",
               width: 1920,
               height: 1080
             } = json_decoded
    end

    test "snapshot message round-trips through encode/decode in both formats" do
      tree = %{
        id: "main",
        type: "window",
        props: %{title: "Test"},
        children: [
          %{id: "label", type: "text", props: %{content: "Hello"}, children: []}
        ]
      }

      json_encoded = Protocol.encode_snapshot(tree, :json)
      json_decoded = Protocol.decode_message(IO.iodata_to_binary(json_encoded), :json)

      msgpack_encoded = Protocol.encode_snapshot(tree, :msgpack)
      msgpack_decoded = Protocol.decode_message(IO.iodata_to_binary(msgpack_encoded), :msgpack)

      assert json_decoded == msgpack_decoded
      assert {:snapshot, snapshot_tree} = json_decoded
      assert snapshot_tree["id"] == "main"
      assert snapshot_tree["type"] == "window"
    end

    test "effect event with nested data round-trips across formats" do
      original = %{
        "type" => "event",
        "family" => "effect_response",
        "id" => "req_1",
        "value" => %{"status" => "ok", "payload" => %{"text" => "clipboard contents"}}
      }

      json_wire = Jason.encode!(original) <> "\n"
      json_decoded = Protocol.decode_message(json_wire, :json)

      msgpack_wire = Msgpax.pack!(original) |> IO.iodata_to_binary()
      msgpack_decoded = Protocol.decode_message(msgpack_wire, :msgpack)

      assert json_decoded == msgpack_decoded
    end
  end

  describe "diagnostic messages" do
    test "decodes typed diagnostics with explicit levels" do
      json =
        Jason.encode!(%{
          type: "diagnostic",
          session: "pool_1",
          level: "info",
          diagnostic: %{kind: "font_family_not_found", family: "Missing"}
        })

      assert %DiagnosticMessage{
               session: "pool_1",
               level: :info,
               diagnostic: %Diagnostic.FontFamilyNotFound{family: "Missing"}
             } = Protocol.decode_message(json, :json)
    end

    test "defaults missing diagnostic level to warn" do
      json =
        Jason.encode!(%{
          type: "diagnostic",
          diagnostic: %{kind: "wire_input_error", detail: "bad frame"}
        })

      assert %DiagnosticMessage{
               level: :warn,
               diagnostic: %Diagnostic.WireInputError{detail: "bad frame"}
             } = Protocol.decode_message(json, :json)
    end

    test "returns a protocol error for unknown diagnostic level" do
      json =
        Jason.encode!(%{
          type: "diagnostic",
          level: "trace",
          diagnostic: %{kind: "font_family_not_found", family: "Missing"}
        })

      assert {:error, {:invalid_event_field, "diagnostic", :level, "trace", :invalid, _}} =
               Protocol.decode_message(json, :json)
    end

    test "returns a protocol error for unknown diagnostic kind" do
      json =
        Jason.encode!(%{
          type: "diagnostic",
          diagnostic: %{kind: "future_diagnostic"}
        })

      assert {:error,
              {:invalid_event_field, "diagnostic", :diagnostic, %{"kind" => "future_diagnostic"},
               message, _}} = Protocol.decode_message(json, :json)

      assert message =~ "unknown diagnostic kind"
    end

    test "decodes renderer diagnostic variants" do
      assert %Diagnostic.DashSegmentsCapExceeded{max: 8} =
               Diagnostic.decode!(%{"kind" => "dash_segments_cap_exceeded", "max" => 8})

      assert %Diagnostic.UnknownPatchOp{op: "replace_all", payload: %{"op" => "replace_all"}} =
               Diagnostic.decode!(%{
                 "kind" => "unknown_patch_op",
                 "op" => "replace_all",
                 "payload" => %{"op" => "replace_all"}
               })

      assert %Diagnostic.AnimationDescriptorInvalid{id: "btn", prop: "opacity"} =
               Diagnostic.decode!(%{
                 "kind" => "animation_descriptor_invalid",
                 "id" => "btn",
                 "prop" => "opacity"
               })

      assert %Diagnostic.RendererRuntimeError{detail: "event loop failed"} =
               Diagnostic.decode!(%{
                 "kind" => "renderer_runtime_error",
                 "detail" => "event loop failed"
               })
    end
  end

  describe "protocol response messages" do
    test "decodes query_response messages" do
      json =
        Jason.encode!(%{
          type: "query_response",
          id: "q1",
          target: "tree",
          data: %{id: "main"}
        })

      assert {:query_response, "q1", "tree", %{"id" => "main"}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes reset_response messages" do
      json = Jason.encode!(%{type: "reset_response", id: "r1", status: "ok"})

      assert {:reset_response, "r1", "ok"} = Protocol.decode_message(json, :json)
    end
  end

  describe "protocol validation" do
    test "rejects widget events with empty local IDs" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "click",
          id: "main#",
          window_id: "main"
        })

      assert {:error, {:invalid_event_field, "click", "id", "main#", :empty, _}} =
               Protocol.decode_message(json, :json)
    end

    test "rejects malformed modifier payloads" do
      json =
        Jason.encode!(%{
          type: "event",
          family: "modifiers_changed",
          modifiers: "ctrl"
        })

      assert {:error, {:invalid_event_field, "modifiers", :modifiers, "ctrl", :invalid, _}} =
               Protocol.decode_message(json, :json)
    end

    test "reports decoded-map protocol errors without pretending to know the wire format" do
      error =
        assert_raise Plushie.Protocol.Error, fn ->
          Protocol.decode_event(%{"family" => "click", "id" => "main#"})
        end

      assert error.format == :decoded
    end

    test "rejects non-map snapshots" do
      assert_raise FunctionClauseError, fn ->
        Protocol.encode_snapshot("not a tree", :json)
      end
    end
  end

  describe "binary field normalization" do
    test "decodes JSON image_op binary fields from string-keyed payloads" do
      raw = <<1, 2, 3>>

      encoded =
        Protocol.encode_image_op("create_image", %{"handle" => "logo", "data" => raw}, :json)

      assert {:image_op, "create_image", %{"handle" => "logo", "data" => ^raw}} =
               Protocol.decode_message(encoded, :json)
    end

    test "decodes JSON load_font binary payloads" do
      raw = <<7, 8, 9>>
      encoded = Protocol.encode_load_font("Inter", raw, :json)

      assert {:load_font, "Inter", ^raw} = Protocol.decode_message(encoded, :json)
    end

    test "reports invalid base64 in JSON binary fields" do
      json =
        Jason.encode!(%{
          type: "image_op",
          op: "create_image",
          payload: %{handle: "logo", data: "not base64"}
        })

      assert {:error, {:decode_failed, {:invalid_base64, "image_op.payload.data"}}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes effect_response screenshot rgba payloads" do
      raw = <<4, 5, 6>>

      json =
        Jason.encode!(%{
          type: "effect_response",
          id: "main",
          status: "ok",
          result: %{op: "screenshot", rgba: Base.encode64(raw)}
        })

      assert {:effect_response, "main", "ok", %{op: "screenshot", rgba: ^raw}} =
               Protocol.decode_message(json, :json)
    end

    test "decodes truncated MessagePack as a decode failure" do
      truncated_bin8 = <<0xC4, 0x04, 0x01>>

      assert {:error, {:decode_failed, _}} = Protocol.decode_message(truncated_bin8, :msgpack)
    end
  end

  describe "screenshot encoding" do
    test "encodes screenshot requests with optional dimensions" do
      encoded = Protocol.encode_screenshot("sc_1", "main", [width: 320, height: 200], :json)

      assert {:screenshot, "sc_1", "main", [height: 200, width: 320]} =
               Protocol.decode_message(encoded, :json)
    end
  end

  describe "ProtocolVersionMismatchError" do
    test "formats expected and actual versions" do
      error = Protocol.ProtocolVersionMismatchError.exception(expected: 1, got: 2)

      assert error.expected == 1
      assert error.got == 2
      assert error.message == "protocol version mismatch: expected 1, got 2"
    end
  end
end
