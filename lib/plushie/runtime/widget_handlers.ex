defmodule Plushie.Runtime.WidgetHandlers do
  @moduledoc """
  Runtime support for widget handler event dispatch and state management.

  Maintains a registry of active widget_handlers (keyed by window ID and
  scoped ID)
  derived from the normalized tree. Routes events through the scope
  chain of widget handlers, following iced's captured/ignored
  model.

  ## Event dispatch

  When an event arrives with a scope that contains one or more
  registered widget_handlers, the runtime builds a handler chain
  (innermost to outermost) and walks it:

  - `:ignored` -- handler didn't capture; continue to next handler
  - `:consumed` / `{:update_state, ...}` -- captured, no output; stop
  - `{:emit, ...}` -- captured with output; replace event and continue

  If no handler captures, the event reaches `app.update/2` unchanged.
  This mirrors iced's `Status::Captured` / `Status::Ignored` model.

  ## Scoped ID reconstruction

  Events carry a reversed ancestor scope list (e.g., `["picker", "form"]`
  for a widget at `form/picker`). Registry keys are forward-order scoped
  IDs. The dispatch logic reconstructs scoped IDs from the scope array
  to build the handler chain.
  """

  require Logger

  alias Plushie.Widget.Handler

  @doc """
  Normalizes a widget event by resolving the wire family string
  (e.g., "color_picker:select") into a `{widget_type, event_name}`
  tuple and applying the event spec (scalar extraction, field atomization).

  Non-widget events pass through unchanged.

  The `widget_events` argument is the event registry derived from the tree
  (keyed by `{window_id, scoped_id}`).
  """
  @spec normalize_widget_event!(widget_events :: map(), event :: term()) :: term()
  def normalize_widget_event!(widget_events, %Plushie.Event.WidgetEvent{type: family} = event)
      when is_binary(family) do
    target = Plushie.Event.target(event)
    registry_key = {Map.get(event, :window_id), target}

    case Map.get(widget_events, registry_key) do
      %{widget_type: widget_type, events: events, event_specs: event_specs} ->
        {family_widget_type, event_name} = parse_widget_family!(family)

        cond do
          family_widget_type != widget_type ->
            raise Plushie.Protocol.Error,
              reason: {:unknown_event_family, family, %{"id" => target}},
              format: :msgpack,
              data: <<>>

          MapSet.member?(events, event_name) ->
            spec = Map.get(event_specs, event_name)
            apply_widget_event_family_spec(event, widget_type, event_name, spec)

          true ->
            raise Plushie.Protocol.Error,
              reason: {:unknown_event_family, family, %{"id" => target}},
              format: :msgpack,
              data: <<>>
        end

      nil ->
        raise Plushie.Protocol.Error,
          reason: {:unknown_event_family, family, %{"id" => target}},
          format: :msgpack,
          data: <<>>
    end
  end

  def normalize_widget_event!(_widget_events, event), do: event

  @doc """
  Applies an event spec to a native widget event, setting type tuple
  and routing data to value/data fields based on the spec.
  """
  @spec apply_widget_event_family_spec(
          event :: Plushie.Event.WidgetEvent.t(),
          widget_type :: atom(),
          event_name :: atom(),
          spec :: Plushie.Event.BuiltinSpecs.t() | nil
        ) :: Plushie.Event.WidgetEvent.t()
  def apply_widget_event_family_spec(event, widget_type, event_name, spec) do
    event = %{event | type: {widget_type, event_name}}

    case spec do
      %{carrier: :value, fields: declared_fields} ->
        wire_data = if is_map(event.value), do: event.value, else: %{}
        parsed = atomize_declared_fields(wire_data, declared_fields)
        %{event | value: parsed}

      %{carrier: :value} ->
        wire_value = extract_wire_value(event.value)
        %{event | value: wire_value}

      %{carrier: :none} ->
        %{event | value: nil}

      nil ->
        event
    end
  end

  @doc """
  Extracts a scalar value from wire event data. Wire data from the
  renderer is a string-keyed map; value events carry the value under
  "value". Falls back to the raw data for pre-parsed or nil values.
  """
  @spec extract_wire_value(wire_data :: map() | term()) :: term()
  def extract_wire_value(%{"value" => v}), do: v
  def extract_wire_value(v), do: v

  @doc """
  Atomizes declared field keys from wire data and parses typed fields.
  Undeclared keys are dropped; only declared fields appear in the result.
  """
  @spec atomize_declared_fields(
          wire_data :: map(),
          declared_fields :: [{atom(), Plushie.Event.BuiltinSpecs.field_type()}]
        ) :: map()
  def atomize_declared_fields(wire_data, declared_fields) do
    Map.new(declared_fields, fn {field_name, type} ->
      wire_key = Atom.to_string(field_name)
      raw_value = Map.get(wire_data, wire_key)

      parsed =
        case Plushie.Type.cast_field(type, raw_value) do
          {:ok, v} ->
            v

          :error ->
            Logger.warning(
              "event field #{inspect(field_name)} failed to parse as #{inspect(type)}, " <>
                "raw value: #{inspect(raw_value)}"
            )

            raw_value
        end

      {field_name, parsed}
    end)
  end

  @doc """
  Parses a wire event family string (e.g., "color_picker:select") into
  a `{widget_type, event_name}` tuple of existing atoms.
  """
  @spec parse_widget_family!(String.t()) :: {atom(), atom()}
  def parse_widget_family!(family) do
    case String.split(family, ":", parts: 2) do
      [widget_type, event_name] when widget_type != "" and event_name != "" ->
        {String.to_existing_atom(widget_type), String.to_existing_atom(event_name)}

      _ ->
        raise Plushie.Protocol.Error,
          reason: {:unknown_event_family, family, %{}},
          format: :msgpack,
          data: <<>>
    end
  rescue
    ArgumentError ->
      reraise Plushie.Protocol.Error.exception(
                reason: {:unknown_event_family, family, %{}},
                format: :msgpack,
                data: <<>>
              ),
              __STACKTRACE__
  end

  @doc """
  Collects subscription specs from all registered widget_handlers.

  Each widget's `subscribe/2` callback (if defined) is called with
  props and state from the registry. The returned specs are namespaced
  with the widget ID so they don't collide with app subscriptions or
  other widgets.
  """
  @type widget_key :: {String.t() | nil, String.t()}

  @spec collect_subscriptions(registry :: %{widget_key() => map()}) :: [Plushie.Subscription.t()]
  def collect_subscriptions(registry) do
    Enum.flat_map(registry, fn {{window_id, widget_id}, entry} ->
      %{module: module, state: widget_state} = entry
      props = Map.get(entry, :props, %{})

      if function_exported?(module, :subscribe, 2) do
        try do
          module.subscribe(props, widget_state)
          |> List.wrap()
          |> Enum.map(&namespace_subscription(&1, window_id, widget_id))
        rescue
          error ->
            Logger.warning(
              "widget_handler #{inspect(module)} (#{widget_id}) " <>
                "raised in subscribe/2: #{Exception.message(error)}"
            )

            []
        end
      else
        []
      end
    end)
  end

  @doc """
  Checks if a timer event is for a widget handler subscription.
  If so, routes it through the widget's handle_event and returns
  the result. Timer-triggered emits are dispatched through the
  scope chain of parent widget_handlers.

  Returns:
  - `{:handled, event_or_nil, new_registry}` -- timer was for a widget handler
  - `:not_routed` -- not a widget handler timer
  """
  @spec maybe_handle_timer(registry :: %{widget_key() => map()}, tag :: term()) ::
          {:handled, struct() | nil, map()} | :not_routed
  def maybe_handle_timer(registry, {:__widget__, window_id, widget_id, inner_tag}) do
    case Map.get(registry, {window_id, widget_id}) do
      %{module: module, state: widget_state} = entry ->
        timer_event = %Plushie.Event.TimerEvent{
          tag: inner_tag,
          timestamp: System.monotonic_time(:millisecond)
        }

        {action, new_state} =
          try do
            Handler.invoke_handler(
              module,
              timer_event,
              widget_state,
              widget_id,
              entry.window_id
            )
          rescue
            error ->
              Logger.warning(
                "widget_handler #{inspect(module)} (#{widget_id}) " <>
                  "raised in timer handle_event: #{Exception.message(error)}"
              )

              {:ignored, widget_state}
          end

        new_registry = put_in(registry, [{window_id, widget_id}, :state], new_state)

        case action do
          {:emit, transformed} ->
            # Dispatch the emitted event through the scope chain
            # so parent widget_handlers can intercept it.
            {result_event, final_registry} = dispatch_event(new_registry, transformed)
            {:handled, result_event, final_registry}

          :consumed ->
            {:handled, nil, new_registry}

          :ignored ->
            {:handled, nil, new_registry}
        end

      nil ->
        :not_routed
    end
  end

  def maybe_handle_timer(_registry, _tag), do: :not_routed

  defp namespace_subscription(spec, window_id, widget_id) do
    Plushie.Subscription.map_tag(spec, fn tag ->
      {:__widget__, window_id, widget_id, tag}
    end)
  end

  @doc """
  Derives the widget handler registry from the normalized tree.

  The tree carries widget metadata (module, state, props) in each
  stateful widget node's `:meta` field. This function extracts that
  metadata into a flat map keyed by scoped ID for O(1) event
  dispatch lookups.

  Called after each render. The tree is the single source of truth --
  new widgets appear with their initial state (set during normalization),
  existing widgets carry their updated state, and removed widgets are
  simply absent.
  """
  @spec derive_registry(tree :: map() | nil) :: %{widget_key() => map()}
  def derive_registry(nil), do: %{}

  def derive_registry(tree) do
    collect_widget_entries(tree, nil, %{})
  end

  @doc """
  Derives all registries from the normalized tree in a single walk.

  Returns `{handler_registry, event_registry, window_set}` where:
  - `handler_registry` is the same as `derive_registry/1`
  - `event_registry` is the widget event spec registry (previously
    `derive_widget_event_registry/1` in Runtime)
  - `window_set` is the MapSet of window IDs (previously
    `Windows.detect_windows/1`)
  """
  @spec derive_all_registries(tree :: map() | nil) ::
          {%{widget_key() => map()}, map(), MapSet.t()}
  def derive_all_registries(nil), do: {%{}, %{}, MapSet.new()}

  def derive_all_registries(tree) do
    {handlers, events, window_ids} = collect_all(tree, nil, {%{}, %{}, []})
    {handlers, events, MapSet.new(window_ids)}
  end

  defp collect_all(%{id: id, type: "window", children: children}, _window_id, {h, e, w}) do
    Enum.reduce(children, {h, e, [id | w]}, &collect_all(&1, id, &2))
  end

  defp collect_all(%{id: id, children: children} = node, window_id, {h, e, w}) do
    meta = Map.get(node, :meta, %{})

    {h, e} = collect_meta(meta, window_id, id, h, e)

    Enum.reduce(children, {h, e, w}, &collect_all(&1, window_id, &2))
  end

  defp collect_all(%{children: children}, window_id, acc) do
    Enum.reduce(children, acc, &collect_all(&1, window_id, &2))
  end

  defp collect_all(_, _window_id, acc), do: acc

  # Extract handler and event entries from a node's meta in one pass.
  defp collect_meta(
         %{
           __widget__: %Plushie.Widget.Meta.Composite{
             module: module,
             state: state,
             handles_events: handles_events,
             props: props,
             type: widget_type,
             events: events,
             event_specs: event_specs
           }
         },
         window_id,
         id,
         h,
         e
       ) do
    h =
      if handles_events do
        Map.put(h, {window_id, id}, %{
          module: module,
          state: state,
          props: props || %{},
          window_id: window_id
        })
      else
        h
      end

    e =
      if is_atom(widget_type) and not is_nil(widget_type) and is_list(events) do
        specs_map = Map.new(event_specs || [], fn {name, spec} -> {name, spec} end)

        Map.put(e, {window_id, id}, %{
          widget_type: widget_type,
          events: MapSet.new(events),
          event_specs: specs_map
        })
      else
        e
      end

    {h, e}
  end

  defp collect_meta(
         %{
           __widget__: %Plushie.Widget.Meta.Native{
             type: widget_type,
             events: events,
             event_specs: event_specs
           }
         },
         window_id,
         id,
         h,
         e
       ) do
    e =
      if is_atom(widget_type) and not is_nil(widget_type) and is_list(events) do
        specs_map = Map.new(event_specs || [], fn {name, spec} -> {name, spec} end)

        Map.put(e, {window_id, id}, %{
          widget_type: widget_type,
          events: MapSet.new(events),
          event_specs: specs_map
        })
      else
        e
      end

    {h, e}
  end

  defp collect_meta(_meta, _window_id, _id, h, e), do: {h, e}

  defp collect_widget_entries(%{id: id, type: "window", children: children}, _window_id, acc) do
    Enum.reduce(children, acc, &collect_widget_entries(&1, id, &2))
  end

  defp collect_widget_entries(%{id: id, children: children} = node, window_id, acc) do
    meta = Map.get(node, :meta, %{})

    acc =
      case meta do
        %{
          __widget__: %Plushie.Widget.Meta.Composite{
            module: module,
            state: state,
            handles_events: true,
            props: props
          }
        } ->
          Map.put(acc, {window_id, id}, %{
            module: module,
            state: state,
            props: props || %{},
            window_id: window_id
          })

        _ ->
          acc
      end

    Enum.reduce(children, acc, &collect_widget_entries(&1, window_id, &2))
  end

  defp collect_widget_entries(%{children: children}, window_id, acc) do
    Enum.reduce(children, acc, &collect_widget_entries(&1, window_id, &2))
  end

  defp collect_widget_entries(_, _window_id, acc), do: acc

  @doc """
  Dispatches an event through the widget handler chain.

  Builds an ordered list of widget handlers from the event's
  scope (innermost to outermost), then walks the chain:

  - `:ignored` -- not captured, continue to next handler
  - `:consumed` / `{:update_state, ...}` -- captured, stop
  - `{:emit, family, data}` -- captured, replace event, continue

  Returns `{event_or_nil, updated_registry}`. If no handler captures,
  returns the original event unchanged. If a handler consumes, returns
  nil. This follows iced's captured/ignored model.
  """
  @spec dispatch_event(registry :: map(), event :: struct()) ::
          {struct() | nil, map()}
  def dispatch_event(registry, event) when is_map(event) do
    scope = Map.get(event, :scope, [])
    id = Map.get(event, :id, "")
    window_id = Map.get(event, :window_id)

    # Strip window_id from end of scope for registry lookups.
    # Registry keys are {window_id, scoped_id} where scoped_id
    # does not include the window -- it's keyed separately.
    container_scope = Plushie.Event.strip_window_from_scope(scope, window_id)

    target_id = scope_to_id(container_scope, id)
    target_entry = widget_entry(registry, window_id, target_id)
    chain = build_handler_chain(registry, window_id, container_scope)

    chain =
      case target_entry do
        nil -> chain
        {^target_id, _entry} when chain != [] and elem(hd(chain), 0) == target_id -> chain
        {target_id, entry} -> [{target_id, entry} | chain]
      end

    walk_chain(registry, event, chain)
  end

  # Non-map events (tuples, atoms) can't have scope -- pass through.
  def dispatch_event(registry, event), do: {event, registry}

  # Build an ordered list of {scoped_id, registry_entry} for all
  # widget_handlers in the scope chain, from innermost to outermost.
  #
  # For scope ["picker", "form", "page"]:
  #   candidates: "page/form/picker", "page/form", "page"
  #   returns only those present in the registry, in inner-to-outer order
  @spec build_handler_chain(map(), String.t() | nil, [String.t()]) :: [{String.t(), map()}]
  defp build_handler_chain(_registry, _window_id, []), do: []

  defp build_handler_chain(registry, window_id, scope) do
    forward = Enum.reverse(scope)
    len = length(forward)

    # Generate candidate scoped IDs from innermost to outermost
    for n <- len..1//-1,
        scoped_id = forward |> Enum.take(n) |> Enum.join("/"),
        entry = Map.get(registry, {window_id, scoped_id}),
        entry != nil do
      {scoped_id, entry}
    end
  end

  defp widget_entry(registry, window_id, scoped_id) do
    case Map.get(registry, {window_id, scoped_id}) do
      nil -> nil
      entry -> {scoped_id, entry}
    end
  end

  # Reconstruct a full scoped ID from a reversed scope list and a local ID.
  # scope_to_id(["form"], "submit") => "form/submit"
  # scope_to_id([], "picker") => "picker"
  @spec scope_to_id([String.t()], String.t()) :: String.t()
  defp scope_to_id([], id), do: id
  defp scope_to_id(scope, id), do: Enum.join(Enum.reverse(scope) ++ [id], "/")

  # Walk the handler chain, dispatching the event to each handler
  # until one captures it or the chain is exhausted.
  @spec walk_chain(map(), struct(), [{String.t(), map()}]) :: {struct() | nil, map()}
  defp walk_chain(registry, event, []) do
    # No handler captured -- event reaches app.update/2.
    {event, registry}
  end

  defp walk_chain(
         registry,
         event,
         [{scoped_id, %{module: module, state: widget_state, window_id: widget_window_id}} | rest]
       ) do
    {action, new_state} =
      try do
        Handler.invoke_handler(module, event, widget_state, scoped_id, widget_window_id)
      rescue
        error ->
          Logger.warning(
            "widget_handler #{inspect(module)} (#{scoped_id}) " <>
              "raised in handle_event: #{Exception.message(error)}"
          )

          {:ignored, widget_state}
      end

    new_registry = put_in(registry, [{widget_window_id, scoped_id}, :state], new_state)

    case action do
      {:emit, transformed} ->
        # Captured with output. The transformed event continues
        # through remaining handlers in the chain.
        walk_chain(new_registry, transformed, rest)

      :consumed ->
        # Captured, no output. Stop.
        {nil, new_registry}

      :ignored ->
        # Not captured. Continue to next handler with original event.
        walk_chain(new_registry, event, rest)
    end
  end
end
