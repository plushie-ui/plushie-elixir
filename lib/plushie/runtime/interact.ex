defmodule Plushie.Runtime.Interact do
  @moduledoc false

  # Applies an event through widget routing and update/2 without
  # re-rendering. Returns `{state, commands}` for deferred execution
  # during interact_step batches where a single snapshot is sent after
  # all events are processed.
  #
  # `safe_update_fn` wraps the app's update/2 with error handling.
  # Signature: `fn app, model, event, consecutive_errors ->
  # {:ok, model, commands} | :error end`.
  @doc false
  @spec apply_event_deferred(
          state :: map(),
          event :: term(),
          safe_update_fn ::
            (module(), term(), term(), non_neg_integer() ->
               {:ok, term(), [Plushie.Command.t()]} | :error)
        ) :: {map(), [Plushie.Command.t()]}
  def apply_event_deferred(state, event, safe_update_fn) do
    {resolved_event, state} = route_through_widgets(state, event)

    if is_nil(resolved_event) do
      {state, []}
    else
      case safe_update_fn.(state.app, state.model, resolved_event, state.consecutive_errors) do
        {:ok, new_model, commands} ->
          {%{state | model: new_model, consecutive_errors: 0}, List.wrap(commands)}

        :error ->
          {%{state | consecutive_errors: state.consecutive_errors + 1}, []}
      end
    end
  end

  # Decodes a renderer event map from interact_step/interact_response
  # using the shared protocol decoder so scripted interactions and
  # normal runtime event delivery stay on the same path.
  @doc false
  @spec decode_event(map()) :: term()
  def decode_event(%{} = event_map), do: Plushie.Protocol.decode_event(event_map)

  def decode_event(other) do
    raise Plushie.Protocol.Error,
      reason: {:invalid_event_field, "interact", :event, other, :expected_map, %{}},
      format: :msgpack,
      data: <<>>
  end

  # -- Private ----------------------------------------------------------------

  defp route_through_widgets(state, event) do
    event = Plushie.Runtime.WidgetHandlers.normalize_widget_event!(state.widget_events, event)

    {result_event, new_registry} =
      Plushie.Runtime.WidgetHandlers.dispatch_event(state.widget_handlers, event)

    {result_event, %{state | widget_handlers: new_registry}}
  end
end
