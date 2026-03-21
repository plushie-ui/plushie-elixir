defmodule Plushie.ExtensionTest do
  use ExUnit.Case, async: true

  defmodule MockExtension do
    @behaviour Plushie.Extension

    @impl true
    def native_crate, do: "native/mock_ext"

    @impl true
    def rust_constructor, do: "mock_ext::MockExt::new()"

    @impl true
    def type_names, do: [:mock_widget]
  end

  defmodule ConflictExtension do
    @behaviour Plushie.Extension

    @impl true
    def native_crate, do: "native/conflict_ext"

    @impl true
    def rust_constructor, do: "conflict_ext::ConflictExt::new()"

    @impl true
    def type_names, do: [:mock_widget]
  end

  test "configured_extensions reads from application config" do
    extensions = Mix.Tasks.Plushie.Build.configured_extensions()
    assert is_list(extensions)
  end

  test "check_collisions! raises on duplicate type names" do
    assert_raise Mix.Error, ~r/collision/i, fn ->
      Mix.Tasks.Plushie.Build.check_collisions!([MockExtension, ConflictExtension])
    end
  end

  test "check_collisions! passes with no duplicates" do
    assert :ok == Mix.Tasks.Plushie.Build.check_collisions!([MockExtension])
  end
end
