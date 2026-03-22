defmodule Plushie.Docs.LayoutTest do
  use ExUnit.Case, async: true

  import Plushie.UI

  # -- Length examples ----------------------------------------------------------

  test "layout_length_fill_test" do
    tree =
      column id: "main", width: :fill do
        text("x", "x")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "column"
    assert node.id == "main"
    assert node.props[:width] == "fill"
  end

  test "layout_length_fixed_test" do
    tree =
      container "sidebar", width: 250 do
        text("x", "x")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "container"
    assert node.id == "sidebar"
    assert node.props[:width] == 250
  end

  test "layout_length_fill_portion_test" do
    tree =
      row do
        container "left", width: {:fill_portion, 2} do
          text("x", "x")
        end

        container "right", width: {:fill_portion, 1} do
          text("y", "y")
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "row"
    assert [left, right] = node.children
    assert left.id == "left"
    assert right.id == "right"
    assert left.props[:width] == ["fill_portion", 2]
    assert right.props[:width] == ["fill_portion", 1]
  end

  test "layout_length_shrink_test" do
    tree = button("save", "Save", width: :shrink)
    node = Plushie.Tree.normalize(tree)
    assert node.type == "button"
    assert node.props[:width] == "shrink"
  end

  # -- Padding examples ---------------------------------------------------------

  test "layout_padding_uniform_test" do
    tree =
      container "box", padding: 16 do
        text("x", "x")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "container"
    assert node.props[:padding] == 16
  end

  test "layout_padding_xy_test" do
    tree =
      container "box", padding: {8, 16} do
        text("x", "x")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.props[:padding] == [8, 16]
  end

  test "layout_padding_per_side_test" do
    tree =
      container "box", padding: %{top: 0, right: 16, bottom: 8, left: 16} do
        text("x", "x")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.props[:padding] == %{top: 0, right: 16, bottom: 8, left: 16}
  end

  # -- Spacing example ----------------------------------------------------------

  test "layout_spacing_test" do
    tree =
      column spacing: 8 do
        text("First")
        text("Second")
        text("Third")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "column"
    assert node.props[:spacing] == 8
    assert [a, b, c] = node.children
    assert a.props[:content] == "First"
    assert b.props[:content] == "Second"
    assert c.props[:content] == "Third"
  end

  # -- Alignment examples -------------------------------------------------------

  test "layout_align_x_column_test" do
    tree =
      column align_x: :center do
        text("Centered")
        button("ok", "OK")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "column"
    assert node.props[:align_x] == "center"
    assert [text_node, btn_node] = node.children
    assert text_node.props[:content] == "Centered"
    assert btn_node.props[:label] == "OK"
  end

  test "layout_align_center_container_test" do
    tree =
      container "page", width: :fill, height: :fill, center: true do
        text("Dead center")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "container"
    assert node.props[:width] == "fill"
    assert node.props[:height] == "fill"
    assert node.props[:center] == true
    assert [child] = node.children
    assert child.props[:content] == "Dead center"
  end

  # -- Layout container examples ------------------------------------------------

  test "layout_column_with_props_test" do
    tree =
      column id: "main", spacing: 16, padding: 20, width: :fill, align_x: :center do
        text("title", "Title", size: 24)
        text("subtitle", "Subtitle", size: 14)
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "column"
    assert node.id == "main"
    assert node.props[:spacing] == 16
    assert node.props[:padding] == 20
    assert node.props[:width] == "fill"
    assert node.props[:align_x] == "center"
    assert [title, subtitle] = node.children
    assert title.props[:size] == 24
    assert subtitle.props[:size] == 14
  end

  test "layout_row_with_align_y_test" do
    tree =
      row spacing: 8, align_y: :center do
        button("back", "<")
        text("Page 1 of 5")
        button("next", ">")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "row"
    assert node.props[:spacing] == 8
    assert node.props[:align_y] == "center"
    assert [back, page, next_btn] = node.children
    assert back.props[:label] == "<"
    assert page.props[:content] == "Page 1 of 5"
    assert next_btn.props[:label] == ">"
  end

  test "layout_container_with_style_test" do
    tree =
      container "card", padding: 16, style: :rounded_box, width: :fill do
        column do
          text("Card title")
          text("Card content")
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "container"
    assert node.id == "card"
    assert node.props[:style] == "rounded_box"
    assert node.props[:width] == "fill"
    assert node.props[:padding] == 16
    assert [col] = node.children
    assert col.type == "column"
    assert [t, c] = col.children
    assert t.props[:content] == "Card title"
    assert c.props[:content] == "Card content"
  end

  test "layout_scrollable_test" do
    tree =
      scrollable "list", height: 400, width: :fill do
        column spacing: 4 do
          text("item", "Item")
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "scrollable"
    assert node.id == "list"
    assert node.props[:height] == 400
    assert node.props[:width] == "fill"
    assert [col] = node.children
    assert col.type == "column"
    assert col.props[:spacing] == 4
  end

  test "layout_stack_test" do
    tree =
      stack do
        image("bg", "background.png", width: :fill, height: :fill)

        container "overlay", width: :fill, height: :fill, center: true do
          text("overlay_text", "Overlaid text", size: 48)
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "stack"
    assert [bg, overlay] = node.children
    assert bg.type == "image"
    assert bg.props[:source] == "background.png"
    assert bg.props[:width] == "fill"
    assert overlay.type == "container"
    assert [text_node] = overlay.children
    assert text_node.props[:content] == "Overlaid text"
    assert text_node.props[:size] == 48
  end

  test "layout_space_test" do
    tree =
      row do
        text("Left")
        space(width: :fill)
        text("Right")
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "row"
    assert [left, gap, right] = node.children
    assert left.props[:content] == "Left"
    assert gap.type == "space"
    assert gap.props[:width] == "fill"
    assert right.props[:content] == "Right"
  end

  test "layout_grid_test" do
    items = [%{id: "1", url: "a.png"}, %{id: "2", url: "b.png"}]

    tree =
      grid id: "gallery", columns: 3, spacing: 8 do
        for item <- items do
          image("img:#{item.id}", item.url, width: :fill)
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "grid"
    assert node.id == "gallery"
    assert node.props[:spacing] == 8
    assert node.props[:columns] == 3
    assert length(node.children) == 2
    assert Enum.all?(node.children, &(&1.type == "image"))
  end

  # -- Common layout patterns ---------------------------------------------------

  test "layout_centered_page_test" do
    tree =
      container "page", width: :fill, height: :fill, center: true do
        column spacing: 16, align_x: :center do
          text("welcome", "Welcome", size: 32)
          button("start", "Get Started")
        end
      end

    node = Plushie.Tree.normalize(tree)
    assert node.type == "container"
    assert node.id == "page"
    assert node.props[:width] == "fill"
    assert node.props[:height] == "fill"
    assert node.props[:center] == true
    assert [col] = node.children
    assert col.props[:align_x] == "center"
    assert col.props[:spacing] == 16
    assert [text_node, btn] = col.children
    assert text_node.props[:content] == "Welcome"
    assert text_node.props[:size] == 32
    assert btn.props[:label] == "Get Started"
  end
end
