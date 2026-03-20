defmodule Toddy.Type.ColorTest do
  use ExUnit.Case, async: true

  alias Toddy.Type.Color

  doctest Toddy.Type.Color

  describe "from_rgb/3" do
    test "converts 0-255 RGB to hex string" do
      assert Color.from_rgb(255, 0, 0) == "#ff0000"
    end

    test "converts mid-range values" do
      assert Color.from_rgb(128, 64, 32) == "#804020"
    end

    test "converts all zeros to black" do
      assert Color.from_rgb(0, 0, 0) == "#000000"
    end

    test "converts all 255 to white" do
      assert Color.from_rgb(255, 255, 255) == "#ffffff"
    end
  end

  describe "from_rgba/4" do
    test "converts 0-255 RGB with full alpha" do
      assert Color.from_rgba(255, 0, 0, 1.0) == "#ff0000ff"
    end

    test "converts with half alpha" do
      # 0.5 * 255 = 127.5, rounds to 128 = 0x80
      assert Color.from_rgba(255, 0, 0, 0.5) == "#ff000080"
    end

    test "zero alpha is fully transparent" do
      assert Color.from_rgba(100, 100, 100, 0.0) == "#64646400"
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

    test "downcases uppercase hex" do
      assert Color.from_hex("#FF0000") == "#ff0000"
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
    test "returns fully transparent black hex string" do
      assert Color.transparent() == "#00000000"
    end
  end

  describe "cast/1" do
    test "casts named atom :black" do
      assert Color.cast(:black) == "#000000"
    end

    test "casts named atom :white" do
      assert Color.cast(:white) == "#ffffff"
    end

    test "casts named atom :transparent" do
      assert Color.cast(:transparent) == "#00000000"
    end

    test "casts named atom :red" do
      assert Color.cast(:red) == "#ff0000"
    end

    test "casts :gray and :grey to same value" do
      assert Color.cast(:gray) == Color.cast(:grey)
      assert Color.cast(:gray) == "#808080"
    end

    test "casts hex string passthrough" do
      assert Color.cast("#ff0000") == "#ff0000"
    end

    test "casts uppercase hex string with downcase" do
      assert Color.cast("#FF0000") == "#ff0000"
    end

    test "raises on unknown atom" do
      assert_raise ArgumentError, ~r/unknown color name/, fn ->
        Color.cast(:nonexistent_color)
      end
    end
  end

  describe "encode/1" do
    test "passes through hex strings unchanged" do
      assert Color.encode("#ff0000") == "#ff0000"
    end
  end
end
