defmodule Toddy.Test.ScreenshotTest do
  use ExUnit.Case, async: true

  alias Toddy.Test.Screenshot

  describe "save_png/2" do
    test "writes valid PNG for known RGBA data" do
      # 2x2 red square (RGBA: 255,0,0,255 for each pixel)
      rgba = <<255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255>>
      s = %Screenshot{name: "red-square", hash: "abc", size: {2, 2}, rgba_data: rgba}

      path =
        Path.join(
          System.tmp_dir!(),
          "test_red_square_#{System.unique_integer([:positive])}.png"
        )

      on_exit(fn -> File.rm(path) end)

      assert :ok = Screenshot.save_png(s, path)
      assert File.exists?(path)

      # Verify PNG magic bytes
      contents = File.read!(path)
      assert <<137, 80, 78, 71, 13, 10, 26, 10, _rest::binary>> = contents

      # Verify IHDR dimensions
      <<_sig::binary-size(8), _len::32, "IHDR", w::32, h::32, _rest2::binary>> = contents
      assert w == 2
      assert h == 2
    end

    test "writes valid PNG for 1x1 pixel" do
      rgba = <<0, 255, 0, 128>>
      s = %Screenshot{name: "green-pixel", hash: "def", size: {1, 1}, rgba_data: rgba}

      path =
        Path.join(
          System.tmp_dir!(),
          "test_green_pixel_#{System.unique_integer([:positive])}.png"
        )

      on_exit(fn -> File.rm(path) end)

      assert :ok = Screenshot.save_png(s, path)
      assert File.exists?(path)

      contents = File.read!(path)
      # PNG signature present
      assert <<137, 80, 78, 71, 13, 10, 26, 10, _::binary>> = contents

      # IHDR shows 1x1
      <<_sig::binary-size(8), _len::32, "IHDR", 1::32, 1::32, _::binary>> = contents
    end

    test "no-op when rgba_data is nil" do
      s = %Screenshot{name: "empty", hash: "", size: {0, 0}, rgba_data: nil}

      path =
        Path.join(System.tmp_dir!(), "should_not_exist_#{System.unique_integer([:positive])}.png")

      assert :ok = Screenshot.save_png(s, path)
      refute File.exists?(path)
    end
  end

  describe "assert_match/2" do
    test "with empty hash is a no-op" do
      screenshot = %Screenshot{hash: "", name: "test", size: {0, 0}, rgba_data: nil}
      golden_dir = "/tmp/toddy_screenshot_noop_#{System.unique_integer([:positive])}"

      assert :ok = Screenshot.assert_match(screenshot, golden_dir)

      # No golden file should have been created
      refute File.exists?(golden_dir)
    end

    test "with non-empty hash creates and checks golden file" do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "toddy_screenshot_test_#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      hash_a = "deadbeef1234567890abcdef"
      hash_b = "cafebabe0987654321fedcba"

      screenshot_a = %Screenshot{hash: hash_a, name: "shot", size: {100, 100}, rgba_data: nil}
      screenshot_b = %Screenshot{hash: hash_b, name: "shot", size: {100, 100}, rgba_data: nil}
      golden_path = Path.join(tmp_dir, "shot.sha256")

      # First call creates the golden file
      assert :ok = Screenshot.assert_match(screenshot_a, tmp_dir)
      assert File.exists?(golden_path)
      assert File.read!(golden_path) == hash_a

      # Same hash passes
      assert :ok = Screenshot.assert_match(screenshot_a, tmp_dir)

      # Different hash raises
      assert_raise ExUnit.AssertionError, ~r/Screenshot mismatch/, fn ->
        Screenshot.assert_match(screenshot_b, tmp_dir)
      end
    end
  end
end
