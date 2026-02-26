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

  test "unknown events are handled gracefully" do
    model = Catalog.init([])
    model2 = Catalog.update(model, :some_random_event)
    assert model2 == model
  end
end
