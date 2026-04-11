defmodule Plushie.Runtime.ViewErrors do
  @moduledoc false

  require Logger

  @view_error_warn_threshold 5

  # Increments the consecutive view error counter and, at the warning
  # threshold, injects a frozen-UI overlay into the tree so the user
  # sees that the UI is stale.
  @doc false
  @spec track_view_error(map()) :: map()
  def track_view_error(state) do
    count = state.consecutive_view_errors + 1

    if count == @view_error_warn_threshold do
      Logger.warning(
        "plushie runtime: view/1 has failed #{count} consecutive times, " <>
          "the UI is stale. Check the error log for details."
      )
    end

    state = %{state | consecutive_view_errors: count}

    if count == @view_error_warn_threshold && is_nil(state.dev_overlay) && state.tree do
      overlay = %Plushie.Dev.RebuildingOverlay{status: :frozen_ui}
      new_tree = maybe_inject_overlay(state.tree, overlay)
      ops = Plushie.Tree.diff(state.tree, new_tree)

      if ops != [] do
        notify_bridge(state, &Plushie.Bridge.send_patch(&1, ops))
      end

      %{state | dev_overlay: overlay, tree: new_tree}
    else
      state
    end
  end

  # Resets the consecutive view error counter and clears any frozen-UI
  # overlay that was injected by `track_view_error/1`.
  @doc false
  @spec clear_view_errors(map()) :: map()
  def clear_view_errors(state) do
    state = %{state | consecutive_view_errors: 0}
    clear_frozen_ui_overlay(state)
  end

  # Clears the dev overlay only if it is the frozen-UI sentinel
  # (injected by view error tracking). Dev rebuild overlays are left
  # untouched.
  @doc false
  @spec clear_frozen_ui_overlay(map()) :: map()
  def clear_frozen_ui_overlay(state) do
    case state.dev_overlay do
      %Plushie.Dev.RebuildingOverlay{status: :frozen_ui} ->
        %{state | dev_overlay: nil}

      _ ->
        state
    end
  end

  # Delegates to the overlay module's tree injection.
  @doc false
  @spec maybe_inject_overlay(map() | nil, Plushie.Dev.RebuildingOverlay.t() | nil) ::
          map() | nil
  def maybe_inject_overlay(tree, overlay) do
    Plushie.Dev.RebuildingOverlay.maybe_inject(tree, overlay)
  end

  # -- Private ----------------------------------------------------------------

  defp notify_bridge(%{bridge: nil}, _fun), do: :ok
  defp notify_bridge(%{bridge: bridge}, fun), do: fun.(bridge)
end
