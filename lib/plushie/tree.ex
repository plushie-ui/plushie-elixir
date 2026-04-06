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

  @typep normalize_ctx :: Plushie.Tree.NormalizeCtx.t()

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

  @default_ctx %Plushie.Tree.NormalizeCtx{scope: "", window_id: nil}

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
        ) :: {tree_node(), normalize_ctx()}
  def normalize_with_caches(tree, ctx) do
    normalize_root(tree, ctx)
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
      {cached_tree, delta_handlers, delta_events, delta_windows} ->
        :telemetry.execute([:plushie, :memo, :hit], %{count: 1}, %{id: node_id})
        refreshed_handlers = refresh_handler_states(delta_handlers, ctx.widget_states)

        ctx = %{
          ctx
          | memo:
              Map.put(
                ctx.memo,
                cache_key,
                {cached_tree, delta_handlers, delta_events, delta_windows}
              ),
            widget_handlers: Map.merge(ctx.widget_handlers, refreshed_handlers),
            widget_events: Map.merge(ctx.widget_events, delta_events),
            window_ids: delta_windows ++ ctx.window_ids
        }

        {cached_tree, ctx}

      _ ->
        :telemetry.execute([:plushie, :memo, :miss], %{count: 1}, %{id: node_id})
        pre_handlers = ctx.widget_handlers
        pre_events = ctx.widget_events
        pre_windows = ctx.window_ids

        {result, ctx} = normalize_memo_body(memo_fun, ctx)

        delta_handlers = Map.drop(ctx.widget_handlers, Map.keys(pre_handlers))
        delta_events = Map.drop(ctx.widget_events, Map.keys(pre_events))
        delta_windows = ctx.window_ids -- pre_windows

        ctx = %{
          ctx
          | memo:
              Map.put(ctx.memo, cache_key, {result, delta_handlers, delta_events, delta_windows})
        }

        {result, ctx}
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

    ctx =
      if type_str == "window" do
        %{ctx | window_ids: [scoped_id | ctx.window_ids]}
      else
        ctx
      end

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
    # Widget registry entries are accumulated into the context.
    {result, ctx} =
      case render_widget_placeholder(meta, id, scoped_id, ctx) do
        {:rendered, final_node, ctx} ->
          {final_node, ctx}

        {:not_a_widget_placeholder, ctx} ->
          normalized_props = encode_prop_values(wire_props)

          # Canvas nodes: promote shapes from props to tree children.
          # Layers become __layer__ container nodes; shapes become leaf nodes
          # with their properties as props. This enables standard diff_children
          # to handle shape diffing automatically.
          {normalized_props, children} =
            if type_str == "canvas" do
              shapes_as_children(normalized_props, scoped_id)
            else
              {normalized_props, children}
            end

          {children, child_ctx} = normalize_children_with_ctx(children, child_ctx)

          node = %{
            id: scoped_id,
            type: type_str,
            props: normalized_props,
            children: children
          }

          # Accumulate native widget entries into ctx instead of attaching :meta
          ctx = accumulate_native_meta(ctx, scoped_id, meta)

          # Merge child_ctx caches and accumulators back into ctx
          {node,
           %{
             ctx
             | memo: child_ctx.memo,
               widget_view: child_ctx.widget_view,
               widget_handlers: child_ctx.widget_handlers,
               widget_events: child_ctx.widget_events,
               window_ids: child_ctx.window_ids
           }}
      end

    {result, %{ctx | depth: ctx.depth - 1}}
  end

  # Render a stateful widget placeholder with stored or initial state.
  # Returns {:rendered, fully_normalized_node, ctx} or {:not_a_widget_placeholder, ctx}.
  #
  # The rendered output is normalized at the same scope position. Since
  # view/3 produces a plain canvas node (no __widget__ tags in
  # its props), normalization processes it as a regular widget -- no
  # recursion is possible. Widget handler and event registry entries
  # are accumulated into the context during rendering.
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

              # Snapshot accumulators before normalizing child tree for delta tracking.
              pre_handlers = ctx.widget_handlers
              pre_events = ctx.widget_events
              pre_windows = ctx.window_ids

              # Normalize the raw canvas output. It has no __widget__
              # tags, so this is a plain normalization pass with no recursion.
              {node, ctx} = normalize_with_ctx(rendered, ctx)

              # Auto-apply standard widget options (:a11y, :event_rate) from the
              # original widget props to the top-level rendered node. This way
              # widget authors don't have to manually forward these options.
              node = merge_standard_widget_props(node, widget_props)

              ctx =
                widget_view_cache_store(module, scoped_id, widget_props, widget_state, node, ctx,
                  pre: {pre_handlers, pre_events, pre_windows}
                )

              {node, ctx}
          end

        # Accumulate widget entry into ctx instead of attaching :meta to the node.
        ctx = accumulate_widget_entry(ctx, scoped_id, composite, widget_state)
        {:rendered, normalized, ctx}

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

  # Accumulate handler and event entries for a composite widget into ctx.
  # Mirrors the logic in WidgetHandlers.collect_meta for Composite structs.
  @spec accumulate_widget_entry(normalize_ctx(), String.t(), Meta.Composite.t(), map()) ::
          normalize_ctx()
  defp accumulate_widget_entry(ctx, scoped_id, composite, widget_state) do
    window_id = ctx.window_id
    key = {window_id, scoped_id}

    ctx =
      if composite.handles_events do
        entry = %{
          module: composite.module,
          state: widget_state,
          props: composite.props || %{},
          window_id: window_id
        }

        %{ctx | widget_handlers: Map.put(ctx.widget_handlers, key, entry)}
      else
        ctx
      end

    widget_type = composite.type
    events = composite.events
    event_specs = composite.event_specs

    if is_atom(widget_type) and not is_nil(widget_type) and is_list(events) do
      specs_map = Map.new(event_specs || [], fn {name, spec} -> {name, spec} end)

      event_entry = %{
        widget_type: widget_type,
        events: MapSet.new(events),
        event_specs: specs_map
      }

      %{ctx | widget_events: Map.put(ctx.widget_events, key, event_entry)}
    else
      ctx
    end
  end

  # Accumulate event entries for native widget meta into ctx.
  # Native widgets only have event entries (no handler entries).
  @spec accumulate_native_meta(normalize_ctx(), String.t(), map()) :: normalize_ctx()
  defp accumulate_native_meta(ctx, _scoped_id, meta) when meta == %{}, do: ctx

  defp accumulate_native_meta(ctx, scoped_id, %{
         __widget__: %Meta.Native{type: widget_type, events: events, event_specs: event_specs}
       }) do
    if is_atom(widget_type) and not is_nil(widget_type) and is_list(events) do
      key = {ctx.window_id, scoped_id}
      specs_map = Map.new(event_specs || [], fn {name, spec} -> {name, spec} end)

      event_entry = %{
        widget_type: widget_type,
        events: MapSet.new(events),
        event_specs: specs_map
      }

      %{ctx | widget_events: Map.put(ctx.widget_events, key, event_entry)}
    else
      ctx
    end
  end

  defp accumulate_native_meta(ctx, _scoped_id, _meta), do: ctx

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
      child_ops = diff_children(old.children, new.children, path)
      prop_ops = diff_props(old.props, new.props, path)
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
  # A future renderer protocol extension could support granular shape ops
  # (add/remove/update by ID), at which point this function would return
  # a diff instead of a boolean, enabling sub-list patching over the wire.
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

    old_ids = Enum.map(old_children, & &1.id)

    # Common IDs in old and new order
    common_old = Enum.filter(old_ids, &Map.has_key?(new_by_id, &1))
    common_new = Enum.filter(new_ids, &Map.has_key?(old_by_id, &1))

    # Fast path: identical ID sequences, just diff props per child
    if old_ids == new_ids do
      diff_children_same_order(old_children, new_children, path)
    else
      # IDs that exist only in old (pure removals)
      old_only = MapSet.new(old_ids) |> MapSet.difference(MapSet.new(new_ids))

      if common_old == common_new do
        # Medium path: no reordering among common IDs. Use simple
        # insert/remove logic (no LIS needed).
        diff_children_no_reorder(
          old_by_id,
          new_children,
          old_only,
          path
        )
      else
        # Slow path: reordering detected. Use LIS to minimize moves.
        diff_children_reorder(
          old_by_id,
          new_by_id,
          new_children,
          common_new,
          old_only,
          path
        )
      end
    end
  end

  # Fast path: old and new have identical ID lists. Diff props per child.
  defp diff_children_same_order(old_children, new_children, path) do
    old_children
    |> Enum.zip(new_children)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{old_child, new_child}, idx} ->
      diff_node(old_child, new_child, path ++ [idx])
    end)
  end

  # Medium path: common IDs maintain relative order. Pure inserts and
  # removes with no moves needed.
  defp diff_children_no_reorder(old_by_id, new_children, old_only, path) do
    # Collect old indices that will be removed (old-only IDs)
    removed_indices =
      old_only
      |> Enum.map(fn id -> old_by_id |> Map.fetch!(id) |> elem(1) end)
      |> Enum.sort()

    remove_ops =
      removed_indices
      |> Enum.reverse()
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

    remove_ops ++ update_ops ++ insert_ops
  end

  # Slow path: reordering detected. Use LIS to find the largest subset
  # of common elements that maintain relative order. Elements in the LIS
  # stay in place; elements not in the LIS are removed and re-inserted
  # at their new positions.
  defp diff_children_reorder(
         old_by_id,
         _new_by_id,
         new_children,
         common_new,
         old_only,
         path
       ) do
    # For common IDs in new order, get their old indices
    old_indices_of_common =
      Enum.map(common_new, fn id ->
        old_by_id |> Map.fetch!(id) |> elem(1)
      end)

    # Find LIS positions (indices into common_new that form the LIS)
    lis_positions = longest_increasing_subsequence(old_indices_of_common)
    lis_set = MapSet.new(lis_positions)

    # IDs that stay in place (in the LIS)
    lis_ids =
      common_new
      |> Enum.with_index()
      |> Enum.filter(fn {_id, i} -> MapSet.member?(lis_set, i) end)
      |> Enum.map(fn {id, _i} -> id end)
      |> MapSet.new()

    # IDs that need to move: common but not in LIS
    moved_ids =
      common_new
      |> MapSet.new()
      |> MapSet.difference(lis_ids)

    # All indices to remove: old-only IDs + moved IDs (removed from old position)
    all_remove_ids = MapSet.union(old_only, moved_ids)

    removed_indices =
      all_remove_ids
      |> Enum.map(fn id -> old_by_id |> Map.fetch!(id) |> elem(1) end)
      |> Enum.sort()

    remove_ops =
      removed_indices
      |> Enum.reverse()
      |> Enum.map(fn idx -> %{op: "remove_child", path: path, index: idx} end)

    # Build new child lookup for O(1) access
    new_child_by_id = Map.new(new_children, fn c -> {c.id, c} end)

    # Update ops for LIS elements (they survive removals, need adjusted indices)
    update_ops =
      lis_ids
      |> Enum.flat_map(fn id ->
        {old_child, old_idx} = Map.fetch!(old_by_id, id)
        new_child = Map.fetch!(new_child_by_id, id)
        child_path = path ++ [index_after_removals(old_idx, removed_indices)]
        diff_node(old_child, new_child, child_path)
      end)

    # Insert ops: new-only IDs and moved IDs, at their new positions
    insert_ops =
      new_children
      |> Enum.with_index()
      |> Enum.filter(fn {child, _idx} ->
        not Map.has_key?(old_by_id, child.id) or MapSet.member?(moved_ids, child.id)
      end)
      |> Enum.map(fn {child, idx} ->
        # For moved IDs, use the new version of the node from new_children
        # (which is already `child` here). For props that changed, the
        # insert carries the full new node so no separate update is needed.
        %{op: "insert_child", path: path, index: idx, node: child}
      end)

    remove_ops ++ update_ops ++ insert_ops
  end

  # Returns the adjusted index of an element after removals, using binary
  # search on a sorted tuple of removed indices. O(log r) per call.
  @spec index_after_removals(non_neg_integer(), [non_neg_integer()]) :: non_neg_integer()
  defp index_after_removals(old_idx, sorted_removed) do
    tup = List.to_tuple(sorted_removed)
    old_idx - bsearch_count_lt(tup, old_idx, 0, tuple_size(tup))
  end

  # Binary search: count elements in a sorted tuple that are strictly less
  # than the target value. O(log n) with O(1) random access.
  defp bsearch_count_lt(_tup, _target, lo, hi) when lo >= hi, do: lo

  defp bsearch_count_lt(tup, target, lo, hi) do
    mid = div(lo + hi, 2)

    if elem(tup, mid) < target do
      bsearch_count_lt(tup, target, mid + 1, hi)
    else
      bsearch_count_lt(tup, target, lo, mid)
    end
  end

  # Longest Increasing Subsequence using patience sorting.
  # Returns the indices (positions) in the input list that form the LIS.
  # Uses Erlang :array for O(1) random access in the inner binary search.
  # O(n log n) time, O(n) space.
  @spec longest_increasing_subsequence([integer()]) :: [non_neg_integer()]
  defp longest_increasing_subsequence([]), do: []

  defp longest_increasing_subsequence(values) do
    # tails[i] = smallest tail value for increasing subsequence of length i+1
    # idxs[i] = index in original list for tails[i]
    # preds = %{pos => predecessor_pos} for backtracking
    n = length(values)
    empty_arr = :array.new(n, default: 0)

    {_tails, preds, idxs, len} =
      values
      |> Enum.with_index()
      |> Enum.reduce({empty_arr, %{}, empty_arr, 0}, fn {val, pos}, {tails, preds, idxs, len} ->
        insert_pos = lis_bsearch(tails, val, 0, len)

        preds =
          if insert_pos > 0 do
            Map.put(preds, pos, :array.get(insert_pos - 1, idxs))
          else
            preds
          end

        tails = :array.set(insert_pos, val, tails)
        idxs = :array.set(insert_pos, pos, idxs)
        len = max(len, insert_pos + 1)

        {tails, preds, idxs, len}
      end)

    # Reconstruct the LIS by following predecessors backward
    last_idx = :array.get(len - 1, idxs)
    reconstruct_lis(preds, last_idx, len, [])
  end

  defp lis_bsearch(_tails, _val, lo, hi) when lo >= hi, do: lo

  defp lis_bsearch(tails, val, lo, hi) do
    mid = div(lo + hi, 2)

    if :array.get(mid, tails) < val do
      lis_bsearch(tails, val, mid + 1, hi)
    else
      lis_bsearch(tails, val, lo, mid)
    end
  end

  defp reconstruct_lis(_preds, _idx, 0, acc), do: acc

  defp reconstruct_lis(preds, idx, remaining, acc) do
    case Map.fetch(preds, idx) do
      {:ok, prev_idx} -> reconstruct_lis(preds, prev_idx, remaining - 1, [idx | acc])
      :error -> [idx | acc]
    end
  end

  # Extracts shapes/layers from canvas props and converts them to tree
  # children. Returns {updated_props, children} where shapes/layers keys
  # are removed from props and shape maps become child nodes.
  #
  # Shapes have already been through encode_prop_values at this point,
  # so they are plain maps (atom keys) like %{type: "rect", x: 0, ...}.
  # Each shape becomes a node: %{id: shape_id, type: shape_type, props: rest, children: []}.
  # Layers become container nodes: %{id: layer_name, type: "__layer__", props: %{}, children: [shape_nodes]}.
  @spec shapes_as_children(map(), String.t()) :: {map(), [map()]}
  defp shapes_as_children(props, _canvas_id) do
    cond do
      # Layered canvas: %{layers: %{layer_name => [shape_maps]}}
      Map.has_key?(props, :layers) ->
        layers = Map.get(props, :layers, %{})
        rest_props = Map.drop(props, [:layers, :shapes])

        children =
          layers
          |> Enum.sort_by(fn {name, _} -> name end)
          |> Enum.map(fn {layer_name, shapes} ->
            shape_children = shapes_to_nodes(shapes, layer_name)

            %{
              id: "auto:layer:#{layer_name}",
              type: "__layer__",
              props: %{name: layer_name},
              children: shape_children
            }
          end)

        {rest_props, children}

      # Flat canvas: %{shapes: [shape_maps]}
      Map.has_key?(props, :shapes) ->
        shapes = Map.get(props, :shapes, [])
        rest_props = Map.drop(props, [:shapes])

        children = shapes_to_nodes(shapes, "default")
        {rest_props, children}

      true ->
        {props, []}
    end
  end

  # Converts a list of encoded shape maps to tree nodes. Each shape map
  # has :type and an optional :id. Shapes without an explicit :id get
  # a positional auto-id.
  defp shapes_to_nodes(shapes, _parent_id) when not is_list(shapes), do: []

  defp shapes_to_nodes(shapes, parent_id) do
    shapes
    |> Enum.with_index()
    |> Enum.map(fn {shape, idx} ->
      shape_to_node(shape, parent_id, idx)
    end)
  end

  defp shape_to_node(%{} = shape, parent_id, idx) do
    shape_type = Map.get(shape, :type, "unknown")

    # Use explicit shape id if present, otherwise generate an auto-id.
    # Auto-ids use the auto: prefix to bypass user ID validation.
    shape_id =
      case Map.get(shape, :id) do
        nil -> "auto:shape:#{parent_id}:#{idx}"
        explicit -> explicit
      end

    # Extract children for group shapes (they contain nested shapes)
    {shape_children, shape_props} =
      case Map.pop(shape, :children) do
        {nil, props} ->
          {[], props}

        {child_shapes, props} when is_list(child_shapes) ->
          nodes = shapes_to_nodes(child_shapes, shape_id)
          {nodes, props}

        {_, props} ->
          {[], props}
      end

    # Remove :type from props (it's on the node itself) but keep :id for the
    # renderer to use as canvas element identifier
    clean_props = Map.drop(shape_props, [:type])

    %{
      id: shape_id,
      type: shape_type,
      props: clean_props,
      children: shape_children
    }
  end

  defp shape_to_node(other, parent_id, idx) do
    # Non-map shape (shouldn't happen after encoding, but be defensive)
    %{
      id: "auto:shape:#{parent_id}:#{idx}",
      type: "unknown",
      props: %{value: other},
      children: []
    }
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

  defp encode_value(v), do: Plushie.Type.encode_value(v)

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
    normalized = infer_radio_groups(normalized)
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

  # Scans normalized children for radio widgets sharing a group prop and
  # injects position_in_set / size_of_set into their a11y props. Respects
  # manual overrides: if position_in_set is already set, the node is left
  # untouched (but still counted toward size_of_set for siblings).
  defp infer_radio_groups(children) do
    radio_groups =
      children
      |> Enum.with_index()
      |> Enum.filter(fn {node, _idx} ->
        node.type == "radio" and is_binary(Map.get(node.props, :group, nil))
      end)
      |> Enum.group_by(fn {node, _idx} -> node.props.group end)

    if map_size(radio_groups) == 0 do
      children
    else
      patches =
        Enum.reduce(radio_groups, %{}, fn {_group, members}, acc ->
          radio_group_patches(members, acc)
        end)

      children
      |> Enum.with_index()
      |> Enum.map(fn {node, idx} ->
        case Map.fetch(patches, idx) do
          {:ok, a11y} -> %{node | props: Map.put(node.props, :a11y, a11y)}
          :error -> node
        end
      end)
    end
  end

  defp radio_group_patches(members, acc) do
    size = length(members)

    members
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn {{node, child_idx}, pos}, inner_acc ->
      patch_radio_a11y(node, child_idx, pos, size, inner_acc)
    end)
  end

  defp patch_radio_a11y(node, child_idx, pos, size, acc) do
    a11y = Map.get(node.props, :a11y) || %{}
    has_position = Map.get(a11y, :position_in_set) != nil
    has_size = Map.get(a11y, :size_of_set) != nil

    cond do
      has_position and has_size ->
        acc

      has_position ->
        Map.put(acc, child_idx, Map.put(a11y, :size_of_set, size))

      true ->
        patched = a11y |> Map.put(:position_in_set, pos) |> Map.put(:size_of_set, size)
        Map.put(acc, child_idx, patched)
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
        {cached_tree, delta_handlers, delta_events, delta_windows} ->
          :telemetry.execute([:plushie, :widget_cache, :hit], %{count: 1}, %{
            id: scoped_id,
            module: module
          })

          refreshed_handlers = refresh_handler_states(delta_handlers, ctx.widget_states)

          ctx = %{
            ctx
            | widget_view:
                Map.put(
                  ctx.widget_view,
                  cache_key,
                  {cached_tree, delta_handlers, delta_events, delta_windows}
                ),
              widget_handlers: Map.merge(ctx.widget_handlers, refreshed_handlers),
              widget_events: Map.merge(ctx.widget_events, delta_events),
              window_ids: delta_windows ++ ctx.window_ids
          }

          {:hit, cached_tree, ctx}

        _ ->
          :telemetry.execute([:plushie, :widget_cache, :miss], %{count: 1}, %{
            id: scoped_id,
            module: module
          })

          {:miss, ctx}
      end
    else
      {:miss, ctx}
    end
  end

  # Store a rendered widget node in the widget view cache with registry deltas.
  # pre_* snapshots are taken BEFORE the widget's normalize_with_ctx call;
  # deltas capture entries accumulated during the widget's child normalization.
  # The widget's OWN entry is accumulated AFTER this call, so it is not
  # included in the delta (correct, since the widget's entry depends on
  # the composite struct, not the cached child tree).
  defp widget_view_cache_store(module, scoped_id, props, state, node, ctx, opts) do
    {pre_handlers, pre_events, pre_windows} = Keyword.fetch!(opts, :pre)

    if function_exported?(module, :__cache_key__, 2) do
      key = module.__cache_key__(props, state)
      cache_key = {module, scoped_id, key}

      delta_handlers = Map.drop(ctx.widget_handlers, Map.keys(pre_handlers))
      delta_events = Map.drop(ctx.widget_events, Map.keys(pre_events))
      delta_windows = ctx.window_ids -- pre_windows

      %{
        ctx
        | widget_view:
            Map.put(
              ctx.widget_view,
              cache_key,
              {node, delta_handlers, delta_events, delta_windows}
            )
      }
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

  # Refresh handler entry states from the current widget_states map.
  # Flat map iteration (no tree walk). Returns a new map with updated
  # states where they differ from the cached version.
  @spec refresh_handler_states(map(), map()) :: map()
  defp refresh_handler_states(handlers, widget_states) do
    Map.new(handlers, fn {key, entry} ->
      case Map.get(widget_states, key) do
        %{state: fresh_state} when fresh_state !== entry.state ->
          {key, %{entry | state: fresh_state}}

        _ ->
          {key, entry}
      end
    end)
  end
end
