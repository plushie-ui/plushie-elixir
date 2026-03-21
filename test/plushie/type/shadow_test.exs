defmodule Plushie.Type.ShadowTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Shadow

  describe "new/0" do
    test "returns default shadow struct" do
      assert Shadow.new() == %Shadow{
               color: "#000000",
               offset_x: 0,
               offset_y: 0,
               blur_radius: 0
             }
    end
  end

  describe "color/2" do
    test "sets the shadow color" do
      shadow = Shadow.new() |> Shadow.color("#ff0000")
      assert shadow.color == "#ff0000"
    end

    test "casts atom color names" do
      shadow = Shadow.new() |> Shadow.color(:red)
      assert shadow.color == "#ff0000"
    end
  end

  describe "offset/3" do
    test "sets x and y offset" do
      shadow = Shadow.new() |> Shadow.offset(5, 10)
      assert shadow.offset_x == 5
      assert shadow.offset_y == 10
    end

    test "accepts negative offsets" do
      shadow = Shadow.new() |> Shadow.offset(-3, -7)
      assert shadow.offset_x == -3
      assert shadow.offset_y == -7
    end

    test "accepts float offsets" do
      shadow = Shadow.new() |> Shadow.offset(2.5, 3.5)
      assert shadow.offset_x == 2.5
      assert shadow.offset_y == 3.5
    end
  end

  describe "blur_radius/2" do
    test "sets the blur radius" do
      shadow = Shadow.new() |> Shadow.blur_radius(12)
      assert shadow.blur_radius == 12
    end
  end

  describe "pipeline usage" do
    test "builds a complete shadow via chaining" do
      shadow =
        Shadow.new()
        |> Shadow.color("#333333")
        |> Shadow.offset(2, 4)
        |> Shadow.blur_radius(8)

      assert shadow == %Shadow{color: "#333333", offset_x: 2, offset_y: 4, blur_radius: 8}
    end
  end

  describe "struct" do
    test "is a proper struct" do
      shadow = Shadow.new()
      assert %Shadow{} = shadow
    end

    test "builder functions require struct" do
      bare_map = %{color: "#000000", offset_x: 0, offset_y: 0, blur_radius: 0}

      assert_raise FunctionClauseError, fn ->
        apply(Shadow, :color, [bare_map, "#ff0000"])
      end
    end
  end
end
