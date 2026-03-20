defmodule Toddy.Widget.VerticalSliderTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.VerticalSlider

  describe "new/4" do
    test "creates struct with id, range, and value" do
      vs = VerticalSlider.new("pitch", {20, 20_000}, 440)
      assert %VerticalSlider{} = vs
      assert vs.id == "pitch"
      assert vs.range == {20, 20_000}
      assert vs.value == 440
    end

    test "optional fields default to nil" do
      vs = VerticalSlider.new("vs", {0, 100}, 50)
      assert vs.step == nil
      assert vs.shift_step == nil
      assert vs.default == nil
      assert vs.width == nil
      assert vs.height == nil
      assert vs.style == nil
    end

    test "accepts keyword options" do
      vs = VerticalSlider.new("vs", {0, 100}, 50, step: 10, height: :fill)
      assert vs.step == 10
      assert vs.height == :fill
    end
  end

  describe "builders" do
    test "step/2 sets step" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.step(1)
      assert vs.step == 1
    end

    test "shift_step/2 sets shift_step" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.shift_step(5)
      assert vs.shift_step == 5
    end

    test "default/2 sets default" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.default(3)
      assert vs.default == 3
    end

    test "height/2 sets height" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.height(200)
      assert vs.height == 200
    end

    test "width/2 sets width" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.width(40)
      assert vs.width == 40
    end

    test "style/2 sets style" do
      vs = VerticalSlider.new("id", {0, 10}, 5) |> VerticalSlider.style(:default)
      assert vs.style == :default
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = VerticalSlider.new("vs", {0, 100}, 50) |> VerticalSlider.build()
      assert node.type == "vertical_slider"
      assert node.id == "vs"
      assert node.children == []
    end

    test "includes value and range in props" do
      node = VerticalSlider.new("vs", {0, 100}, 75) |> VerticalSlider.build()
      assert node.props["value"] == 75
      assert node.props["range"] != nil
    end

    test "includes non-nil optional props" do
      node =
        VerticalSlider.new("vs", {0, 10}, 5, step: 2, width: 40, height: 300)
        |> VerticalSlider.build()

      assert node.props["step"] == 2
      assert node.props["width"] == 40
      assert node.props["height"] == 300
    end

    test "omits nil props" do
      node = VerticalSlider.new("vs", {0, 10}, 5) |> VerticalSlider.build()
      refute Map.has_key?(node.props, "step")
      refute Map.has_key?(node.props, "shift_step")
      refute Map.has_key?(node.props, "default")
      refute Map.has_key?(node.props, "style")
    end
  end

  describe "with_options/2" do
    test "routes multiple options" do
      vs =
        VerticalSlider.new("id", {0, 10}, 5)
        |> VerticalSlider.with_options(step: 1, default: 0, style: :default)

      assert vs.step == 1
      assert vs.default == 0
      assert vs.style == :default
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        VerticalSlider.new("id", {0, 10}, 5, bogus: true)
      end
    end
  end
end
