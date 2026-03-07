defmodule Julep.Test.FullTest do
  use ExUnit.Case, async: false

  @moduletag :full

  # Skip unless full backend is available (opt-in via env var).
  unless System.get_env("JULEP_FULL") || System.get_env("JULEP_TEST_BACKEND") == "full" do
    @moduletag :skip
  end

  # These tests require Xvfb and `cargo build --features test-mode`.
  # Enabled by setting JULEP_FULL=1 or JULEP_TEST_BACKEND=full.

  test "placeholder - full backend starts" do
    # Will be implemented when test-mode Rust mode is complete
  end
end
