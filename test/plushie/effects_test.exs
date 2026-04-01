defmodule Plushie.EffectsTest do
  use ExUnit.Case, async: true

  alias Plushie.Command
  alias Plushie.Effects

  describe "request/3" do
    test "returns command with correct type and payload" do
      cmd = Effects.request(:open, :file_open, title: "Pick a file")

      assert %Command{type: :effect, payload: payload} = cmd
      assert is_binary(payload.id)
      assert payload.tag == :open
      assert payload.kind == "file_open"
      assert payload.opts == %{title: "Pick a file"}
    end

    test "IDs start with ef_ prefix" do
      cmd = Effects.request(:read, :clipboard_read)
      assert String.starts_with?(cmd.payload.id, "ef_")
    end

    test "IDs are unique across calls" do
      ids = for _ <- 1..100, do: Effects.request(:read, :clipboard_read).payload.id
      assert length(Enum.uniq(ids)) == 100
    end

    test "opts default to empty map" do
      cmd = Effects.request(:read, :clipboard_read)
      assert cmd.payload.opts == %{}
    end

    test "rejects invalid effect kind" do
      assert_raise FunctionClauseError, fn ->
        Effects.request(:bad, :http)
      end
    end
  end

  describe "convenience functions" do
    test "file_open returns kind file_open" do
      cmd = Effects.file_open(:open, title: "Pick a file")
      assert cmd.payload.tag == :open
      assert cmd.payload.kind == "file_open"
      assert cmd.payload.opts == %{title: "Pick a file"}
    end

    test "file_save returns kind file_save" do
      cmd = Effects.file_save(:save, default_name: "out.txt")
      assert cmd.payload.tag == :save
      assert cmd.payload.kind == "file_save"
      assert cmd.payload.opts == %{default_name: "out.txt"}
    end

    test "directory_select returns kind directory_select" do
      cmd = Effects.directory_select(:browse)
      assert cmd.payload.tag == :browse
      assert cmd.payload.kind == "directory_select"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_read returns kind clipboard_read" do
      cmd = Effects.clipboard_read(:read)
      assert cmd.payload.tag == :read
      assert cmd.payload.kind == "clipboard_read"
      assert cmd.payload.opts == %{}
    end

    test "clipboard_write returns kind clipboard_write with text" do
      cmd = Effects.clipboard_write(:write, "hello")
      assert cmd.payload.tag == :write
      assert cmd.payload.kind == "clipboard_write"
      assert cmd.payload.opts == %{text: "hello"}
    end

    test "notification returns kind notification with title and body" do
      cmd = Effects.notification(:notify, "Alert", "Something happened")
      assert cmd.payload.tag == :notify
      assert cmd.payload.kind == "notification"
      assert cmd.payload.opts == %{title: "Alert", body: "Something happened"}
    end
  end
end
