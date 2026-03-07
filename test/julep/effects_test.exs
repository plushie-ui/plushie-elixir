defmodule Julep.EffectsTest do
  use ExUnit.Case, async: true

  alias Julep.Command
  alias Julep.Effects

  describe "request/2" do
    test "returns command with correct type and payload" do
      cmd = Effects.request(:http, url: "https://example.com")

      assert %Command{type: :effect_request, payload: payload} = cmd
      assert is_binary(payload.id)
      assert payload.kind == "http"
      assert payload.opts == %{url: "https://example.com"}
    end

    test "IDs start with ef_ prefix" do
      cmd = Effects.request(:test)
      assert String.starts_with?(cmd.payload.id, "ef_")
    end

    test "IDs are unique across calls" do
      ids = for _ <- 1..100, do: Effects.request(:test).payload.id
      assert length(Enum.uniq(ids)) == 100
    end

    test "opts default to empty map" do
      cmd = Effects.request(:noop)
      assert cmd.payload.opts == %{}
    end
  end

  describe "convenience functions" do
    test "file_open returns kind file_open" do
      cmd = Effects.file_open(title: "Pick a file")
      assert cmd.payload.kind == "file_open"
      assert cmd.payload.opts == %{title: "Pick a file"}
    end

    test "file_save returns kind file_save" do
      cmd = Effects.file_save(default_name: "out.txt")
      assert cmd.payload.kind == "file_save"
      assert cmd.payload.opts == %{default_name: "out.txt"}
    end

    test "directory_select returns kind directory_select" do
      cmd = Effects.directory_select()
      assert cmd.payload.kind == "directory_select"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_read returns kind clipboard_read" do
      cmd = Effects.clipboard_read()
      assert cmd.payload.kind == "clipboard_read"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_write returns kind clipboard_write with text" do
      cmd = Effects.clipboard_write("hello")
      assert cmd.payload.kind == "clipboard_write"
      assert cmd.payload.opts == %{text: "hello"}
    end

    test "notification returns kind notification with title and body" do
      cmd = Effects.notification("Alert", "Something happened")
      assert cmd.payload.kind == "notification"
      assert cmd.payload.opts == %{title: "Alert", body: "Something happened"}
    end
  end
end
