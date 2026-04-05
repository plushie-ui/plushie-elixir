defmodule Plushie.Widget.Pin.SingleChild do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      defoverridable build: 1

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(w.id, "pin", Enum.reverse(w.children))
        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Pin do
  @moduledoc """
  Pin layout, positions child at absolute coordinates.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Pin.SingleChild

  widget :pin, container: true do
    field :x, :float, doc: "X position in pixels. Default: 0."
    field :y, :float, doc: "Y position in pixels. Default: 0."
    field :width, Plushie.Type.Length, doc: "Pin container width. Default: shrink."
    field :height, Plushie.Type.Length, doc: "Pin container height. Default: shrink."
  end
end
