defmodule Julep.Iced.Widget.ComboBoxTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.ComboBox

  @options ["Apple", "Banana", "Cherry"]

  describe "new/3" do
    test "creates struct with id and options" do
      cb = ComboBox.new("fruit", @options)
      assert %ComboBox{} = cb
      assert cb.id == "fruit"
      assert cb.options == @options
    end

    test "optional fields default to nil" do
      cb = ComboBox.new("fruit", @options)
      assert cb.selected == nil
      assert cb.placeholder == nil
      assert cb.width == nil
      assert cb.padding == nil
      assert cb.size == nil
      assert cb.font == nil
      assert cb.line_height == nil
      assert cb.menu_height == nil
      assert cb.icon == nil
      assert cb.on_option_hovered == nil
      assert cb.on_open == nil
      assert cb.on_close == nil
    end

    test "accepts keyword options" do
      cb = ComboBox.new("fruit", @options, placeholder: "Search...", size: 14)
      assert cb.placeholder == "Search..."
      assert cb.size == 14
    end
  end

  describe "builders" do
    test "selected/2 sets selected" do
      cb = ComboBox.new("id", @options) |> ComboBox.selected("Apple")
      assert cb.selected == "Apple"
    end

    test "placeholder/2 sets placeholder" do
      cb = ComboBox.new("id", @options) |> ComboBox.placeholder("Pick...")
      assert cb.placeholder == "Pick..."
    end

    test "width/2 sets width" do
      cb = ComboBox.new("id", @options) |> ComboBox.width(:fill)
      assert cb.width == :fill
    end

    test "padding/2 sets padding" do
      cb = ComboBox.new("id", @options) |> ComboBox.padding(6)
      assert cb.padding == 6
    end

    test "size/2 sets text size" do
      cb = ComboBox.new("id", @options) |> ComboBox.size(16)
      assert cb.size == 16
    end

    test "menu_height/2 sets menu_height" do
      cb = ComboBox.new("id", @options) |> ComboBox.menu_height(150)
      assert cb.menu_height == 150
    end

    test "icon/2 sets the icon map" do
      icon = %{code_point: "?", side: "left"}
      cb = ComboBox.new("id", @options) |> ComboBox.icon(icon)
      assert cb.icon == icon
    end

    test "on_option_hovered/2 sets on_option_hovered" do
      cb = ComboBox.new("id", @options) |> ComboBox.on_option_hovered(true)
      assert cb.on_option_hovered == true
    end

    test "on_open/2 sets on_open" do
      cb = ComboBox.new("id", @options) |> ComboBox.on_open(true)
      assert cb.on_open == true
    end

    test "on_close/2 sets on_close" do
      cb = ComboBox.new("id", @options) |> ComboBox.on_close(true)
      assert cb.on_close == true
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = ComboBox.new("fruit", @options) |> ComboBox.build()
      assert node.type == "combo_box"
      assert node.id == "fruit"
      assert node.children == []
    end

    test "includes options in props" do
      node = ComboBox.new("fruit", @options) |> ComboBox.build()
      assert node.props["options"] == @options
    end

    test "includes on_open and on_close in props when set" do
      node =
        ComboBox.new("fruit", @options)
        |> ComboBox.on_open(true)
        |> ComboBox.on_close(true)
        |> ComboBox.build()

      assert node.props["on_open"] == true
      assert node.props["on_close"] == true
    end

    test "omits nil props" do
      node = ComboBox.new("fruit", @options) |> ComboBox.build()
      refute Map.has_key?(node.props, "selected")
      refute Map.has_key?(node.props, "placeholder")
      refute Map.has_key?(node.props, "on_open")
      refute Map.has_key?(node.props, "on_close")
      refute Map.has_key?(node.props, "on_option_hovered")
    end

    test "includes false values in props" do
      node =
        ComboBox.new("fruit", @options)
        |> ComboBox.on_option_hovered(false)
        |> ComboBox.build()

      assert node.props["on_option_hovered"] == false
    end
  end

  describe "with_options/2" do
    test "routes multiple options including on_open/on_close" do
      cb =
        ComboBox.new("id", @options)
        |> ComboBox.with_options(selected: "Apple", on_open: true, on_close: true)

      assert cb.selected == "Apple"
      assert cb.on_open == true
      assert cb.on_close == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        ComboBox.new("id", @options, bogus: true)
      end
    end
  end
end
