defmodule Plushie.Runtime.Coalescable do
  @moduledoc false

  # Stores a high-frequency event for deferred processing. A zero-delay
  # timer ensures the flush fires at the next message boundary.
  # Consecutive coalescable events for the same key overwrite each
  # other so only the latest survives.
  @doc false
  @spec store(map(), term(), Plushie.Event.t()) :: map()
  def store(state, key, event) do
    state =
      if state.coalesce_timer == nil do
        ref = Process.send_after(self(), :flush_coalescables, 0)
        %{state | coalesce_timer: ref}
      else
        state
      end

    # GenServer processes messages in arrival order. Prepend to avoid
    # O(n) list append, then reverse before flushing so coalesced keys
    # are processed in their first-seen order.
    pending_coalesce_order =
      if Map.has_key?(state.pending_coalesce, key) do
        state.pending_coalesce_order
      else
        [key | state.pending_coalesce_order]
      end

    %{
      state
      | pending_coalesce: Map.put(state.pending_coalesce, key, event),
        pending_coalesce_order: pending_coalesce_order
    }
  end

  # Flushes all pending coalescable events, processing each through
  # `run_update_fn` in insertion order. Returns the updated state with
  # all coalescable tracking cleared.
  @doc false
  @spec flush(map(), (map(), term() -> map())) :: map()
  def flush(%{pending_coalesce: pending} = state, _run_update_fn)
      when map_size(pending) == 0 do
    state
  end

  def flush(state, run_update_fn) do
    if state.coalesce_timer, do: Process.cancel_timer(state.coalesce_timer)

    state =
      state.pending_coalesce_order
      |> Enum.reverse()
      |> Enum.reduce(state, fn key, acc ->
        event = Map.fetch!(acc.pending_coalesce, key)
        run_update_fn.(acc, event)
      end)

    %{state | pending_coalesce: %{}, pending_coalesce_order: [], coalesce_timer: nil}
  end

  # Drains queued subscription ticks for the same tag/interval from the
  # mailbox. This coalesces rapid-fire animation or timer ticks so the
  # runtime only processes the latest one, avoiding redundant update
  # cycles.
  @doc false
  @spec drain_matching_ticks(term(), non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def drain_matching_ticks(tag, interval, count \\ 0) do
    receive do
      {:subscription_tick, ^tag, ^interval} -> drain_matching_ticks(tag, interval, count + 1)
    after
      0 ->
        if count > 0 do
          :telemetry.execute(
            [:plushie, :runtime, :ticks_drained],
            %{count: count},
            %{tag: tag}
          )
        end

        count
    end
  end
end
