defmodule Plushie.Widget.Sensor.Extras do
  @moduledoc false

  # Overrides on_resize/2 to coerce atoms to strings.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable on_resize: 2

      @doc "Sets the event tag for resize events. Atoms are coerced to strings."
      def on_resize(%__MODULE__{} = sensor, nil),
        do: %{sensor | on_resize: nil}

      def on_resize(%__MODULE__{} = sensor, tag) when is_atom(tag),
        do: %{sensor | on_resize: Atom.to_string(tag)}

      def on_resize(%__MODULE__{} = sensor, tag) when is_binary(tag),
        do: %{sensor | on_resize: tag}
    end
  end
end

defmodule Plushie.Widget.Sensor do
  @moduledoc """
  Sensor, detects visibility and size changes on child content.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Sensor.Extras

  widget :sensor, container: :single do
    field :delay, :integer, doc: "Delay in milliseconds before emitting events."
    field :anticipate, :float, doc: "Distance in pixels to anticipate visibility."
    field :on_resize, :string, doc: "Event tag for resize events."
  end
end
