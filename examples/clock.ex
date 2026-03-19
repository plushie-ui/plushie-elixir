defmodule Clock do
  @moduledoc """
  Clock example showing the current time, updated every second.

  Demonstrates:
  - `Toddy.Subscription.every/2` for timer-based updates
  - Pattern matching on `%Timer{tag: :tick}` in `update/2`
  - Simple model with derived display value
  """

  use Toddy.App

  import Toddy.UI

  alias Toddy.Event.Timer
  alias Toddy.Subscription

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{time: current_time()}
  end

  # -- update ----------------------------------------------------------------

  def update(model, %Timer{tag: :tick}) do
    %{model | time: current_time()}
  end

  def update(model, _event), do: model

  # -- subscribe -------------------------------------------------------------

  def subscribe(_model) do
    [Subscription.every(1000, :tick)]
  end

  # -- view ------------------------------------------------------------------

  def view(model) do

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
