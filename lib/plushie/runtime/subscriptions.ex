defmodule Plushie.Runtime.Subscriptions do
  @moduledoc """
  Subscription lifecycle management for the Plushie runtime.

  Compares the app's current `subscribe/1` output against the active
  subscriptions, starting new ones and stopping removed ones. Timer-based
  subscriptions (`:every`) are managed locally; renderer-based subscriptions
  (`:on_key_press`, etc.) are forwarded to the bridge.
  """

  require Logger

  @doc """
  Synchronizes subscriptions with the app's current `subscribe/1` output.

  Stops subscriptions that are no longer in the spec list, starts new ones,
  and preserves unchanged ones. Returns the updated state.
  """
  @spec sync_subscriptions(map(), term(), [Plushie.Subscription.t()]) :: map()
  def sync_subscriptions(state, new_model, extra_specs \\ []) do
    app_specs =
      try do
        case state.app.subscribe(new_model) do
          specs when is_list(specs) ->
            specs

          other ->
            Logger.error(
              "plushie runtime: subscribe/1 must return a list, got: #{inspect(other)}"
            )

            []
        end
      rescue
        e ->
          Logger.error("""
          plushie runtime: subscribe/1 raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

          []
      end

    new_specs =
      (app_specs ++ extra_specs)
      |> Enum.filter(fn
        %Plushie.Subscription{} ->
          true

        other ->
          Logger.warning(
            "plushie runtime: subscribe/1 returned invalid spec (dropping): #{inspect(other)}"
          )

          false
      end)

    new_by_key = Map.new(new_specs, fn spec -> {Plushie.Subscription.key(spec), spec} end)
    new_sorted_keys = new_by_key |> Map.keys() |> Enum.sort()

    # Short-circuit: if the sorted key list hasn't changed, the subscription
    # set is identical and we can skip the full diff. But max_rate may have
    # changed on existing subscriptions -- check and re-send if needed.
    if new_sorted_keys == state.subscription_keys do
      update_max_rates(state, new_by_key)
    else
      diff_subscriptions(state, new_by_key, new_sorted_keys)
    end
  end

  # -- Private helpers --------------------------------------------------------

  defp diff_subscriptions(state, new_by_key, new_sorted_keys) do
    old_key_set = state.subscriptions |> Map.keys() |> MapSet.new()
    new_key_set = new_by_key |> Map.keys() |> MapSet.new()

    # Stop removed subscriptions
    to_stop = MapSet.difference(old_key_set, new_key_set)
    stop_subscriptions(to_stop, state.subscriptions, state.bridge)

    # Start new subscriptions
    to_start = MapSet.difference(new_key_set, old_key_set)

    new_entries =
      Map.new(to_start, fn key ->
        spec = Map.fetch!(new_by_key, key)
        {key, start_subscription(spec, state.bridge)}
      end)

    # Keep existing (unchanged) subscriptions, updating max_rate if needed
    kept_keys = MapSet.difference(new_key_set, to_start) |> MapSet.to_list()
    kept = update_kept_subscriptions(kept_keys, state.subscriptions, new_by_key, state.bridge)

    %{state | subscriptions: Map.merge(kept, new_entries), subscription_keys: new_sorted_keys}
  end

  # For kept subscriptions, check if max_rate changed and re-send subscribe
  # with the new rate. The renderer updates the rate in place.
  defp update_kept_subscriptions(kept_keys, old_subs, new_by_key, bridge) do
    Map.new(kept_keys, fn key ->
      old_entry = Map.fetch!(old_subs, key)
      new_spec = Map.fetch!(new_by_key, key)

      case old_entry do
        {:renderer, type, old_rate, _tag} when old_rate != new_spec.max_rate ->
          if bridge do
            Plushie.Bridge.send_subscribe(
              bridge,
              Atom.to_string(type),
              Atom.to_string(new_spec.tag),
              new_spec.max_rate,
              new_spec.window_id
            )
          end

          {key, {:renderer, type, new_spec.max_rate, new_spec.tag}}

        _ ->
          {key, old_entry}
      end
    end)
  end

  # When keys haven't changed at all, still check for max_rate updates
  # on renderer subscriptions.
  defp update_max_rates(state, new_by_key) do
    updated =
      Enum.reduce(new_by_key, state.subscriptions, fn {key, new_spec}, subs ->
        case Map.get(subs, key) do
          {:renderer, type, old_rate, _tag} when old_rate != new_spec.max_rate ->
            if state.bridge do
              Plushie.Bridge.send_subscribe(
                state.bridge,
                Atom.to_string(type),
                Atom.to_string(new_spec.tag),
                new_spec.max_rate,
                new_spec.window_id
              )
            end

            Map.put(subs, key, {:renderer, type, new_spec.max_rate, new_spec.tag})

          _ ->
            subs
        end
      end)

    %{state | subscriptions: updated}
  end

  defp stop_subscriptions(keys, subscriptions, bridge) do
    Enum.each(keys, fn key ->
      case Map.get(subscriptions, key) do
        {:timer, ref} ->
          Process.cancel_timer(ref)

        {:renderer, type, _max_rate, tag} ->
          if bridge,
            do: Plushie.Bridge.send_unsubscribe(bridge, Atom.to_string(type), Atom.to_string(tag))

        _ ->
          :ok
      end
    end)
  end

  defp start_subscription(
         %Plushie.Subscription{type: :every, interval: interval, tag: tag},
         _bridge
       ) do
    ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
    {:timer, ref}
  end

  defp start_subscription(
         %Plushie.Subscription{type: type, tag: tag, max_rate: max_rate, window_id: window_id},
         bridge
       )
       when type in [
              :on_key_press,
              :on_key_release,
              :on_window_close,
              :on_window_event,
              :on_window_open,
              :on_window_resize,
              :on_window_focus,
              :on_window_unfocus,
              :on_window_move,
              :on_pointer_move,
              :on_pointer_button,
              :on_pointer_scroll,
              :on_pointer_touch,
              :on_ime,
              :on_theme_change,
              :on_animation_frame,
              :on_file_drop,
              :on_event,
              :on_modifiers_changed
            ] do
    if bridge do
      Plushie.Bridge.send_subscribe(
        bridge,
        Atom.to_string(type),
        Atom.to_string(tag),
        max_rate,
        window_id
      )
    end

    {:renderer, type, max_rate, tag}
  end
end
