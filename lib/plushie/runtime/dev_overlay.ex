defmodule Plushie.Runtime.DevOverlay do
  @moduledoc false

  require Logger

  alias Plushie.Event.WidgetEvent

  @dev_overlay_dismiss_ms Plushie.Dev.RebuildingOverlay.dismiss_ms()

  # Checks whether the event is a dev overlay event and applies the
  # corresponding action. Returns `{:rerender, state}` when the overlay
  # changed and a re-render is needed, `{:noop, state}` when the overlay
  # handled the event but nothing visual changed, or `:passthrough` when
  # the event is not an overlay event.
  @doc false
  @spec maybe_handle_event(map(), term()) :: {:rerender, map()} | {:noop, map()} | :passthrough
  def maybe_handle_event(state, %WidgetEvent{id: id})
      when is_binary(id) do
    if Plushie.Dev.RebuildingOverlay.overlay_event?(id) do
      handle_action(Plushie.Dev.RebuildingOverlay.action(id), state)
    else
      :passthrough
    end
  end

  def maybe_handle_event(_state, _event), do: :passthrough

  # Processes a {:dev_overlay, overlay} message. Updates state with the
  # new overlay and schedules auto-dismiss for success states.
  @doc false
  @spec handle_overlay_message(map(), Plushie.Dev.RebuildingOverlay.t()) :: map()
  def handle_overlay_message(state, overlay) do
    state = cancel_timer(state)
    state = %{state | dev_overlay: overlay}

    if overlay.status == :succeeded do
      schedule_dismiss(state)
    else
      state
    end
  end

  # Handles the auto-dismiss timer. Returns `{:rerender, state}` when
  # the overlay was dismissed, `{:noop, state}` when the user has the
  # overlay expanded (skip dismiss).
  @doc false
  @spec handle_auto_dismiss(map()) :: {:rerender, map()} | {:noop, map()}
  def handle_auto_dismiss(state) do
    if state.dev_overlay && state.dev_overlay.expanded do
      {:noop, state}
    else
      {:rerender, %{state | dev_overlay: nil, dev_overlay_timer: nil}}
    end
  end

  @doc false
  @spec schedule_dismiss(map()) :: map()
  def schedule_dismiss(state) do
    state = cancel_timer(state)
    ref = Process.send_after(self(), :dev_overlay_auto_dismiss, @dev_overlay_dismiss_ms)
    %{state | dev_overlay_timer: ref}
  end

  @doc false
  @spec cancel_timer(map()) :: map()
  def cancel_timer(%{dev_overlay_timer: nil} = state), do: state

  def cancel_timer(state) do
    Process.cancel_timer(state.dev_overlay_timer)
    %{state | dev_overlay_timer: nil}
  end

  # -- Private ----------------------------------------------------------------

  defp handle_action(_action, %{dev_overlay: nil} = state), do: {:noop, state}

  defp handle_action(action, state) do
    case Plushie.Dev.RebuildingOverlay.handle_action(action, state.dev_overlay) do
      {:updated, overlay} ->
        state = %{state | dev_overlay: overlay}

        state =
          if not overlay.expanded and overlay.status == :succeeded do
            schedule_dismiss(state)
          else
            cancel_timer(state)
          end

        {:rerender, state}

      :dismissed ->
        state = cancel_timer(state)
        {:rerender, %{state | dev_overlay: nil}}

      :noop ->
        {:noop, state}
    end
  catch
    kind, reason ->
      Logger.warning(
        "plushie runtime: dev overlay action #{kind}: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      {:noop, state}
  end
end
