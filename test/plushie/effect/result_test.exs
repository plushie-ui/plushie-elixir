defmodule Plushie.Effect.ResultTest do
  use ExUnit.Case, async: true

  alias Plushie.Effect.Result

  describe "decode/3 success results" do
    test "decodes file and directory path results" do
      assert Result.decode("file_open", "ok", %{path: "/tmp/a.txt"}) ==
               %Result.FileOpened{path: "/tmp/a.txt"}

      assert Result.decode("file_save", "ok", %{"path" => "/tmp/out.txt"}) ==
               %Result.FileSaved{path: "/tmp/out.txt"}

      assert Result.decode("directory_select", "ok", %{path: "/tmp"}) ==
               %Result.DirectorySelected{path: "/tmp"}
    end

    test "decodes multiple path results" do
      assert Result.decode("file_open_multiple", "ok", %{paths: ["/a", "/b"]}) ==
               %Result.FilesOpened{paths: ["/a", "/b"]}

      assert Result.decode("directory_select_multiple", "ok", %{"paths" => ["/a", "/b"]}) ==
               %Result.DirectoriesSelected{paths: ["/a", "/b"]}
    end

    test "decodes clipboard read results" do
      assert Result.decode("clipboard_read", "ok", %{text: "hello"}) ==
               %Result.ClipboardText{text: "hello"}

      assert Result.decode("clipboard_read_primary", "ok", %{"text" => "primary"}) ==
               %Result.ClipboardText{text: "primary"}

      assert Result.decode("clipboard_read_html", "ok", %{html: "<b>x</b>", alt_text: "x"}) ==
               %Result.ClipboardHtml{html: "<b>x</b>", alt_text: "x"}

      assert Result.decode("clipboard_read_html", "ok", %{html: "<b>x</b>"}) ==
               %Result.ClipboardHtml{html: "<b>x</b>", alt_text: nil}
    end

    test "decodes side-effect acknowledgements" do
      assert Result.decode("clipboard_write", "ok", %{}) == %Result.ClipboardWritten{}
      assert Result.decode("clipboard_write_html", "ok", %{}) == %Result.ClipboardWritten{}
      assert Result.decode("clipboard_write_primary", "ok", %{}) == %Result.ClipboardWritten{}
      assert Result.decode("clipboard_clear", "ok", %{}) == %Result.ClipboardCleared{}
      assert Result.decode("notification", "ok", %{}) == %Result.NotificationShown{}
    end
  end

  describe "decode/3 non-success results" do
    test "decodes cancelled and unsupported statuses" do
      assert Result.decode("file_open", "cancelled", nil) == %Result.Cancelled{}
      assert Result.decode("file_open", "unsupported", nil) == %Result.Unsupported{}
    end

    test "decodes errors with safe messages" do
      assert Result.decode("file_open", "error", "denied") == %Result.Error{message: "denied"}
      assert Result.decode("file_open", "error", :denied) == %Result.Error{message: "denied"}

      assert Result.decode("file_open", "error", %{reason: :denied}) == %Result.Error{
               message: "%{reason: :denied}"
             }
    end

    test "unknown statuses become typed errors" do
      assert Result.decode("file_open", "weird", nil) == %Result.Error{
               message: "unknown effect status"
             }
    end
  end

  describe "decode/3 malformed ok payloads" do
    test "unknown kinds become typed errors" do
      assert Result.decode("not_real", "ok", %{}) == %Result.Error{
               message: "unknown effect kind: not_real"
             }
    end

    test "missing required fields become typed errors" do
      assert Result.decode("file_open", "ok", %{}) == %Result.Error{
               message: "malformed effect result for file_open"
             }
    end

    test "invalid path lists become typed errors" do
      assert Result.decode("file_open_multiple", "ok", %{paths: ["/a", nil]}) == %Result.Error{
               message: "malformed effect result for file_open_multiple"
             }
    end

    test "invalid optional strings become typed errors" do
      assert Result.decode("clipboard_read_html", "ok", %{html: "<b>x</b>", alt_text: 123}) ==
               %Result.Error{message: "malformed effect result for clipboard_read_html"}
    end
  end

  describe "timeout and restart constructors" do
    test "return typed runtime-only results" do
      assert Result.timeout() == %Result.Timeout{}
      assert Result.renderer_restarted() == %Result.RendererRestarted{}
    end
  end
end
