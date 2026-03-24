defmodule Plushie.Type.StyleMapTest do
  use ExUnit.Case, async: true

  alias Plushie.Encode
  alias Plushie.Type.{Border, Color, Shadow, StyleMap}

  # -- Construction -----------------------------------------------------------

  describe "new/0" do
    test "returns an empty struct with all nil fields" do
      style = StyleMap.new()

      assert %StyleMap{} = style
      assert is_nil(style.background)
      assert is_nil(style.text_color)
      assert is_nil(style.border)
      assert is_nil(style.shadow)
      assert is_nil(style.hovered)
      assert is_nil(style.pressed)
      assert is_nil(style.disabled)
      assert is_nil(style.focused)
    end
  end

  # -- Color builders ---------------------------------------------------------

  describe "background/2" do
    test "sets background color from a hex string" do
      style = StyleMap.new() |> StyleMap.background("#3366ff")
      assert style.background == "#3366ff"
    end

    test "casts named atom through Color.cast" do
      style = StyleMap.new() |> StyleMap.background(:red)
      assert style.background == Color.cast(:red)
      assert style.background == "#ff0000"
    end
  end

  describe "text_color/2" do
    test "sets text_color from a hex string" do
      style = StyleMap.new() |> StyleMap.text_color("#ffffff")
      assert style.text_color == "#ffffff"
    end

    test "casts named atom through Color.cast" do
      style = StyleMap.new() |> StyleMap.text_color(:blue)
      assert style.text_color == "#0000ff"
    end
  end

  # -- Struct builders --------------------------------------------------------

  describe "border/2" do
    test "sets the border struct" do
      border = Border.new() |> Border.color("#000000") |> Border.width(2) |> Border.rounded(4)
      style = StyleMap.new() |> StyleMap.border(border)

      assert %Border{color: "#000000", width: 2, radius: 4} = style.border
    end
  end

  describe "shadow/2" do
    test "sets the shadow struct" do
      shadow =
        Shadow.new() |> Shadow.color("#00000080") |> Shadow.offset(4, 4) |> Shadow.blur_radius(8)

      style = StyleMap.new() |> StyleMap.shadow(shadow)

      assert %Shadow{color: "#00000080", offset_x: 4, offset_y: 4, blur_radius: 8} = style.shadow
    end
  end

  # -- Status overrides -------------------------------------------------------

  describe "hovered/2" do
    test "accepts a map and normalizes color fields" do
      style = StyleMap.new() |> StyleMap.hovered(%{background: :red, text_color: "#ffffff"})

      assert style.hovered == %{background: "#ff0000", text_color: "#ffffff"}
    end

    test "accepts a keyword list and converts to a map" do
      style = StyleMap.new() |> StyleMap.hovered(background: "#cccccc")

      assert is_map(style.hovered)
      assert style.hovered == %{background: "#cccccc"}
    end
  end

  describe "pressed/2" do
    test "sets pressed override" do
      style = StyleMap.new() |> StyleMap.pressed(%{background: "#990000"})
      assert style.pressed == %{background: "#990000"}
    end
  end

  describe "disabled/2" do
    test "sets disabled override" do
      style = StyleMap.new() |> StyleMap.disabled(%{background: "#888888"})
      assert style.disabled == %{background: "#888888"}
    end
  end

  describe "focused/2" do
    test "sets focused override" do
      style = StyleMap.new() |> StyleMap.focused(%{background: "#0088ff"})
      assert style.focused == %{background: "#0088ff"}
    end
  end

  describe "status overrides cast colors" do
    test "named atom colors are normalized in override maps" do
      style = StyleMap.new() |> StyleMap.hovered(%{background: :white, text_color: :black})

      assert style.hovered.background == "#ffffff"
      assert style.hovered.text_color == "#000000"
    end
  end

  # -- Encode protocol --------------------------------------------------------

  describe "Encode protocol" do
    test "encodes a fully-populated style map to atom-keyed wire map" do
      border = Border.new() |> Border.color("#000000") |> Border.width(1) |> Border.rounded(4)

      shadow =
        Shadow.new() |> Shadow.color("#00000040") |> Shadow.offset(2, 2) |> Shadow.blur_radius(6)

      style =
        StyleMap.new()
        |> StyleMap.background(:red)
        |> StyleMap.text_color(:white)
        |> StyleMap.border(border)
        |> StyleMap.shadow(shadow)

      encoded = Encode.encode(style)

      assert encoded[:background] == "#ff0000"
      assert encoded[:text_color] == "#ffffff"
      assert is_map(encoded[:border])
      assert encoded[:border][:color] == "#000000"
      assert encoded[:border][:width] == 1
      assert encoded[:border][:radius] == 4
      assert is_map(encoded[:shadow])
      assert encoded[:shadow][:color] == "#00000040"
      assert encoded[:shadow][:offset] == [2, 2]
      assert encoded[:shadow][:blur_radius] == 6
    end

    test "omits nil fields from the wire map" do
      style = StyleMap.new() |> StyleMap.background("#336699")
      encoded = Encode.encode(style)

      assert encoded[:background] == "#336699"
      refute Map.has_key?(encoded, :text_color)
      refute Map.has_key?(encoded, :border)
      refute Map.has_key?(encoded, :shadow)
      refute Map.has_key?(encoded, :hovered)
      refute Map.has_key?(encoded, :pressed)
      refute Map.has_key?(encoded, :disabled)
      refute Map.has_key?(encoded, :focused)
    end

    test "includes status overrides as nested maps with atom keys" do
      style =
        StyleMap.new()
        |> StyleMap.hovered(%{background: "#aaaaaa"})
        |> StyleMap.pressed(%{background: "#555555", text_color: "#ffffff"})

      encoded = Encode.encode(style)

      assert encoded[:hovered][:background] == "#aaaaaa"
      assert encoded[:pressed][:background] == "#555555"
      assert encoded[:pressed][:text_color] == "#ffffff"
    end

    test "encodes border and shadow structs inside status overrides" do
      border = Border.new() |> Border.color("#ff0000") |> Border.width(2) |> Border.rounded(6)

      shadow =
        Shadow.new() |> Shadow.color("#00000080") |> Shadow.offset(1, 1) |> Shadow.blur_radius(4)

      style =
        StyleMap.new()
        |> StyleMap.focused(%{border: border, shadow: shadow})
        |> StyleMap.hovered(%{border: border})

      encoded = Encode.encode(style)

      assert is_map(encoded[:focused][:border])
      assert encoded[:focused][:border][:color] == "#ff0000"
      assert encoded[:focused][:border][:width] == 2
      assert encoded[:focused][:border][:radius] == 6
      assert encoded[:focused][:shadow][:color] == "#00000080"
      assert encoded[:focused][:shadow][:offset] == [1, 1]
      assert encoded[:focused][:shadow][:blur_radius] == 4
      assert encoded[:hovered][:border][:color] == "#ff0000"
    end

    test "full builder chain produces expected encoded output" do
      border = Border.new() |> Border.color("#333333") |> Border.width(2) |> Border.rounded(8)

      style =
        StyleMap.new()
        |> StyleMap.background("#ff6600")
        |> StyleMap.text_color(:white)
        |> StyleMap.border(border)
        |> StyleMap.hovered(background: "#ff8833")
        |> StyleMap.pressed(%{background: :red})
        |> StyleMap.disabled(background: "#cccccc", text_color: "#999999")

      encoded = Encode.encode(style)

      # Base properties
      assert encoded[:background] == "#ff6600"
      assert encoded[:text_color] == "#ffffff"

      # Border encoded to plain map
      assert is_map(encoded[:border])
      assert encoded[:border][:color] == "#333333"
      assert encoded[:border][:width] == 2
      assert encoded[:border][:radius] == 8

      # Status overrides
      assert encoded[:hovered][:background] == "#ff8833"
      assert encoded[:pressed][:background] == "#ff0000"
      assert encoded[:disabled][:background] == "#cccccc"
      assert encoded[:disabled][:text_color] == "#999999"

      # Not set
      refute Map.has_key?(encoded, :focused)
      refute Map.has_key?(encoded, :shadow)
    end
  end
end
