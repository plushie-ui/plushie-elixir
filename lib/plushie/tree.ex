defmodule Plushie.Tree do
  @moduledoc """
  Utilities for working with Plushie UI trees.

  A UI tree is a plain map (or list of maps) with the shape:

      %{
        id: "unique-id",
        type: "button",
        props: %{label: "Click me"},
        children: [...]
      }

  This module provides normalization, tree search, and diffing for
  incremental renderer updates.

  Normalization is strict. Missing required fields, duplicate sibling
  IDs, and malformed children raise immediately instead of being
  silently repaired.
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
    :__widget__,
    :__widget_props__,
    :__widget_state__,
    :__extension_widget_type__,
    :__extension_widget_events__,
    :__extension_widget_event_specs__
  ]

  @doc """
  Normalizes a UI tree into the canonical node shape.

  Accepts:
  - `nil` -- returns an empty root container
  - a single node map -- normalizes and returns it
  - a list of node maps -- wraps them in a synthetic root container

  Every normalized node has `:id`, `:type`, `:props`, and `:children`.
  Prop values are encoded for the wire format. Missing `:props` and
  `:children` default to `%{}` and `[]`. Missing required fields or
  malformed shapes raise.
  """
  @spec normalize(tree :: nil | tree_node() | [tree_node()] | struct()) :: tree_node()
  def normalize(nil), do: @empty_container

  def normalize([]), do: @empty_container

  def normalize([single]), do: normalize(single)

  def normalize([_ | _] = nodes) do
    # Synthetic root wrapper -- does not create a scope boundary
    children = normalize_children_with_scope(nodes, "", nil)

    %{
      id: "root",
      type: "container",
      props: %{},
      children: children
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
            "Canvas metadata should be inside a group block."
  end

  def normalize(%module{} = widget) when is_atom(module) do
    if canvas_shape_struct_module?(module) do
      short_name = module |> Module.split() |> List.last()

      raise ArgumentError,
            "found canvas shape (#{short_name}) where a widget node was expected. " <>
              "Canvas shapes belong inside canvas layers, not in the widget tree."
    end

    normalize(Plushie.Widget.to_node(widget))
  end

  def normalize(%{} = node) do
    normalize_with_scope(node, "", nil)
  end

  # Private scope-aware normalize. `scope` is the prefix string to prepend
  # to children's IDs (e.g. "sidebar/form"). Empty string means no scope.
  defp normalize_with_scope({:__widget_prop__, key, _value}, _scope, _window_id) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  defp normalize_with_scope({:__canvas_meta__, type, _value}, _scope, _window_id) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata should be inside a group block."
  end

  defp normalize_with_scope(%module{} = widget, scope, window_id) when is_atom(module) do
    if canvas_shape_struct_module?(module) do
      short_name = module |> Module.split() |> List.last()

      raise ArgumentError,
            "found canvas shape (#{short_name}) where a widget node was expected. " <>
              "Canvas shapes belong inside canvas layers, not in the widget tree."
    end

    normalize_with_scope(Plushie.Widget.to_node(widget), scope, window_id)
  end

  defp normalize_with_scope(%{} = node, scope, window_id) do
    raw_id = required_field!(node, :id, "id")
    type = required_field!(node, :type, "type")
    props = optional_map_field!(node, :props, "props", %{})
    children = optional_list_field!(node, :children, "children", [])

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

    child_window_id = if type_str == "window", do: scoped_id, else: window_id

    atom_props =
      props
      |> atomize_keys()
      |> atomize_a11y()
      |> resolve_a11y_id_refs(scope)

    {meta, wire_props} = extract_meta(atom_props)

    # Stateful widget rendering: if this node is a stateful widget placeholder
    # (tagged with __widget__ in meta), render it with the best
    # available state and normalize the output. The rendered canvas node
    # does NOT have __widget__ in its props, so normalization of
    # the output won't re-trigger rendering (no recursion possible).
    # Widget metadata is attached to the final node's :meta directly.
    case render_widget_placeholder(meta, id, scoped_id, scope, window_id) do
      {:rendered, final_node} ->
        final_node

      :not_a_widget_placeholder ->
        normalized_props = encode_prop_values(wire_props)

        node = %{
          id: scoped_id,
          type: type_str,
          props: normalized_props,
          children: normalize_children_with_scope(children, child_scope, child_window_id)
        }

        if meta == %{}, do: node, else: Map.put(node, :meta, meta)
    end
  end

  # Render a stateful widget placeholder with stored or initial state.
  # Returns {:rendered, fully_normalized_node} or :not_a_widget_placeholder.
  #
  # The rendered output is normalized at the same scope position. Since
  # render/3 produces a plain canvas node (no __widget__ tags in
  # its props), normalization processes it as a regular widget -- no
  # recursion is possible. After normalization, stateful widget metadata
  # (module, state, props) is attached to :meta for registry derivation
  # and event interception.
  @spec render_widget_placeholder(map(), String.t(), String.t(), String.t(), String.t() | nil) ::
          {:rendered, map()} | :not_a_widget_placeholder
  defp render_widget_placeholder(meta, local_id, scoped_id, scope, window_id) do
    case Map.get(meta, :__widget__) do
      module when is_atom(module) and not is_nil(module) ->
        widget_props = Map.get(meta, :__widget_props__, %{})
        widget_state = lookup_widget_state(scoped_id, window_id, module)

        # Render with local ID -- normalization applies scoping.
        # State is always a map (empty for stateless widgets).
        # Children are in props[:children] for container widgets.
        rendered = module.render(local_id, widget_props, widget_state)

        # Normalize the raw canvas output. It has no __widget__
        # tags, so this is a plain normalization pass with no recursion.
        normalized = normalize_with_scope(rendered, scope, window_id)

        # Attach stateful widget metadata to the final node's :meta.
        # This is the ONLY place these keys appear in meta on the
        # final tree -- they weren't in the rendered node's props.
        widget_meta = %{
          __widget__: module,
          __widget_state__: widget_state,
          __widget_props__: widget_props,
          __extension_widget_type__: Map.get(meta, :__extension_widget_type__),
          __extension_widget_events__: Map.get(meta, :__extension_widget_events__, []),
          __extension_widget_event_specs__: Map.get(meta, :__extension_widget_event_specs__, [])
        }

        existing_meta = Map.get(normalized, :meta, %{})
        final = Map.put(normalized, :meta, Map.merge(existing_meta, widget_meta))
        {:rendered, final}

      _ ->
        :not_a_widget_placeholder
    end
  end

  # Look up stored stateful widget state from the process dictionary
  # (set by the runtime's safe_view). Falls back to initial state
  # for new widgets or when called outside a runtime context.
  @spec lookup_widget_state(String.t(), String.t() | nil, module()) :: map()
  defp lookup_widget_state(scoped_id, window_id, module) do
    case Process.get(Plushie.Extension.WidgetHandler.widget_states_key()) do
      registry when is_map(registry) ->
        case Map.get(registry, {window_id, scoped_id}) do
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
  Finds the node in a tree whose `:id` exactly matches the given scoped ID.

  This does exact matching only. It does not fall back to local-ID
  guessing. If the same ID appears in multiple windows, this raises and
  you must use `find/3` with a window ID.
  """
  @spec find(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find(tree, target_id) do
    case find_all_exact(tree, target_id, []) do
      [] ->
        nil

      [node] ->
        node

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with id #{inspect(target_id)}; use find/3 with a window id"
    end
  end

  @doc """
  Finds a node by exact scoped ID within a specific window.

  Searches only inside the window whose `id` matches `window_id`.
  Returns the node map, or `nil` if not found.
  """
  @spec find(tree :: tree_node(), id :: String.t(), window_id :: String.t()) :: tree_node() | nil
  def find(tree, target_id, window_id) do
    tree
    |> find_window(window_id)
    |> case do
      nil -> nil
      window -> find_exact(window, target_id)
    end
  end

  @doc """
  Finds a node by local ID.

  This matches the last segment of each node ID. It is for callers that
  intentionally want local widget IDs instead of full scoped paths.

  Raises if more than one node has the same local ID.
  """
  @spec find_local(tree :: tree_node(), id :: String.t()) :: tree_node() | nil
  def find_local(tree, local_id) do
    case find_all_local(tree, local_id, []) do
      [] ->
        nil

      [node] ->
        node

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with local id #{inspect(local_id)}; use a scoped id or window-aware lookup"
    end
  end

  @doc """
  Finds a node by local ID within a specific window.

  Searches only inside the window whose `id` matches `window_id`.
  Raises if more than one node in that window has the same local ID.
  """
  @spec find_local(tree :: tree_node(), id :: String.t(), window_id :: String.t()) ::
          tree_node() | nil
  def find_local(tree, local_id, window_id) do
    tree
    |> find_window(window_id)
    |> case do
      nil -> nil
      window -> find_local(window, local_id)
    end
  end

  @doc """
  Returns the window ID that owns an exact scoped target ID.

  Returns `nil` when the target is not inside any window. Raises if the
  same target appears in more than one window.
  """
  @spec window_id_for(tree :: tree_node(), id :: String.t()) :: String.t() | nil
  def window_id_for(tree, target_id) do
    case collect_window_ids(tree, target_id, nil, []) |> Enum.uniq() do
      [] ->
        nil

      [window_id] ->
        window_id

      _ ->
        raise ArgumentError,
              "tree contains multiple nodes with id #{inspect(target_id)} in different windows"
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

  defp find_all_exact(%{id: id} = node, target_id, acc) when id == target_id do
    acc =
      case node do
        %{children: children} when is_list(children) ->
          Enum.reduce(children, [node | acc], &find_all_exact(&1, target_id, &2))

        _ ->
          [node | acc]
      end

    acc
  end

  defp find_all_exact(%{children: children}, target_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_exact(&1, target_id, &2))
  end

  defp find_all_exact(%{"id" => id} = node, target_id, acc) when id == target_id do
    acc =
      case node do
        %{"children" => children} when is_list(children) ->
          Enum.reduce(children, [node | acc], &find_all_exact(&1, target_id, &2))

        _ ->
          [node | acc]
      end

    acc
  end

  defp find_all_exact(%{"children" => children}, target_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_exact(&1, target_id, &2))
  end

  defp find_all_exact(_node, _target_id, acc), do: acc

  defp find_all_local(%{id: id} = node, local_id, acc) do
    acc = if local_id(id) == local_id, do: [node | acc], else: acc

    case node do
      %{children: children} when is_list(children) ->
        Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))

      _ ->
        acc
    end
  end

  defp find_all_local(%{"id" => id} = node, local_id, acc) do
    acc = if local_id(id) == local_id, do: [node | acc], else: acc

    case node do
      %{"children" => children} when is_list(children) ->
        Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))

      _ ->
        acc
    end
  end

  defp find_all_local(%{children: children}, local_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))
  end

  defp find_all_local(%{"children" => children}, local_id, acc) when is_list(children) do
    Enum.reduce(children, acc, &find_all_local(&1, local_id, &2))
  end

  defp find_all_local(_node, _local_id, acc), do: acc

  defp local_id(id) when is_binary(id) do
    case String.split(id, "/") do
      [] -> id
      parts -> List.last(parts)
    end
  end

  defp find_window(%{type: "window", id: id} = node, id), do: node

  defp find_window(%{children: children}, window_id) when is_list(children) do
    Enum.find_value(children, &find_window(&1, window_id))
  end

  defp find_window(_, _window_id), do: nil

  defp collect_window_ids(%{type: "window", id: id, children: children}, target_id, _current, acc) do
    acc = if id == target_id, do: [id | acc], else: acc
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, id, &2))
  end

  defp collect_window_ids(%{id: id, children: children}, target_id, current_window, acc) do
    acc = if id == target_id and current_window, do: [current_window | acc], else: acc

    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(%{children: children}, target_id, current_window, acc)
       when is_list(children) do
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(
         %{"type" => "window", "id" => id, "children" => children},
         target_id,
         _current,
         acc
       ) do
    acc = if id == target_id, do: [id | acc], else: acc
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, id, &2))
  end

  defp collect_window_ids(%{"id" => id, "children" => children}, target_id, current_window, acc) do
    acc = if id == target_id and current_window, do: [current_window | acc], else: acc

    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(%{"children" => children}, target_id, current_window, acc)
       when is_list(children) do
    Enum.reduce(children, acc, &collect_window_ids(&1, target_id, current_window, &2))
  end

  defp collect_window_ids(_node, _target_id, _current_window, acc), do: acc

  @doc """
  Returns true if a node with the given `id` exists in the tree.

  Checks exact scoped IDs only.
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
  @spec find_all(node :: tree_node() | nil, fun :: (tree_node() -> as_boolean(term()))) ::
          [tree_node()]
  def find_all(nil, _fun), do: []

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
  def diff(_old_tree, nil), do: [%{op: "replace_node", path: [], node: @empty_container}]

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
      raise ArgumentError, "duplicate child IDs in diff: #{inspect(Enum.uniq(dupes))}"
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

  defp normalize_children_with_scope(children, scope, window_id) when is_list(children) do
    normalized = Enum.map(children, &normalize_with_scope(&1, scope, window_id))
    check_duplicate_ids(normalized)
    normalized
  end

  defp normalize_children_with_scope(children, _scope, _window_id) do
    raise ArgumentError, "widget children must be a list, got: #{inspect(children)}"
  end

  defp check_duplicate_ids(children) do
    ids = Enum.map(children, & &1.id)

    if length(ids) != length(Enum.uniq(ids)) do
      dupes = ids -- Enum.uniq(ids)

      raise ArgumentError,
            "duplicate sibling IDs detected during normalize: #{inspect(Enum.uniq(dupes))}"
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

  defp required_field!(map, atom_key, string_key) do
    case fetch_field(map, atom_key, string_key) do
      nil ->
        raise ArgumentError, "widget node is missing required field #{inspect(atom_key)}"

      value ->
        value
    end
  end

  defp optional_map_field!(map, atom_key, string_key, default) do
    case fetch_field(map, atom_key, string_key) do
      nil ->
        default

      value when is_map(value) ->
        value

      value ->
        raise ArgumentError,
              "widget field #{inspect(atom_key)} must be a map, got: #{inspect(value)}"
    end
  end

  defp optional_list_field!(map, atom_key, string_key, default) do
    case fetch_field(map, atom_key, string_key) do
      nil ->
        default

      value when is_list(value) ->
        value

      value ->
        raise ArgumentError,
              "widget field #{inspect(atom_key)} must be a list, got: #{inspect(value)}"
    end
  end

  defp canvas_shape_struct_module?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?("Elixir.Plushie.Canvas.Shape.")
  end
end
