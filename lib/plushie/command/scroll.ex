defmodule Plushie.Command.Scroll do
  @moduledoc """
  Scroll commands: absolute, relative, and snap positioning.

  All functions support window-qualified paths (`"window#widget"`).

  ## Example

      def update(model, %WidgetEvent{type: :click, id: "to-top"}) do
        {model, Command.Scroll.snap_to("main#content", 0.0, 0.0)}
      end
  """

  use Plushie.Command

  command :scroll_to, fields: [x: :float, y: :float]
  command :snap_to, fields: [x: :float, y: :float]
  command :snap_to_end
  command :scroll_by, fields: [x: :float, y: :float]
end
