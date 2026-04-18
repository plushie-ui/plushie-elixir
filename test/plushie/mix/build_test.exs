defmodule Mix.Tasks.Plushie.BuildTest do
  use ExUnit.Case, async: true

  # The build task delegates workspace generation and widget discovery
  # to cargo-plushie. The collision checks, main.rs generation, and
  # Cargo.lock shepherding that used to live here are now covered by
  # cargo-plushie's own test suite in plushie-rust.
  #
  # What remains in this SDK: discovering widget modules through the
  # Plushie.Widget protocol, resolving their crate paths, and writing
  # a small "spec" Cargo.toml that cargo-plushie inspects via
  # cargo metadata. Integration coverage for the full build lives
  # behind `mix preflight`, which exercises the task through the real
  # plushie-rust source checkout.

  describe "mix task module" do
    test "is loadable" do
      assert Code.ensure_loaded?(Mix.Tasks.Plushie.Build)
    end

    test "is registered as a Mix task" do
      assert Mix.Task.task_name(Mix.Tasks.Plushie.Build) == "plushie.build"
      assert Mix.Task.moduledoc(Mix.Tasks.Plushie.Build) =~ "cargo-plushie"
    end
  end
end
