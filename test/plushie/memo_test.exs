defmodule Plushie.MemoTest do
  use ExUnit.Case, async: true

  alias Plushie.Tree

  describe "memo normalize" do
    test "cache miss evaluates the body" do
      tree =
        memo_tree(:v1, fn ->
          [%{id: "child", type: "text", props: %{content: "hello"}, children: []}]
        end)

      result = normalize_in_window(tree)
      child = hd(result.children)
      assert child.type == "text"
      assert child.props.content == "hello"
    end

    test "cache hit returns same reference on second normalize" do
      body_fn = fn ->
        [%{id: "child", type: "text", props: %{content: "hello"}, children: []}]
      end

      tree = memo_tree(:v1, body_fn)

      # First normalize (miss)
      first = normalize_with_memo(tree)
      memo_cache = Tree.take_memo_cache()
      assert map_size(memo_cache) == 1

      # Second normalize with same deps (hit)
      Tree.set_memo_prev_cache(memo_cache)
      tree2 = memo_tree(:v1, body_fn)
      second = normalize_with_memo(tree2)
      _cache2 = Tree.take_memo_cache()

      # The memo node itself should be reference-equal from cache
      first_memo_child = hd(first.children)
      second_memo_child = hd(second.children)
      assert first_memo_child === second_memo_child
    end

    test "deps change triggers re-evaluation" do
      body_v1 = fn ->
        [%{id: "child", type: "text", props: %{content: "v1"}, children: []}]
      end

      body_v2 = fn ->
        [%{id: "child", type: "text", props: %{content: "v2"}, children: []}]
      end

      tree1 = memo_tree(:v1, body_v1)
      _first = normalize_with_memo(tree1)
      cache1 = Tree.take_memo_cache()

      Tree.set_memo_prev_cache(cache1)
      tree2 = memo_tree(:v2, body_v2)
      second = normalize_with_memo(tree2)
      _cache2 = Tree.take_memo_cache()

      child = hd(second.children)
      assert child.props.content == "v2"
    end

    test "empty memo body returns empty container" do
      tree = memo_tree(:v1, fn -> [] end)
      result = normalize_in_window(tree)
      memo_child = hd(result.children)
      assert memo_child.type == "container"
      assert memo_child.children == []
    end

    test "multiple children in memo body are wrapped in container" do
      tree =
        memo_tree(:v1, fn ->
          [
            %{id: "a", type: "text", props: %{}, children: []},
            %{id: "b", type: "text", props: %{}, children: []}
          ]
        end)

      result = normalize_in_window(tree)
      memo_child = hd(result.children)
      assert memo_child.type == "container"
      assert length(memo_child.children) == 2
    end

    test "nested memos work independently" do
      inner_body = fn ->
        [%{id: "inner_child", type: "text", props: %{content: "inner"}, children: []}]
      end

      outer_body = fn ->
        [memo_node("auto:memo:inner:1", :inner_deps, inner_body)]
      end

      tree = memo_tree(:outer_deps, outer_body)
      _first = normalize_with_memo(tree)
      cache = Tree.take_memo_cache()

      # Both inner and outer should be cached
      assert map_size(cache) == 2
    end

    test "telemetry events are emitted on hit and miss" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "memo-miss-#{inspect(ref)}",
        [:plushie, :memo, :miss],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:memo_miss, metadata})
        end,
        nil
      )

      :telemetry.attach(
        "memo-hit-#{inspect(ref)}",
        [:plushie, :memo, :hit],
        fn _event, _measurements, metadata, _config ->
          send(test_pid, {:memo_hit, metadata})
        end,
        nil
      )

      body = fn ->
        [%{id: "child", type: "text", props: %{}, children: []}]
      end

      # First pass: miss
      tree = memo_tree(:v1, body)
      _first = normalize_with_memo(tree)
      cache = Tree.take_memo_cache()
      assert_receive {:memo_miss, %{id: "auto:memo:test:1"}}

      # Second pass: hit
      Tree.set_memo_prev_cache(cache)
      tree2 = memo_tree(:v1, body)
      _second = normalize_with_memo(tree2)
      Tree.take_memo_cache()
      assert_receive {:memo_hit, %{id: "auto:memo:test:1"}}

      :telemetry.detach("memo-miss-#{inspect(ref)}")
      :telemetry.detach("memo-hit-#{inspect(ref)}")
    end

    test "old cache entries are naturally pruned" do
      body = fn ->
        [%{id: "child", type: "text", props: %{}, children: []}]
      end

      # First render with memo
      tree = memo_tree(:v1, body)
      _first = normalize_with_memo(tree)
      cache1 = Tree.take_memo_cache()
      assert map_size(cache1) == 1

      # Second render WITHOUT memo (simulating the memo being removed)
      Tree.set_memo_prev_cache(cache1)

      plain_tree = %{
        id: "main",
        type: "window",
        props: %{},
        children: [%{id: "other", type: "text", props: %{}, children: []}]
      }

      Tree.normalize(plain_tree, %{})
      cache2 = Tree.take_memo_cache()
      # Old memo entry should be gone (not written to new cache)
      assert map_size(cache2) == 0
    end
  end

  # Helpers

  defp memo_node(id, deps, body_fn) do
    %{
      type: "__memo__",
      id: id,
      props: %{},
      children: [],
      meta: %{
        __memo_deps__: deps,
        __memo_fun__: body_fn
      }
    }
  end

  defp memo_tree(deps, body_fn) do
    %{
      id: "main",
      type: "window",
      props: %{},
      children: [
        memo_node("auto:memo:test:1", deps, body_fn)
      ]
    }
  end

  defp normalize_in_window(tree) do
    Tree.normalize(tree, %{})
  end

  defp normalize_with_memo(tree) do
    Tree.normalize(tree, %{})
  end
end
