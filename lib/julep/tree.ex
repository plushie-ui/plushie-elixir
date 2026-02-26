defmodule Julep.Tree do
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

  No diffing here -- that's Phase 1.
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
  @spec normalize(nil | tree_node() | [tree_node()]) :: tree_node()
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

  def normalize(%{} = node) do
    id = fetch_field(node, :id, "id") || "unknown"
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
  @spec find(tree_node(), String.t()) :: tree_node() | nil
  def find(%{id: id} = node, id), do: node

  def find(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, &find(&1, target_id))
  end

  def find(_node, _target_id), do: nil

  @doc """
  Finds all nodes in a tree for which `fun` returns truthy.

  Walks the entire tree depth-first and accumulates all matches.
  """
  @spec find_all(tree_node(), (tree_node() -> as_boolean(term()))) :: [tree_node()]
  def find_all(node, fun) do
    do_find_all(node, fun, [])
    |> Enum.reverse()
  end

  @doc """
  Converts atom keys in a map to string keys.

  Recursively stringifies nested map values. Does NOT recurse into
  lists (child nodes are not prop values and must not be treated as such).
  """
  @spec stringify_keys(map()) :: %{String.t() => term()}
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

  # Recurse into nested maps for stringify_keys, but not lists.
  # Lists in props are treated as scalar sequences (e.g. color tuples, ranges),
  # not as child node collections.
  defp stringify_value(%{} = v), do: stringify_keys(v)
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
