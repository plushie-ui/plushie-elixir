defmodule Julep.Examples.Counter do
  use Julep.App

  def init(_opts), do: %{count: 0}

  def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
  def update(model, {:click, "decrement"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("Count: #{model.count}")

        row spacing: 8 do
          button("increment", "+")
          button("decrement", "-")
        end
      end
    end
  end
end
