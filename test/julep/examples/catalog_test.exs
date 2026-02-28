defmodule Julep.Examples.CatalogTest do
  use ExUnit.Case, async: true

  alias Julep.Examples.Catalog

  test "init returns expected model" do
    model = Catalog.init([])
    assert model.active_tab == "layout"
  end

  test "switching tabs" do
    model = Catalog.init([])
    model = Catalog.update(model, {:click, "tab_input"})
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
    model = Catalog.update(model, {:input, "demo_input", "hello"})
    assert model.text_value == "hello"
  end

  test "checkbox toggle" do
    model = Catalog.init([])
    model = Catalog.update(model, {:toggle, "demo_check", true})
    assert model.checkbox_checked == true
  end

  test "slider change" do
    model = Catalog.init([])
    model = Catalog.update(model, {:slide, "demo_slider", 75})
    assert model.slider_value == 75
  end

  test "radio group select" do
    model = Catalog.init([])
    assert model.radio_selected == "a"
    model = Catalog.update(model, {:select, "demo_radio", "b"})
    assert model.radio_selected == "b"
    model = Catalog.update(model, {:select, "demo_radio", "c"})
    assert model.radio_selected == "c"
  end

  test "radio buttons emit group prop in tree" do
    model = Catalog.init([]) |> Map.put(:active_tab, "input")
    tree = Catalog.view(model)
    radios = Julep.UI.find_all(tree, fn node -> node.type == "radio" end)
    assert length(radios) == 3
    assert Enum.all?(radios, fn r -> r.props["group"] == "demo_radio" end)
  end

  test "pick list select" do
    model = Catalog.init([])
    model = Catalog.update(model, {:select, "demo_pick", "Medium"})
    assert model.pick_list_selected == "Medium"
  end

  test "modal show/hide" do
    model = Catalog.init([])
    model = Catalog.update(model, {:click, "show_modal"})
    assert model.modal_visible == true
    model = Catalog.update(model, {:click, "hide_modal"})
    assert model.modal_visible == false
  end

  test "panel collapse toggle" do
    model = Catalog.init([])
    model = Catalog.update(model, {:click, "demo_panel"})
    assert model.panel_collapsed == true
    model = Catalog.update(model, {:click, "demo_panel"})
    assert model.panel_collapsed == false
  end

  test "all widget types appear in their respective tabs" do
    model = Catalog.init([])

    # Layout tab
    tree = Catalog.view(%{model | active_tab: "layout"})
    ids = Julep.UI.ids(tree)
    assert "catalog" in ids

    # Input tab
    tree = Catalog.view(%{model | active_tab: "input"})
    assert Julep.UI.exists?(tree, "demo_input")
    assert Julep.UI.exists?(tree, "demo_check")

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

    model = Catalog.update(model, {:click, "tab_two"})
    assert model.demo_tabs_active == "tab_two"

    tree = Catalog.view(model)
    tabs_node = Julep.UI.find(tree, "demo_tabs")
    assert tabs_node.props["active"] == "tab_two"
  end

  test "modal hides when not visible and shows when visible" do
    model = Catalog.init([]) |> Map.put(:active_tab, "composite")
    assert model.modal_visible == false

    tree = Catalog.view(model)
    modal_node = Julep.UI.find(tree, "demo_modal")
    assert modal_node.props["visible"] == false

    model = Catalog.update(model, {:click, "show_modal"})
    assert model.modal_visible == true

    tree = Catalog.view(model)
    modal_node = Julep.UI.find(tree, "demo_modal")
    assert modal_node.props["visible"] == true
    # Modal should have children (the content) when visible
    assert length(modal_node.children) > 0
  end

  test "canvas node exists in display tab" do
    model = Catalog.init([]) |> Map.put(:active_tab, "display")
    tree = Catalog.view(model)
    assert Julep.UI.exists?(tree, "demo_canvas")
    canvas_node = Julep.UI.find(tree, "demo_canvas")
    assert canvas_node.type == "canvas"
    assert is_map(canvas_node.props["layers"])
    assert map_size(canvas_node.props["layers"]) > 0
  end

  test "table node exists in composite tab" do
    model = Catalog.init([]) |> Map.put(:active_tab, "composite")
    tree = Catalog.view(model)
    assert Julep.UI.exists?(tree, "demo_table")
    table_node = Julep.UI.find(tree, "demo_table")
    assert table_node.type == "table"
    assert length(table_node.props["columns"]) == 3
    assert length(table_node.props["rows"]) == 3
  end

  test "unknown events are handled gracefully" do
    model = Catalog.init([])
    model2 = Catalog.update(model, :some_random_event)
    assert model2 == model
  end
end
