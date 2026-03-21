defmodule CatalogTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.Widget

  alias Catalog

  test "init returns expected model" do
    model = Catalog.init([])
    assert model.active_tab == "layout"
  end

  test "switching tabs" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :click, id: "tab_input"})
    assert model.active_tab == "input"
  end

  test "view renders for each tab without errors" do
    model = Catalog.init([])

    for tab <- ["layout", "input", "display", "composite"] do
      m = %{model | active_tab: tab}
      tree = Catalog.view(m)
      assert tree.type == "window"
    end
  end

  test "text input updates" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :input, id: "demo_input", value: "hello"})
    assert model.text_value == "hello"
  end

  test "checkbox toggle" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :toggle, id: "demo_check", value: true})
    assert model.checkbox_checked == true
  end

  test "slider change" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :slide, id: "demo_slider", value: 75})
    assert model.slider_value == 75
  end

  test "radio group select" do
    model = Catalog.init([])
    assert model.radio_selected == "a"
    model = Catalog.update(model, %Widget{type: :select, id: "demo_radio", value: "b"})
    assert model.radio_selected == "b"
    model = Catalog.update(model, %Widget{type: :select, id: "demo_radio", value: "c"})
    assert model.radio_selected == "c"
  end

  test "radio buttons emit group prop in tree" do
    model = Catalog.init([]) |> Map.put(:active_tab, "input")
    tree = Catalog.view(model)
    radios = Plushie.UI.find_all(tree, fn node -> node.type == "radio" end)
    assert length(radios) == 3
    assert Enum.all?(radios, fn r -> r.props[:group] == "demo_radio" end)
  end

  test "pick list select" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :select, id: "demo_pick", value: "Medium"})
    assert model.pick_list_selected == "Medium"
  end

  test "modal show/hide" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :click, id: "show_modal"})
    assert model.modal_visible == true
    model = Catalog.update(model, %Widget{type: :click, id: "hide_modal"})
    assert model.modal_visible == false
  end

  test "panel collapse toggle" do
    model = Catalog.init([])
    model = Catalog.update(model, %Widget{type: :click, id: "demo_panel"})
    assert model.panel_collapsed == true
    model = Catalog.update(model, %Widget{type: :click, id: "demo_panel"})
    assert model.panel_collapsed == false
  end

  test "all widget types appear in their respective tabs" do
    model = Catalog.init([])

    # Layout tab
    tree = Catalog.view(%{model | active_tab: "layout"})
    ids = Plushie.UI.ids(tree)
    assert "catalog" in ids

    # Input tab
    tree = Catalog.view(%{model | active_tab: "input"})
    assert Plushie.UI.exists?(tree, "demo_input")
    assert Plushie.UI.exists?(tree, "demo_check")

    # Display tab
    tree = Catalog.view(%{model | active_tab: "display"})
    assert tree.type == "window"

    # Composite tab
    tree = Catalog.view(%{model | active_tab: "composite"})
    assert tree.type == "window"
  end

  test "demo tabs switch active content" do
    model = Catalog.init([]) |> Map.put(:active_tab, "composite")
    assert model.demo_tabs_active == "tab_one"

    model = Catalog.update(model, %Widget{type: :click, id: "tab_two"})
    assert model.demo_tabs_active == "tab_two"

    tree = Catalog.view(model)
    assert Plushie.UI.exists?(tree, "demo_tabs")
  end

  test "modal hides when not visible and shows when visible" do
    model = Catalog.init([]) |> Map.put(:active_tab, "composite")
    assert model.modal_visible == false

    tree = Catalog.view(model)
    # Modal container not in tree when hidden
    refute Plushie.UI.exists?(tree, "demo_modal")

    model = Catalog.update(model, %Widget{type: :click, id: "show_modal"})
    assert model.modal_visible == true

    tree = Catalog.view(model)
    modal_node = Plushie.UI.find(tree, "demo_modal")
    assert modal_node != nil
    # Modal should have children (the content) when visible
    assert modal_node.children != []
  end

  test "canvas node exists in display tab" do
    model = Catalog.init([]) |> Map.put(:active_tab, "display")
    tree = Catalog.view(model)
    assert Plushie.UI.exists?(tree, "demo_canvas")
    canvas_node = Plushie.UI.find(tree, "demo_canvas")
    assert canvas_node.type == "canvas"
    assert is_map(canvas_node.props[:layers])
    assert map_size(canvas_node.props[:layers]) > 0
  end

  test "table node exists in composite tab" do
    model = Catalog.init([]) |> Map.put(:active_tab, "composite")
    tree = Catalog.view(model)
    assert Plushie.UI.exists?(tree, "demo_table")
    table_node = Plushie.UI.find(tree, "demo_table")
    assert table_node.type == "table"
    assert length(table_node.props[:columns]) == 3
    assert length(table_node.props[:rows]) == 3
  end

  test "unknown events are handled gracefully" do
    model = Catalog.init([])
    model2 = Catalog.update(model, :some_random_event)
    assert model2 == model
  end
end
