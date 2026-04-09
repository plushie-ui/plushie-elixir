defmodule Plushie.UI.WidgetSetTest do
  use ExUnit.Case, async: true

  # A simple override widget that wraps the built-in button
  # with different defaults.
  defmodule FancyButton do
    use Plushie.Widget

    widget :button do
      field :label, :string
      field :style, :atom, default: :primary
    end

    def view(id, props) do
      import Plushie.UI

      button(id, props.label || "Fancy", style: props.style, padding: 16)
    end
  end

  # A widget set that overrides button with FancyButton.
  defmodule FancyUI do
    use Plushie.UI.WidgetSet,
      override: [button: FancyButton]
  end

  describe "WidgetSet override" do
    test "overridden button uses the override module" do
      use FancyUI

      # button/2 resolves to FancyButton. View-based widgets produce a
      # widget_placeholder node with the module in __widget__ metadata.
      node = button("save", label: "Save")
      assert node.type == "widget_placeholder"
      assert node.props[:__widget__].module == FancyButton
    end

    test "non-overridden widgets use built-in modules" do
      use FancyUI

      node = text("greeting", "Hello")
      assert node.type == "text"
    end
  end

  describe "validation" do
    test "raises on unknown widget name" do
      assert_raise ArgumentError, ~r/not a macro exported by Plushie.UI/, fn ->
        Code.compile_string("""
        defmodule BadOverride do
          use Plushie.UI.WidgetSet,
            override: [nonexistent_widget: SomeModule]
        end
        """)
      end
    end
  end

  # Simple node finder for test assertions.
  defp find_node(%{id: id} = node, target) when id == target, do: node

  defp find_node(%{children: children}, target) do
    Enum.find_value(children, fn child -> find_node(child, target) end)
  end

  defp find_node(_, _), do: nil
end
