defmodule Plushie.Docs.CompositionPatternsTest do
  use ExUnit.Case, async: true

  # ============================================================================
  # Tab bar (section 1)
  # ============================================================================

  defmodule TabApp do
    use Plushie.App

    alias Plushie.Event.WidgetEvent
    alias Plushie.Type.Border
    alias Plushie.Type.StyleMap

    def init(_opts), do: %{active_tab: :overview}

    def update(model, %WidgetEvent{type: :click, id: "tab:" <> name}) do
      %{model | active_tab: String.to_existing_atom(name)}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      tabs = [:overview, :details, :settings]

      window "main", title: "Tab Demo" do
        column width: :fill do
          row spacing: 0 do
            for tab <- tabs do
              button(
                "tab:#{tab}",
                tab |> Atom.to_string() |> String.capitalize(),
                style: tab_style(model.active_tab == tab),
                padding: %{top: 10, bottom: 10, left: 20, right: 20}
              )
            end
          end

          rule()

          container "content", padding: 20, width: :fill, height: :fill do
            text("Content for #{model.active_tab}")
          end
        end
      end
    end

    defp tab_style(true = _active?) do
      StyleMap.new()
      |> StyleMap.background("#ffffff")
      |> StyleMap.text_color("#1a1a1a")
      |> StyleMap.border(
        Border.new()
        |> Border.color("#0066ff")
        |> Border.width(2)
        |> Border.rounded(0)
      )
    end

    defp tab_style(false = _active?) do
      StyleMap.new()
      |> StyleMap.background("#f0f0f0")
      |> StyleMap.text_color("#666666")
      |> StyleMap.hovered(%{background: "#e0e0e0"})
    end
  end

  test "composition_patterns_tab_bar_init_test" do
    model = TabApp.init([])
    assert model.active_tab == :overview
  end

  test "composition_patterns_tab_bar_click_changes_active_tab_test" do
    model = TabApp.init([])
    model = TabApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "tab:settings"})
    assert model.active_tab == :settings
  end

  test "composition_patterns_tab_bar_view_has_three_tab_buttons_test" do
    model = TabApp.init([])
    tree = Plushie.Tree.normalize(TabApp.view(model))

    assert [column] = tree.children
    assert [row, _rule, _content] = column.children
    assert length(row.children) == 3

    ids = Enum.map(row.children, & &1.id)
    assert ids == ["main#tab:overview", "main#tab:details", "main#tab:settings"]
  end

  test "composition_patterns_tab_bar_view_content_reflects_active_tab_test" do
    model = %{active_tab: :details}
    tree = Plushie.Tree.normalize(TabApp.view(model))

    assert [column] = tree.children
    assert [_, _, content] = column.children
    assert [text_node] = content.children
    assert text_node.props[:content] == "Content for details"
  end

  # ============================================================================
  # Sidebar navigation (section 2)
  # ============================================================================

  defmodule SidebarApp do
    use Plushie.App

    alias Plushie.Event.WidgetEvent
    alias Plushie.Type.StyleMap

    @nav_items [
      {:inbox, "Inbox"},
      {:sent, "Sent"},
      {:drafts, "Drafts"},
      {:trash, "Trash"}
    ]

    def init(_opts), do: %{page: :inbox}

    def update(model, %WidgetEvent{type: :click, id: "nav:" <> name}) do
      %{model | page: String.to_existing_atom(name)}
    end

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Sidebar Demo" do
        row width: :fill, height: :fill do
          container "sidebar", width: 200, height: :fill, background: "#1e1e2e", padding: 8 do
            column spacing: 4, width: :fill do
              text("nav_label", "Navigation", size: 12, color: "#888888")
              space(height: 8)

              for {id, label} <- @nav_items do
                button(
                  "nav:#{id}",
                  label,
                  style: nav_item_style(model.page == id),
                  width: :fill,
                  padding: %{top: 8, bottom: 8, left: 12, right: 12}
                )
              end
            end
          end

          container "main", width: :fill, height: :fill, padding: 24 do
            text("page_title", "#{model.page |> Atom.to_string() |> String.capitalize()} page",
              size: 20
            )
          end
        end
      end
    end

    defp nav_item_style(true = _selected?) do
      StyleMap.new()
      |> StyleMap.background("#3366ff")
      |> StyleMap.text_color("#ffffff")
      |> StyleMap.hovered(%{background: "#4477ff"})
    end

    defp nav_item_style(false = _selected?) do
      StyleMap.new()
      |> StyleMap.background("#1e1e2e")
      |> StyleMap.text_color("#cccccc")
      |> StyleMap.hovered(%{background: "#2a2a3e", text_color: "#ffffff"})
    end
  end

  test "composition_patterns_sidebar_init_test" do
    model = SidebarApp.init([])
    assert model.page == :inbox
  end

  test "composition_patterns_sidebar_click_changes_page_test" do
    model = SidebarApp.init([])
    model = SidebarApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "nav:sent"})
    assert model.page == :sent
  end

  test "composition_patterns_sidebar_view_has_nav_items_test" do
    model = SidebarApp.init([])
    tree = Plushie.Tree.normalize(SidebarApp.view(model))

    assert [row] = tree.children
    assert [sidebar_container, main_container] = row.children
    assert sidebar_container.id == "main#sidebar"
    assert main_container.id == "main#main"

    assert [nav_col] = sidebar_container.children
    # nav_label, spacer, and 4 nav buttons
    nav_buttons = Enum.filter(nav_col.children, &(&1.type == "button"))
    assert length(nav_buttons) == 4
  end

  test "composition_patterns_sidebar_view_shows_page_title_test" do
    model = %{page: :drafts}
    tree = Plushie.Tree.normalize(SidebarApp.view(model))

    assert [row] = tree.children
    assert [_, main_container] = row.children
    assert [title] = main_container.children
    assert title.props[:content] == "Drafts page"
  end

  # ============================================================================
  # Modal dialog (section 4)
  # ============================================================================

  defmodule ModalApp do
    use Plushie.App

    alias Plushie.Event.WidgetEvent
    alias Plushie.Type.Border
    alias Plushie.Type.Shadow
    alias Plushie.Type.StyleMap

    def init(_opts), do: %{show_modal: false, confirmed: false}

    def update(model, %WidgetEvent{type: :click, id: "open_modal"}),
      do: %{model | show_modal: true}

    def update(model, %WidgetEvent{type: :click, id: "confirm"}),
      do: %{model | show_modal: false, confirmed: true}

    def update(model, %WidgetEvent{type: :click, id: "cancel"}),
      do: %{model | show_modal: false}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Modal Demo" do
        stack width: :fill, height: :fill do
          container "main", width: :fill, height: :fill, padding: 24, center: true do
            column spacing: 12, align_x: :center do
              text("main_content", "Main application content", size: 20)

              if model.confirmed do
                text("confirmed_msg", "Action confirmed.", color: "#22aa44")
              end

              button("open_modal", "Open Dialog", style: :primary)
            end
          end

          if model.show_modal do
            container "overlay",
              width: :fill,
              height: :fill,
              background: "#00000088",
              center: true do
              container "dialog" do
                max_width(400)
                padding(24)
                background("#ffffff")

                border do
                  color("#dddddd")
                  width(1)
                  rounded(8)
                end

                shadow do
                  color("#00000040")
                  offset_y(4)
                  blur_radius(16)
                end

                column spacing: 16 do
                  text("dialog_title", "Confirm action", size: 18, color: "#1a1a1a")

                  text(
                    "dialog_body",
                    "Are you sure you want to proceed? This cannot be undone.",
                    color: "#555555",
                    wrapping: :word
                  )

                  row spacing: 8 do
                    button("cancel", "Cancel", style: :secondary)
                    button("confirm", "Confirm", style: :primary)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "composition_patterns_modal_init_test" do
    model = ModalApp.init([])
    assert model.show_modal == false
    assert model.confirmed == false
  end

  test "composition_patterns_modal_open_test" do
    model = ModalApp.init([])
    model = ModalApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "open_modal"})
    assert model.show_modal == true
  end

  test "composition_patterns_modal_confirm_test" do
    model = %{show_modal: true, confirmed: false}
    model = ModalApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "confirm"})
    assert model.show_modal == false
    assert model.confirmed == true
  end

  test "composition_patterns_modal_cancel_test" do
    model = %{show_modal: true, confirmed: false}
    model = ModalApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "cancel"})
    assert model.show_modal == false
    assert model.confirmed == false
  end

  test "composition_patterns_modal_view_no_overlay_when_closed_test" do
    model = %{show_modal: false, confirmed: false}
    tree = Plushie.Tree.normalize(ModalApp.view(model))

    assert [stack] = tree.children
    # Only the main content child, no overlay
    assert length(stack.children) == 1
  end

  test "composition_patterns_modal_view_has_overlay_when_open_test" do
    model = %{show_modal: true, confirmed: false}
    tree = Plushie.Tree.normalize(ModalApp.view(model))

    assert [stack] = tree.children
    # main content + overlay
    assert length(stack.children) == 2

    assert [_, overlay] = stack.children
    assert overlay.id == "main#overlay"
    assert [dialog] = overlay.children
    assert dialog.id == "main#overlay/dialog"
  end

  test "composition_patterns_modal_view_shows_confirmed_message_test" do
    model = %{show_modal: false, confirmed: true}
    tree = Plushie.Tree.normalize(ModalApp.view(model))

    assert [stack] = tree.children
    assert [main] = stack.children
    assert [main_col] = main.children
    # main_content text, confirmed_msg text, open button
    assert length(main_col.children) == 3
    assert [_, confirmed, _] = main_col.children
    assert confirmed.id == "main#main/confirmed_msg"
  end

  # ============================================================================
  # Card (section 5)
  # ============================================================================

  defmodule CardHelper do
    import Plushie.UI

    alias Plushie.Type.Border
    alias Plushie.Type.Shadow

    def card(id, title, body_fn) do
      border = Border.new() |> Border.color("#e0e0e0") |> Border.width(1) |> Border.rounded(8)

      shadow =
        Shadow.new() |> Shadow.color("#00000020") |> Shadow.offset(0, 2) |> Shadow.blur_radius(8)

      container id,
        width: :fill,
        padding: 16,
        background: "#ffffff",
        border: border,
        shadow: shadow do
        column spacing: 8 do
          text("card_title", title, size: 16, color: "#1a1a1a")
          rule()

          for node <- body_fn.() do
            node
          end
        end
      end
    end
  end

  test "composition_patterns_card_helper_produces_correct_structure_test" do
    import Plushie.UI

    node =
      CardHelper.card("info", "System status", fn ->
        [
          text("status_msg", "All services operational", color: "#22aa44")
        ]
      end)

    tree = Plushie.Tree.normalize(node)

    assert tree.type == "container"
    assert tree.id == "info"

    assert [col] = tree.children
    assert col.type == "column"

    # title, rule, body text
    assert length(col.children) == 3
    assert [title, rule_node, body_text] = col.children
    assert title.id == "info/card_title"
    assert title.props[:content] == "System status"
    assert rule_node.type == "rule"
    assert body_text.id == "info/status_msg"
  end

  # ============================================================================
  # Split panel (section 6)
  # ============================================================================

  defmodule SplitApp do
    use Plushie.App

    alias Plushie.Event.WidgetEvent

    def init(_opts), do: %{left_width: 300}

    def update(model, _event), do: model

    def view(model) do
      import Plushie.UI

      window "main", title: "Split Panel Demo" do
        row width: :fill, height: :fill do
          container "left_panel",
            width: model.left_width,
            height: :fill,
            padding: 16,
            background: "#fafafa" do
            column spacing: 8 do
              text("left_title", "Left panel", size: 16)

              text("left_desc", "File browser, outline, or any sidebar content.",
                color: "#666666"
              )
            end
          end

          pointer_area "divider", cursor: :resizing_horizontally do
            container "divider_track",
              width: 5,
              height: :fill,
              background: "#e0e0e0" do
              rule(direction: :vertical)
            end
          end

          container "right_panel",
            width: :fill,
            height: :fill,
            padding: 16 do
            column spacing: 8 do
              text("right_title", "Right panel", size: 16)
              text("right_desc", "Main editor or content area.", color: "#666666")
            end
          end
        end
      end
    end
  end

  test "composition_patterns_split_panel_has_three_sections_test" do
    model = SplitApp.init([])
    tree = Plushie.Tree.normalize(SplitApp.view(model))

    assert [row] = tree.children
    assert length(row.children) == 3

    assert [left, divider, right] = row.children
    assert left.id == "main#left_panel"
    assert divider.id == "main#divider"
    assert divider.type == "pointer_area"
    assert right.id == "main#right_panel"
  end

  # ============================================================================
  # Breadcrumb (section 7)
  # ============================================================================

  defmodule BreadcrumbApp do
    alias Plushie.Event.WidgetEvent

    def init(_opts), do: %{path: ["Home", "Projects", "Plushie", "Docs"]}

    def update(model, %WidgetEvent{type: :click, id: "crumb:" <> index_str}) do
      index = String.to_integer(index_str)
      %{model | path: Enum.take(model.path, index + 1)}
    end

    def update(model, _event), do: model
  end

  test "composition_patterns_breadcrumb_click_truncates_path_test" do
    model = BreadcrumbApp.init([])
    model = BreadcrumbApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "crumb:1"})
    assert model.path == ["Home", "Projects"]
  end

  test "composition_patterns_breadcrumb_click_first_keeps_root_test" do
    model = %{path: ["Home", "Projects", "Plushie"]}
    model = BreadcrumbApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "crumb:0"})
    assert model.path == ["Home"]
  end

  # ============================================================================
  # Badge / chip (section 8)
  # ============================================================================

  defmodule ChipApp do
    alias Plushie.Event.WidgetEvent

    def init(_opts), do: %{selected: MapSet.new(["elixir"])}

    def update(model, %WidgetEvent{type: :click, id: "tag:" <> name}) do
      selected =
        if MapSet.member?(model.selected, name) do
          MapSet.delete(model.selected, name)
        else
          MapSet.put(model.selected, name)
        end

      %{model | selected: selected}
    end

    def update(model, _event), do: model
  end

  test "composition_patterns_chip_toggle_on_test" do
    model = %{selected: MapSet.new()}
    model = ChipApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "tag:rust"})
    assert MapSet.member?(model.selected, "rust")
  end

  test "composition_patterns_chip_toggle_off_test" do
    model = %{selected: MapSet.new(["rust"])}
    model = ChipApp.update(model, %Plushie.Event.WidgetEvent{type: :click, id: "tag:rust"})
    refute MapSet.member?(model.selected, "rust")
  end

  # ============================================================================
  # State helpers: undo, selection, route, data
  # ============================================================================

  # -- undo --

  test "composition_patterns_state_helper_undo_apply_and_revert_test" do
    undo = Plushie.Undo.new(0)

    undo =
      Plushie.Undo.push(undo, %{
        apply: &(&1 + 10),
        undo: &(&1 - 10),
        label: "add 10"
      })

    assert Plushie.Undo.current(undo) == 10

    undo = Plushie.Undo.undo(undo)
    assert Plushie.Undo.current(undo) == 0

    undo = Plushie.Undo.redo(undo)
    assert Plushie.Undo.current(undo) == 10
  end

  # -- selection --

  test "composition_patterns_state_helper_selection_multi_test" do
    sel = Plushie.Selection.new(mode: :multi)
    sel = Plushie.Selection.select(sel, "item_1")
    sel = Plushie.Selection.select(sel, "item_3", extend: true)

    assert MapSet.member?(Plushie.Selection.selected(sel), "item_1")
    assert MapSet.member?(Plushie.Selection.selected(sel), "item_3")

    sel = Plushie.Selection.toggle(sel, "item_1")
    refute MapSet.member?(Plushie.Selection.selected(sel), "item_1")
    assert MapSet.member?(Plushie.Selection.selected(sel), "item_3")
  end

  test "composition_patterns_state_helper_selection_range_test" do
    sel = Plushie.Selection.new(mode: :range, order: ["a", "b", "c", "d", "e"])
    sel = Plushie.Selection.select(sel, "b")
    sel = Plushie.Selection.range_select(sel, "d")

    selected = Plushie.Selection.selected(sel)
    assert MapSet.member?(selected, "b")
    assert MapSet.member?(selected, "c")
    assert MapSet.member?(selected, "d")
    refute MapSet.member?(selected, "a")
    refute MapSet.member?(selected, "e")
  end

  # -- route --

  test "composition_patterns_state_helper_route_push_and_pop_test" do
    route = Plushie.Route.new("/dashboard")
    route = Plushie.Route.push(route, "/settings", %{tab: "general"})

    assert Plushie.Route.current(route) == "/settings"
    assert Plushie.Route.params(route) == %{tab: "general"}

    route = Plushie.Route.pop(route)
    assert Plushie.Route.current(route) == "/dashboard"
  end

  # -- data --

  test "composition_patterns_state_helper_data_query_filter_test" do
    records = [
      %{id: 1, name: "Alice", role: "admin", active: true},
      %{id: 2, name: "Bob", role: "user", active: false},
      %{id: 3, name: "Carol", role: "admin", active: true}
    ]

    result =
      Plushie.Data.query(records,
        filter: fn r -> r.active end,
        sort: {:asc, :name},
        page: 1,
        page_size: 10
      )

    assert result.total == 2
    names = Enum.map(result.entries, & &1.name)
    assert names == ["Alice", "Carol"]
  end
end
