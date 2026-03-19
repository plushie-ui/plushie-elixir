defmodule Julep.Event do
  @moduledoc "Event types delivered to `update/2`."

  alias Julep.Event.{
    Async,
    Canvas,
    Effect,
    Ime,
    Key,
    Modifiers,
    Mouse,
    MouseArea,
    Pane,
    Sensor,
    Stream,
    System,
    Timer,
    Touch,
    Widget,
    Window
  }

  @type t ::
          Widget.t()
          | Key.t()
          | Modifiers.t()
          | Mouse.t()
          | Touch.t()
          | Ime.t()
          | Window.t()
          | Canvas.t()
          | MouseArea.t()
          | Pane.t()
          | Sensor.t()
          | Effect.t()
          | System.t()
          | Timer.t()
          | Async.t()
          | Stream.t()

  @doc """
  Returns the full scoped path as a forward-order string.

  Works with any event struct that has `id` and `scope` fields.

  ## Examples

      iex> Julep.Event.target(%Julep.Event.Widget{type: :click, id: "save", scope: []})
      "save"

      iex> Julep.Event.target(%Julep.Event.Widget{type: :click, id: "save", scope: ["form", "sidebar"]})
      "sidebar/form/save"
  """
  @spec target(event :: struct()) :: String.t()
  def target(%{id: id, scope: []}), do: id
  def target(%{id: id, scope: scope}), do: Enum.join(Enum.reverse([id | scope]), "/")
end
