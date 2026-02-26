defmodule Julep.EffectsTest do
  use ExUnit.Case, async: true

  alias Julep.Effects
  alias Julep.Command

  describe "request/2" do
    test "returns {command, id} with correct type and payload" do
      {cmd, id} = Effects.request(:http, url: "https://example.com")

      assert %Command{type: :effect_request, payload: payload} = cmd
      assert payload.id == id
      assert payload.kind == "http"
      assert payload.opts == %{url: "https://example.com"}
    end

    test "IDs start with ef_ prefix" do
      {_cmd, id} = Effects.request(:test)
      assert String.starts_with?(id, "ef_")
    end

    test "IDs are unique across calls" do
      ids = for _ <- 1..100, do: elem(Effects.request(:test), 1)
      assert length(Enum.uniq(ids)) == 100
    end

    test "opts default to empty map" do
      {cmd, _id} = Effects.request(:noop)
      assert cmd.payload.opts == %{}
    end
  end

  describe "convenience functions" do
    test "file_open returns kind file_open" do
      {cmd, _id} = Effects.file_open(title: "Pick a file")
      assert cmd.payload.kind == "file_open"
      assert cmd.payload.opts == %{title: "Pick a file"}
    end

    test "file_save returns kind file_save" do
      {cmd, _id} = Effects.file_save(default_name: "out.txt")
      assert cmd.payload.kind == "file_save"
      assert cmd.payload.opts == %{default_name: "out.txt"}
    end

    test "directory_select returns kind directory_select" do
      {cmd, _id} = Effects.directory_select()
      assert cmd.payload.kind == "directory_select"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_read returns kind clipboard_read" do
      {cmd, _id} = Effects.clipboard_read()
      assert cmd.payload.kind == "clipboard_read"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_write returns kind clipboard_write with text" do
      {cmd, _id} = Effects.clipboard_write("hello")
      assert cmd.payload.kind == "clipboard_write"
      assert cmd.payload.opts == %{text: "hello"}
    end

    test "notification returns kind notification with title and body" do
      {cmd, _id} = Effects.notification("Alert", "Something happened")
      assert cmd.payload.kind == "notification"
      assert cmd.payload.opts == %{title: "Alert", body: "Something happened"}
    end
  end
end
