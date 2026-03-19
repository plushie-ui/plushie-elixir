defprotocol Julep.Iced.Widget do
  @moduledoc """
  Protocol for converting typed widget structs to `ui_node()` maps.

  Each widget module under `Julep.Iced.Widget.*` defines a struct with
  typed fields and builder functions mirroring iced's API. This protocol
  converts those structs to the plain `%{id, type, props, children}` maps
  that the runtime, tree differ, and wire encoder expect.

  The runtime calls this protocol automatically during tree normalization,
  so widget structs can be returned directly from `view/1` without an
  explicit `build/1` call.

  ## Example

      alias Julep.Iced.Widget.Button

      # Builder pattern -- struct returned, runtime converts automatically
      Button.new("btn", "Click me")
      |> Button.style(:primary)
      |> Button.width(:fill)

      # Explicit conversion if you want the map
      Button.new("btn", "Click me")
      |> Button.style(:primary)
      |> Button.build()
      #=> %{id: "btn", type: "button", props: %{"label" => "Click me", "style" => "primary"}, children: []}
  """

  @doc "Converts a widget struct to a `Julep.Iced.ui_node()` map."
  @spec to_node(t) :: Julep.Iced.ui_node()
  def to_node(widget)
end
