defmodule Julep.Test.HeadlessTest do
  use ExUnit.Case, async: false

  @moduletag :headless
  @moduletag :skip

  # These tests require `cargo build --features headless`.
  # Run with: mix test --include headless

  test "placeholder - headless backend starts" do
    # Will be implemented when headless Rust mode is complete
  end
end
