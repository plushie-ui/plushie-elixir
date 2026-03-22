defmodule Plushie.Docs.ExtensionsTest do
  use ExUnit.Case, async: true

  # ---------------------------------------------------------------------------
  # Extension modules mirroring the extensions.md code blocks.
  # ---------------------------------------------------------------------------

  defmodule TestSparkline do
    use Plushie.Extension, :native_widget

    widget(:sparkline)

    rust_crate("native/my_sparkline")
    rust_constructor("my_sparkline::SparklineExtension::new()")

    prop(:data, {:list, :number}, doc: "Sample values to plot")
    prop(:color, :color, default: "#4CAF50", doc: "Line color")
    prop(:capacity, :number, default: 100, doc: "Max samples in the ring buffer")

    command(:push, value: :number)
  end

  defmodule TestHexView do
    use Plushie.Extension, :native_widget

    widget(:hex_view)

    rust_crate("native/hex_view")
    rust_constructor("hex_view::HexViewExtension::new()")

    prop(:data, :string, doc: "Binary data (base64)")
    prop(:columns, :number, default: 16)
  end

  defmodule TestCard do
    use Plushie.Extension, :widget

    widget(:card, container: true)

    prop(:title, :string)
    prop(:subtitle, :string, default: nil)

    def render(id, props, children) do
      column id: id, padding: 16, spacing: 8 do
        text("ext_title", props.title, size: 20)

        if props.subtitle do
          text("ext_subtitle", props.subtitle, size: 14)
        end

        children
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Quick start: sparkline definition and build
  # ---------------------------------------------------------------------------

  test "extensions_sparkline_def_test" do
    assert TestSparkline.type_names() == [:sparkline]
    assert TestSparkline.native_crate() == "native/my_sparkline"
    assert TestSparkline.rust_constructor() == "my_sparkline::SparklineExtension::new()"
  end

  test "extensions_sparkline_build_test" do
    widget = TestSparkline.new("s1", data: [1.0, 2.0, 3.0], color: "#ff0000")
    node = Plushie.Widget.to_node(widget) |> Plushie.Tree.normalize()

    assert node.id == "s1"
    assert node.type == "sparkline"
    assert node.props[:color] == "#ff0000"
  end

  test "extensions_sparkline_push_command_test" do
    cmd = TestSparkline.push("s1", 42.0)
    assert %Plushie.Command{type: :extension_command} = cmd
  end

  # ---------------------------------------------------------------------------
  # Native widget: hex_view
  # ---------------------------------------------------------------------------

  test "extensions_hex_view_def_test" do
    assert TestHexView.type_names() == [:hex_view]
    assert TestHexView.native_crate() == "native/hex_view"
  end

  test "extensions_hex_view_build_test" do
    widget = TestHexView.new("hv1", data: "deadbeef", columns: 16)
    node = Plushie.Widget.to_node(widget) |> Plushie.Tree.normalize()

    assert node.type == "hex_view"
    assert node.props[:data] == "deadbeef"
  end

  # ---------------------------------------------------------------------------
  # Composite widget: card with render/3
  # ---------------------------------------------------------------------------

  test "extensions_composite_card_test" do
    import Plushie.UI

    child = text("child1", "Hello")

    node =
      TestCard.new("info",
        title: "Details",
        subtitle: "More info",
        do: [child]
      )
      |> Plushie.Tree.normalize()

    assert node.type == "column"
    assert node.id == "info"

    # Verify children contain the expected title and subtitle text nodes
    types = Enum.map(node.children, & &1.type)
    assert "text" in types

    title_node =
      Enum.find(node.children, fn c ->
        c.type == "text" and c.props[:content] == "Details"
      end)

    assert title_node != nil

    subtitle_node =
      Enum.find(node.children, fn c ->
        c.type == "text" and c.props[:content] == "More info"
      end)

    assert subtitle_node != nil
  end
end
