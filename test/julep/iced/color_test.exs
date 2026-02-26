defmodule Julep.Iced.ColorTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Color

  describe "from_rgb/3" do
    test "converts 0-255 RGB to normalized RGBA map" do
      assert Color.from_rgb(255, 0, 0) == %{r: 1.0, g: 0.0, b: 0.0, a: 1.0}
    end

    test "converts mid-range values" do
      result = Color.from_rgb(128, 64, 32)
      assert_in_delta result.r, 128 / 255, 0.001
      assert_in_delta result.g, 64 / 255, 0.001
      assert_in_delta result.b, 32 / 255, 0.001
      assert result.a == 1.0
    end

    test "converts all zeros to black with full alpha" do
      assert Color.from_rgb(0, 0, 0) == %{r: 0.0, g: 0.0, b: 0.0, a: 1.0}
    end

    test "converts all 255 to white with full alpha" do
      assert Color.from_rgb(255, 255, 255) == %{r: 1.0, g: 1.0, b: 1.0, a: 1.0}
    end
  end

  describe "from_rgba/4" do
    test "converts 0-255 RGB with alpha" do
      assert Color.from_rgba(255, 0, 0, 0.5) == %{r: 1.0, g: 0.0, b: 0.0, a: 0.5}
    end

    test "alpha of 0.0 is fully transparent" do
      result = Color.from_rgba(100, 100, 100, 0.0)
      assert result.a == 0.0
    end

    test "alpha of 1.0 is fully opaque" do
      result = Color.from_rgba(100, 100, 100, 1.0)
      assert result.a == 1.0
    end
  end

  describe "from_hex/1" do
    test "prepends # to 6-character hex string" do
      assert Color.from_hex("ff0000") == "#ff0000"
    end

    test "handles 8-character hex string (with alpha)" do
      assert Color.from_hex("ff000080") == "#ff000080"
    end

    test "strips leading # if already present" do
      assert Color.from_hex("#abcdef") == "#abcdef"
    end

    test "passes through lowercase hex" do
      assert Color.from_hex("aabbcc") == "#aabbcc"
    end
  end

  describe "black/0" do
    test "returns black hex string" do
      assert Color.black() == "#000000"
    end
  end

  describe "white/0" do
    test "returns white hex string" do
      assert Color.white() == "#ffffff"
    end
  end

  describe "transparent/0" do
    test "returns fully transparent black RGBA map" do
      assert Color.transparent() == %{r: 0.0, g: 0.0, b: 0.0, a: 0.0}
    end
  end

  describe "encode/1" do
    test "passes through hex strings unchanged" do
      assert Color.encode("#ff0000") == "#ff0000"
    end

    test "passes through RGBA maps unchanged" do
      color = %{r: 1.0, g: 0.0, b: 0.0, a: 1.0}
      assert Color.encode(color) == color
    end

    test "adds default alpha to RGB-only map" do
      assert Color.encode(%{r: 1.0, g: 0.0, b: 0.0}) == %{r: 1.0, g: 0.0, b: 0.0, a: 1.0}
    end
  end
end
