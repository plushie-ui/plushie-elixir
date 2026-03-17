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
end
