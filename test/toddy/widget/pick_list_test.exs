defmodule Toddy.Widget.PickListTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.PickList

  @options ["Red", "Green", "Blue"]

  describe "new/3" do
    test "creates struct with id and options" do
      pl = PickList.new("color", @options)
      assert %PickList{} = pl
      assert pl.id == "color"
      assert pl.options == @options
    end

    test "optional fields default to nil" do
      pl = PickList.new("color", @options)
      assert pl.selected == nil
      assert pl.placeholder == nil
      assert pl.width == nil
      assert pl.padding == nil
      assert pl.text_size == nil
      assert pl.font == nil
      assert pl.line_height == nil
      assert pl.menu_height == nil
      assert pl.text_shaping == nil
      assert pl.handle == nil
      assert pl.style == nil
      assert pl.on_open == nil
      assert pl.on_close == nil
    end

    test "accepts keyword options" do
      pl = PickList.new("color", @options, selected: "Red", placeholder: "Pick one")
      assert pl.selected == "Red"
      assert pl.placeholder == "Pick one"
    end
  end

  describe "builders" do
    test "selected/2 sets selected" do
      pl = PickList.new("id", @options) |> PickList.selected("Green")
      assert pl.selected == "Green"
    end

    test "placeholder/2 sets placeholder" do
      pl = PickList.new("id", @options) |> PickList.placeholder("Choose...")
      assert pl.placeholder == "Choose..."
    end

    test "width/2 sets width" do
      pl = PickList.new("id", @options) |> PickList.width(:fill)
      assert pl.width == :fill
    end

    test "padding/2 sets padding" do
      pl = PickList.new("id", @options) |> PickList.padding(8)
      assert pl.padding == 8
    end

    test "text_size/2 sets text_size" do
      pl = PickList.new("id", @options) |> PickList.text_size(14)
      assert pl.text_size == 14
    end

    test "menu_height/2 sets menu_height" do
      pl = PickList.new("id", @options) |> PickList.menu_height(200)
      assert pl.menu_height == 200
    end

    test "handle/2 sets handle" do
      h = %{type: "arrow", size: 12}
      pl = PickList.new("id", @options) |> PickList.handle(h)
      assert pl.handle == h
    end

    test "on_open/2 sets on_open" do
      pl = PickList.new("id", @options) |> PickList.on_open(true)
      assert pl.on_open == true
    end

    test "on_close/2 sets on_close" do
      pl = PickList.new("id", @options) |> PickList.on_close(true)
      assert pl.on_close == true
    end

    test "style/2 sets style" do
      pl = PickList.new("id", @options) |> PickList.style(:default)
      assert pl.style == :default
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = PickList.new("color", @options) |> PickList.build()
      assert node.type == "pick_list"
      assert node.id == "color"
      assert node.children == []
    end

    test "includes options in props" do
      node = PickList.new("color", @options) |> PickList.build()
      assert node.props[:options] == @options
    end

    test "includes on_open and on_close in props when set" do
      node =
        PickList.new("color", @options)
        |> PickList.on_open(true)
        |> PickList.on_close(true)
        |> PickList.build()

      assert node.props[:on_open] == true
      assert node.props[:on_close] == true
    end

    test "omits nil props" do
      node = PickList.new("color", @options) |> PickList.build()
      refute Map.has_key?(node.props, "selected")
      refute Map.has_key?(node.props, "placeholder")
      refute Map.has_key?(node.props, "on_open")
      refute Map.has_key?(node.props, "on_close")
      refute Map.has_key?(node.props, "style")
    end

    test "includes false values in props" do
      node = PickList.new("color", @options) |> PickList.on_open(false) |> PickList.build()
      assert node.props[:on_open] == false
    end
  end

  describe "with_options/2" do
    test "routes multiple options including on_open/on_close" do
      pl =
        PickList.new("id", @options)
        |> PickList.with_options(selected: "Red", on_open: true, on_close: true)

      assert pl.selected == "Red"
      assert pl.on_open == true
      assert pl.on_close == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        PickList.new("id", @options, bogus: true)
      end
    end
  end
end
