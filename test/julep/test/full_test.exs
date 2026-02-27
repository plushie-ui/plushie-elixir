defmodule Julep.Test.FullTest do
  use ExUnit.Case, async: false

  @moduletag :full
  @moduletag :skip

  # These tests require Xvfb and `cargo build --features test-mode`.
  # Run with: mix test --include full

  test "placeholder - full backend starts" do
    # Will be implemented when test-mode Rust mode is complete
  end
end
