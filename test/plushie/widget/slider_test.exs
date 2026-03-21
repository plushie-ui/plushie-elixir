defmodule Plushie.Widget.SliderTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Slider

  describe "new/4" do
    test "creates struct with id, range, and value" do
      s = Slider.new("vol", {0, 100}, 50)
      assert %Slider{} = s
      assert s.id == "vol"
      assert s.range == {0, 100}
      assert s.value == 50
    end

    test "optional fields default to nil" do
      s = Slider.new("vol", {0, 100}, 50)
      assert s.step == nil
      assert s.shift_step == nil
      assert s.default == nil
      assert s.width == nil
      assert s.height == nil
      assert s.circular_handle == nil
      assert s.style == nil
    end

    test "accepts keyword options" do
      s = Slider.new("vol", {0, 100}, 50, step: 5, height: 20)
      assert s.step == 5
      assert s.height == 20
    end
  end

  describe "builders" do
    test "step/2 sets step" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.step(1)
      assert s.step == 1
    end

    test "shift_step/2 sets shift_step" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.shift_step(10)
      assert s.shift_step == 10
    end

    test "default/2 sets default" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.default(0)
      assert s.default == 0
    end

    test "width/2 sets width" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.width(:fill)
      assert s.width == :fill
    end

    test "height/2 sets height" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.height(24)
      assert s.height == 24
    end

    test "circular_handle/2 sets circular_handle" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.circular_handle(true)
      assert s.circular_handle == true
    end

    test "style/2 sets style" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.style(:default)
      assert s.style == :default
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = Slider.new("vol", {0, 100}, 75) |> Slider.build()
      assert node.type == "slider"
      assert node.id == "vol"
      assert node.children == []
    end

    test "includes value and range in props" do
      node = Slider.new("vol", {0, 100}, 75) |> Slider.build()
      assert node.props[:value] == 75
      # range is a tuple, Encode protocol converts it
      assert node.props[:range] != nil
    end

    test "includes non-nil optional props" do
      node = Slider.new("s", {0, 10}, 5, step: 1, height: 20) |> Slider.build()
      assert node.props[:step] == 1
      assert node.props[:height] == 20
    end

    test "omits nil props" do
      node = Slider.new("s", {0, 10}, 5) |> Slider.build()
      refute Map.has_key?(node.props, "step")
      refute Map.has_key?(node.props, "shift_step")
      refute Map.has_key?(node.props, "default")
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "style")
    end

    test "includes false values in props" do
      node = Slider.new("s", {0, 10}, 5) |> Slider.circular_handle(false) |> Slider.build()
      assert node.props[:circular_handle] == false
    end
  end

  describe "with_options/2" do
    test "routes multiple options" do
      s = Slider.new("id", {0, 10}, 5) |> Slider.with_options(step: 2, default: 0)
      assert s.step == 2
      assert s.default == 0
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:nope/, fn ->
        Slider.new("id", {0, 10}, 5, nope: true)
      end
    end
  end
end
