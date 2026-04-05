defmodule Plushie.Widget.Responsive.SingleChild do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      defoverridable build: 1

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(w.id, "responsive", Enum.reverse(w.children))
        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Responsive do
  @moduledoc """
  Responsive layout, adapts to available size by reporting resize events.

  The renderer wraps child content in a sensor that sends
  `%WidgetEvent{type: :resize}` events so the Elixir app can adjust
  its view based on the measured size.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Responsive.SingleChild

  widget :responsive, container: true do
    field :width, Plushie.Type.Length, doc: "Container width. Default: fill."
    field :height, Plushie.Type.Length, doc: "Container height. Default: fill."
  end
end
