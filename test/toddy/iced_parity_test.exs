defmodule Toddy.IcedParityTest do
  @moduledoc """
  Tests for all new widgets in Toddy.Iced added in the iced parity pass.
  Does not duplicate tests from iced_test.exs.
  """
  use ExUnit.Case, async: true

  alias Toddy.Iced

  # ---------------------------------------------------------------------------
  # Layout widgets
  # ---------------------------------------------------------------------------

  describe "grid/3" do
    test "returns correct node with defaults" do
      node = Iced.grid("g1")
      assert node == %{id: "g1", type: "grid", props: %{}, children: []}
    end

    test "passes props and children" do
      child = Iced.text("t1", %{content: "cell"})
      node = Iced.grid("g1", %{column_count: 3, spacing: 4}, [child, child])
      assert node.type == "grid"
      assert node.props["column_count"] == 3
      assert node.props["spacing"] == 4
      assert length(node.children) == 2
    end

    test "supports column_width and row_height props" do
      node = Iced.grid("g1", %{column_width: 100, row_height: 50})
      assert node.props["column_width"] == 100
      assert node.props["row_height"] == 50
    end
  end

  describe "pin/3" do
    test "returns correct node with defaults" do
      node = Iced.pin("p1")
      assert node == %{id: "p1", type: "pin", props: %{}, children: []}
    end

    test "accepts children for absolute positioning" do
      child = Iced.text("t1", %{content: "pinned"})
      node = Iced.pin("p1", %{width: 200, height: 200}, [child])
      assert node.type == "pin"
      assert length(node.children) == 1
    end
  end

  describe "float_widget/3" do
    test "returns correct node type 'float'" do
      node = Iced.float_widget("f1")
      assert node.type == "float"
      assert node.id == "f1"
      assert node.children == []
    end

    test "passes props and children" do
      child = Iced.text("overlay", %{content: "I float"})
      node = Iced.float_widget("f1", %{width: 300}, [child])
      assert node.props["width"] == 300
      assert length(node.children) == 1
    end
  end

  describe "responsive/3" do
    test "returns correct node with defaults" do
      node = Iced.responsive("r1")
      assert node == %{id: "r1", type: "responsive", props: %{}, children: []}
    end

    test "accepts children" do
      child = Iced.text("t1", %{content: "adapts"})
      node = Iced.responsive("r1", %{}, [child])
      assert length(node.children) == 1
    end
  end

  describe "keyed_column/3" do
    test "returns correct node with defaults" do
      node = Iced.keyed_column("kc1")
      assert node == %{id: "kc1", type: "keyed_column", props: %{}, children: []}
    end

    test "passes spacing and children" do
      children = for i <- 1..3, do: Iced.text("t#{i}", %{content: "item #{i}"})
      node = Iced.keyed_column("kc1", %{spacing: 4}, children)
      assert node.props["spacing"] == 4
      assert length(node.children) == 3
    end

    test "supports align_x prop" do
      node = Iced.keyed_column("kc1", %{align_x: :center})
      assert node.props["align_x"] == :center
    end
  end

  # ---------------------------------------------------------------------------
  # Interactive widgets
  # ---------------------------------------------------------------------------

  describe "mouse_area/3" do
    test "returns correct node with defaults" do
      node = Iced.mouse_area("ma1")
      assert node == %{id: "ma1", type: "mouse_area", props: %{}, children: []}
    end

    test "passes event handler props and children" do
      child = Iced.button("btn1", %{label: "Click me"})
      node = Iced.mouse_area("ma1", %{on_press: :pressed, on_release: :released}, [child])
      assert node.props["on_press"] == :pressed
      assert node.props["on_release"] == :released
      assert length(node.children) == 1
    end

    test "supports all mouse event props" do
      props = %{
        on_press: :p,
        on_release: :r,
        on_right_press: :rp,
        on_middle_press: :mp,
        on_enter: :enter,
        on_exit: :exit
      }

      node = Iced.mouse_area("ma1", props)
      assert node.props["on_press"] == :p
      assert node.props["on_right_press"] == :rp
      assert node.props["on_middle_press"] == :mp
      assert node.props["on_enter"] == :enter
      assert node.props["on_exit"] == :exit
    end
  end

  describe "sensor/3" do
    test "returns correct node with defaults" do
      node = Iced.sensor("s1")
      assert node == %{id: "s1", type: "sensor", props: %{}, children: []}
    end

    test "passes on_resize and on_appear props" do
      child = Iced.text("t1", %{content: "watched"})
      node = Iced.sensor("s1", %{on_resize: :resized, on_appear: :appeared}, [child])
      assert node.props["on_resize"] == :resized
      assert node.props["on_appear"] == :appeared
      assert length(node.children) == 1
    end
  end

  describe "pane_grid/2" do
    test "returns correct node with defaults" do
      node = Iced.pane_grid("pg1")
      assert node == %{id: "pg1", type: "pane_grid", props: %{}, children: []}
    end

    test "passes pane configuration props" do
      node = Iced.pane_grid("pg1", %{panes: [:a, :b], spacing: 2, on_resize: :resized})
      assert node.props["panes"] == [:a, :b]
      assert node.props["spacing"] == 2
      assert node.props["on_resize"] == :resized
    end

    test "has no children (panes are in props)" do
      node = Iced.pane_grid("pg1", %{panes: [:a]})
      assert node.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # Display widgets
  # ---------------------------------------------------------------------------

  describe "rich_text/2" do
    test "returns correct node with defaults" do
      node = Iced.rich_text("rt1")
      assert node == %{id: "rt1", type: "rich_text", props: %{}, children: []}
    end

    test "passes spans prop" do
      spans = [
        %{text: "bold", weight: :bold},
        %{text: " and ", weight: :normal},
        %{text: "italic", style: :italic}
      ]

      node = Iced.rich_text("rt1", %{spans: spans, width: :fill})
      assert node.props["spans"] == spans
      assert node.props["width"] == :fill
    end

    test "has no children (content via spans prop)" do
      node = Iced.rich_text("rt1", %{spans: [%{text: "hi"}]})
      assert node.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # Font stretch encoding (new)
  # ---------------------------------------------------------------------------

  describe "Font.encode/1 with stretch" do
    alias Toddy.Iced.Font

    test "encodes condensed stretch" do
      result = Font.encode(%{family: "Inter", stretch: :condensed})
      assert result["stretch"] == "Condensed"
    end

    test "encodes ultra_condensed stretch" do
      result = Font.encode(%{family: "Inter", stretch: :ultra_condensed})
      assert result["stretch"] == "UltraCondensed"
    end

    test "encodes semi_expanded stretch" do
      result = Font.encode(%{family: "Inter", stretch: :semi_expanded})
      assert result["stretch"] == "SemiExpanded"
    end

    test "encodes extra_expanded stretch" do
      result = Font.encode(%{family: "Inter", stretch: :extra_expanded})
      assert result["stretch"] == "ExtraExpanded"
    end

    test "encodes ultra_expanded stretch" do
      result = Font.encode(%{family: "Inter", stretch: :ultra_expanded})
      assert result["stretch"] == "UltraExpanded"
    end

    test "encodes normal stretch" do
      result = Font.encode(%{family: "Inter", stretch: :normal})
      assert result["stretch"] == "Normal"
    end

    test "combines stretch with weight and style" do
      result = Font.encode(%{family: "Inter", weight: :bold, style: :italic, stretch: :condensed})
      assert result["family"] == "Inter"
      assert result["weight"] == "Bold"
      assert result["style"] == "Italic"
      assert result["stretch"] == "Condensed"
    end

    test "omits stretch when not provided" do
      result = Font.encode(%{family: "Inter", weight: :bold})
      refute Map.has_key?(result, "stretch")
    end
  end

  # ---------------------------------------------------------------------------
  # Theme warning color (new)
  # ---------------------------------------------------------------------------

  describe "Theme.custom/2 with warning color" do
    alias Toddy.Iced.Theme

    test "includes warning color when provided" do
      result = Theme.custom("MyTheme", warning: "#ffaa00")
      assert result["warning"] == "#ffaa00"
    end

    test "omits warning when not provided" do
      result = Theme.custom("MyTheme", primary: "#ff0000")
      refute Map.has_key?(result, "warning")
    end

    test "includes warning alongside all other palette colors" do
      result =
        Theme.custom("Full",
          base: :dark,
          background: "#1a1b26",
          text: "#c0caf5",
          primary: "#7aa2f7",
          success: "#9ece6a",
          danger: "#f7768e",
          warning: "#e0af68"
        )

      assert result["warning"] == "#e0af68"
      assert result["success"] == "#9ece6a"
      assert result["danger"] == "#f7768e"
    end
  end

  # ---------------------------------------------------------------------------
  # Effects - primary clipboard (new)
  # ---------------------------------------------------------------------------

  describe "Effects.clipboard_read_primary/0" do
    test "returns command and effect id" do
      cmd = Toddy.Effects.clipboard_read_primary()
      assert %Toddy.Command{type: :effect} = cmd
      assert cmd.payload.kind == "clipboard_read_primary"
      assert is_binary(cmd.payload.id)
      assert String.starts_with?(cmd.payload.id, "ef_")
    end
  end

  describe "Effects.clipboard_write_primary/1" do
    test "returns command with text payload" do
      cmd = Toddy.Effects.clipboard_write_primary("hello")
      assert %Toddy.Command{type: :effect} = cmd
      assert cmd.payload.kind == "clipboard_write_primary"
      assert cmd.payload.opts.text == "hello"
      assert is_binary(cmd.payload.id)
    end
  end

  # ---------------------------------------------------------------------------
  # All new widgets use string keys in props
  # ---------------------------------------------------------------------------

  describe "prop key normalization" do
    test "atom keys in props map become string keys" do
      nodes = [
        Iced.grid("g", %{column_count: 3}),
        Iced.pin("p", %{width: 100}),
        Iced.float_widget("f", %{height: 50}),
        Iced.responsive("r", %{width: :fill}),
        Iced.keyed_column("kc", %{spacing: 8}),
        Iced.mouse_area("ma", %{on_press: :p}),
        Iced.sensor("s", %{on_resize: :r}),
        Iced.pane_grid("pg", %{spacing: 2}),
        Iced.rich_text("rt", %{width: :fill})
      ]

      for node <- nodes do
        for key <- Map.keys(node.props) do
          assert is_binary(key), "Expected string key in #{node.type} props, got: #{inspect(key)}"
        end
      end
    end
  end
end
