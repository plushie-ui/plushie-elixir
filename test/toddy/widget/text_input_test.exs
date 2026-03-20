defmodule Toddy.Widget.TextInputTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.TextInput

  describe "new/3" do
    test "creates struct with id and value" do
      ti = TextInput.new("name", "Arthur")
      assert %TextInput{} = ti
      assert ti.id == "name"
      assert ti.value == "Arthur"
    end

    test "optional fields default to nil" do
      ti = TextInput.new("name", "")
      assert ti.placeholder == nil
      assert ti.padding == nil
      assert ti.width == nil
      assert ti.size == nil
      assert ti.font == nil
      assert ti.line_height == nil
      assert ti.align_x == nil
      assert ti.icon == nil
      assert ti.on_submit == nil
      assert ti.on_paste == nil
      assert ti.secure == nil
      assert ti.style == nil
    end

    test "accepts keyword options" do
      ti = TextInput.new("name", "", placeholder: "Enter name", size: 16)
      assert ti.placeholder == "Enter name"
      assert ti.size == 16
    end
  end

  describe "builders" do
    test "placeholder/2 sets the placeholder" do
      ti = TextInput.new("id", "") |> TextInput.placeholder("hint")
      assert ti.placeholder == "hint"
    end

    test "padding/2 sets padding" do
      ti = TextInput.new("id", "") |> TextInput.padding(10)
      assert ti.padding == 10
    end

    test "width/2 sets width" do
      ti = TextInput.new("id", "") |> TextInput.width(:fill)
      assert ti.width == :fill
    end

    test "size/2 sets font size" do
      ti = TextInput.new("id", "") |> TextInput.size(20)
      assert ti.size == 20
    end

    test "font/2 sets font" do
      ti = TextInput.new("id", "") |> TextInput.font("Monospace")
      assert ti.font == "Monospace"
    end

    test "line_height/2 sets line height" do
      ti = TextInput.new("id", "") |> TextInput.line_height(1.5)
      assert ti.line_height == 1.5
    end

    test "align_x/2 sets horizontal alignment" do
      ti = TextInput.new("id", "") |> TextInput.align_x(:center)
      assert ti.align_x == :center
    end

    test "icon/2 sets the icon map" do
      icon = %{code_point: "X", side: "left"}
      ti = TextInput.new("id", "") |> TextInput.icon(icon)
      assert ti.icon == icon
    end

    test "on_submit/2 sets on_submit" do
      ti = TextInput.new("id", "") |> TextInput.on_submit(true)
      assert ti.on_submit == true
    end

    test "on_paste/2 sets on_paste" do
      ti = TextInput.new("id", "") |> TextInput.on_paste(true)
      assert ti.on_paste == true
    end

    test "secure/2 sets secure" do
      ti = TextInput.new("id", "") |> TextInput.secure(true)
      assert ti.secure == true
    end

    test "style/2 sets style" do
      ti = TextInput.new("id", "") |> TextInput.style(:default)
      assert ti.style == :default
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = TextInput.new("search", "query") |> TextInput.build()
      assert node.type == "text_input"
      assert node.id == "search"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        TextInput.new("search", "hello", placeholder: "type here", size: 14, secure: true)
        |> TextInput.build()

      assert node.props["value"] == "hello"
      assert node.props["placeholder"] == "type here"
      assert node.props["size"] == 14
      assert node.props["secure"] == true
    end

    test "omits nil props" do
      node = TextInput.new("id", "val") |> TextInput.build()
      refute Map.has_key?(node.props, "placeholder")
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "font")
      refute Map.has_key?(node.props, "style")
    end

    test "includes false values in props" do
      node = TextInput.new("id", "") |> TextInput.secure(false) |> TextInput.build()
      assert node.props["secure"] == false
    end
  end

  describe "with_options/2" do
    test "routes multiple options" do
      ti = TextInput.new("id", "") |> TextInput.with_options(width: :fill, on_submit: true)
      assert ti.width == :fill
      assert ti.on_submit == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        TextInput.new("id", "", bogus: true)
      end
    end
  end
end
