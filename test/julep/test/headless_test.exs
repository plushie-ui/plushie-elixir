defmodule Julep.Test.HeadlessTest do
  @moduledoc """
  Tests for the Headless test backend.

  Requires `cargo build --features headless`.
  Run with: JULEP_TEST_BACKEND=headless mix test
  """

  use ExUnit.Case, async: false

  @moduletag :headless
  @moduletag :skip

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
