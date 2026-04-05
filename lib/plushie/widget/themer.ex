defmodule Plushie.Widget.Themer.Extras do
  @moduledoc false

  # Overrides new/2 to accept either keyword opts or a direct theme value.
  # Overrides build/1 to validate single child.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable new: 2, build: 1

      @doc "Creates a new themer. Accepts keyword opts or a direct theme value."
      def new(id, opts) when is_binary(id) and is_list(opts), do: super(id, opts)
      def new(id, theme) when is_binary(id), do: %__MODULE__{id: id, theme: theme}

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(w.id, "themer", Enum.reverse(w.children))
        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.Themer do
  @moduledoc """
  Per-subtree theme override, applies a different theme to a single child widget.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Themer.Extras

  widget :themer, container: true do
    field :theme, :any, doc: "Built-in theme atom (e.g. `:dark`, `:nord`) or custom palette map."
  end
end
