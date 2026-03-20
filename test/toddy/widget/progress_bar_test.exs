defmodule Toddy.Widget.ProgressBarTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.ProgressBar

  describe "new/3" do
    test "creates progress bar with range and value" do
      bar = ProgressBar.new("pb1", {0, 100}, 50)
      assert %ProgressBar{} = bar
      assert bar.id == "pb1"
      assert bar.range == {0, 100}
      assert bar.value == 50
    end

    test "all optional fields default to nil" do
      bar = ProgressBar.new("pb1", {0, 100}, 0)
      assert bar.width == nil
      assert bar.height == nil
      assert bar.style == nil
      assert bar.vertical == nil
    end

    test "accepts keyword opts" do
      bar = ProgressBar.new("pb1", {0, 50}, 25, style: :success, vertical: true)
      assert bar.style == :success
      assert bar.vertical == true
    end
  end

  describe "width/2" do
    test "sets the width field" do
      bar = ProgressBar.new("pb", {0, 100}, 0) |> ProgressBar.width(:fill)
      assert bar.width == :fill
    end
  end

  describe "height/2" do
    test "sets the height field" do
      bar = ProgressBar.new("pb", {0, 100}, 0) |> ProgressBar.height(20)
      assert bar.height == 20
    end
  end

  describe "style/2" do
    test "sets the style field" do
      bar = ProgressBar.new("pb", {0, 100}, 0) |> ProgressBar.style(:danger)
      assert bar.style == :danger
    end
  end

  describe "vertical/2" do
    test "sets the vertical field" do
      bar = ProgressBar.new("pb", {0, 100}, 0) |> ProgressBar.vertical(true)
      assert bar.vertical == true
    end
  end

  describe "build/1" do
    test "returns a map with correct type and id" do
      node = ProgressBar.new("pb1", {0, 100}, 50) |> ProgressBar.build()
      assert node.type == "progress_bar"
      assert node.id == "pb1"
      assert node.children == []
    end

    test "includes range as two-element list in props" do
      node = ProgressBar.new("pb1", {0, 200}, 75) |> ProgressBar.build()
      assert node.props[:range] == [0, 200]
    end

    test "includes value in props" do
      node = ProgressBar.new("pb1", {0, 100}, 42) |> ProgressBar.build()
      assert node.props[:value] == 42
    end

    test "includes non-nil optional props" do
      node =
        ProgressBar.new("pb1", {0, 100}, 50)
        |> ProgressBar.width(:fill)
        |> ProgressBar.style(:warning)
        |> ProgressBar.vertical(true)
        |> ProgressBar.build()

      assert node.props[:width] == "fill"
      assert node.props[:style] == "warning"
      assert node.props[:vertical] == true
    end

    test "omits nil optional props" do
      node = ProgressBar.new("pb1", {0, 100}, 50) |> ProgressBar.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "style")
      refute Map.has_key?(node.props, "vertical")
    end

    test "value of zero is included in props" do
      node = ProgressBar.new("pb1", {0, 100}, 0) |> ProgressBar.build()
      assert node.props[:value] == 0
    end
  end

  describe "with_options/2" do
    test "routes all supported options" do
      bar =
        ProgressBar.new("pb", {0, 100}, 10,
          width: :fill,
          height: 8,
          style: :secondary,
          vertical: false
        )

      assert bar.width == :fill
      assert bar.height == 8
      assert bar.style == :secondary
      assert bar.vertical == false
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:color/, fn ->
        ProgressBar.new("pb", {0, 100}, 0, color: "red")
      end
    end
  end
end
