defmodule Plushie.WidgetCacheKeyTest do
  use ExUnit.Case, async: true

  alias Plushie.Tree

  # ---------------------------------------------------------------------------
  # Test widgets
  # ---------------------------------------------------------------------------

  defmodule CachedWidget do
    use Plushie.Widget

    widget :cached_thing

    field :data_version, :integer, default: 0
    field :label, :string, default: "default"

    state do
      field :zoom, :float, default: 1.0
    end

    cache_key(fn props, state ->
      {props.data_version, state.zoom}
    end)

    @impl true
    def view(id, props, _state) do
      %{id: id, type: "text", props: %{content: props.label}, children: []}
    end
  end

  defmodule UncachedWidget do
    use Plushie.Widget

    widget :uncached_thing

    field :label, :string, default: "hello"

    state do
      field :count, :integer, default: 0
    end

    @impl true
    def view(id, props, _state) do
      %{id: id, type: "text", props: %{content: props.label}, children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "cache_key macro" do
    test "generates __cache_key__/2 on the module" do
      assert function_exported?(CachedWidget, :__cache_key__, 2)
    end

    test "does not generate __cache_key__/2 when not declared" do
      refute function_exported?(UncachedWidget, :__cache_key__, 2)
    end

    test "__cache_key__/2 returns the expected key" do
      props = %{data_version: 42}
      state = %{zoom: 2.5}
      assert CachedWidget.__cache_key__(props, state) == {42, 2.5}
    end
  end

  describe "widget view cache in normalize" do
    test "cache miss renders the widget" do
      tree = widget_tree(CachedWidget, "w1", data_version: 1, label: "first")
      result = normalize_in_window(tree)
      child = hd(result.children)
      assert child.props.content == "first"
    end

    test "cache hit returns same reference on second normalize" do
      tree1 = widget_tree(CachedWidget, "w1", data_version: 1, label: "first")

      {first, wvc} = normalize_with_widget_cache(tree1)
      assert map_size(wvc) == 1

      # Second normalize with same cache_key
      tree2 = widget_tree(CachedWidget, "w1", data_version: 1, label: "first")
      {second, _wvc2} = normalize_with_widget_cache(tree2, wvc)

      # The rendered content node should be reference-equal from cache.
      # We compare the text child (not the top-level window).
      first_child = hd(first.children)
      second_child = hd(second.children)

      # The meta may differ (widget state refresh), but the rendered
      # content props should be the same reference.
      assert first_child.props === second_child.props
    end

    test "cache_key change triggers re-render" do
      tree1 = widget_tree(CachedWidget, "w1", data_version: 1, label: "v1")
      {_first, wvc} = normalize_with_widget_cache(tree1)

      tree2 = widget_tree(CachedWidget, "w1", data_version: 2, label: "v2")
      {second, _wvc2} = normalize_with_widget_cache(tree2, wvc)

      child = hd(second.children)
      assert child.props.content == "v2"
    end

    test "widget without cache_key always re-renders" do
      tree1 = widget_tree(UncachedWidget, "w1", label: "hello")
      {_first, wvc} = normalize_with_widget_cache(tree1)

      # No entries for uncached widget
      assert map_size(wvc) == 0
    end

    test "old cache entries are naturally pruned" do
      tree1 = widget_tree(CachedWidget, "w1", data_version: 1, label: "v1")
      {_first, wvc} = normalize_with_widget_cache(tree1)
      assert map_size(wvc) == 1

      # Second render without the widget (simulating removal)
      plain_tree = %{
        id: "main",
        type: "window",
        props: %{},
        children: [%{id: "other", type: "text", props: %{}, children: []}]
      }

      {_result, wvc2} = normalize_with_widget_cache(plain_tree, wvc)
      assert map_size(wvc2) == 0
    end
  end

  describe "telemetry" do
    test "emits hit and miss events" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "wvc-miss-#{inspect(ref)}",
        [:plushie, :widget_cache, :miss],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:wvc_miss, metadata})
        end,
        nil
      )

      :telemetry.attach(
        "wvc-hit-#{inspect(ref)}",
        [:plushie, :widget_cache, :hit],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:wvc_hit, metadata})
        end,
        nil
      )

      # First pass: miss
      tree1 = widget_tree(CachedWidget, "w1", data_version: 1, label: "v1")
      {_first, wvc} = normalize_with_widget_cache(tree1)
      assert_receive {:wvc_miss, %{id: "w1", module: CachedWidget}}

      # Second pass: hit
      tree2 = widget_tree(CachedWidget, "w1", data_version: 1, label: "v1")
      normalize_with_widget_cache(tree2, wvc)
      assert_receive {:wvc_hit, %{id: "w1", module: CachedWidget}}

      :telemetry.detach("wvc-miss-#{inspect(ref)}")
      :telemetry.detach("wvc-hit-#{inspect(ref)}")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp widget_tree(module, id, opts) do
    widget = module.new(id, opts)
    node = Plushie.Widget.to_node(widget)

    %{
      id: "main",
      type: "window",
      props: %{},
      children: [node]
    }
  end

  defp normalize_in_window(tree) do
    Tree.normalize(tree, %{})
  end

  defp normalize_with_widget_cache(tree, widget_view_prev \\ %{}) do
    ctx = %Plushie.Tree.NormalizeCtx{
      scope: "",
      window_id: nil,
      widget_view_prev: widget_view_prev
    }

    {result, _memo, widget_view} = Tree.normalize_with_caches(tree, ctx)
    {result, widget_view}
  end
end
