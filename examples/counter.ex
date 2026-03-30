defmodule Counter do
  @moduledoc """
  Minimal counter example.

  Demonstrates:
  - Button click handling via `%WidgetEvent{type: :click}`
  - Model updates from events
  - Basic column/row layout
  """

  use Plushie.App

  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "inc"}), do: %{model | count: model.count + 1}
  def update(model, %WidgetEvent{type: :click, id: "dec"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  def view(model) do
    import Plushie.UI

    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")

        row spacing: 8 do
          button("inc", "+")
          button("dec", "-")
        end
      end
    end
  end
end
