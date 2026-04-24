defmodule Plushie.WidgetMacroTest do
  # async: false because Code.compile_string affects global code server state
  use ExUnit.Case, async: false

  # For testing generated docs, we use Plushie.Type.type_display_string/1
  # and Plushie.DSL.Widget.Codegen.generate_moduledoc_sections/7 directly
  # rather than extracting from beam chunks (which have encoding issues in
  # Latin1 VMs).

  # ---------------------------------------------------------------------------
  # Test modules: native_widget
  # ---------------------------------------------------------------------------

  defmodule GaugeWidget do
    use Plushie.Widget, :native_widget

    widget(:gauge)
    event(:calibrated, value: :float)

    field(:value, :float)
    field(:min, :float, default: 0)
    field(:max, :float, default: 100)
    field(:color, Plushie.Type.Color, default: :blue)
    field(:width, Plushie.Type.Length)
    field(:height, Plushie.Type.Length)
    field(:label, :string)
    field(:a11y, Plushie.Type.A11y, default: %{role: :meter})

    rust_crate("native/my_gauge")
    rust_constructor("my_gauge::GaugeWidget::new()")

    command(:set_value, value: :float)
    command(:reset)
    command(:set_range, fields: [min: :float, max: :float])

    command :configure do
      field :min, :float
      field :max, :float
      field :step, :float, required: false
    end

    command(:send_data, value: :any)
    command(:tag, fields: [label: :string, metadata: :any])
  end

  defmodule ContainerNative do
    use Plushie.Widget, :native_widget

    widget(:native_panel, container: true)

    field(:title, :string)
    field(:padding, Plushie.Type.Padding)
    field(:align, Plushie.Type.Alignment, default: :center)

    rust_crate("native/panel")
    rust_constructor("panel::PanelExtension::new()")
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (leaf, node builder)
  # ---------------------------------------------------------------------------

  defmodule BadgeWidget do
    use Plushie.Widget

    widget(:badge)

    field(:label, :string)
    field(:color, Plushie.Type.Color, default: :red)
    field(:size, :float, default: 14)
    field(:a11y, Plushie.Type.A11y, default: %{role: :badge})
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (container, node builder)
  # ---------------------------------------------------------------------------

  defmodule CardWidget do
    use Plushie.Widget

    widget(:card, container: true)

    field(:title, :string)
    field(:style, Plushie.Type.Style, default: :primary)
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with view/2)
  # ---------------------------------------------------------------------------

  defmodule StatusIndicator do
    use Plushie.Widget

    widget(:status_indicator)

    field(:status, :atom)
    field(:label, :string)

    def view(id, props) do
      status_str = Map.get(props, :status, "unknown")
      label = Map.get(props, :label, "Status")
      %{id: id, type: "text", props: %{content: "#{label}: #{status_str}"}, children: []}
    end
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget (composite with view/3, container)
  # ---------------------------------------------------------------------------

  defmodule Wrapper do
    use Plushie.Widget

    widget(:wrapper)

    field(:border, :boolean, default: false)

    def view(id, props) do
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
  # Test modules: field type coverage
  # ---------------------------------------------------------------------------

  defmodule TypeKitchen do
    use Plushie.Widget

    widget(:type_kitchen)

    field(:a_number, :float)
    field(:a_string, :string)
    field(:a_bool, :boolean)
    field(:a_color, Plushie.Type.Color)
    field(:a_length, Plushie.Type.Length)
    field(:a_padding, Plushie.Type.Padding)
    field(:an_alignment, Plushie.Type.Alignment)
    field(:an_atom, :atom)
    field(:a_map, :map)
    field(:a_list, {:list, :string})
    field(:any_val, :any)
    field(:a_style, Plushie.Type.Style)
    field(:a_font, Plushie.Type.Font)
  end

  # ---------------------------------------------------------------------------
  # Test modules: widget block form
  # ---------------------------------------------------------------------------

  defmodule BlockFormWidget do
    use Plushie.Widget

    @moduledoc "A widget using block form."

    widget :block_form do
      field :label, :string, doc: "Text label."
      field :size, :float, default: 14, doc: "Font size in pixels."
      field :active, :boolean, doc: "Whether active."

      positional [:label]
    end

    event :click, value: :boolean, doc: "Emitted on click."
  end

  # ---------------------------------------------------------------------------
  # Test modules: state block form
  # ---------------------------------------------------------------------------

  defmodule StatefulBlockWidget do
    use Plushie.Widget

    @moduledoc "A stateful widget using state block form."

    widget :stateful_block

    field :color, Plushie.Type.Color, default: :red

    state do
      field :hue, :float, default: 0.0
      field :saturation, :float, default: 1.0
    end

    @impl Plushie.Widget.Handler
    def view(id, props, state) do
      %{
        id: id,
        type: "container",
        props: %{color: Map.get(props, :color), hue: state.hue},
        children: []
      }
    end
  end

  # =========================================================================
  # Tests
  # =========================================================================

  describe "native_widget behaviour callbacks" do
    test "type_names/0 returns the widget type as an atom list" do
      assert GaugeWidget.type_names() == [:gauge]
    end

    test "__widget_type__/0 and __events__/0 expose declared widget event metadata" do
      assert GaugeWidget.__widget_type__() == :gauge
      assert GaugeWidget.__events__() == [:calibrated]
    end

    test "native_crate/0 returns the crate path" do
      assert GaugeWidget.native_crate() == "native/my_gauge"
    end

    test "rust_constructor/0 returns the constructor expression" do
      assert GaugeWidget.rust_constructor() == "my_gauge::GaugeWidget::new()"
    end
  end

  describe "widget new/2 produces correct tree nodes (via build)" do
    test "leaf widget builds node with type and props" do
      node = BadgeWidget.new("b1", label: "New") |> BadgeWidget.build()
      assert node.id == "b1"
      assert node.type == "badge"
      assert node.props[:label] == "New"
      assert node.children == []
    end

    test "native widget builds node with type and props" do
      node = GaugeWidget.new("g1", value: 42) |> GaugeWidget.build()
      assert node.id == "g1"
      assert node.type == "gauge"
      assert node.props[:value] == 42
      assert node.props[:min] == 0
      assert node.props[:max] == 100
      assert node.props[:__widget__].type == :gauge
      assert node.props[:__widget__].events == [:calibrated]
      assert node.children == []
    end

    test "native widget rejects missing id during node conversion" do
      widget = %GaugeWidget{id: nil}

      assert_raise ArgumentError, ~r/requires a non-empty id/, fn ->
        Plushie.Widget.to_node(widget)
      end
    end

    test "leaf widget rejects empty id during node conversion" do
      widget = %BadgeWidget{id: "", label: "Badge"}

      assert_raise ArgumentError, ~r/requires a non-empty id/, fn ->
        Plushie.Widget.to_node(widget)
      end
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

  describe "prop validation rejects unknown keys" do
    test "raises ArgumentError for unknown option" do
      assert_raise ArgumentError, ~r/unknown option/, fn ->
        BadgeWidget.new("b1", label: "X", bogus: true)
      end
    end

    test "raises ArgumentError listing the unknown keys" do
      assert_raise ArgumentError, ~r/bogus/, fn ->
        GaugeWidget.new("g1", bogus: 123)
      end
    end
  end

  describe "prop defaults are applied" do
    test "color default is cast and applied" do
      node = BadgeWidget.new("b1") |> BadgeWidget.build()
      assert node.props[:color] == "#ff0000"
      assert node.props[:size] == 14
    end

    test "number defaults applied for native" do
      node = GaugeWidget.new("g1", value: 50) |> GaugeWidget.build()
      assert node.props[:min] == 0
      assert node.props[:max] == 100
    end

    test "props without defaults are omitted when not provided" do
      node = GaugeWidget.new("g1", value: 50) |> GaugeWidget.build()
      refute Map.has_key?(node.props, "width")
      refute Map.has_key?(node.props, "height")
      refute Map.has_key?(node.props, "label")
    end
  end

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
      node = GaugeWidget.new("g1", value: 0, width: :fill) |> GaugeWidget.build()
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

  describe "command generation for native widgets" do
    test "value command encodes through Plushie.Type" do
      cmd = GaugeWidget.set_value("g1", 75)
      assert cmd.type == :command
      assert cmd.payload.id == "g1"
      assert cmd.payload.family == "set_value"
      assert cmd.payload.value == 75
    end

    test "no-payload command passes nil value" do
      cmd = GaugeWidget.reset("g1")
      assert cmd.type == :command
      assert cmd.payload.id == "g1"
      assert cmd.payload.family == "reset"
      assert cmd.payload.value == nil
    end

    test "fields command encodes each field" do
      cmd = GaugeWidget.set_range("g1", 0.0, 100.0)
      assert cmd.type == :command
      assert cmd.payload.id == "g1"
      assert cmd.payload.family == "set_range"
      assert cmd.payload.value == %{min: 0.0, max: 100.0}
    end

    test "block command with optional fields accepts keyword opts" do
      cmd = GaugeWidget.configure("g1", 0.0, 100.0, step: 0.5)
      assert cmd.type == :command
      assert cmd.payload.family == "configure"
      assert cmd.payload.value == %{min: 0.0, max: 100.0, step: 0.5}
    end

    test "block command without optional fields omits them" do
      cmd = GaugeWidget.configure("g1", 0.0, 100.0)
      assert cmd.type == :command
      assert cmd.payload.value == %{min: 0.0, max: 100.0}
    end

    test "block command rejects unknown opts" do
      assert_raise ArgumentError, ~r/unknown option.*bogus/, fn ->
        GaugeWidget.configure("g1", 0.0, 100.0, bogus: true)
      end
    end

    test "command enforces widget_id is binary" do
      assert_raise FunctionClauseError, fn ->
        GaugeWidget.set_value(:not_binary, 42)
      end
    end

    test "command enforces type guard on params" do
      assert_raise FunctionClauseError, fn ->
        GaugeWidget.set_value("g1", "not a number")
      end
    end

    test "fields command enforces type guards" do
      assert_raise FunctionClauseError, fn ->
        GaugeWidget.set_range("g1", "not a number", 100.0)
      end
    end

    test "value :any command accepts any value without guard" do
      cmd = GaugeWidget.send_data("g1", %{custom: "data"})
      assert cmd.type == :command
      assert cmd.payload.family == "send_data"
      assert cmd.payload.value == %{custom: "data"}
    end

    test "fields with :any type skip guard for that field" do
      cmd = GaugeWidget.tag("g1", "important", %{nested: true})
      assert cmd.type == :command
      assert cmd.payload.family == "tag"
      assert cmd.payload.value == %{label: "important", metadata: %{nested: true}}
    end
  end

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

  describe "composite with view callback" do
    test "view/2 widget produces struct" do
      widget = StatusIndicator.new("si1", status: :ok, label: "Health")
      assert %StatusIndicator{id: "si1", status: :ok, label: "Health"} = widget
    end

    test "view/2 widget renders via to_node placeholder" do
      widget = StatusIndicator.new("si1", status: :ok, label: "Health")
      node = Plushie.Widget.to_node(widget)
      assert node.type == "widget_placeholder"
    end

    test "omitted nil composite props are absent from metadata" do
      widget = StatusIndicator.new("si1", status: :ok)
      node = Plushie.Widget.to_node(widget)

      props = node.props[:__widget__].props
      assert props[:status] == :ok
      refute Map.has_key?(props, :label)
    end

    test "explicit nil composite props are present in metadata" do
      widget = StatusIndicator.new("si1", status: :ok, label: nil)
      node = Plushie.Widget.to_node(widget)

      props = node.props[:__widget__].props
      assert props[:status] == :ok
      assert Map.has_key?(props, :label)
      assert props[:label] == nil
    end

    test "view/3 widget produces struct" do
      widget = Wrapper.new("w1", border: true)
      assert %Wrapper{id: "w1", border: true} = widget
    end

    test "non-nil composite defaults stay in metadata" do
      widget = Wrapper.new("w1")
      node = Plushie.Widget.to_node(widget)

      props = node.props[:__widget__].props
      assert props[:border] == false
    end

    test "stateful widget placeholder rejects missing id" do
      widget = %StatefulBlockWidget{id: nil}

      assert_raise ArgumentError, ~r/requires a non-empty id/, fn ->
        Plushie.Widget.to_node(widget)
      end
    end

    test "stateful widget placeholder rejects empty id" do
      widget = %StatefulBlockWidget{id: ""}

      assert_raise ArgumentError, ~r/requires a non-empty id/, fn ->
        Plushie.Widget.to_node(widget)
      end
    end
  end

  describe "compile errors" do
    test "missing widget declaration raises CompileError" do
      assert_raise CompileError, ~r/missing.*widget :type_name/, fn ->
        Code.compile_string("""
        defmodule MissingWidget do
          use Plushie.Widget

          field :foo, :string
        end
        """)
      end
    end

    # --- 10. compile error on missing rust_crate for native -------------------

    test "missing rust_crate raises CompileError" do
      assert_raise CompileError, ~r/missing.*rust_crate/, fn ->
        Code.compile_string("""
        defmodule MissingCrate do
          use Plushie.Widget, :native_widget

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
          use Plushie.Widget, :native_widget

          widget :foo
          rust_crate "native/foo"
        end
        """)
      end
    end
  end

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
        GaugeWidget.new("g1", value: 50, a11y: a11y)
        |> GaugeWidget.build()

      assert %Plushie.Type.A11y{} = node.props[:a11y]
      assert node.props[:a11y].role == :meter
      assert node.props[:a11y].label == "CPU"
    end

    test "a11y has per-widget default in props" do
      node = BadgeWidget.new("b1") |> BadgeWidget.build()
      assert Map.has_key?(node.props, :a11y)
      assert node.props[:a11y][:role] == :badge
    end
  end

  describe "__prop_names__/0" do
    test "returns declared prop names plus :a11y" do
      names = BadgeWidget.__prop_names__()
      assert :label in names
      assert :color in names
      assert :size in names
      assert :a11y in names
    end
  end

  describe "widget kind does not define native callbacks" do
    test "pure widget does not export native_crate/0" do
      refute function_exported?(BadgeWidget, :native_crate, 0)
    end

    test "pure widget does not export rust_constructor/0" do
      refute function_exported?(BadgeWidget, :rust_constructor, 0)
    end
  end

  describe "compile-time validation" do
    test "raises on invalid kind" do
      assert_raise ArgumentError, ~r/must be one of/, fn ->
        Code.compile_string("""
        defmodule TestInvalidKind do
          use Plushie.Widget, :invalid
        end
        """)
      end
    end

    test "raises on unknown field type" do
      assert_raise CompileError, ~r/unsupported field type.*:bogus_type/, fn ->
        Code.compile_string("""
        defmodule TestBadPropType do
          use Plushie.Widget

          widget :bad_prop
          field :foo, :bogus_type
        end
        """)
      end
    end

    test "raises on unknown command param type" do
      assert_raise CompileError, ~r/invalid type.*:widget_ref/, fn ->
        Code.compile_string("""
        defmodule TestBadCmdType do
          use Plushie.Widget, :native_widget

          widget :bad_cmd
          rust_crate "native/bad"
          rust_constructor "bad::Bad::new()"
          command :do_thing, value: :widget_ref
        end
        """)
      end
    end

    test "allows {:list, inner} field type" do
      Code.compile_string("""
      defmodule TestListPropType do
        use Plushie.Widget

        widget :list_prop
        field :items, {:list, :string}
      end
      """)
    end

    test "rejects {:list, bad_inner} field type" do
      assert_raise CompileError, ~r/unsupported field type.*\{:list, :widget_ref\}/, fn ->
        Code.compile_string("""
        defmodule TestBadListPropType do
          use Plushie.Widget

          widget :bad_list_prop
          field :items, {:list, :widget_ref}
        end
        """)
      end
    end

    test "warns on duplicate field names" do
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          Code.compile_string("""
          defmodule TestDuplicateProps do
            use Plushie.Widget

            widget :dup_props
            field :foo, :string
            field :foo, :float
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
            use Plushie.Widget

            widget :first_name
            widget :second_name

            field :label, :string
          end
          """)
        end)

      assert warnings =~ "widget type already declared"
      assert warnings =~ "first_name"
    end
  end

  describe "reserved field names" do
    test "raises on field named :id" do
      assert_raise CompileError, ~r/field name :id is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedId do
          use Plushie.Widget
          widget :bad
          field :id, :string
        end
        """)
      end
    end

    test "raises on field named :type" do
      assert_raise CompileError, ~r/field name :type is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedType do
          use Plushie.Widget
          widget :bad
          field :type, :string
        end
        """)
      end
    end

    test "raises on field named :children" do
      assert_raise CompileError, ~r/field name :children is reserved/, fn ->
        Code.compile_string("""
        defmodule TestReservedChildren do
          use Plushie.Widget
          widget :bad
          field :children, :any
        end
        """)
      end
    end

    test "a11y is not a reserved field name" do
      Code.compile_string("""
      defmodule TestA11yField do
        use Plushie.Widget
        widget :a11y_test
        field :a11y, Plushie.Type.A11y, default: %{role: :generic_container}
      end
      """)

      assert :a11y in apply(TestA11yField, :__prop_names__, [])
    end
  end

  describe "struct API for non-composite widgets" do
    test "new/2 returns a struct for leaf widget" do
      widget = BadgeWidget.new("b1")
      assert %BadgeWidget{} = widget
      assert widget.id == "b1"
    end

    test "new/2 returns a struct for native widget" do
      widget = GaugeWidget.new("g1", value: 42)
      assert %GaugeWidget{} = widget
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
      assert {:ok, widget.color} == Plushie.Type.Color.cast(:green)
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
      node = GaugeWidget.new("g1", value: 75, width: :fill) |> GaugeWidget.build()
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
      assert node.props[:color] == "#ff0000"
      assert node.props[:size] == 14
    end

    test "struct fields without defaults are nil" do
      widget = BadgeWidget.new("b1")
      assert widget.label == nil
    end

    test "a11y field has per-widget default" do
      widget = BadgeWidget.new("b1")
      assert widget.a11y == %{role: :badge}
    end
  end

  describe "widget block form" do
    test "block form produces same struct as flat form" do
      widget = BlockFormWidget.new("b1", "Hello", size: 18)
      assert %BlockFormWidget{} = widget
      assert widget.id == "b1"
      assert widget.label == "Hello"
      assert widget.size == 18
    end

    test "block form respects positional args" do
      widget = BlockFormWidget.new("b1", "Hello")
      assert widget.label == "Hello"
      assert widget.size == 14
    end

    test "block form applies defaults" do
      node = BlockFormWidget.new("b1", "X") |> BlockFormWidget.build()
      assert node.props[:size] == 14
    end

    test "block form type_names still works" do
      assert BlockFormWidget.type_names() == [:block_form]
    end

    test "block form events still work" do
      assert BlockFormWidget.__events__() == [:click]
    end
  end

  describe "state block form" do
    test "state block produces correct initial state" do
      state = StatefulBlockWidget.__initial_state__()
      assert state == %{hue: 0.0, saturation: 1.0}
    end

    test "state block widget creates struct" do
      widget = StatefulBlockWidget.new("s1", color: :blue)
      assert %StatefulBlockWidget{} = widget
      assert widget.id == "s1"
    end
  end

  describe "generated moduledoc sections" do
    test "props table contains field names, types, defaults, and descriptions" do
      props = [
        {:label, :string, [doc: "Text label."]},
        {:size, :float, [default: 14, doc: "Font size."]}
      ]

      doc =
        Plushie.DSL.Widget.Codegen.generate_moduledoc_sections(
          __MODULE__,
          props,
          [],
          [],
          [],
          [],
          []
        )

      assert doc =~ "## Props"
      assert doc =~ "| `label` |"
      assert doc =~ "Text label."
      assert doc =~ "| `size` |"
      assert doc =~ "Font size."
      assert doc =~ "`14`"
    end

    test "events section contains event name, type, and doc" do
      events = [:click]
      event_specs = [{:click, %{carrier: :value, type: :boolean, doc: "Emitted on click."}}]

      doc =
        Plushie.DSL.Widget.Codegen.generate_moduledoc_sections(
          __MODULE__,
          [{:value, :float, []}],
          [],
          events,
          event_specs,
          [],
          []
        )

      assert doc =~ "## Events"
      assert doc =~ "`:click`"
      assert doc =~ "Emitted on click."
      assert doc =~ "`value: boolean()`"
    end

    test "constructor section shows positional form" do
      doc =
        Plushie.DSL.Widget.Codegen.generate_moduledoc_sections(
          Plushie.Widget.Checkbox,
          [{:label, :string, []}],
          [:label],
          [],
          [],
          [],
          []
        )

      assert doc =~ "## Constructor"
      assert doc =~ "Checkbox.new(id, label)"
      assert doc =~ "Checkbox.new(id, label, opts)"
    end

    test "state section contains typed state fields" do
      state_fields_raw = [
        {:hue, 0.0, :float},
        {:saturation, 1.0, :float}
      ]

      doc =
        Plushie.DSL.Widget.Codegen.generate_moduledoc_sections(
          __MODULE__,
          [],
          [],
          [],
          [],
          state_fields_raw,
          []
        )

      assert doc =~ "## Internal State"
      assert doc =~ "| `hue` |"
      assert doc =~ "| `saturation` |"
      assert doc =~ "`number()`"
      assert doc =~ "`0.0`"
    end

    test "empty when no props, events, state, or commands" do
      doc =
        Plushie.DSL.Widget.Codegen.generate_moduledoc_sections(
          __MODULE__,
          [],
          [],
          [],
          [],
          [],
          []
        )

      assert doc == ""
    end

    test "widget module with block form compiles with all fields" do
      info = BlockFormWidget.__widget_info__()
      assert info.props == [:label, :size, :active]
      assert info.events == [:click]
    end
  end

  describe "positional argument guards" do
    test "new/2 rejects non-binary id with FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        BlockFormWidget.new(123, "label")
      end
    end

    test "new/2 rejects non-string/atom positional label with FunctionClauseError" do
      assert_raise FunctionClauseError, fn ->
        BlockFormWidget.new("ok", 999)
      end
    end

    test "new/2 accepts binary id and binary positional label" do
      widget = BlockFormWidget.new("w1", "Hello")
      assert widget.id == "w1"
      assert widget.label == "Hello"
    end

    test "new/2 accepts atom positional label" do
      widget = BlockFormWidget.new("w1", :hello)
      assert widget.id == "w1"
      assert widget.label == :hello
    end

    test "native widget new/2 rejects non-binary id" do
      assert_raise FunctionClauseError, fn ->
        GaugeWidget.new(42)
      end
    end

    test "widget without positional args rejects non-binary id" do
      assert_raise FunctionClauseError, fn ->
        BadgeWidget.new(42)
      end
    end

    test "widget without positional args accepts binary id" do
      widget = BadgeWidget.new("b1")
      assert widget.id == "b1"
    end
  end

  describe "type_display_string" do
    test "primitive types render correctly" do
      assert Plushie.Type.type_display_string(:string) == "String.t() | atom()"
      assert Plushie.Type.type_display_string(:float) == "number()"
      assert Plushie.Type.type_display_string(:boolean) == "boolean()"
    end
  end

  describe "setter @doc with field description" do
    test "setter works on widget with :doc options" do
      widget = BlockFormWidget.new("b1", "X")
      widget = BlockFormWidget.label(widget, "Y")
      assert widget.label == "Y"
    end
  end
end
