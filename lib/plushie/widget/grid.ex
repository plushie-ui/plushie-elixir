defmodule Plushie.Widget.Grid do
  @moduledoc """
  Grid layout, arranges children in a fixed-column grid.
  """

  use Plushie.Widget

  defmodule Validation do
    @moduledoc false

    defmacro __before_compile__(_env) do
      quote do
        defoverridable num_columns: 2

        def num_columns(%__MODULE__{} = grid, nil), do: %{grid | num_columns: nil}

        def num_columns(%__MODULE__{} = grid, value) when is_integer(value) and value > 0,
          do: %{grid | num_columns: value}

        def num_columns(%__MODULE__{} = grid, value) do
          raise ArgumentError,
                "grid #{inspect(grid.id)}: num_columns must be a positive integer, got: #{inspect(value)}"
        end
      end
    end
  end

  @before_compile Validation

  # No a11y defaults: layout containers are transparent to AT

  widget :grid, container: true do
    field :num_columns, :integer, doc: "Number of columns. Default: 1."
    field :spacing, :float, doc: "Spacing between grid cells in pixels. Default: 0."
    field :width, :float, doc: "Grid width in pixels."
    field :height, :float, doc: "Grid height in pixels."

    field :column_width, Plushie.Type.Length,
      doc: "Width of each column. Accepts `:fill`, `:shrink`, `{:fill_portion, n}`, or a number."

    field :row_height, Plushie.Type.Length,
      doc: "Height of each row. Accepts `:fill`, `:shrink`, `{:fill_portion, n}`, or a number."

    field :fluid, :float,
      doc: "Enables fluid grid mode. Value is max cell width; columns auto-wrap."

    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
