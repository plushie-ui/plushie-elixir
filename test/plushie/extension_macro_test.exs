defmodule Plushie.ExtensionMacroTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Test modules: native_widget
  # ---------------------------------------------------------------------------

  defmodule GaugeExtension do
    use Plushie.Extension, :native_widget

    widget(:gauge)
    event(:calibrated, value: :number)

    prop(:value, :number)
    prop(:min, :number, default: 0)
    prop(:max, :number, default: 100)
    prop(:color, :color, default: :blue)
    prop(:width, :length)
    prop(:height, :length)
    prop(:label, :string)

    rust_crate("native/my_gauge")
    rust_constructor("my_gauge::GaugeExtension::new()")

    command(:set_value, value: :number)
    command(:reset)
  end

  defmodule ContainerNative do
    use Plushie.Extension, :native_widget

    widget(:native_panel, container: true)

    prop(:title, :string)
    prop(:padding, :padding)
    prop(:align, :alignment, default: :center)

    rust_crate("native/panel")
    rust_constructor("panel::PanelExtension::new()")
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (leaf, node builder)
  # ---------------------------------------------------------------------------

  defmodule BadgeWidget do
    use Plushie.Extension, :widget

    widget(:badge)

    prop(:label, :string)
    prop(:color, :color, default: :red)
    prop(:size, :number, default: 14)
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (container, node builder)
  # ---------------------------------------------------------------------------

  defmodule CardWidget do
    use Plushie.Extension, :widget

    widget(:card, container: true)

    prop(:title, :string)
    prop(:style, :style, default: :primary)
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with render/2)
  # ---------------------------------------------------------------------------

  defmodule StatusIndicator do
    use Plushie.Extension, :widget

    widget(:status_indicator)

    prop(:status, :atom)
    prop(:label, :string)

    def render(id, props) do
      status_str = Map.get(props, :status, "unknown")
      label = Map.get(props, :label, "Status")
      %{id: id, type: "text", props: %{content: "#{label}: #{status_str}"}, children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with render/3, container)
  # ---------------------------------------------------------------------------

  defmodule Wrapper do
    use Plushie.Extension, :widget

    widget(:wrapper)

    prop(:border, :boolean, default: false)

    def render(id, props) do
      border_val = Map.get(props, :border, false)

      %{
        id: id,
        type: "container",
        props: %{border: border_val},
        children: []
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Test modules: prop type coverage
  # ---------------------------------------------------------------------------

  defmodule TypeKitchen do
    use Plushie.Extension, :widget

    widget(:type_kitchen)

    prop(:a_number, :number)
    prop(:a_string, :string)
    prop(:a_bool, :boolean)
    prop(:a_color, :color)
    prop(:a_length, :length)
    prop(:a_padding, :padding)
    prop(:an_alignment, :alignment)
    prop(:an_atom, :atom)
    prop(:a_map, :map)
    prop(:a_list, {:list, :string})
    prop(:any_val, :any)
    prop(:a_style, :style)
    prop(:a_font, :font)
  end

  # =========================================================================
  # Tests
  # =========================================================================

  # --- 1. native_widget behaviour callbacks ---------------------------------

  describe "native_widget behaviour callbacks" do
    test "type_names/0 returns the widget type as an atom list" do
      assert GaugeExtension.type_names() == [:gauge]
    end

    test "__widget_type__/0 and __events__/0 expose declared widget event metadata" do
      assert GaugeExtension.__widget_type__() == :gauge
      assert GaugeExtension.__events__() == [:calibrated]
    end

    test "native_crate/0 returns the crate path" do
      assert GaugeExtension.native_crate() == "native/my_gauge"
    end

    test "rust_constructor/0 returns the constructor expression" do
      assert GaugeExtension.rust_constructor() == "my_gauge::GaugeExtension::new()"
    end
  end

  # --- 2. widget new/2 produces correct tree nodes --------------------------

  describe "widget new/2 produces correct tree nodes (via build)" do
    test "leaf widget builds node with type and props" do
      node = BadgeWidget.new("b1", label: "New") |> BadgeWidget.build()
      assert node.id == "b1"
      assert node.type == "badge"
      assert node.props[:label] == "New"
      assert node.children == []
    end

    test "native widget builds node with type and props" do
      node = GaugeExtension.new("g1", value: 42) |> GaugeExtension.build()
      assert node.id == "g1"
      assert node.type == "gauge"
      assert node.props[:value] == 42
      assert node.props[:min] == 0
      assert node.props[:max] == 100
      assert node.props[:__extension_widget_type__] == :gauge
      assert node.props[:__extension_widget_events__] == [:calibrated]
      assert node.children == []
    end

    test "container widget accepts children via :do" do
      child = %{id: "c", type: "text", props: %{}, children: []}
      node = CardWidget.new("card1", title: "Hello", do: [child]) |> CardWidget.build()
      assert node.id == "card1"
      assert node.type == "card"
      assert node.props[:title] == "Hello"
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
      node = BadgeWidget.new("b1") |> BadgeWidget.build()
      assert node.props[:color] == Plushie.Type.Color.cast(:red)
      assert node.props[:size] == 14
    end

    test "number defaults applied for native" do
      node = GaugeExtension.new("g1", value: 50) |> GaugeExtension.build()
      assert node.props[:min] == 0
      assert node.props[:max] == 100
    end

    test "props without defaults are omitted when not provided" do
      node = GaugeExtension.new("g1", value: 50) |> GaugeExtension.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "label")
    end
  end

  # --- 5. prop type encoding ------------------------------------------------

  describe "prop type encoding" do
    test "color cast normalizes named atoms" do
      node = BadgeWidget.new("b1", color: :cornflowerblue) |> BadgeWidget.build()
      assert node.props[:color] == "#6495ed"
    end

    test "color cast normalizes hex strings" do
      node = BadgeWidget.new("b1", color: "#FF0000") |> BadgeWidget.build()
      assert node.props[:color] == "#ff0000"
    end

    test "length values are stored raw" do
      node = GaugeExtension.new("g1", value: 0, width: :fill) |> GaugeExtension.build()
      assert node.props[:width] == :fill
    end

    test "alignment values are stored raw" do
      node = ContainerNative.new("p1") |> ContainerNative.build()
      assert node.props[:align] == :center
    end

    test "atom values are stored raw" do
      node = TypeKitchen.new("tk", an_atom: :hello) |> TypeKitchen.build()
      assert node.props[:an_atom] == :hello
    end

    test "number passes through" do
      node = TypeKitchen.new("tk", a_number: 42) |> TypeKitchen.build()
      assert node.props[:a_number] == 42
    end

    test "string passes through" do
      node = TypeKitchen.new("tk", a_string: "hi") |> TypeKitchen.build()
      assert node.props[:a_string] == "hi"
    end

    test "boolean passes through" do
      node = TypeKitchen.new("tk", a_bool: true) |> TypeKitchen.build()
      assert node.props[:a_bool] == true
    end

    test "map passes through" do
      node = TypeKitchen.new("tk", a_map: %{x: 1}) |> TypeKitchen.build()
      assert node.props[:a_map] == %{x: 1}
    end

    test "list passes through" do
      node = TypeKitchen.new("tk", a_list: ["a", "b"]) |> TypeKitchen.build()
      assert node.props[:a_list] == ["a", "b"]
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
      node = CardWidget.new("c1", title: "Test", do: [child1, child2]) |> CardWidget.build()
      assert length(node.children) == 2
    end

    test "native container captures children" do
      child = %{id: "inner", type: "text", props: %{}, children: []}
      node = ContainerNative.new("p1", title: "Panel", do: [child]) |> ContainerNative.build()
      assert length(node.children) == 1
      assert node.type == "native_panel"
    end

    test "container with no children defaults to empty list" do
      node = CardWidget.new("c1", title: "Empty") |> CardWidget.build()
      assert node.children == []
    end
  end

  # --- 8. composite with render callback ------------------------------------

  describe "composite with render callback" do
    test "render/2 widget produces struct" do
      widget = StatusIndicator.new("si1", status: :ok, label: "Health")
      assert %StatusIndicator{id: "si1", status: :ok, label: "Health"} = widget
    end

    test "render/2 widget renders via to_node placeholder" do
      widget = StatusIndicator.new("si1", status: :ok, label: "Health")
      node = Plushie.Widget.to_node(widget)
      assert node.type == "widget_placeholder"
    end

    test "render/3 widget produces struct" do
      widget = Wrapper.new("w1", border: true)
      assert %Wrapper{id: "w1", border: true} = widget
    end
  end

  # --- 9. compile error on missing widget declaration -----------------------

  describe "compile errors" do
    test "missing widget declaration raises CompileError" do
      assert_raise CompileError, ~r/missing.*widget :type_name/, fn ->
        Code.compile_string("""
        defmodule MissingWidget do
          use Plushie.Extension, :widget

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
          use Plushie.Extension, :native_widget

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
          use Plushie.Extension, :native_widget

          widget :foo
          rust_crate "native/foo"
        end
        """)
      end
    end
  end

  # --- a11y prop support ----------------------------------------------------

  describe "a11y prop" do
    test "a11y prop is raw struct on leaf widget" do
      a11y = %{role: :alert, label: "New items"}
      node = BadgeWidget.new("b1", a11y: a11y) |> BadgeWidget.build()

      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :alert
      assert node.props[:a11y].label == "New items"
    end

    test "a11y prop is raw struct on native widget" do
      a11y = %{role: :meter, label: "CPU"}

      node =
        GaugeExtension.new("g1", value: 50, a11y: a11y)
        |> GaugeExtension.build()

      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :meter
      assert node.props[:a11y].label == "CPU"
    end

    test "without a11y prop, no a11y key in props" do
      node = BadgeWidget.new("b1") |> BadgeWidget.build()
      refute Map.has_key?(node.props, :a11y)
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

  # --- compile-time validation ------------------------------------------------

  describe "compile-time validation" do
    test "raises on invalid kind" do
      assert_raise ArgumentError, ~r/must be one of/, fn ->
        Code.compile_string("""
        defmodule TestInvalidKind do
          use Plushie.Extension, :invalid
        end
        """)
      end
    end

    test "raises on unknown prop type" do
      assert_raise CompileError, ~r/unsupported prop type.*:bogus_type/, fn ->
        Code.compile_string("""
        defmodule TestBadPropType do
          use Plushie.Extension, :widget

          widget :bad_prop
          prop :foo, :bogus_type
        end
        """)
      end
    end

    test "raises on unknown command param type" do
      assert_raise CompileError, ~r/unsupported command param type.*:widget_ref/, fn ->
        Code.compile_string("""
        defmodule TestBadCmdType do
          use Plushie.Extension, :native_widget

          widget :bad_cmd
          rust_crate "native/bad"
          rust_constructor "bad::Bad::new()"
          command :do_thing, target: :widget_ref
        end
        """)
      end
    end

    test "allows {:list, inner} prop type" do
      Code.compile_string("""
      defmodule TestListPropType do
        use Plushie.Extension, :widget

        widget :list_prop
        prop :items, {:list, :string}
      end
      """)
    end

    test "rejects {:list, bad_inner} prop type" do
      assert_raise CompileError, ~r/unsupported prop type.*\{:list, :widget_ref\}/, fn ->
        Code.compile_string("""
        defmodule TestBadListPropType do
          use Plushie.Extension, :widget

          widget :bad_list_prop
          prop :items, {:list, :widget_ref}
        end
        """)
      end
    end

    test "warns on duplicate prop names" do
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string("""
          defmodule TestDuplicateProps do
            use Plushie.Extension, :widget

            widget :dup_props
            prop :foo, :string
            prop :foo, :number
          end
          """)
        end)

      assert warnings =~ "duplicate prop names"
      assert warnings =~ "foo"
    end

    test "duplicate widget declaration warns" do
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string("""
          defmodule TestDuplicateWidget do
            use Plushie.Extension, :widget

            widget :first_name
            widget :second_name
          end
          """)
        end)

      assert warnings =~ "widget type already declared"
      assert warnings =~ "first_name"
    end
  end

  describe "reserved prop names" do
    test "raises on prop named :id" do
      assert_raise CompileError, ~r/prop name :id is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedId do
          use Plushie.Extension, :widget
          widget :bad
          prop :id, :string
        end
        """)
      end
    end

    test "raises on prop named :type" do
      assert_raise CompileError, ~r/prop name :type is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedType do
          use Plushie.Extension, :widget
          widget :bad
          prop :type, :string
        end
        """)
      end
    end

    test "raises on prop named :children" do
      assert_raise CompileError, ~r/prop name :children is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedChildren do
          use Plushie.Extension, :widget
          widget :bad
          prop :children, :any
        end
        """)
      end
    end

    test "raises on prop named :a11y" do
      assert_raise CompileError, ~r/prop name :a11y is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedA11y do
          use Plushie.Extension, :widget
          widget :bad
          prop :a11y, :map
        end
        """)
      end
    end
  end

  # --- struct API for non-composite widgets ---------------------------------

  describe "struct API for non-composite widgets" do
    test "new/2 returns a struct for leaf widget" do
      widget = BadgeWidget.new("b1")
      assert %BadgeWidget{} = widget
      assert widget.id == "b1"
    end

    test "new/2 returns a struct for native widget" do
      widget = GaugeExtension.new("g1", value: 42)
      assert %GaugeExtension{} = widget
      assert widget.id == "g1"
    end

    test "new/2 returns a struct for container widget" do
      widget = CardWidget.new("c1", title: "Hello")
      assert %CardWidget{} = widget
      assert widget.id == "c1"
    end

    test "setter functions return updated struct" do
      widget = BadgeWidget.new("b1") |> BadgeWidget.color("#ff0000")
      assert %BadgeWidget{} = widget
      assert widget.color == "#ff0000"
    end

    test "setter functions chain" do
      widget =
        BadgeWidget.new("b1")
        |> BadgeWidget.label("Hello")
        |> BadgeWidget.size(18)
        |> BadgeWidget.color(:green)

      assert widget.label == "Hello"
      assert widget.size == 18
      assert widget.color == Plushie.Type.Color.cast(:green)
    end

    test "with_options/2 applies multiple options" do
      widget = BadgeWidget.new("b1") |> BadgeWidget.with_options(label: "X", size: 20)
      assert widget.label == "X"
      assert widget.size == 20
    end

    test "build/1 converts struct to node map" do
      node = BadgeWidget.new("b1", label: "Test", color: "#00ff00") |> BadgeWidget.build()
      assert is_map(node)
      assert node.id == "b1"
      assert node.type == "badge"
      assert node.props[:label] == "Test"
      assert node.props[:color] == "#00ff00"
      assert node.children == []
    end

    test "build/1 on native widget converts struct to node map" do
      node = GaugeExtension.new("g1", value: 75, width: :fill) |> GaugeExtension.build()
      assert node.id == "g1"
      assert node.type == "gauge"
      assert node.props[:value] == 75
      assert node.props[:width] == :fill
    end

    test "build/1 on container includes children" do
      child = %{id: "c", type: "text", props: %{}, children: []}
      node = CardWidget.new("c1", title: "Hi", do: [child]) |> CardWidget.build()
      assert node.type == "card"
      assert length(node.children) == 1
    end

    test "a11y setter works on struct" do
      widget = BadgeWidget.new("b1") |> BadgeWidget.a11y(%{role: :alert, label: "Alert"})
      assert %BadgeWidget{} = widget
      node = BadgeWidget.build(widget)
      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :alert
      assert node.props[:a11y].label == "Alert"
    end

    test "defaults are applied via setter encoding in build" do
      node = BadgeWidget.new("b1") |> BadgeWidget.build()
      assert node.props[:color] == Plushie.Type.Color.cast(:red)
      assert node.props[:size] == 14
    end

    test "struct fields without defaults are nil" do
      widget = BadgeWidget.new("b1")
      assert widget.label == nil
      assert widget.a11y == nil
    end
  end
end
