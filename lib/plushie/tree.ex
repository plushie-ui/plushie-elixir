defmodule Plushie.Tree do
  require Logger

  @moduledoc """
  Utilities for working with Plushie UI trees.

  A UI tree is a plain map (or list of maps) with the shape:

      %{
        id: "unique-id",
        type: "button",
        props: %{label: "Click me"},
        children: [...]
      }

  This module provides normalization (ensuring the canonical shape),
  tree search (by ID and by predicate), and diffing that produces
  minimal patch operations for incremental renderer updates.
  """

  @type tree_node :: %{
          required(:id) => String.t(),
          required(:type) => String.t(),
          required(:props) => %{atom() => term()},
          required(:children) => [tree_node()]
        }

  @empty_container %{
    id: "root",
    type: "container",
    props: %{},
    children: []
  }

  # Props with these keys are runtime metadata, not wire props.
  # They're extracted into a separate :meta field during normalization
  # and never sent to the renderer.
  @runtime_meta_keys [
    :__canvas_widget__,
    :__canvas_widget_props__,
    :__canvas_widget_state__,
    :__extension_widget_type__,
    :__extension_widget_events__
  ]

  @doc """
  Normalizes a UI tree into the canonical node shape.

  Accepts:
  - `nil` -- returns an empty root container
  - a single node map -- normalizes and returns it
  - a list of node maps -- for Phase 0, wraps in a root container
    (single-window; multi-window support is Phase 1)

  Every node is guaranteed to have `:id`, `:type`, `:props`, and
  `:children`. Prop values are encoded for the wire format. Children
  are always a list, normalized recursively.
  """
  @canvas_shape_structs [
    Plushie.Canvas.Shape.Rect,
    Plushie.Canvas.Shape.Circle,
    Plushie.Canvas.Shape.Line,
    Plushie.Canvas.Shape.CanvasText,
    Plushie.Canvas.Shape.Path,
    Plushie.Canvas.Shape.CanvasImage,
    Plushie.Canvas.Shape.CanvasSvg,
    Plushie.Canvas.Shape.Group,
    Plushie.Canvas.Shape.Translate,
    Plushie.Canvas.Shape.Rotate,
    Plushie.Canvas.Shape.Scale,
    Plushie.Canvas.Shape.Clip
  ]

  @spec normalize(tree :: nil | tree_node() | [tree_node()] | struct()) :: tree_node()
  def normalize(nil), do: @empty_container

  def normalize([]), do: @empty_container

  def normalize([single]), do: normalize(single)

  def normalize([_ | _] = nodes) do
    # Synthetic root wrapper -- does not create a scope boundary
    %{
      id: "root",
      type: "container",
      props: %{},
      children: Enum.map(nodes, &normalize_with_scope(&1, ""))
    }
  end

  def normalize({:__widget_prop__, key, _value}) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  def normalize({:__canvas_meta__, type, _value}) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata (like interactive) should be inside a group block."
  end

  def normalize(%module{}) when module in @canvas_shape_structs do
    short_name = module |> Module.split() |> List.last()

    raise ArgumentError,
          "found canvas shape (#{short_name}) where a widget node was expected. " <>
            "Canvas shapes belong inside canvas layers, not in the widget tree."
  end

  def normalize(%module{} = widget) when is_atom(module) do
    normalize(Plushie.Widget.to_node(widget))
  end

  def normalize(%{} = node) do
    normalize_with_scope(node, "")
  end

  # Private scope-aware normalize. `scope` is the prefix string to prepend
  # to children's IDs (e.g. "sidebar/form"). Empty string means no scope.
  defp normalize_with_scope({:__widget_prop__, key, _value}, _scope) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  defp normalize_with_scope({:__canvas_meta__, type, _value}, _scope) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata (like interactive) should be inside a group block."
  end

  defp normalize_with_scope(%module{}, _scope) when module in @canvas_shape_structs do
    short_name = module |> Module.split() |> List.last()

    raise ArgumentError,
          "found canvas shape (#{short_name}) where a widget node was expected. " <>
            "Canvas shapes belong inside canvas layers, not in the widget tree."
  end

  defp normalize_with_scope(%module{} = widget, scope) when is_atom(module) do
    normalize_with_scope(Plushie.Widget.to_node(widget), scope)
  end

  defp normalize_with_scope(%{} = node, scope) do
    raw_id = fetch_field(node, :id, "id") || "unknown_#{:erlang.unique_integer([:positive])}"
    type = fetch_field(node, :type, "type") || "container"
    props = fetch_field(node, :props, "props") || %{}
    children = fetch_field(node, :children, "children") || []

    id = to_string(raw_id)
    type_str = to_string(type)

    # Validate: user-provided IDs must not contain "/"
    if not auto_id?(id) and String.contains?(id, "/") do
      raise ArgumentError,
            "widget ID #{inspect(id)} cannot contain \"/\" -- " <>
              "scoped paths are built automatically by named containers"
    end

    # Apply scope prefix to this node's ID
    scoped_id =
      if scope != "" and not auto_id?(id) do
        "#{scope}/#{id}"
      else
        id
      end

    # Determine scope for children: named (non-auto) non-window nodes
    # propagate their scoped ID as the child scope
    child_scope =
      if auto_id?(id) or type_str == "window" do
        scope
      else
        scoped_id
      end

    atom_props =
      props
      |> atomize_keys()
      |> atomize_a11y()
      |> resolve_a11y_id_refs(scope)

    {meta, wire_props} = extract_meta(atom_props)

    # Canvas widget rendering: if this node is a canvas_widget placeholder
    # (tagged with __canvas_widget__ in meta), render it with the best
    # available state and normalize the output. The rendered canvas node
    # does NOT have __canvas_widget__ in its props, so normalization of
    # the output won't re-trigger rendering (no recursion possible).
    # Widget metadata is attached to the final node's :meta directly.
    case render_canvas_widget(meta, id, scoped_id, scope) do
      {:rendered, final_node} ->
        final_node

      :not_a_canvas_widget ->
        normalized_props = encode_prop_values(wire_props)

        node = %{
          id: scoped_id,
          type: type_str,
          props: normalized_props,
          children: normalize_children_with_scope(children, child_scope)
        }

        if meta == %{}, do: node, else: Map.put(node, :meta, meta)
    end
  end

  # Render a canvas_widget placeholder with stored or initial state.
  # Returns {:rendered, fully_normalized_node} or :not_a_canvas_widget.
  #
  # The rendered output is normalized at the same scope position. Since
  # render/3 produces a plain canvas node (no __canvas_widget__ tags in
  # its props), normalization processes it as a regular widget -- no
  # recursion is possible. After normalization, canvas_widget metadata
  # (module, state, props) is attached to :meta for registry derivation
  # and event interception.
  @spec render_canvas_widget(map(), String.t(), String.t(), String.t()) ::
          {:rendered, map()} | :not_a_canvas_widget
  defp render_canvas_widget(meta, local_id, scoped_id, scope) do
    case Map.get(meta, :__canvas_widget__) do
      module when is_atom(module) and not is_nil(module) ->
        widget_props = Map.get(meta, :__canvas_widget_props__, %{})
        widget_state = lookup_canvas_widget_state(scoped_id, module)

        # Render with local ID -- normalization applies scoping.
        rendered = module.render(local_id, widget_props, widget_state)

        # Normalize the raw canvas output. It has no __canvas_widget__
        # tags, so this is a plain normalization pass with no recursion.
        normalized = normalize_with_scope(rendered, scope)

        # Attach canvas_widget metadata to the final node's :meta.
        # This is the ONLY place these keys appear in meta on the
        # final tree -- they weren't in the rendered node's props.
        widget_meta = %{
          __canvas_widget__: module,
          __canvas_widget_state__: widget_state,
          __canvas_widget_props__: widget_props,
          __extension_widget_type__: Map.get(meta, :__extension_widget_type__),
          __extension_widget_events__: Map.get(meta, :__extension_widget_events__, [])
        }

        existing_meta = Map.get(normalized, :meta, %{})
        final = Map.put(normalized, :meta, Map.merge(existing_meta, widget_meta))
        {:rendered, final}

      _ ->
        :not_a_canvas_widget
    end
  end

  # Look up stored canvas_widget state from the process dictionary
  # (set by the runtime's safe_view). Falls back to initial state
  # for new widgets or when called outside a runtime context.
  @spec lookup_canvas_widget_state(String.t(), module()) :: map()
  defp lookup_canvas_widget_state(scoped_id, module) do
    case Process.get(Plushie.Extension.CanvasWidget.widget_states_key()) do
      registry when is_map(registry) ->
        case Map.get(registry, scoped_id) do
          %{state: state} -> state
          nil -> module.__initial_state__()
        end

      nil ->
        module.__initial_state__()
    end
  end

  # Resolve a11y ID references (labelled_by, described_by, error_message)
  # relative to the current scope. These fields reference sibling widgets
  # by local ID; the renderer needs the full scoped path to find them.
  @a11y_id_ref_keys [:labelled_by, :described_by, :error_message]

  defp resolve_a11y_id_refs(props, scope) do
    case Map.get(props, :a11y) do
      nil ->
        props

      a11y when is_map(a11y) ->
        resolved =
          Enum.reduce(@a11y_id_ref_keys, a11y, fn key, acc ->
            case Map.get(acc, key) do
              nil -> acc
              ref when is_binary(ref) -> Map.put(acc, key, scope_ref(ref, scope))
              _ -> acc
            end
          end)

        Map.put(props, :a11y, resolved)

      _ ->
        props
    end
  end

  # Prefix an ID reference with the current scope, unless it already
  # contains "/" (already a full path) or the scope is empty.
  defp scope_ref(ref, ""), do: ref
  defp scope_ref(ref, _scope) when ref == "", do: ref

  defp scope_ref(ref, scope) do
    if String.contains?(ref, "/") do
      ref
    else
      "#{scope}/#{ref}"
    end
  end

  defp auto_id?(id), do: String.starts_with?(id, "auto:")

  @doc """
  Finds the first node in a tree whose `:id` matches the given `id`.

  Matches against the full scoped ID first. If no match is found and
  the target does not contain "/", falls back to matching the local
  segment (the part after the last "/") of each node's scoped ID.

  Returns the node map, or `nil` if not found. Searches depth-first.
  """
  @spec find(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find(tree, target_id) do
    find_exact(tree, target_id) ||
      if not String.contains?(target_id, "/") do
        find_by_local(tree, target_id)
      end
  end

  defp find_exact(%{id: id} = node, id), do: node

  defp find_exact(%{children: children}, target_id) when is_list(children) do
    Enum.find_value(children, &find_exact(&1, target_id))
  end

  defp find_exact(%{"id" => id} = node, id), do: node

  defp find_exact(%{"children" => children}, target_id) when is_list(children) do
    Enum.find_value(children, &find_exact(&1, target_id))
  end

  defp find_exact(_node, _target_id), do: nil

  defp find_by_local(%{id: node_id} = node, target_id) do
    local = node_id |> String.split("/") |> List.last()

    if local == target_id do
      node
    else
      case node do
        %{children: children} when is_list(children) ->
          Enum.find_value(children, &find_by_local(&1, target_id))

        _ ->
          nil
      end
    end
  end

  defp find_by_local(_, _), do: nil

  @doc """
  Returns true if a node with the given `id` exists in the tree.

  Supports both full scoped IDs and local IDs (see `find/2`).
  """
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
  Extracts the display text from a node.

  Returns the `"content"` prop for text-like widgets, or `nil` if
  no display text is available.
  """
  @spec text_of(node :: tree_node()) :: String.t() | nil
  def text_of(%{props: %{content: c}}) when is_binary(c), do: c
  def text_of(%{props: %{"content" => c}}) when is_binary(c), do: c
  def text_of(%{"props" => %{"content" => c}}) when is_binary(c), do: c
  def text_of(_), do: nil

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
    if old.type != new.type do
      [%{op: "replace_node", path: path, node: new}]
    else
      case diff_children(old.children, new.children, path) do
        :reordered ->
          [%{op: "replace_node", path: path, node: new}]

        child_ops ->
          prop_ops = diff_props(old.props, new.props, path)
          prop_ops ++ child_ops
      end
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
    old_by_id = old_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)
    new_by_id = new_children |> Enum.with_index() |> Map.new(fn {c, i} -> {c.id, {c, i}} end)

    new_ids = Enum.map(new_children, & &1.id)

    if length(new_ids) != map_size(new_by_id) do
      dupes = new_ids -- Enum.uniq(new_ids)

      Logger.error(
        "plushie tree: duplicate child IDs will cause rendering errors: #{inspect(Enum.uniq(dupes))}"
      )
    end

    # Reorder detection uses the maps we already built, avoiding duplicate
    # MapSet construction. Uses key set comparison of common child IDs, not
    # LCS (Longest Common Subsequence). LCS would produce minimal move
    # operations but is O(n^2). Set comparison is O(n) and catches all
    # reorders, at the cost of producing a full replace_node instead of
    # individual moves. Deliberate simplicity-over-optimality tradeoff.
    old_ids = Enum.map(old_children, & &1.id)
    common_old = Enum.filter(old_ids, &Map.has_key?(new_by_id, &1))
    common_new = Enum.filter(new_ids, &Map.has_key?(old_by_id, &1))

    if common_old != common_new do
      :reordered
    else
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

      # Patch ops MUST be applied sequentially in the order they appear.
      # The ordering is: removals (descending index), then updates (adjusted
      # indices), then inserts (ascending index). The Rust renderer applies
      # ops sequentially per the protocol spec ("Operations are applied
      # sequentially"). The index calculations in update ops depend on
      # removals having been applied first.
      remove_ops ++ update_ops ++ insert_ops
    end
  end

  defp index_after_removals(old_idx, removed_indices) do
    old_idx - Enum.count(removed_indices, &(&1 < old_idx))
  end

  # Ensures all keys in the map are atoms. String keys from manually
  # constructed node maps are converted; atom keys pass through.
  defp atomize_keys(%{} = map) do
    if Enum.all?(map, fn {k, _} -> is_atom(k) end) do
      map
    else
      Map.new(map, fn
        {k, v} when is_binary(k) ->
          try do
            {String.to_existing_atom(k), v}
          rescue
            ArgumentError -> {k, v}
          end

        {k, v} ->
          {k, v}
      end)
    end
  end

  # Atomize string keys inside the :a11y sub-map so resolve_a11y_id_refs
  # can always match on atom keys like :labelled_by, :described_by, etc.
  defp atomize_a11y(%{a11y: %_{}} = props), do: props
  defp atomize_a11y(%{a11y: %{} = a11y} = props), do: %{props | a11y: atomize_keys(a11y)}
  defp atomize_a11y(props), do: props

  defp extract_meta(props) do
    Map.split_with(props, fn {k, _} -> k in @runtime_meta_keys end)
  end

  defp encode_prop_values(%{} = map) do
    Map.new(map, fn {k, v} -> {k, encode_value(v)} end)
  end

  # Like stringify_value but preserves atom keys in nested maps.
  defp encode_value(%_{} = v), do: Plushie.Encode.encode(v)

  defp encode_value(%{} = v) do
    Map.new(v, fn {k, val} -> {k, encode_value(val)} end)
  end

  defp encode_value(list) when is_list(list), do: Enum.map(list, &encode_value/1)

  defp encode_value(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&encode_value/1)
  end

  defp encode_value(true), do: true
  defp encode_value(false), do: false
  defp encode_value(nil), do: nil
  defp encode_value(v) when is_atom(v), do: Atom.to_string(v)
  defp encode_value(v), do: v

  # Private

  defp normalize_children_with_scope(children, scope) when is_list(children) do
    normalized = Enum.map(children, &normalize_with_scope(&1, scope))
    check_duplicate_ids(normalized)
    normalized
  end

  defp normalize_children_with_scope(_, _scope), do: []

  defp check_duplicate_ids(children) do
    ids = Enum.map(children, & &1.id)

    if length(ids) != length(Enum.uniq(ids)) do
      dupes = ids -- Enum.uniq(ids)

      Logger.error(
        "Duplicate sibling IDs detected during normalize: #{inspect(Enum.uniq(dupes))}"
      )
    end
  end

  defp do_find_all(%{children: children} = node, fun, acc) do
    acc = if fun.(node), do: [node | acc], else: acc
    Enum.reduce(children, acc, &do_find_all(&1, fun, &2))
  end

  defp do_find_all(node, fun, acc) do
    if fun.(node), do: [node | acc], else: acc
  end

  # Fetches a field by atom key first, then string key, returning nil if absent.
  defp fetch_field(map, atom_key, string_key) do
    case map do
      %{^atom_key => v} -> v
      %{^string_key => v} -> v
      _ -> nil
    end
  end
end
