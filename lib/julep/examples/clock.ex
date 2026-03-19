defmodule Julep.Examples.Clock do
  @moduledoc """
  Clock example showing the current time, updated every second.

  Demonstrates `Julep.Subscription.every/2` for timer-based updates.
  The subscription delivers `%Julep.Event.Timer{tag: :tick, timestamp: ...}` to `update/2` each second.
  """

  use Julep.App

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{time: current_time()}
  end

  # -- update ----------------------------------------------------------------

  def update(model, %Julep.Event.Timer{tag: :tick}) do
    %{model | time: current_time()}
  end

  def update(model, _event), do: model

  # -- subscribe -------------------------------------------------------------

  def subscribe(_model) do
    [Julep.Subscription.every(1000, :tick)]
  end

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Julep.UI

    window "main", title: "Clock" do
      column padding: 24, spacing: 16, width: :fill, align_x: :center do
        text("clock_display", model.time, size: 48)
        text("subtitle", "Updates every second", size: 12, color: "#888888")
      end
    end
  end

  # -- private ---------------------------------------------------------------

  defp current_time do
    Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
  end
end
