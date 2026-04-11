defprotocol Plushie.Tree.Node do
  @moduledoc """
  Protocol for converting typed structs to `ui_node()` maps.

  Widgets and canvas elements define typed structs with builder
  functions. This protocol converts those structs to the plain
  `%{id, type, props, children}` maps that the runtime, tree differ,
  and wire encoder expect.

  The runtime calls this protocol automatically during tree normalization,
  so structs can be returned directly from `view/1` without an
  explicit `build/1` call.

  ## Example

      alias Plushie.Widget.Button

      # Builder pattern -- struct returned, runtime converts automatically
      Button.new("btn", "Click me")
      |> Button.style(:primary)
      |> Button.width(:fill)

      # Explicit conversion if you want the map
      Button.new("btn", "Click me")
      |> Button.style(:primary)
      |> Button.build()
      #=> %{id: "btn", type: "button", props: %{label: "Click me", style: "primary"}, children: []}
  """

  @typedoc "A UI tree node map. Every widget builder returns this shape."
  @type ui_node :: %{
          id: String.t(),
          type: String.t(),
          props: %{optional(atom()) => term()},
          children: [ui_node()]
        }

  @doc "Converts a struct to a `Plushie.Tree.Node.ui_node()` map."
  @spec to_node(t) :: ui_node()
  def to_node(widget)
end
