defmodule Julep.Iced.BorderTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Border

  describe "new/0" do
    test "returns default border with nil color, zero width, zero radius" do
      assert Border.new() == %{color: nil, width: 0, radius: 0}
    end
  end

  describe "color/2" do
    test "sets the border color" do
      border = Border.new() |> Border.color("#ff0000")
      assert border.color == "#ff0000"
    end

    test "overwrites previous color" do
      border = Border.new() |> Border.color("#ff0000") |> Border.color("#00ff00")
      assert border.color == "#00ff00"
    end
  end

  describe "width/2" do
    test "sets the border width" do
      border = Border.new() |> Border.width(2)
      assert border.width == 2
    end

    test "accepts float width" do
      border = Border.new() |> Border.width(1.5)
      assert border.width == 1.5
    end
  end

  describe "rounded/2" do
    test "sets uniform corner radius" do
      border = Border.new() |> Border.rounded(8)
      assert border.radius == 8
    end
  end

  describe "radius/4" do
    test "creates per-corner radius map" do
      r = Border.radius(1, 2, 3, 4)
      assert r == %{top_left: 1, top_right: 2, bottom_right: 3, bottom_left: 4}
    end

    test "all zeros" do
      r = Border.radius(0, 0, 0, 0)
      assert r == %{top_left: 0, top_right: 0, bottom_right: 0, bottom_left: 0}
    end
  end

  describe "pipeline usage" do
    test "builds a complete border via chaining" do
      border =
        Border.new()
        |> Border.color("#333")
        |> Border.width(1)
        |> Border.rounded(4)

      assert border == %{color: "#333", width: 1, radius: 4}
    end

    test "uses per-corner radius in a border" do
      border =
        Border.new()
        |> Border.color("#000")
        |> Border.width(2)

      border = %{border | radius: Border.radius(4, 4, 0, 0)}
      assert border.radius == %{top_left: 4, top_right: 4, bottom_right: 0, bottom_left: 0}
    end
  end

  describe "encode/1" do
    test "passes through the border map unchanged" do
      border = Border.new() |> Border.color("#fff") |> Border.width(1)
      assert Border.encode(border) == border
    end
  end
end
