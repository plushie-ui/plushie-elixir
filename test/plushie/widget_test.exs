defmodule Plushie.WidgetTest do
  use ExUnit.Case, async: true

  defmodule MockNativeWidget do
    @behaviour Plushie.Widget

    @impl true
    def native_crate, do: "native/mock_ext"

    @impl true
    def rust_constructor, do: "mock_ext::MockExt::new()"

    @impl true
    def type_names, do: [:mock_widget]
  end

  defmodule ConflictWidget do
    @behaviour Plushie.Widget

    @impl true
    def native_crate, do: "native/conflict_ext"

    @impl true
    def rust_constructor, do: "conflict_ext::ConflictExt::new()"

    @impl true
    def type_names, do: [:mock_widget]
  end

  # Collision checks used to live in Mix.Tasks.Plushie.Build. They now
  # live in cargo-plushie, which runs them during `cargo plushie build`
  # using the widget metadata tables in each crate's Cargo.toml. The
  # reference widget modules above stay because they exercise the
  # Plushie.Widget behaviour + registry discovery below.

  test "widget registry discovers widgets via protocol" do
    widgets = Plushie.WidgetRegistry.all_widgets()
    assert is_list(widgets)
    assert widgets != []
  end

  describe "WidgetRegistry" do
    test "native_widgets/0 returns only modules with native_crate/0" do
      natives = Plushie.WidgetRegistry.native_widgets()

      for mod <- natives do
        assert function_exported?(mod, :native_crate, 0),
               "#{inspect(mod)} is in native_widgets/0 but does not export native_crate/0"
      end
    end

    test "invalidate/0 clears the cache and all_widgets still works" do
      # Warm the cache
      first = Plushie.WidgetRegistry.all_widgets()
      assert is_list(first)

      # Invalidate
      assert :ok = Plushie.WidgetRegistry.invalidate()

      # Re-discover
      second = Plushie.WidgetRegistry.all_widgets()
      assert is_list(second)
      assert second != []
    end
  end
end
