defmodule Julep.Tree do
  require Logger

  @moduledoc """
  Utilities for working with Julep UI trees.

  A UI tree is a plain map (or list of maps) with the shape:

      %{
        id: "unique-id",
        type: "button",
        props: %{"label" => "Click me"},
        children: [...]
      }

  This module provides normalization (ensuring the canonical shape),
  tree search by ID, and predicate-based search.

  Includes tree diffing that produces minimal patch operations.
  """

  @type tree_node :: %{
          required(:id) => String.t(),
          required(:type) => String.t(),
          required(:props) => %{String.t() => term()},
          required(:children) => [tree_node()]
        }

  @empty_container %{
    id: "root",
    type: "container",
    props: %{},
    children: []
  }

  @doc """
  Normalizes a UI tree into the canonical node shape.

  Accepts:
  - `nil` -- returns an empty root container
  - a single node map -- normalizes and returns it
  - a list of node maps -- for Phase 0, wraps in a root container
    (single-window; multi-window support is Phase 1)

  Every node is guaranteed to have `:id`, `:type`, `:props`, and
  `:children`. Props are normalized to string keys. Children are
  always a list, normalized recursively.
  """
  @spec normalize(tree :: nil | tree_node() | [tree_node()] | struct()) :: tree_node()
  def normalize(nil), do: @empty_container

  def normalize([]), do: @empty_container

  def normalize([single]), do: normalize(single)

  def normalize([_ | _] = nodes) do
    %{
      id: "root",
      type: "container",
      props: %{},
      children: Enum.map(nodes, &normalize/1)
    }
  end

  def normalize(%module{} = widget) when is_atom(module) do
    normalize(Julep.Iced.Widget.to_node(widget))
  end

  def normalize(%{} = node) do
    id = fetch_field(node, :id, "id") || "unknown_#{:erlang.unique_integer([:positive])}"
    type = fetch_field(node, :type, "type") || "container"
    props = fetch_field(node, :props, "props") || %{}
    children = fetch_field(node, :children, "children") || []

    %{
      id: to_string(id),
      type: to_string(type),
      props: stringify_keys(props),
      children: normalize_children(children)
    }
  end

  @doc """
  Finds the first node in a tree whose `:id` matches the given `id`.

  Returns the node map, or `nil` if not found. Searches depth-first.
  """
  @spec find(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find(%{id: id} = node, id), do: node

  def find(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, &find(&1, target_id))
  end

  def find(%{"id" => id} = node, id), do: node

  def find(%{"children" => children}, target_id) when is_list(children) do
    Enum.find_value(children, &find(&1, target_id))
  end

  def find(_node, _target_id), do: nil

  @doc "Returns true if a node with the given `id` exists in the tree."
  @spec exists?(tree :: map() | nil, id :: String.t()) :: boolean()
  def exists?(nil, _id), do: false

  def exists?(tree, id) do
    find(tree, id) != nil
  end

  @doc "Returns a flat list of all node IDs in the tree (depth-first order)."
  @spec ids(tree :: map() | nil) :: [String.t()]
  def ids(nil), do: []

  def ids(%{id: id, children: children}) do
    [id | Enum.flat_map(children, &ids/1)]
  end

  def ids(%{"id" => id, "children" => children}) do
    [id | Enum.flat_map(children, &ids/1)]
  end

  def ids(_), do: []

  @doc """
  Finds all nodes in a tree for which `fun` returns truthy.

  Walks the entire tree depth-first and accumulates all matches.
  """
  @spec find_all(node :: tree_node(), fun :: (tree_node() -> as_boolean(term()))) :: [tree_node()]
  def find_all(node, fun) do
    do_find_all(node, fun, [])
    |> Enum.reverse()
  end

  @doc """
  Compares two normalized trees and returns a list of patch operations.

  Patch operations:
    - `%{op: "replace_node", path: [int], node: map}` -- replace entire subtree
    - `%{op: "update_props", path: [int], props: map}` -- merge props at path
    - `%{op: "insert_child", path: [int], index: int, node: map}` -- insert child
    - `%{op: "remove_child", path: [int], index: int}` -- remove child at index

  Path is a list of child indices from the root. An empty path `[]` means the root node.
  """
  @spec diff(old_tree :: map() | nil, new_tree :: map() | nil) :: [map()]
  def diff(nil, nil), do: []
  def diff(nil, new_tree), do: [%{op: "replace_node", path: [], node: new_tree}]
  def diff(_old_tree, nil), do: [%{op: "remove_child", path: [], index: 0}]

  def diff(%{id: old_id} = _old_tree, %{id: new_id} = new_tree) when old_id != new_id do
    [%{op: "replace_node", path: [], node: new_tree}]
  end

  def diff(%{} = old_tree, %{} = new_tree) do
    diff_node(old_tree, new_tree, [])
  end

  defp diff_node(old, new, path) do
    cond do
      old.type != new.type ->
        [%{op: "replace_node", path: path, node: new}]

      children_reordered?(old.children, new.children) ->
        [%{op: "replace_node", path: path, node: new}]

      true ->
        prop_ops = diff_props(old.props, new.props, path)
        child_ops = diff_children(old.children, new.children, path)
        prop_ops ++ child_ops
    end
  end

  defp diff_props(old_props, new_props, _path) when old_props == new_props, do: []

  defp diff_props(old_props, new_props, path) do
    changed =
      new_props
      |> Enum.reduce(%{}, fn {k, v}, acc ->
        case Map.fetch(old_props, k) do
          {:ok, ^v} -> acc
          _ -> Map.put(acc, k, v)
        end
      end)

    # Keys removed in new -- set to nil so the renderer can clear them
    removed =
      old_props
      |> Enum.reduce(%{}, fn {k, _v}, acc ->
        if Map.has_key?(new_props, k), do: acc, else: Map.put(acc, k, nil)
      end)

    merged = Map.merge(changed, removed)

    if map_size(merged) == 0 do
      []
    else
      [%{op: "update_props", path: path, props: merged}]
    end
  end

  defp diff_children(old_children, new_children, path) do
    new_ids = Enum.map(new_children, & &1.id)

    if length(new_ids) != MapSet.size(MapSet.new(new_ids)) do
      Logger.warning("julep tree: duplicate child IDs detected: #{inspect(new_ids)}")
    end

    old_by_id = old_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)
    new_by_id = new_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)

    # Removals: old IDs not present in new, highest index first
    removed_indices =
      old_by_id
      |> Enum.reject(fn {id, _} -> Map.has_key?(new_by_id, id) end)
      |> Enum.map(fn {_, {_, idx}} -> idx end)

    remove_ops =
      removed_indices
      |> Enum.sort(:desc)
      |> Enum.map(fn idx -> %{op: "remove_child", path: path, index: idx} end)

    # Walk new children for updates and inserts
    {update_ops, insert_ops} =
      new_children
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {child, idx}, {updates, inserts} ->
        case Map.fetch(old_by_id, child.id) do
          {:ok, {old_child, old_idx}} ->
            child_path = path ++ [index_after_removals(old_idx, removed_indices)]
            ops = diff_node(old_child, child, child_path)
            {updates ++ ops, inserts}

          :error ->
            insert = %{op: "insert_child", path: path, index: idx, node: child}
            {updates, inserts ++ [insert]}
        end
      end)

    # Ordering is load-bearing: removals descending (highest index first to
    # avoid index shift), then updates (on adjusted indices), then inserts
    # ascending (lowest index first to build correctly).
    remove_ops ++ update_ops ++ insert_ops
  end

  defp children_reordered?(old_children, new_children) do
    old_ids = Enum.map(old_children, & &1.id)
    new_ids = Enum.map(new_children, & &1.id)

    old_set = MapSet.new(old_ids)
    new_set = MapSet.new(new_ids)

    common_old = Enum.filter(old_ids, &MapSet.member?(new_set, &1))
    common_new = Enum.filter(new_ids, &MapSet.member?(old_set, &1))

    common_old != common_new
  end

  defp index_after_removals(old_idx, removed_indices) do
    old_idx - Enum.count(removed_indices, &(&1 < old_idx))
  end

  @doc """
  Converts atom keys in a map to string keys.

  Recursively stringifies nested map values. Does NOT recurse into
  lists (child nodes are not prop values and must not be treated as such).
  """
  @spec stringify_keys(map :: map()) :: %{String.t() => term()}
  def stringify_keys(%{} = map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), stringify_value(v)}
      {k, v} when is_binary(k) -> {k, stringify_value(v)}
      {k, v} -> {inspect(k), stringify_value(v)}
    end)
  end

  # Private

  defp normalize_children(children) when is_list(children) do
    Enum.map(children, &normalize/1)
  end

  defp normalize_children(_), do: []

  defp do_find_all(%{children: children} = node, fun, acc) do
    acc = if fun.(node), do: [node | acc], else: acc
    Enum.reduce(children, acc, &do_find_all(&1, fun, &2))
  end

  defp do_find_all(node, fun, acc) do
    if fun.(node), do: [node | acc], else: acc
  end

  # Structs must be encoded before key stringification -- otherwise they
  # match the bare map clause and get destructured into raw struct fields.
  defp stringify_value(%_{} = v), do: Julep.Iced.Encode.encode(v)

  # Recurse into nested maps for stringify_keys, but not lists.
  # Lists in props are treated as scalar sequences (e.g. color tuples, ranges),
  # not as child node collections.
  defp stringify_value(%{} = v), do: stringify_keys(v)

  defp stringify_value(list) when is_list(list) do
    Enum.map(list, &stringify_value/1)
  end

  defp stringify_value(v), do: v

  # Fetches a field by atom key first, then string key, returning nil if absent.
  defp fetch_field(map, atom_key, string_key) do
    case map do
      %{^atom_key => v} -> v
      %{^string_key => v} -> v
      _ -> nil
    end
  end
end
