defmodule Plushie.Test.WindowedTest do
  @moduledoc """
  Tests for the Windowed test backend.

  These tests only run when PLUSHIE_TEST_BACKEND=windowed.
  Requires a display server (headless weston or similar).
  """

  use ExUnit.Case, async: false

  @moduletag backend: :windowed

  test "placeholder - windowed backend starts" do
    assert Application.get_env(:plushie, :test_backend) == :windowed
  end
end
