defmodule Julep.ExtensionMacroTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Test modules: native_widget
  # ---------------------------------------------------------------------------

  defmodule GaugeExtension do
    use Julep.Extension, :native_widget

    widget :gauge

    prop :value, :number
    prop :min, :number, default: 0
    prop :max, :number, default: 100
    prop :color, :color, default: :blue
    prop :width, :length
    prop :height, :length
    prop :label, :string

    rust_crate "native/my_gauge"
    rust_constructor "my_gauge::GaugeExtension::new()"

    command :set_value, value: :number
    command :reset
  end

  defmodule ContainerNative do
    use Julep.Extension, :native_widget

    widget :native_panel, container: true

    prop :title, :string
    prop :padding, :padding
    prop :align, :alignment, default: :center

    rust_crate "native/panel"
    rust_constructor "panel::PanelExtension::new()"
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (leaf, node builder)
  # ---------------------------------------------------------------------------

  defmodule BadgeWidget do
    use Julep.Extension, :widget

    widget :badge

    prop :label, :string
    prop :color, :color, default: :red
    prop :size, :number, default: 14
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (container, node builder)
  # ---------------------------------------------------------------------------

  defmodule CardWidget do
    use Julep.Extension, :widget

    widget :card, container: true

    prop :title, :string
    prop :style, :style, default: :primary
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with render/2)
  # ---------------------------------------------------------------------------

  defmodule StatusIndicator do
    use Julep.Extension, :widget

    widget :status_indicator

    prop :status, :atom
    prop :label, :string

    def render(id, props) do
      status_str = Map.get(props, :status, "unknown")
      label = Map.get(props, :label, "Status")
      %{id: id, type: "text", props: %{"content" => "#{label}: #{status_str}"}, children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with render/3, container)
  # ---------------------------------------------------------------------------

  defmodule Wrapper do
    use Julep.Extension, :widget

    widget :wrapper, container: true

    prop :border, :boolean, default: false

    def render(id, props, children) do
      border_val = Map.get(props, :border, false)

      %{
        id: id,
        type: "container",
        props: %{"border" => border_val},
        children: children
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Test modules: prop type coverage
  # ---------------------------------------------------------------------------

  defmodule TypeKitchen do
    use Julep.Extension, :widget

    widget :type_kitchen

    prop :a_number, :number
    prop :a_string, :string
    prop :a_bool, :boolean
    prop :a_color, :color
    prop :a_length, :length
    prop :a_padding, :padding
    prop :an_alignment, :alignment
    prop :an_atom, :atom
    prop :a_map, :map
    prop :a_list, {:list, :string}
    prop :any_val, :any
    prop :a_style, :style
    prop :a_font, :font
  end

  # =========================================================================
  # Tests
  # =========================================================================

  # --- 1. native_widget behaviour callbacks ---------------------------------

  describe "native_widget behaviour callbacks" do
    test "type_names/0 returns the widget type as a string list" do
      assert GaugeExtension.type_names() == ["gauge"]
    end

    test "native_crate/0 returns the crate path" do
      assert GaugeExtension.native_crate() == "native/my_gauge"
    end

    test "rust_constructor/0 returns the constructor expression" do
      assert GaugeExtension.rust_constructor() == "my_gauge::GaugeExtension::new()"
    end
  end

  # --- 2. widget new/2 produces correct tree nodes --------------------------

  describe "widget new/2 produces correct tree nodes" do
    test "leaf widget builds node with type and props" do
      node = BadgeWidget.new("b1", label: "New")
      assert node.id == "b1"
      assert node.type == "badge"
      assert node.props["label"] == "New"
      assert node.children == []
    end

    test "native widget builds node with type and props" do
      node = GaugeExtension.new("g1", value: 42)
      assert node.id == "g1"
      assert node.type == "gauge"
      assert node.props["value"] == 42
      assert node.props["min"] == 0
      assert node.props["max"] == 100
      assert node.children == []
    end

    test "container widget accepts children via :do" do
      child = %{id: "c", type: "text", props: %{}, children: []}
      node = CardWidget.new("card1", title: "Hello", do: [child])
      assert node.id == "card1"
      assert node.type == "card"
      assert node.props["title"] == "Hello"
      assert length(node.children) == 1
    end
  end

  # --- 3. unknown keys rejected --------------------------------------------

  describe "prop validation rejects unknown keys" do
    test "raises ArgumentError for unknown option" do
      assert_raise ArgumentError, ~r/unknown option/, fn ->
        BadgeWidget.new("b1", label: "X", bogus: true)
      end
    end

    test "raises ArgumentError listing the unknown keys" do
      assert_raise ArgumentError, ~r/bogus/, fn ->
        GaugeExtension.new("g1", bogus: 123)
      end
    end
  end

  # --- 4. defaults applied --------------------------------------------------

  describe "prop defaults are applied" do
    test "color default is cast and applied" do
      node = BadgeWidget.new("b1")
      assert node.props["color"] == Julep.Iced.Color.cast(:red)
      assert node.props["size"] == 14
    end

    test "number defaults applied for native" do
      node = GaugeExtension.new("g1", value: 50)
      assert node.props["min"] == 0
      assert node.props["max"] == 100
    end

    test "props without defaults are omitted when not provided" do
      node = GaugeExtension.new("g1", value: 50)
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "label")
    end
  end

  # --- 5. prop type encoding ------------------------------------------------

  describe "prop type encoding" do
    test "color cast normalizes named atoms" do
      node = BadgeWidget.new("b1", color: :cornflowerblue)
      assert node.props["color"] == "#6495ed"
    end

    test "color cast normalizes hex strings" do
      node = BadgeWidget.new("b1", color: "#FF0000")
      assert node.props["color"] == "#ff0000"
    end

    test "length values are encoded" do
      node = GaugeExtension.new("g1", value: 0, width: :fill)
      assert node.props["width"] == "fill"
    end

    test "alignment values are encoded" do
      node = ContainerNative.new("p1")
      assert node.props["align"] == "center"
    end

    test "atom values are converted to strings" do
      node = TypeKitchen.new("tk", an_atom: :hello)
      assert node.props["an_atom"] == "hello"
    end

    test "number passes through" do
      node = TypeKitchen.new("tk", a_number: 42)
      assert node.props["a_number"] == 42
    end

    test "string passes through" do
      node = TypeKitchen.new("tk", a_string: "hi")
      assert node.props["a_string"] == "hi"
    end

    test "boolean passes through" do
      node = TypeKitchen.new("tk", a_bool: true)
      assert node.props["a_bool"] == true
    end

    test "map passes through" do
      node = TypeKitchen.new("tk", a_map: %{x: 1})
      assert node.props["a_map"] == %{x: 1}
    end

    test "list passes through" do
      node = TypeKitchen.new("tk", a_list: ["a", "b"])
      assert node.props["a_list"] == ["a", "b"]
    end
  end

  # --- 6. command generation (native) ---------------------------------------

  describe "command generation for native widgets" do
    test "parameterized command returns extension_command" do
      cmd = GaugeExtension.set_value("g1", 75)
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "g1"
      assert cmd.payload.op == "set_value"
      assert cmd.payload.payload == %{value: 75}
    end

    test "parameterless command returns extension_command" do
      cmd = GaugeExtension.reset("g1")
      assert cmd.type == :extension_command
      assert cmd.payload.node_id == "g1"
      assert cmd.payload.op == "reset"
      assert cmd.payload.payload == %{}
    end

    test "command enforces widget_id is binary" do
      assert_raise FunctionClauseError, fn ->
        GaugeExtension.set_value(:not_binary, 42)
      end
    end

    test "command enforces type guard on params" do
      assert_raise FunctionClauseError, fn ->
        GaugeExtension.set_value("g1", "not a number")
      end
    end
  end

  # --- 7. container: true accepts do blocks ---------------------------------

  describe "container widgets accept do blocks" do
    test "card container captures children" do
      child1 = %{id: "t1", type: "text", props: %{}, children: []}
      child2 = %{id: "t2", type: "text", props: %{}, children: []}
      node = CardWidget.new("c1", title: "Test", do: [child1, child2])
      assert length(node.children) == 2
    end

    test "native container captures children" do
      child = %{id: "inner", type: "text", props: %{}, children: []}
      node = ContainerNative.new("p1", title: "Panel", do: [child])
      assert length(node.children) == 1
      assert node.type == "native_panel"
    end

    test "container with no children defaults to empty list" do
      node = CardWidget.new("c1", title: "Empty")
      assert node.children == []
    end
  end

  # --- 8. composite with render callback ------------------------------------

  describe "composite with render callback" do
    test "render/2 composite produces custom output" do
      node = StatusIndicator.new("si1", status: :ok, label: "Health")
      assert node.type == "text"
      assert node.props["content"] == "Health: ok"
    end

    test "render/3 composite receives children" do
      child = %{id: "x", type: "text", props: %{}, children: []}
      node = Wrapper.new("w1", border: true, do: [child])
      assert node.type == "container"
      assert node.props["border"] == true
      assert length(node.children) == 1
    end
  end

  # --- 9. compile error on missing widget declaration -----------------------

  describe "compile errors" do
    test "missing widget declaration raises CompileError" do
      assert_raise CompileError, ~r/missing.*widget :type_name/, fn ->
        Code.compile_string("""
        defmodule MissingWidget do
          use Julep.Extension, :widget

          prop :foo, :string
        end
        """)
      end
    end

    # --- 10. compile error on missing rust_crate for native -------------------

    test "missing rust_crate raises CompileError" do
      assert_raise CompileError, ~r/missing.*rust_crate/, fn ->
        Code.compile_string("""
        defmodule MissingCrate do
          use Julep.Extension, :native_widget

          widget :foo
          rust_constructor "foo::Foo::new()"
        end
        """)
      end
    end

    test "missing rust_constructor raises CompileError" do
      assert_raise CompileError, ~r/missing.*rust_constructor/, fn ->
        Code.compile_string("""
        defmodule MissingConstructor do
          use Julep.Extension, :native_widget

          widget :foo
          rust_crate "native/foo"
        end
        """)
      end
    end
  end

  # --- a11y prop support ----------------------------------------------------

  describe "a11y prop" do
    test "a11y prop is encoded on leaf widget" do
      node = BadgeWidget.new("b1", a11y: %{role: :alert, label: "New items"})
      assert node.props["a11y"]["role"] == "alert"
      assert node.props["a11y"]["label"] == "New items"
    end

    test "a11y prop is encoded on native widget" do
      node = GaugeExtension.new("g1", value: 50, a11y: %{role: :meter, label: "CPU"})
      assert node.props["a11y"]["role"] == "meter"
      assert node.props["a11y"]["label"] == "CPU"
    end

    test "without a11y prop, no a11y key in props" do
      node = BadgeWidget.new("b1")
      refute Map.has_key?(node.props, "a11y")
    end
  end

  # --- __prop_names__ -------------------------------------------------------

  describe "__prop_names__/0" do
    test "returns declared prop names plus :a11y" do
      names = BadgeWidget.__prop_names__()
      assert :label in names
      assert :color in names
      assert :size in names
      assert :a11y in names
    end
  end

  # --- widget kind callback for :widget doesn't have native callbacks -------

  describe "widget kind does not define native callbacks" do
    test "widget extension does not export native_crate/0" do
      refute function_exported?(BadgeWidget, :native_crate, 0)
    end

    test "widget extension does not export rust_constructor/0" do
      refute function_exported?(BadgeWidget, :rust_constructor, 0)
    end
  end
end
