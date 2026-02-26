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
      result = Protocol.encode_snapshot(tree)
      parsed = decode_json!(result)
      assert parsed["type"] == "snapshot"
      assert is_map(parsed["tree"])
    end

    test "the 'tree' value matches the input" do
      tree = %{tag: "column", children: []}
      result = Protocol.encode_snapshot(tree)
      parsed = decode_json!(result)
      assert parsed["tree"]["tag"] == "column"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_snapshot(%{})
      assert String.ends_with?(result, "\n")
    end

    test "output is valid JSON before the trailing newline" do
      result = Protocol.encode_snapshot(%{tag: "button"})
      assert {:ok, _} = Jason.decode(String.trim_trailing(result, "\n"))
    end
  end

  # ---------------------------------------------------------------------------
  # encode_patch/1
  # ---------------------------------------------------------------------------

  describe "encode_patch/1" do
    test "produces a JSON object with type 'patch' and an 'ops' key" do
      result = Protocol.encode_patch([])
      parsed = decode_json!(result)
      assert parsed["type"] == "patch"
      assert parsed["ops"] == []
    end

    test "encodes the ops list as-is" do
      ops = [%{"op" => "replace", "path" => "/label", "value" => "Save"}]
      result = Protocol.encode_patch(ops)
      parsed = decode_json!(result)
      assert length(parsed["ops"]) == 1
      assert hd(parsed["ops"])["op"] == "replace"
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_patch([])
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # encode_effect_request/3
  # ---------------------------------------------------------------------------

  describe "encode_effect_request/3" do
    test "produces a JSON object with type 'effect_request'" do
      result = Protocol.encode_effect_request("req_1", "http", %{url: "https://example.com"})
      parsed = decode_json!(result)
      assert parsed["type"] == "effect_request"
    end

    test "includes the id, kind, and payload fields" do
      result = Protocol.encode_effect_request("req_42", "shell", %{cmd: "ls"})
      parsed = decode_json!(result)
      assert parsed["id"] == "req_42"
      assert parsed["kind"] == "shell"
      assert is_map(parsed["payload"])
    end

    test "output ends with a trailing newline" do
      result = Protocol.encode_effect_request("r", "k", %{})
      assert String.ends_with?(result, "\n")
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- event families
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- click events" do
    test "decodes a click event to {:click, id}" do
      json = Jason.encode!(%{type: "event", family: "click", id: "btn_save"})
      assert Protocol.decode_message(json) == {:click, "btn_save"}
    end

    test "widget id is preserved exactly" do
      json = Jason.encode!(%{type: "event", family: "click", id: "panel/submit"})
      assert {:click, "panel/submit"} = Protocol.decode_message(json)
    end
  end

  describe "decode_message/1 -- input events" do
    test "decodes an input event to {:input, id, value}" do
      json = Jason.encode!(%{type: "event", family: "input", id: "search", value: "elixir"})
      assert Protocol.decode_message(json) == {:input, "search", "elixir"}
    end

    test "preserves an empty string value" do
      json = Jason.encode!(%{type: "event", family: "input", id: "field", value: ""})
      assert {:input, "field", ""} = Protocol.decode_message(json)
    end
  end

  describe "decode_message/1 -- submit events" do
    test "decodes a submit event to {:submit, id, value}" do
      json = Jason.encode!(%{type: "event", family: "submit", id: "login_form", value: "admin"})
      assert Protocol.decode_message(json) == {:submit, "login_form", "admin"}
    end
  end

  describe "decode_message/1 -- toggle events" do
    test "decodes a toggle event to {:toggle, id, value}" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: true})
      assert Protocol.decode_message(json) == {:toggle, "dark_mode", true}
    end

    test "decodes a toggle-off correctly" do
      json = Jason.encode!(%{type: "event", family: "toggle", id: "dark_mode", value: false})
      assert {:toggle, "dark_mode", false} = Protocol.decode_message(json)
    end
  end

  describe "decode_message/1 -- select events" do
    test "decodes a select event to {:select, id, value}" do
      json = Jason.encode!(%{type: "event", family: "select", id: "lang_picker", value: "fr"})
      assert Protocol.decode_message(json) == {:select, "lang_picker", "fr"}
    end
  end

  describe "decode_message/1 -- slide events" do
    test "decodes a slide event to {:slide, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "volume", value: 0.75})
      assert Protocol.decode_message(json) == {:slide, "volume", 0.75}
    end

    test "value can be an integer" do
      json = Jason.encode!(%{type: "event", family: "slide", id: "zoom", value: 100})
      assert {:slide, "zoom", 100} = Protocol.decode_message(json)
    end
  end

  describe "decode_message/1 -- slide_release events" do
    test "decodes a slide_release event to {:slide_release, id, value}" do
      json = Jason.encode!(%{type: "event", family: "slide_release", id: "scrubber", value: 42.0})
      assert Protocol.decode_message(json) == {:slide_release, "scrubber", 42.0}
    end
  end

  describe "decode_message/1 -- window events" do
    test "decodes a window event to {:window, action_atom, window_id}" do
      json = Jason.encode!(%{
        type: "event",
        family: "window",
        action: "close",
        window_id: "main"
      })
      assert Protocol.decode_message(json) == {:window, :close, "main"}
    end

    test "converts the action string to an atom" do
      json = Jason.encode!(%{
        type: "event",
        family: "window",
        action: "minimize",
        window_id: "settings"
      })
      {:window, action, _} = Protocol.decode_message(json)
      assert is_atom(action)
      assert action == :minimize
    end
  end

  describe "decode_message/1 -- key events" do
    test "decodes a named key to {:key_press, atom, modifiers_map}" do
      json = Jason.encode!(%{
        type: "event",
        family: "key",
        key: "Escape",
        modifiers: %{ctrl: false, shift: false, alt: false}
      })
      assert {:key_press, :escape, _mods} = Protocol.decode_message(json)
    end

    test "decodes a character key to {:key_press, string, modifiers_map}" do
      json = Jason.encode!(%{
        type: "event",
        family: "key",
        key: "a",
        modifiers: %{}
      })
      assert {:key_press, "a", _mods} = Protocol.decode_message(json)
    end

    test "modifiers map has ctrl, shift, alt, logo, and command keys" do
      json = Jason.encode!(%{
        type: "event",
        family: "key",
        key: "s",
        modifiers: %{ctrl: true, shift: false}
      })
      {:key_press, _key, mods} = Protocol.decode_message(json)
      assert Map.has_key?(mods, :ctrl)
      assert Map.has_key?(mods, :shift)
      assert Map.has_key?(mods, :alt)
      assert Map.has_key?(mods, :logo)
      assert Map.has_key?(mods, :command)
    end

    test "modifiers present in the wire message are set correctly" do
      json = Jason.encode!(%{
        type: "event",
        family: "key",
        key: "c",
        modifiers: %{ctrl: true, shift: false, alt: false, logo: false, command: false}
      })
      {:key_press, _key, mods} = Protocol.decode_message(json)
      assert mods.ctrl == true
      assert mods.shift == false
    end

    test "modifiers absent from the wire message default to false" do
      json = Jason.encode!(%{
        type: "event",
        family: "key",
        key: "z",
        modifiers: %{}
      })
      {:key_press, _key, mods} = Protocol.decode_message(json)
      assert mods.ctrl == false
      assert mods.alt == false
    end
  end

  describe "decode_message/1 -- effect_response ok" do
    test "decodes an ok effect response to {:effect_result, id, {:ok, result}}" do
      json = Jason.encode!(%{
        type: "effect_response",
        id: "req_1",
        status: "ok",
        result: %{body: "hello"}
      })
      assert {:effect_result, "req_1", {:ok, result}} = Protocol.decode_message(json)
      assert result["body"] == "hello"
    end

    test "result can be any JSON-decodable value" do
      json = Jason.encode!(%{type: "effect_response", id: "r", status: "ok", result: 99})
      assert {:effect_result, "r", {:ok, 99}} = Protocol.decode_message(json)
    end
  end

  describe "decode_message/1 -- effect_response error" do
    test "decodes an error effect response to {:effect_result, id, {:error, reason}}" do
      json = Jason.encode!(%{
        type: "effect_response",
        id: "req_2",
        status: "error",
        error: "connection refused"
      })
      assert Protocol.decode_message(json) == {:effect_result, "req_2", {:error, "connection refused"}}
    end
  end

  # ---------------------------------------------------------------------------
  # decode_message/1 -- error cases
  # ---------------------------------------------------------------------------

  describe "decode_message/1 -- error cases" do
    test "returns {:error, :invalid_json} for non-JSON input" do
      assert Protocol.decode_message("not json") == {:error, :invalid_json}
    end

    test "returns {:error, :invalid_json} for empty string" do
      assert Protocol.decode_message("") == {:error, :invalid_json}
    end

    test "returns {:error, {:unknown_message, _}} for a JSON object with an unrecognised type" do
      json = Jason.encode!(%{type: "poke", target: "the_bear"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json)
    end

    test "returns {:error, {:unknown_message, _}} for a known type with an unknown family" do
      json = Jason.encode!(%{type: "event", family: "levitate", id: "wizard"})
      assert {:error, {:unknown_message, _}} = Protocol.decode_message(json)
    end

    test "the unknown_message tuple carries the decoded map" do
      json = Jason.encode!(%{type: "mystery"})
      {:error, {:unknown_message, msg}} = Protocol.decode_message(json)
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
      assert Protocol.parse_key("Hyper") == "Hyper"
    end
  end
end
