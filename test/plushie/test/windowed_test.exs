defmodule Plushie.Test.WindowedTest do
  use ExUnit.Case, async: false

  @moduletag :windowed

  # Skip unless windowed backend is available (opt-in via env var).
  unless System.get_env("PLUSHIE_WINDOWED") || System.get_env("PLUSHIE_TEST_BACKEND") == "windowed" do
    @moduletag :skip
  end

  # These tests require Xvfb and `cargo build`.
  # Enabled by setting PLUSHIE_WINDOWED=1 or PLUSHIE_TEST_BACKEND=windowed.

  test "placeholder - windowed backend starts" do
    # Will be implemented when test-mode Rust mode is complete
  end
end
