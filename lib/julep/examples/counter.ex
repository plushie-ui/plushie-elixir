defmodule Julep.Examples.Counter do
  @moduledoc """
  Minimal counter example.

  Demonstrates:
  - Button click handling via `%Widget{type: :click}`
  - Model updates from events
  - Basic column/row layout
  """

  use Julep.App

  alias Julep.Event.Widget

  import Julep.UI
  def init(_opts), do: %{count: 0}

  def update(model, %Widget{type: :click, id: "increment"}), do: %{model | count: model.count + 1}
  def update(model, %Widget{type: :click, id: "decrement"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  def view(model) do

    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")

        row spacing: 8 do
          button("increment", "+")
          button("decrement", "-")
        end
      end
    end
  end
end
