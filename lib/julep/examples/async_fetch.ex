defmodule Julep.Examples.AsyncFetch do
  @moduledoc """
  Async command example with a button that triggers background work.

  Demonstrates `Julep.Command.async/2` for running expensive operations
  off the main update loop. The result is delivered back to `update/2`
  as `{:fetch_result, value}`.
  """

  use Julep.App

  alias Julep.Event.Widget

  # -- init ------------------------------------------------------------------

  def init(_opts) do
    %{status: :idle, result: nil}
  end

  # -- update ----------------------------------------------------------------

  def update(model, %Widget{type: :click, id: "fetch"}) do
    cmd =
      Julep.Command.async(
        fn ->
          # Simulate slow work
          Process.sleep(500)
          "Fetched at #{Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}"
        end,
        :fetch_result
      )

    {%{model | status: :loading, result: nil}, cmd}
  end

  def update(model, {:fetch_result, value}) do
    %{model | status: :done, result: value}
  end

  def update(model, _event), do: model

  # -- view ------------------------------------------------------------------

  def view(model) do
    import Julep.UI

    window "main", title: "Async Fetch" do
      column padding: 24, spacing: 16, width: :fill do
        text("Async Command Demo", size: 20, id: "header")

        button("fetch", "Fetch Data")

        case model.status do
          :idle ->
            text("Press the button to start", color: "#888888", id: "status")

          :loading ->
            text("Loading...", color: "#cc8800", id: "status")

          :done ->
            column spacing: 4 do
              text("Result:", size: 14, id: "status")
              text(model.result, color: "#22aa44", id: "result")
            end
        end
      end
    end
  end
end
