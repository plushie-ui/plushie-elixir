defmodule Plushie.Widget.PointerArea.Extras do
  @moduledoc false

  # Overrides on_press/2 and on_release/2 to coerce atoms to strings.
  # Overrides build/1 to validate single child.
  defmacro __before_compile__(_env) do
    quote do
      defoverridable on_press: 2, on_release: 2, build: 1

      @doc "Sets the event tag for left mouse press events. Atoms are coerced to strings."
      def on_press(%__MODULE__{} = ma, tag) when is_atom(tag),
        do: %{ma | on_press: Atom.to_string(tag)}

      def on_press(%__MODULE__{} = ma, tag) when is_binary(tag),
        do: %{ma | on_press: tag}

      @doc "Sets the event tag for left mouse release events. Atoms are coerced to strings."
      def on_release(%__MODULE__{} = ma, tag) when is_atom(tag),
        do: %{ma | on_release: Atom.to_string(tag)}

      def on_release(%__MODULE__{} = ma, tag) when is_binary(tag),
        do: %{ma | on_release: tag}

      def build(%__MODULE__{} = w) do
        Plushie.Widget.Build.validate_single_child!(
          w.id,
          "pointer_area",
          Enum.reverse(w.children)
        )

        super(w)
      end
    end
  end
end

defmodule Plushie.Widget.PointerArea do
  @moduledoc """
  Pointer area, captures mouse events on child content.

  Wraps child content and emits click events for various mouse buttons,
  hover enter/exit, cursor movement, scroll, and double-click events.
  Optionally sets the mouse cursor when hovering the area.
  """

  use Plushie.Widget

  @before_compile Plushie.Widget.PointerArea.Extras

  widget :pointer_area, container: true do
    field :cursor, :atom, doc: "Mouse cursor to show on hover (e.g. `:pointer`, `:grab`)."
    field :on_press, :string, doc: "Event tag for left mouse press events."
    field :on_release, :string, doc: "Event tag for left mouse release events."
    field :on_right_press, :boolean, doc: "Enable right mouse press events."
    field :on_right_release, :boolean, doc: "Enable right mouse release events."
    field :on_middle_press, :boolean, doc: "Enable middle mouse press events."
    field :on_middle_release, :boolean, doc: "Enable middle mouse release events."
    field :on_double_click, :boolean, doc: "Enable double-click events."
    field :on_enter, :boolean, doc: "Enable cursor enter events."
    field :on_exit, :boolean, doc: "Enable cursor exit events."
    field :on_move, :boolean, doc: "Enable cursor move events."
    field :on_scroll, :boolean, doc: "Enable scroll wheel events."
  end
end
