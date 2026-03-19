defmodule Julep.Runtime.Subscriptions do
  @moduledoc """
  Subscription lifecycle management for the Julep runtime.

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
  @spec sync_subscriptions(map(), term()) :: map()
  def sync_subscriptions(state, new_model) do
    new_specs =
      try do
        case state.app.subscribe(new_model) do
          specs when is_list(specs) ->
            specs

          other ->
            Logger.error("julep runtime: subscribe/1 must return a list, got: #{inspect(other)}")
            []
        end
      rescue
        e ->
          Logger.error("""
          julep runtime: subscribe/1 raised: #{Exception.message(e)}
          #{Exception.format_stacktrace(__STACKTRACE__)}
          """)

          []
      end

    new_by_key = Map.new(new_specs, fn spec -> {Julep.Subscription.key(spec), spec} end)
    old_key_set = state.subscriptions |> Map.keys() |> MapSet.new()
    new_key_set = new_by_key |> Map.keys() |> MapSet.new()

    # Stop removed subscriptions
    to_stop = MapSet.difference(old_key_set, new_key_set)

    Enum.each(to_stop, fn key ->
      case Map.get(state.subscriptions, key) do
        {:timer, ref} ->
          Process.cancel_timer(ref)

        {:renderer, type} ->
          if state.bridge do
            Julep.Bridge.send_unsubscribe(state.bridge, Atom.to_string(type))
          end

        _ ->
          :ok
      end
    end)

    # Start new subscriptions
    to_start = MapSet.difference(new_key_set, old_key_set)

    new_entries =
      Map.new(to_start, fn key ->
        spec = Map.fetch!(new_by_key, key)
        {key, start_subscription(spec, state.bridge)}
      end)

    # Keep existing (unchanged) subscriptions
    kept_keys = MapSet.difference(new_key_set, to_start) |> MapSet.to_list()
    kept = Map.take(state.subscriptions, kept_keys)

    %{state | subscriptions: Map.merge(kept, new_entries)}
  end

  # -- Private helpers --------------------------------------------------------

  defp start_subscription(%{type: :every, interval: interval, tag: tag}, _bridge) do
    ref = Process.send_after(self(), {:subscription_tick, tag, interval}, interval)
    {:timer, ref}
  end

  defp start_subscription(%{type: type, tag: tag}, bridge)
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
              :on_mouse_move,
              :on_mouse_button,
              :on_mouse_scroll,
              :on_touch,
              :on_ime,
              :on_theme_change,
              :on_animation_frame,
              :on_file_drop,
              :on_event,
              :on_modifiers_changed
            ] do
    if bridge do
      Julep.Bridge.send_subscribe(bridge, Atom.to_string(type), Atom.to_string(tag))
    end

    {:renderer, type}
  end
end
