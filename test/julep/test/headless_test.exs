defmodule Julep.Test.HeadlessTest do
  @moduledoc """
  Tests for the Headless test backend.

  Requires `cargo build --features headless`.
  Enabled by setting JULEP_HEADLESS=1 or JULEP_TEST_BACKEND=headless.
  """

  use ExUnit.Case, async: false

  @moduletag :headless

  # Skip unless headless binary is available (opt-in via env var).
  unless System.get_env("JULEP_HEADLESS") || System.get_env("JULEP_TEST_BACKEND") == "headless" do
    @moduletag :skip
  end

  # These tests are run via the standard test suite with JULEP_TEST_BACKEND=headless.
  # The headless backend implements the same Backend behaviour as Sim, so the
  # entire test suite (examples, widget tests, etc.) runs against it unchanged.
  #
  # This file exists as a marker. Individual headless-specific tests can be
  # added here if needed.

  test "placeholder - headless backend starts" do
    # Covered by running the full suite with JULEP_TEST_BACKEND=headless
  end
end
