defmodule Examples.CatalogTest do
  @moduledoc "Integration tests for the Catalog example using the test DSL."

  use Plushie.Test.Case, app: Catalog

  test "starts on the layout tab" do
    assert model().active_tab == "layout"
  end

  test "title renders" do
    assert_text("#catalog_title", "Plushie Widget Catalog")
  end

  test "tab buttons exist" do
    assert_exists("#tab_layout")
    assert_exists("#tab_input")
    assert_exists("#tab_display")
    assert_exists("#tab_composite")
  end

  test "layout tab heading visible on start" do
    assert_text("#layout_heading", "Layout Widgets")
  end

  test "switching to input tab" do
    click("#tab_input")
    assert model().active_tab == "input"
    assert_text("#input_heading", "Input Widgets")
  end

  test "switching to display tab" do
    click("#tab_display")
    assert model().active_tab == "display"
    assert_text("#display_heading", "Display Widgets")
  end

  test "switching to composite tab" do
    click("#tab_composite")
    assert model().active_tab == "composite"
    assert_text("#composite_heading", "Interactive & Composite Widgets")
  end

  test "input tab has text input" do
    click("#tab_input")
    assert_exists("#demo_input")
  end

  test "input tab has checkbox" do
    click("#tab_input")
    assert_exists("#demo_check")
  end

  test "input tab has toggler" do
    click("#tab_input")
    assert_exists("#demo_toggler")
  end

  test "input tab has slider" do
    click("#tab_input")
    assert_exists("#demo_slider")
  end

  test "composite tab has counter button" do
    click("#tab_composite")
    assert_exists("#counter_btn")
    click("#counter_btn")
    assert model().click_count == 1
  end

  test "composite tab has demo tabs" do
    click("#tab_composite")
    assert_exists("#demo_tabs")
    assert_exists("#tab_one")
    assert_exists("#tab_two")
  end

  test "composite tab modal starts hidden" do
    click("#tab_composite")
    assert model().modal_visible == false
    assert_exists("#show_modal")
    assert_not_exists("#demo_modal")
  end

  test "showing and hiding modal" do
    click("#tab_composite")
    click("#show_modal")
    assert model().modal_visible == true
    assert_exists("#demo_modal")
    click("#hide_modal")
    assert model().modal_visible == false
    assert_not_exists("#demo_modal")
  end

  test "collapsing and expanding panel" do
    click("#tab_composite")
    assert model().panel_collapsed == false
    assert_exists("#panel_content")
    click("#demo_panel")
    assert model().panel_collapsed == true
    assert_not_exists("#panel_content")
    click("#demo_panel")
    assert model().panel_collapsed == false
    assert_exists("#panel_content")
  end

  test "layout tab has containers and scrollable" do
    assert_exists("#demo_container")
    assert_exists("#demo_scrollable")
  end

  test "layout tab has themer section" do
    assert_exists("#demo_themer")
  end

  test "display tab has canvas" do
    click("#tab_display")
    assert_exists("#demo_canvas")
  end

  test "display tab has markdown" do
    click("#tab_display")
    assert_exists("#demo_markdown")
  end

  test "composite tab has table" do
    click("#tab_composite")
    assert_exists("#demo_table")
  end

  test "composite tab has pane grid" do
    click("#tab_composite")
    assert_exists("#demo_panes")
  end
end
