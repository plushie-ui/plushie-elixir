defmodule Plushie.Test.HeadlessTest do
  @moduledoc """
  Tests for the Headless test backend.

  These tests only run when PLUSHIE_TEST_BACKEND=headless or windowed.
  """

  use ExUnit.Case, async: false

  @moduletag backend: :headless

  test "placeholder - headless backend starts" do
    # Covered by running the full suite with PLUSHIE_TEST_BACKEND=headless
    assert Application.get_env(:plushie, :test_backend) in [:headless, :windowed]
  end
end
