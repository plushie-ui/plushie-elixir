defmodule Plushie.Widget.Floating.SingleChild do
  @moduledoc false

  defmacro __before_compile__(_env) do
    quote do
      defoverridable build: 1

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(w.id, "floating", Enum.reverse(w.children))
        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Floating do
  @moduledoc """
  Floating overlay, positions child with optional translation and scaling.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Floating.SingleChild

  widget :float, container: true do
    field :translate_x, :float, doc: "Horizontal translation in pixels. Default: 0."
    field :translate_y, :float, doc: "Vertical translation in pixels. Default: 0."
    field :scale, :float, doc: "Scale factor for the child content."
    field :width, Plushie.Type.Length, doc: "Float width."
    field :height, Plushie.Type.Length, doc: "Float height."
  end
end
