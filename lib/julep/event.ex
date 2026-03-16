defmodule Julep.Event do
  @moduledoc "Event types delivered to `update/2`."

  alias Julep.Event.{Widget, Key, Modifiers, Mouse, Touch, Ime, Window, Canvas, MouseArea, Pane, Sensor, Effect, System}

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
end
