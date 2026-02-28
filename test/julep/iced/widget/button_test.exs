defmodule Julep.Iced.Widget.ButtonTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.Button

  describe "new/2" do
    test "creates button with label and id" do
      btn = Button.new("btn1", "Click me")
      assert %Button{} = btn
      assert btn.id == "btn1"
      assert btn.label == "Click me"
    end

    test "all optional fields default to nil" do
      btn = Button.new("btn1", "OK")
      assert btn.width == nil
      assert btn.height == nil
      assert btn.padding == nil
      assert btn.clip == nil
      assert btn.style == nil
      assert btn.disabled == nil
    end

    test "accepts keyword opts" do
      btn = Button.new("btn1", "Go", style: :primary, clip: true)
      assert btn.style == :primary
      assert btn.clip == true
    end
  end

  describe "width/2" do
    test "sets the width field" do
      btn = Button.new("b", "X") |> Button.width(:fill)
      assert btn.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      btn = Button.new("b", "X") |> Button.height(50)
      assert btn.height == 50
    end
  end

  describe "padding/2" do
    test "sets the padding field" do
      btn = Button.new("b", "X") |> Button.padding(10)
      assert btn.padding == 10
    end
  end

  describe "clip/2" do
    test "sets the clip field" do
      btn = Button.new("b", "X") |> Button.clip(true)
      assert btn.clip == true
    end
  end

  describe "style/2" do
    test "sets the style field" do
      btn = Button.new("b", "X") |> Button.style(:danger)
      assert btn.style == :danger
    end
  end

  describe "disabled/2" do
    test "sets the disabled field" do
      btn = Button.new("b", "X") |> Button.disabled(true)
      assert btn.disabled == true
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = Button.new("btn1", "OK") |> Button.build()
      assert node.type == "button"
      assert node.id == "btn1"
      assert node.children == []
    end

    test "includes label in props" do
      node = Button.new("btn1", "Submit") |> Button.build()
      assert node.props["label"] == "Submit"
    end

    test "includes non-nil props" do
      node =
        Button.new("btn1", "Go")
        |> Button.width(:fill)
        |> Button.style(:secondary)
        |> Button.disabled(true)
        |> Button.build()

      assert node.props["width"] == "fill"
      assert node.props["style"] == "secondary"
      assert node.props["disabled"] == true
    end

    test "omits nil props" do
      node = Button.new("btn1", "Go") |> Button.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "padding")
      refute Map.has_key?(node.props, "clip")
      refute Map.has_key?(node.props, "style")
      refute Map.has_key?(node.props, "disabled")
    end

    test "includes disabled false in props" do
      node = Button.new("btn1", "Go") |> Button.disabled(false) |> Button.build()
      assert node.props["disabled"] == false
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      btn =
        Button.new("b", "X",
          width: :fill,
          height: 40,
          padding: 5,
          clip: true,
          style: :danger,
          disabled: true
        )

      assert btn.width == :fill
      assert btn.height == 40
      assert btn.padding == 5
      assert btn.clip == true
      assert btn.style == :danger
      assert btn.disabled == true
    end

    test "enabled option sets disabled inversely" do
      btn = Button.new("b", "X", enabled: false)
      assert btn.disabled == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Button.new("b", "X", bogus: true)
      end
    end
  end
end
