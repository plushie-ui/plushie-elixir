defmodule Toddy.Widget.SvgTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Svg

  describe "new/2" do
    test "creates SVG with source and id" do
      svg = Svg.new("icon1", "/path/to/icon.svg")
      assert %Svg{} = svg
      assert svg.id == "icon1"
      assert svg.source == "/path/to/icon.svg"
    end

    test "all optional fields default to nil" do
      svg = Svg.new("icon1", "logo.svg")
      assert svg.width == nil
      assert svg.height == nil
      assert svg.content_fit == nil
      assert svg.rotation == nil
      assert svg.opacity == nil
      assert svg.color == nil
    end

    test "accepts keyword opts" do
      svg = Svg.new("icon1", "logo.svg", width: 64, opacity: 0.8)
      assert svg.width == 64
      assert svg.opacity == 0.8
    end
  end

  describe "width/2" do
    test "sets the width field" do
      svg = Svg.new("i", "a.svg") |> Svg.width(:fill)
      assert svg.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      svg = Svg.new("i", "a.svg") |> Svg.height(100)
      assert svg.height == 100
    end
  end

  describe "content_fit/2" do
    test "sets the content_fit field" do
      svg = Svg.new("i", "a.svg") |> Svg.content_fit(:cover)
      assert svg.content_fit == :cover
    end
  end

  describe "rotation/2" do
    test "sets the rotation field" do
      svg = Svg.new("i", "a.svg") |> Svg.rotation(45)
      assert svg.rotation == 45
    end
  end

  describe "opacity/2" do
    test "sets the opacity field" do
      svg = Svg.new("i", "a.svg") |> Svg.opacity(0.5)
      assert svg.opacity == 0.5
    end
  end

  describe "color/2" do
    test "sets the color field with hex string" do
      svg = Svg.new("i", "a.svg") |> Svg.color("#ff0000")
      assert svg.color == "#ff0000"
    end

    test "normalizes named color atoms" do
      svg = Svg.new("i", "a.svg") |> Svg.color(:red)
      assert svg.color == "#ff0000"
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = Svg.new("icon1", "logo.svg") |> Svg.build()
      assert node.type == "svg"
      assert node.id == "icon1"
      assert node.children == []
    end

    test "includes source in props" do
      node = Svg.new("icon1", "/icons/star.svg") |> Svg.build()
      assert node.props[:source] == "/icons/star.svg"
    end

    test "includes non-nil optional props" do
      node =
        Svg.new("icon1", "a.svg")
        |> Svg.width(32)
        |> Svg.height(32)
        |> Svg.content_fit(:contain)
        |> Svg.rotation(90)
        |> Svg.opacity(0.75)
        |> Svg.color("#00ff00")
        |> Svg.build()

      assert node.props[:width] == 32
      assert node.props[:height] == 32
      assert node.props[:content_fit] == :contain
      assert node.props[:rotation] == 90
      assert node.props[:opacity] == 0.75
      assert node.props[:color] == "#00ff00"
    end

    test "omits nil optional props" do
      node = Svg.new("icon1", "a.svg") |> Svg.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "content_fit")
      refute Map.has_key?(node.props, "rotation")
      refute Map.has_key?(node.props, "opacity")
      refute Map.has_key?(node.props, "color")
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      svg =
        Svg.new("i", "a.svg",
          width: 48,
          height: 48,
          content_fit: :fill,
          rotation: 180,
          opacity: 1.0,
          color: "#ff0000"
        )

      assert svg.width == 48
      assert svg.height == 48
      assert svg.content_fit == :fill
      assert svg.rotation == 180
      assert svg.opacity == 1.0
      assert svg.color == "#ff0000"
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:border/, fn ->
        Svg.new("i", "a.svg", border: true)
      end
    end
  end
end
