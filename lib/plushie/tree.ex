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

  @typep normalize_ctx :: %{
           scope: String.t(),
           window_id: String.t() | nil,
           widget_states: map(),
           depth: non_neg_integer(),
           memo_prev: map(),
           memo: map(),
           widget_view_prev: map(),
           widget_view: map()
         }

  @empty_container %{
    id: "root",
    type: "container",
    props: %{},
    children: []
  }

  # Maximum tree depth. Warns at @depth_warning, raises at @max_depth.
  # Protects against infinite recursion from circular widget compositions.
  @depth_warning 200
  @max_depth 256

  # Default context for normalization (no caches, no depth)
  @default_ctx %{
    scope: "",
    window_id: nil,
    widget_states: %{},
    depth: 0,
    memo_prev: %{},
    memo: %{},
    widget_view_prev: %{},
    widget_view: %{}
  }

  alias Plushie.Widget.Meta

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
  def normalize(tree), do: normalize(tree, %{})

  @doc """
  Normalizes a UI tree with explicit widget states.

  Same as `normalize/1` but uses the provided `widget_states` map for
  stateful widget rendering instead of relying on the process dictionary.
  """
  @spec normalize(tree :: nil | tree_node() | [tree_node()] | struct(), widget_states :: map()) ::
          tree_node()
  def normalize(nil, _widget_states), do: @empty_container

  def normalize([], _widget_states), do: @empty_container

  def normalize([single], widget_states), do: normalize(single, widget_states)

  def normalize([_ | _] = nodes, widget_states) do
    ctx = %{@default_ctx | widget_states: widget_states}
    # Synthetic root wrapper -- does not create a scope boundary
    {children, _ctx} = normalize_children_with_ctx(nodes, ctx)

    %{
      id: "root",
      type: "container",
      props: %{},
      children: children
    }
  end

  def normalize({:__widget_prop__, key, _value}, _widget_states) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  def normalize({:__canvas_meta__, type, _value}, _widget_states) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata should be inside a group block."
  end

  def normalize(%module{} = widget, widget_states) when is_atom(module) do
    if canvas_shape_struct_module?(module) do
      short_name = module |> Module.split() |> List.last()

      raise ArgumentError,
            "found canvas shape (#{short_name}) where a widget node was expected. " <>
              "Canvas shapes belong inside canvas layers, not in the widget tree."
    end

    normalize(Plushie.Widget.to_node(widget), widget_states)
  end

  def normalize(%{} = node, widget_states) do
    ctx = %{@default_ctx | widget_states: widget_states}
    {result, _ctx} = normalize_with_ctx(node, ctx)
    result
  end

  @doc false
  @spec normalize_with_caches(
          tree :: nil | tree_node() | [tree_node()] | struct(),
          normalize_ctx()
        ) :: {tree_node(), map(), map()}
  def normalize_with_caches(tree, ctx) do
    {result, final_ctx} = normalize_root(tree, ctx)
    {result, final_ctx.memo, final_ctx.widget_view}
  end

  # Top-level entry point for normalize that handles nil, lists, structs,
  # and maps. Returns {tree_node, ctx} with updated caches.
  @spec normalize_root(term(), normalize_ctx()) :: {tree_node(), normalize_ctx()}
  defp normalize_root(nil, ctx), do: {@empty_container, ctx}
  defp normalize_root([], ctx), do: {@empty_container, ctx}

  defp normalize_root([single], ctx), do: normalize_root(single, ctx)

  defp normalize_root([_ | _] = nodes, ctx) do
    {children, ctx} = normalize_children_with_ctx(nodes, ctx)
    {%{id: "root", type: "container", props: %{}, children: children}, ctx}
  end

  defp normalize_root({:__widget_prop__, key, _value}, _ctx) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  defp normalize_root({:__canvas_meta__, type, _value}, _ctx) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata should be inside a group block."
  end

  defp normalize_root(%module{} = widget, ctx) when is_atom(module) do
    if canvas_shape_struct_module?(module) do
      short_name = module |> Module.split() |> List.last()

      raise ArgumentError,
            "found canvas shape (#{short_name}) where a widget node was expected. " <>
              "Canvas shapes belong inside canvas layers, not in the widget tree."
    end

    normalize_root(Plushie.Widget.to_node(widget), ctx)
  end

  defp normalize_root(%{} = node, ctx), do: normalize_with_ctx(node, ctx)

  # Private context-aware normalize. ctx.scope is the prefix string to prepend
  # to children's IDs (e.g. "sidebar/form"). Empty string means no scope.
  # Returns {tree_node, updated_ctx} with memo and widget_view caches threaded through.
  @spec normalize_with_ctx(term(), normalize_ctx()) :: {tree_node(), normalize_ctx()}
  defp normalize_with_ctx({:__widget_prop__, key, _value}, _ctx) do
    raise ArgumentError,
          "found a DSL prop declaration (#{inspect(key)}) in the widget tree. " <>
            "Props should be declared inside a container's do-block, not passed as children."
  end

  defp normalize_with_ctx({:__canvas_meta__, type, _value}, _ctx) do
    raise ArgumentError,
          "found a canvas metadata declaration (#{inspect(type)}) in the widget tree. " <>
            "Canvas metadata should be inside a group block."
  end

  defp normalize_with_ctx(%module{} = widget, ctx) when is_atom(module) do
    if canvas_shape_struct_module?(module) do
      short_name = module |> Module.split() |> List.last()

      raise ArgumentError,
            "found canvas shape (#{short_name}) where a widget node was expected. " <>
              "Canvas shapes belong inside canvas layers, not in the widget tree."
    end

    normalize_with_ctx(Plushie.Widget.to_node(widget), ctx)
  end

  defp normalize_with_ctx(%{type: "__memo__", meta: meta} = node, ctx) do
    deps = Map.fetch!(meta, :__memo_deps__)
    memo_fun = Map.fetch!(meta, :__memo_fun__)
    node_id = Map.fetch!(node, :id)
    cache_key = {node_id, ctx.scope, ctx.window_id, deps}

    case Map.get(ctx.memo_prev, cache_key) do
      nil ->
        :telemetry.execute([:plushie, :memo, :miss], %{count: 1}, %{id: node_id})
        {result, ctx} = normalize_memo_body(memo_fun, ctx)
        ctx = %{ctx | memo: Map.put(ctx.memo, cache_key, result)}
        {result, ctx}

      cached ->
        :telemetry.execute([:plushie, :memo, :hit], %{count: 1}, %{id: node_id})
        refreshed = refresh_widget_states(cached, ctx)
        ctx = %{ctx | memo: Map.put(ctx.memo, cache_key, refreshed)}
        {refreshed, ctx}
    end
  end

  defp normalize_with_ctx(%{} = node, ctx) do
    ctx = check_and_increment_depth(ctx)

    raw_id = required_field!(node, :id, "id")
    type = required_field!(node, :type, "type")
    props = optional_map_field!(node, :props, "props", %{})
    children = optional_list_field!(node, :children, "children", [])

    id = to_string(raw_id)
    type_str = to_string(type)
    scope = ctx.scope
    window_id = ctx.window_id

    # Validate user-provided IDs
    unless auto_id?(id) do
      validate_user_id!(id)
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
    child_ctx = %{ctx | scope: child_scope, window_id: child_window_id}

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
    {result, ctx} =
      case render_widget_placeholder(meta, id, scoped_id, ctx) do
        {:rendered, final_node, ctx} ->
          {final_node, ctx}

        {:not_a_widget_placeholder, ctx} ->
          normalized_props = encode_prop_values(wire_props)
          {children, child_ctx} = normalize_children_with_ctx(children, child_ctx)

          node = %{
            id: scoped_id,
            type: type_str,
            props: normalized_props,
            children: children
          }

          node = if meta == %{}, do: node, else: Map.put(node, :meta, meta)
          # Merge child_ctx caches back into ctx (child_ctx diverged on scope/window_id)
          {node, %{ctx | memo: child_ctx.memo, widget_view: child_ctx.widget_view}}
      end

    {result, %{ctx | depth: ctx.depth - 1}}
  end

  # Render a stateful widget placeholder with stored or initial state.
  # Returns {:rendered, fully_normalized_node, ctx} or {:not_a_widget_placeholder, ctx}.
  #
  # The rendered output is normalized at the same scope position. Since
  # view/3 produces a plain canvas node (no __widget__ tags in
  # its props), normalization processes it as a regular widget -- no
  # recursion is possible. After normalization, stateful widget metadata
  # (module, state, props) is attached to :meta for registry derivation
  # and event interception.
  @spec render_widget_placeholder(map(), String.t(), String.t(), normalize_ctx()) ::
          {:rendered, map(), normalize_ctx()} | {:not_a_widget_placeholder, normalize_ctx()}
  defp render_widget_placeholder(meta, local_id, scoped_id, ctx) do
    case Map.get(meta, :__widget__) do
      %Meta.Composite{module: module} = composite ->
        widget_props = composite.props || %{}
        widget_state = lookup_widget_state(scoped_id, module, ctx)

        # Check opt-in cache_key before calling view/3.
        {normalized, ctx} =
          case widget_view_cache_lookup(module, scoped_id, widget_props, widget_state, ctx) do
            {:hit, cached_node, ctx} ->
              {cached_node, ctx}

            {:miss, ctx} ->
              # View with local ID -- normalization applies scoping.
              # State is always a map (empty for stateless widgets).
              # Children are in props[:children] for container widgets.
              rendered = module.view(local_id, widget_props, widget_state)

              # Normalize the raw canvas output. It has no __widget__
              # tags, so this is a plain normalization pass with no recursion.
              {node, ctx} = normalize_with_ctx(rendered, ctx)

              # Auto-apply standard widget options (:a11y, :event_rate) from the
              # original widget props to the top-level rendered node. This way
              # widget authors don't have to manually forward these options.
              node = merge_standard_widget_props(node, widget_props)

              ctx =
                widget_view_cache_store(module, scoped_id, widget_props, widget_state, node, ctx)

              {node, ctx}
          end

        # Attach stateful widget metadata to the final node's :meta.
        # This is the ONLY place these keys appear in meta on the
        # final tree -- they weren't in the rendered node's props.
        enriched = %Meta.Composite{composite | state: widget_state}
        enriched_meta = %{__widget__: enriched}

        existing_meta = Map.get(normalized, :meta, %{})
        final = Map.put(normalized, :meta, Map.merge(existing_meta, enriched_meta))
        {:rendered, final, ctx}

      _ ->
        {:not_a_widget_placeholder, ctx}
    end
  end

  # Look up stored stateful widget state from the context map.
  # Falls back to initial state for new widgets, module mismatches,
  # or when widget_states is empty.
  @spec lookup_widget_state(String.t(), module(), normalize_ctx()) :: map()
  defp lookup_widget_state(scoped_id, module, ctx) do
    case Map.get(ctx.widget_states, {ctx.window_id, scoped_id}) do
      %{module: ^module, state: state} -> state
      %{module: _other} -> module.__initial_state__()
      nil -> module.__initial_state__()
    end
  end

  # Merge standard widget options (:a11y, :event_rate) from the original
  # widget props into the top-level rendered node's props. These are
  # consumer-facing options that should pass through to the rendered output
  # without widget authors needing to forward them manually.
  @standard_widget_prop_keys [:a11y, :event_rate]

  defp merge_standard_widget_props(node, widget_props) do
    overrides =
      Enum.reduce(@standard_widget_prop_keys, %{}, fn key, acc ->
        case Map.get(widget_props, key) do
          nil -> acc
          val -> Map.put(acc, key, encode_value(val))
        end
      end)

    if map_size(overrides) == 0 do
      node
    else
      Map.update!(node, :props, &Map.merge(&1, overrides))
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

  # Printable ASCII range (0x21-0x7E), excludes space and control characters.
  @valid_id_pattern ~r/^[\x21-\x7e]+$/

  # Validates a user-provided widget ID (not auto-generated).
  # Called only for IDs that did NOT pass auto_id?/1, so the "auto:" prefix
  # is already excluded by the caller.
  #
  # Rules:
  # - Must not be empty
  # - Must not contain "/" (reserved for scope separators)
  # - Must not exceed 1024 bytes
  # - Must contain only printable ASCII (0x21-0x7E)
  @spec validate_user_id!(String.t()) :: :ok
  defp validate_user_id!(id) do
    cond do
      id == "" ->
        raise ArgumentError, "widget ID must not be empty"

      String.contains?(id, "/") ->
        raise ArgumentError,
              "widget ID #{inspect(id)} cannot contain \"/\" -- " <>
                "scoped paths are built automatically by named containers"

      byte_size(id) > 1024 ->
        raise ArgumentError,
              "widget ID #{inspect(id)} exceeds maximum length of 1024 bytes"

      not Regex.match?(@valid_id_pattern, id) ->
        raise ArgumentError,
              "widget ID #{inspect(id)} contains invalid characters -- " <>
                "IDs must contain only printable ASCII (0x21-0x7E)"

      true ->
        :ok
    end
  end

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
  Finds the first node in a tree for which `fun` returns truthy.

  Walks the tree depth-first and returns immediately on the first
  match, avoiding a full tree traversal. Returns `nil` if no node
  matches.
  """
  @spec find_first(node :: tree_node() | nil, fun :: (tree_node() -> as_boolean(term()))) ::
          tree_node() | nil
  def find_first(nil, _fun), do: nil

  def find_first(node, fun) do
    do_find_first(node, fun)
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

  defp diff_node(old, new, _path) when old === new, do: []

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
          {:ok, old_v} -> if id_keyed_list_equal?(old_v, v), do: acc, else: Map.put(acc, k, v)
          :error -> Map.put(acc, k, v)
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

  # Compares two list-valued props by element ID when both are lists of
  # ID-bearing maps (e.g. canvas shape lists). This catches the common
  # case where the view function reconstructed the list with identical
  # content but the structural `===` check failed (different map key
  # ordering, float rounding, nested struct re-encoding).
  #
  # Returns true only when both lists have the same length, every element
  # has an :id key, the ID sequences match, and each pair is structurally
  # equal. Falls back to false for non-list or non-ID-bearing values so
  # the caller treats them as changed (existing behavior).
  #
  # TODO: when the renderer protocol supports granular shape ops
  # (add/remove/update by ID), this function can return a diff instead
  # of a boolean, enabling sub-list patching over the wire.
  @spec id_keyed_list_equal?(term(), term()) :: boolean()
  defp id_keyed_list_equal?(old, new) when is_list(old) and is_list(new) do
    length(old) == length(new) and
      id_keyed_list?(old) and
      id_keyed_list?(new) and
      lists_equal_by_id?(old, new)
  end

  defp id_keyed_list_equal?(_old, _new), do: false

  defp id_keyed_list?(list) do
    list != [] and Enum.all?(list, &match?(%{id: _}, &1))
  end

  defp lists_equal_by_id?(old, new) do
    old_by_id = Map.new(old, fn %{id: id} = el -> {id, el} end)

    Enum.all?(new, fn %{id: id} = el ->
      case Map.fetch(old_by_id, id) do
        {:ok, ^el} -> true
        _ -> false
      end
    end)
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

  # Returns the new index of a child after removals have been applied.
  # O(r) per call where r is the removal count. For n surviving children,
  # total cost is O(n*r). Acceptable for typical UI trees (under ~100
  # children per level). For large flat lists (1000+ items), pre-sorting
  # removed_indices and using binary search would reduce to O(n log r).
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
    case Map.pop(props, :__widget__) do
      {nil, _} -> {%{}, props}
      {widget_meta, rest} -> {%{__widget__: widget_meta}, rest}
    end
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

  # Increments the normalization depth counter in the context and checks limits.
  # Returns the updated context with depth incremented by 1.
  @spec check_and_increment_depth(normalize_ctx()) :: normalize_ctx()
  defp check_and_increment_depth(ctx) do
    depth = ctx.depth + 1

    if depth > @max_depth do
      raise ArgumentError,
            "tree depth exceeds maximum of #{@max_depth} during normalize " <>
              "(likely a circular widget composition)"
    end

    if depth == @depth_warning do
      require Logger

      Logger.warning(
        "plushie tree: normalization depth reached #{@depth_warning}, " <>
          "approaching maximum of #{@max_depth}"
      )
    end

    %{ctx | depth: depth}
  end

  @spec normalize_children_with_ctx([term()], normalize_ctx()) :: {[tree_node()], normalize_ctx()}
  defp normalize_children_with_ctx(children, ctx) when is_list(children) do
    {normalized, ctx} =
      Enum.map_reduce(children, ctx, fn child, acc ->
        normalize_with_ctx(child, acc)
      end)

    check_duplicate_ids(normalized)
    {normalized, ctx}
  end

  defp normalize_children_with_ctx(children, _ctx) do
    raise ArgumentError, "widget children must be a list, got: #{inspect(children)}"
  end

  defp check_duplicate_ids(children) do
    ids = Enum.map(children, & &1.id)

    if length(ids) != length(Enum.uniq(ids)) do
      dupes = Enum.uniq(ids -- Enum.uniq(ids))

      message = "duplicate sibling IDs detected during normalize: #{inspect(dupes)}"

      message =
        if Enum.any?(dupes, &auto_id?/1) do
          message <>
            ". Auto-generated IDs are based on source position; provide explicit " <>
            "IDs for items in dynamic lists (e.g., text(item.id, item.name))"
        else
          message
        end

      raise ArgumentError, message
    end
  end

  defp do_find_all(%{children: children} = node, fun, acc) do
    acc = if fun.(node), do: [node | acc], else: acc
    Enum.reduce(children, acc, &do_find_all(&1, fun, &2))
  end

  defp do_find_all(node, fun, acc) do
    if fun.(node), do: [node | acc], else: acc
  end

  defp do_find_first(%{children: children} = node, fun) do
    if fun.(node) do
      node
    else
      Enum.find_value(children, &do_find_first(&1, fun))
    end
  end

  defp do_find_first(node, fun) do
    if fun.(node), do: node
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

  # Check the widget view cache for a hit. Only applies to widgets that
  # export __cache_key__/2. Returns {:hit, node, ctx} or {:miss, ctx}.
  @spec widget_view_cache_lookup(module(), String.t(), map(), map(), normalize_ctx()) ::
          {:hit, map(), normalize_ctx()} | {:miss, normalize_ctx()}
  defp widget_view_cache_lookup(module, scoped_id, props, state, ctx) do
    if function_exported?(module, :__cache_key__, 2) do
      key = module.__cache_key__(props, state)
      cache_key = {module, scoped_id, key}

      case Map.get(ctx.widget_view_prev, cache_key) do
        nil ->
          :telemetry.execute([:plushie, :widget_cache, :miss], %{count: 1}, %{
            id: scoped_id,
            module: module
          })

          {:miss, ctx}

        cached ->
          :telemetry.execute([:plushie, :widget_cache, :hit], %{count: 1}, %{
            id: scoped_id,
            module: module
          })

          refreshed = refresh_widget_states(cached, ctx)
          ctx = %{ctx | widget_view: Map.put(ctx.widget_view, cache_key, refreshed)}
          {:hit, refreshed, ctx}
      end
    else
      {:miss, ctx}
    end
  end

  # Store a rendered widget node in the widget view cache.
  # Only called when the module exports __cache_key__/2.
  @spec widget_view_cache_store(module(), String.t(), map(), map(), map(), normalize_ctx()) ::
          normalize_ctx()
  defp widget_view_cache_store(module, scoped_id, props, state, node, ctx) do
    if function_exported?(module, :__cache_key__, 2) do
      key = module.__cache_key__(props, state)
      cache_key = {module, scoped_id, key}
      %{ctx | widget_view: Map.put(ctx.widget_view, cache_key, node)}
    else
      ctx
    end
  end

  # Evaluate the memo body function and normalize the result. If the body
  # produces multiple children, wraps them in a transparent container
  # (no scope creation) so the cache stores a single node.
  defp normalize_memo_body(memo_fun, ctx) do
    case memo_fun.() do
      [] ->
        {@empty_container, ctx}

      [single] ->
        normalize_with_ctx(single, ctx)

      [_ | _] = nodes ->
        {children, ctx} = normalize_children_with_ctx(nodes, ctx)

        {%{
           id: "auto:memo_container",
           type: "container",
           props: %{},
           children: children
         }, ctx}

      nil ->
        {@empty_container, ctx}

      single ->
        normalize_with_ctx(single, ctx)
    end
  end

  # Walk a cached normalized subtree and refresh widget internal states.
  # Preserves map references where the state has not changed, so the
  # differ's reference equality check still short-circuits.
  defp refresh_widget_states(node, ctx) do
    case node do
      %{meta: %{__widget__: %Meta.Composite{module: module} = comp}} ->
        fresh_state = lookup_widget_state(node.id, module, ctx)

        node =
          if fresh_state === comp.state do
            node
          else
            updated_comp = %{comp | state: fresh_state}
            put_in(node, [:meta, :__widget__], updated_comp)
          end

        refresh_children_states(node, ctx)

      _ ->
        refresh_children_states(node, ctx)
    end
  end

  defp refresh_children_states(%{children: []} = node, _ctx), do: node

  defp refresh_children_states(%{children: children} = node, ctx) when is_list(children) do
    refreshed =
      Enum.map(children, fn child ->
        refreshed_child = refresh_widget_states(child, ctx)
        # Preserve reference if nothing changed
        if refreshed_child === child, do: child, else: refreshed_child
      end)

    if refreshed === children do
      node
    else
      %{node | children: refreshed}
    end
  end

  defp refresh_children_states(node, _ctx), do: node
end
