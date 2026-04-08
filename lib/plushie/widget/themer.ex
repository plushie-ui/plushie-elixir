defmodule Plushie.Widget.Themer.Extras do
  @moduledoc false

  # Overrides new/2 to accept either keyword opts or a direct theme value.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable new: 2

      @doc "Creates a new themer. Accepts keyword opts or a direct theme value."
      def new(id, opts) when is_binary(id) and is_list(opts), do: super(id, opts)
      def new(id, theme) when is_binary(id), do: %__MODULE__{id: id, theme: theme}
    end
  end
end

defmodule Plushie.Widget.Themer do
  @moduledoc """
  Per-subtree theme override, applies a different theme to a single child widget.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.Themer.Extras

  # No a11y defaults: layout containers are transparent to AT

  widget :themer, container: :single do
    field :theme, :any, doc: "Built-in theme atom (e.g. `:dark`, `:nord`) or custom palette map."
    field :event_rate, :integer, doc: "Max events per second for coalescable events."
    field :a11y, Plushie.Type.A11y, doc: "Accessibility annotations."
  end
end
