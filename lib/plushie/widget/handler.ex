defmodule Plushie.Widget.Handler do
  @moduledoc """
  Runtime support for stateful widgets.

  Canvas widgets are pure-Elixir widgets that render via canvas shapes,
  manage internal state (hover, focus, animation), and transform raw
  canvas events into semantic widget events via `handle_event/2`.

  ## Widget lifecycle

  Canvas widgets follow the standard Widget protocol pipeline:

  1. `new/2` returns a struct (like all other widgets)
  2. `Widget.to_node/1` produces a placeholder node tagged with the
     module and props as metadata
  3. During `Tree.normalize`, the placeholder is detected and rendered
     with the best available state (stored from a previous cycle, or
     initial defaults for new widgets)
  4. The rendered output is normalized in place -- no post-processing

  The tree carries widget state in `:meta` (via `%Meta.Composite{}`),
  making it the single source of truth. The runtime derives a registry
  from the tree after each render for O(1) event dispatch lookups.

  ## Event dispatch (captured/ignored model)

  `invoke_handler/4` is called by the runtime when an event arrives
  for a widget inside a widget's scope. It calls the module's
  `handle_event/2` and interprets the return value using iced's
  captured/ignored model:

  - `{:emit, family, data}` -- captured, emit semantic event
  - `{:emit, family, data, new_state}` -- captured, emit + update state
  - `{:update_state, new_state}` -- captured, internal state change only
  - `:consumed` -- captured, suppress event
  - `:ignored` -- not captured, continue to next handler in scope chain

  Events are dispatched through the scope chain (innermost to outermost).
  `:ignored` continues to the next widget handler in the chain. Captured
  events stop propagation (or, for `:emit`, replace the event and
  continue). If no handler captures, the event reaches `app.update/2`.
  """

  require Logger

  @widget_states_key :__plushie_widget_states__

  @doc "Process dictionary key used to pass canvas widget states during normalization."
  @spec widget_states_key() :: atom()
  def widget_states_key, do: @widget_states_key

  @typedoc "Valid return values from `handle_event/2`."
  @type handle_event_result ::
          {:emit, atom(), term()}
          | {:emit, atom(), term(), map()}
          | {:update_state, map()}
          | :consumed
          | :ignored

  @doc "Transforms a raw event into a semantic widget event (or ignores it)."
  @callback handle_event(event :: struct(), state :: map()) :: handle_event_result()

  @doc "Returns the widget tree for this widget given its id, resolved props, and internal state."
  @callback view(id :: String.t(), props :: map(), state :: map()) :: map()

  @doc "Returns subscription specs for this widget (optional)."
  @callback subscribe(props :: map(), state :: map()) :: [Plushie.Subscription.t()]

  @optional_callbacks [subscribe: 2]

  @doc """
  Invokes a widget's handle_event/2 and interprets the result.

  Returns `{action, new_state}` where action is one of:
  - `{:emit, %WidgetEvent{}}` -- captured with transformed event
  - `:consumed` -- captured, no output
  - `:ignored` -- not captured, continue to next handler
  """
  @spec invoke_handler(
          module :: module(),
          event :: struct(),
          state :: map(),
          widget_id :: String.t(),
          window_id :: String.t() | nil
        ) :: {{:emit, struct()} | :consumed | :ignored, map()}
  def invoke_handler(module, event, state, widget_id \\ "", window_id \\ nil) do
    case module.handle_event(event, state) do
      {:emit, family, data} ->
        {{:emit, build_emit_event(module, family, data, event, widget_id, window_id)}, state}

      {:emit, family, data, new_state} when is_map(new_state) ->
        {{:emit, build_emit_event(module, family, data, event, widget_id, window_id)}, new_state}

      {:update_state, new_state} when is_map(new_state) ->
        {:consumed, new_state}

      :ignored ->
        {:ignored, state}

      :consumed ->
        {:consumed, state}

      other ->
        Logger.warning(
          "widget #{inspect(module)} handle_event/2 returned unexpected value: #{inspect(other)}"
        )

        {:ignored, state}
    end
  end

  @spec build_emit_event(
          module :: module(),
          family :: atom(),
          data :: term(),
          source_event :: struct(),
          widget_id :: String.t(),
          fallback_window_id :: String.t() | nil
        ) :: Plushie.Event.WidgetEvent.t()
  defp build_emit_event(module, family, data, source_event, widget_id, fallback_window_id) do
    {event_type, spec} = resolve_emit_type_and_spec(module, family)

    {id, scope, emit_window_id} =
      resolve_emit_identity(source_event, widget_id, fallback_window_id)

    case spec do
      %{carrier: :value, type: value_type} ->
        validate_emit_value!(family, value_type, data)

        %Plushie.Event.WidgetEvent{
          type: event_type,
          id: id,
          scope: scope,
          window_id: emit_window_id,
          value: data
        }

      %{carrier: :data, fields: declared_fields} = spec ->
        unless is_map(data) do
          raise ArgumentError,
                "event #{inspect(family)} spec declares data fields " <>
                  "#{inspect(Keyword.keys(declared_fields))}, " <>
                  "but emit data is not a map: #{inspect(data)}"
        end

        required_fields = Map.get(spec, :required, Keyword.keys(declared_fields))
        validated = validate_and_coerce_emit_data!(family, data, declared_fields, required_fields)

        %Plushie.Event.WidgetEvent{
          type: event_type,
          id: id,
          scope: scope,
          window_id: emit_window_id,
          data: validated
        }

      %{carrier: :none} ->
        %Plushie.Event.WidgetEvent{
          type: event_type,
          id: id,
          scope: scope,
          window_id: emit_window_id
        }

      nil ->
        raise ArgumentError,
              "no event spec found for #{inspect(family)}. " <>
                "Declare it with the `event` macro."
    end
  end

  # Resolve the ID and scope for emitted events. For pointer events
  # (press, release, move, etc.) the event's id IS the canvas/widget
  # id and scope is the parent scope -- pass through as-is.
  # For other widget events (click on a child element inside a
  # stateful widget), the widget's ID is the first scope element
  # and the remaining scope becomes the parent scope. For non-widget
  # events (Timer, etc.) that lack scope, fall back to splitting the
  # explicit widget_id.
  @canvas_event_types [
    :press,
    :release,
    :move,
    :scroll
  ]

  @spec resolve_emit_identity(struct() | map(), String.t(), String.t() | nil) ::
          {String.t(), [String.t()], String.t() | nil}
  defp resolve_emit_identity(
         %{type: type, id: id, scope: scope, window_id: window_id},
         _widget_id,
         _fallback_window_id
       )
       when type in @canvas_event_types do
    {id, scope, window_id}
  end

  # Top-level widget (no container scope, only window_id in scope list)
  defp resolve_emit_identity(
         %{scope: [wid], id: id, window_id: wid},
         _widget_id,
         _fallback_window_id
       )
       when is_binary(wid) do
    {id, [wid], wid}
  end

  defp resolve_emit_identity(
         %{scope: [canvas_id | parent_scope], window_id: window_id},
         _widget_id,
         _fallback_window_id
       ) do
    {canvas_id, parent_scope, window_id}
  end

  defp resolve_emit_identity(
         %{scope: [], id: id, window_id: window_id},
         _widget_id,
         _fallback_window_id
       ) do
    {id, [], window_id}
  end

  defp resolve_emit_identity(_event, widget_id, fallback_window_id) do
    # Timer or other non-widget event -- use the registered widget ID.
    # Split scoped ID: "form/stars" -> {id: "stars", scope: ["form"]}
    case String.split(widget_id, "/") do
      [single] ->
        {single, [], fallback_window_id}

      parts ->
        {scope_fwd, [local]} = Enum.split(parts, -1)
        {local, Enum.reverse(scope_fwd), fallback_window_id}
    end
  end

  # Resolves the event type (atom or tuple) and looks up the event spec.
  # Custom events (declared via event/events) get tuple types.
  # Built-in events keep bare atoms.
  @spec resolve_emit_type_and_spec(module :: module(), family :: atom()) ::
          {Plushie.Event.WidgetEvent.event_type(), Plushie.Event.BuiltinSpecs.t() | nil}
  defp resolve_emit_type_and_spec(module, family) when is_atom(family) do
    cond do
      family in module.__events__() ->
        event_type = {module.__widget_type__(), family}
        spec = module.__event_spec__(family)
        {event_type, spec}

      Plushie.Event.WidgetEvent.builtin_event_type?(family) ->
        spec = Plushie.Event.BuiltinSpecs.spec(family)
        {family, spec}

      true ->
        raise ArgumentError,
              "#{inspect(module)} emitted undeclared widget event #{inspect(family)}. " <>
                "Declare it with `event` or emit a built-in widget event type."
    end
  end

  # Validates the emitted value matches the declared type.
  @spec validate_emit_value!(family :: atom(), type :: atom(), value :: term()) :: :ok
  defp validate_emit_value!(_family, :any, _value), do: :ok

  defp validate_emit_value!(family, type, value) do
    case Plushie.Type.parse_event_field(type, value) do
      {:ok, _} ->
        :ok

      :error ->
        raise ArgumentError,
              "event #{inspect(family)} declares value type #{inspect(type)}, " <>
                "but got: #{inspect(value)}"
    end
  end

  # Validates and coerces emit data: atomizes keys, checks required
  # fields are present, and validates each declared field's type.
  @spec validate_and_coerce_emit_data!(
          family :: atom(),
          data :: map(),
          declared_fields :: [{atom(), term()}],
          required_fields :: [atom()]
        ) :: map()
  defp validate_and_coerce_emit_data!(family, data, declared_fields, required_fields) do
    atom_data =
      Map.new(data, fn
        {k, v} when is_atom(k) -> {k, v}
        {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      end)

    missing = Enum.reject(required_fields, &Map.has_key?(atom_data, &1))

    if missing != [] do
      raise ArgumentError,
            "event #{inspect(family)} is missing required fields: #{inspect(missing)}"
    end

    for {field_name, type} <- declared_fields do
      if Map.has_key?(atom_data, field_name) do
        value = Map.fetch!(atom_data, field_name)

        case Plushie.Type.parse_event_field(type, value) do
          {:ok, _} ->
            :ok

          :error ->
            raise ArgumentError,
                  "event #{inspect(family)} field #{inspect(field_name)} " <>
                    "declares type #{inspect(type)}, but got: #{inspect(value)}"
        end
      end
    end

    atom_data
  end
end
