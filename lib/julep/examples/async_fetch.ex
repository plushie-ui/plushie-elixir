defmodule Julep.Examples.AsyncFetch do
  @moduledoc """
  Async command example -- a button that triggers background work.

  Demonstrates:
  - `Julep.Command.async/2` for off-thread work
  - Pattern matching on `%Async{tag: ..., result: ...}` for success/error
  - Loading state management
  - Extracting view helpers for reuse
  """

  use Julep.App

  alias Julep.Command
  alias Julep.Event.{Async, Widget}

  # -- Init -------------------------------------------------------------------

  def init(_opts) do
    %{status: :idle, result: nil, error: nil}
  end

  # -- Update -----------------------------------------------------------------

  def update(model, %Widget{type: :click, id: "fetch"}) do
    cmd =
      Command.async(fn ->
        # Simulate a slow network call
        Process.sleep(500)
        {:ok, "Fetched at #{Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")}"}
      end, :fetch_result)

    {%{model | status: :loading, result: nil, error: nil}, cmd}
  end

  def update(model, %Async{tag: :fetch_result, result: {:ok, value}}) do
    %{model | status: :done, result: value}
  end

  def update(model, %Async{tag: :fetch_result, result: {:error, reason}}) do
    %{model | status: :error, error: inspect(reason)}
  end

  def update(model, _event), do: model

  # -- View -------------------------------------------------------------------

  def view(model) do
    import Julep.UI

    window "main", title: "Async Fetch" do
      column padding: 24, spacing: 16, width: :fill do
        text("header", "Async Command Demo", size: 20)
        button("fetch", "Fetch Data")
        status_message(model)
      end
    end
  end

  defp status_message(%{status: :idle}) do
    import Julep.UI
    text("status", "Press the button to start", color: "#888888")
  end

  defp status_message(%{status: :loading}) do
    import Julep.UI
    text("status", "Loading...", color: "#cc8800")
  end

  defp status_message(%{status: :done, result: result}) do
    import Julep.UI

    column spacing: 4 do
      text("label", "Result:", size: 14)
      text("result", result, color: "#22aa44")
    end
  end

  defp status_message(%{status: :error, error: error}) do
    import Julep.UI
    text("error", "Error: #{error}", color: "#cc2222")
  end
end
