defmodule Toddy.Iced.Widget.TextEditorTest do
  use ExUnit.Case, async: true

  alias Toddy.Iced.Widget.TextEditor

  describe "new/2" do
    test "creates struct with id" do
      ed = TextEditor.new("editor")
      assert %TextEditor{} = ed
      assert ed.id == "editor"
    end

    test "optional fields default to nil" do
      ed = TextEditor.new("editor")
      assert ed.content == nil
      assert ed.placeholder == nil
      assert ed.width == nil
      assert ed.height == nil
      assert ed.min_height == nil
      assert ed.max_height == nil
      assert ed.font == nil
      assert ed.size == nil
      assert ed.line_height == nil
      assert ed.padding == nil
      assert ed.wrapping == nil
      assert ed.highlight_syntax == nil
      assert ed.highlight_theme == nil
      assert ed.style == nil
    end

    test "accepts keyword options" do
      ed = TextEditor.new("editor", content: "hello", size: 14)
      assert ed.content == "hello"
      assert ed.size == 14
    end
  end

  describe "builders" do
    test "content/2 sets content" do
      ed = TextEditor.new("id") |> TextEditor.content("some text")
      assert ed.content == "some text"
    end

    test "placeholder/2 sets placeholder" do
      ed = TextEditor.new("id") |> TextEditor.placeholder("Type here...")
      assert ed.placeholder == "Type here..."
    end

    test "width/2 sets width" do
      ed = TextEditor.new("id") |> TextEditor.width(400)
      assert ed.width == 400
    end

    test "height/2 sets height" do
      ed = TextEditor.new("id") |> TextEditor.height(:fill)
      assert ed.height == :fill
    end

    test "min_height/2 sets min_height" do
      ed = TextEditor.new("id") |> TextEditor.min_height(100)
      assert ed.min_height == 100
    end

    test "max_height/2 sets max_height" do
      ed = TextEditor.new("id") |> TextEditor.max_height(500)
      assert ed.max_height == 500
    end

    test "size/2 sets font size" do
      ed = TextEditor.new("id") |> TextEditor.size(18)
      assert ed.size == 18
    end

    test "padding/2 sets padding" do
      ed = TextEditor.new("id") |> TextEditor.padding(12)
      assert ed.padding == 12
    end

    test "wrapping/2 sets wrapping" do
      ed = TextEditor.new("id") |> TextEditor.wrapping(:word)
      assert ed.wrapping == :word
    end

    test "highlight_syntax/2 sets syntax language" do
      ed = TextEditor.new("id") |> TextEditor.highlight_syntax("ex")
      assert ed.highlight_syntax == "ex"
    end

    test "highlight_theme/2 sets highlighter theme" do
      ed = TextEditor.new("id") |> TextEditor.highlight_theme("base16_mocha")
      assert ed.highlight_theme == "base16_mocha"
    end

    test "style/2 sets style" do
      ed = TextEditor.new("id") |> TextEditor.style(:default)
      assert ed.style == :default
    end

    test "key_bindings/2 sets key bindings" do
      bindings = [
        %{"key" => "s", "modifiers" => ["ctrl"], "binding" => %{"custom" => "save"}},
        %{"binding" => "default"}
      ]

      ed = TextEditor.new("id") |> TextEditor.key_bindings(bindings)
      assert ed.key_bindings == bindings
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = TextEditor.new("editor") |> TextEditor.build()
      assert node.type == "text_editor"
      assert node.id == "editor"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        TextEditor.new("editor",
          content: "code",
          highlight_syntax: "rs",
          highlight_theme: "solarized_dark"
        )
        |> TextEditor.build()

      assert node.props["content"] == "code"
      assert node.props["highlight_syntax"] == "rs"
      assert node.props["highlight_theme"] == "solarized_dark"
    end

    test "omits nil props" do
      node = TextEditor.new("editor") |> TextEditor.build()
      refute Map.has_key?(node.props, "content")
      refute Map.has_key?(node.props, "placeholder")
      refute Map.has_key?(node.props, "highlight_syntax")
      refute Map.has_key?(node.props, "highlight_theme")
      refute Map.has_key?(node.props, "style")
      refute Map.has_key?(node.props, "key_bindings")
    end

    test "includes key_bindings in props when set" do
      bindings = [
        %{"key" => "s", "modifiers" => ["ctrl"], "binding" => %{"custom" => "save"}},
        %{"named" => "Enter", "modifiers" => ["ctrl"], "binding" => "enter"},
        %{"binding" => "default"}
      ]

      node =
        TextEditor.new("ed")
        |> TextEditor.key_bindings(bindings)
        |> TextEditor.build()

      assert node.props["key_bindings"] == bindings
    end

    test "includes highlight fields alongside content" do
      node =
        TextEditor.new("ed")
        |> TextEditor.content("defmodule Foo do\nend")
        |> TextEditor.highlight_syntax("ex")
        |> TextEditor.highlight_theme("inspired_github")
        |> TextEditor.build()

      assert node.props["content"] == "defmodule Foo do\nend"
      assert node.props["highlight_syntax"] == "ex"
      assert node.props["highlight_theme"] == "inspired_github"
    end
  end

  describe "with_options/2" do
    test "routes multiple options including highlight fields" do
      ed =
        TextEditor.new("id")
        |> TextEditor.with_options(
          content: "x = 1",
          highlight_syntax: "py",
          highlight_theme: "base16_ocean",
          wrapping: :word
        )

      assert ed.content == "x = 1"
      assert ed.highlight_syntax == "py"
      assert ed.highlight_theme == "base16_ocean"
      assert ed.wrapping == :word
    end

    test "routes key_bindings option" do
      bindings = [%{"binding" => "default"}]

      ed =
        TextEditor.new("id")
        |> TextEditor.with_options(key_bindings: bindings)

      assert ed.key_bindings == bindings
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:readonly/, fn ->
        TextEditor.new("id", readonly: true)
      end
    end
  end
end
