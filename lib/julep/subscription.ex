defmodule Julep.Subscription do
  @moduledoc """
  Declarative subscription specifications for Julep apps.

  Subscriptions are ongoing event sources. Return them from `subscribe/1`
  and the runtime manages their lifecycle automatically.

  ## Example

      def subscribe(model) do
        subs = []
        if model.timer_running do
          subs = [Julep.Subscription.every(1000, :tick) | subs]
        end
        subs
      end
  """

  @type t :: map()

  @doc "Timer that fires every `interval_ms` milliseconds."
  @spec every(pos_integer(), atom()) :: t()
  def every(interval_ms, event_tag)
      when is_integer(interval_ms) and interval_ms > 0 and is_atom(event_tag) do
    %{type: :every, interval: interval_ms, tag: event_tag}
  end

  @doc "Fires on key press events from the renderer."
  @spec on_key_press(atom()) :: t()
  def on_key_press(event_tag) when is_atom(event_tag) do
    %{type: :on_key_press, tag: event_tag}
  end

  @doc "Fires on key release events from the renderer."
  @spec on_key_release(atom()) :: t()
  def on_key_release(event_tag) when is_atom(event_tag) do
    %{type: :on_key_release, tag: event_tag}
  end

  @doc "Fires when a window close is requested."
  @spec on_window_close(atom()) :: t()
  def on_window_close(event_tag) when is_atom(event_tag) do
    %{type: :on_window_close, tag: event_tag}
  end

  @doc "Fires on window events (resize, move, etc.)."
  @spec on_window_event(atom()) :: t()
  def on_window_event(event_tag) when is_atom(event_tag) do
    %{type: :on_window_event, tag: event_tag}
  end

  @doc """
  Returns a key that uniquely identifies this subscription spec.
  Two specs with the same key are considered the same subscription.
  """
  @spec key(t()) :: term()
  def key(%{type: type, tag: tag} = sub) do
    case type do
      :every -> {:every, Map.get(sub, :interval), tag}
      other -> {other, tag}
    end
  end
end
