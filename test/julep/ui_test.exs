defmodule JulepUITestHelper do
  @moduledoc false
  import Julep.UI

  def simple_column do
    column do
      text("hello")
      text("world")
    end
  end

  def column_with_for do
    items = ["a", "b", "c"]

    column do
      for item <- items do
        text(item)
      end
    end
  end

  def column_with_if(show?) do
    column do
      text("always")

      if show? do
        text("sometimes")
      end
    end
  end

  def nested do
    window "main", title: "Test" do
      column padding: 16 do
        text("hello")

        row do
          button("btn1", "One")
          button("btn2", "Two")
        end
      end
    end
  end
end

defmodule Julep.UITest do
  use ExUnit.Case, async: true

  import Julep.UI

  # ---------------------------------------------------------------------------
  # button/2,3
  # ---------------------------------------------------------------------------

  describe "button/2" do
    test "produces correct node shape" do
      node = button("save", "Save")
      assert node.id == "save"
      assert node.type == "button"
      assert node.props["label"] == "Save"
      assert node.children == []
    end

    test "props contains label as string key" do
      node = button("b", "Label")
      assert Map.has_key?(node.props, "label")
      refute Map.has_key?(node.props, :label)
    end
  end

  describe "button/3 with opts" do
    test "extra opts become string-keyed props" do
      node = button("save", "Save", style: :primary, disabled: true)
      assert node.props["style"] == :primary
      assert node.props["disabled"] == true
    end

    test "reserved keys are not included in props" do
      node = button("b", "B", id: "override", children: [], do: nil)
      refute Map.has_key?(node.props, "id")
      refute Map.has_key?(node.props, "children")
      refute Map.has_key?(node.props, "do")
    end

    test "label is still present alongside extra props" do
      node = button("b", "Click", size: 14)
      assert node.props["label"] == "Click"
      assert node.props["size"] == 14
    end
  end

  # ---------------------------------------------------------------------------
  # text_input/2,3
  # ---------------------------------------------------------------------------

  describe "text_input/2" do
    test "produces correct node shape" do
      node = text_input("name", "Alice")
      assert node.id == "name"
      assert node.type == "text_input"
      assert node.props["value"] == "Alice"
      assert node.children == []
    end
  end

  describe "text_input/3 with opts" do
    test "extra opts become string-keyed props" do
      node = text_input("name", "Alice", placeholder: "Enter name")
      assert node.props["placeholder"] == "Enter name"
      assert node.props["value"] == "Alice"
    end
  end

  # ---------------------------------------------------------------------------
  # checkbox/2,3
  # ---------------------------------------------------------------------------

  describe "checkbox/2" do
    test "produces correct node shape with checked: true" do
      node = checkbox("agree", true)
      assert node.id == "agree"
      assert node.type == "checkbox"
      assert node.props["checked"] == true
      assert node.children == []
    end

    test "produces correct node shape with checked: false" do
      node = checkbox("agree", false)
      assert node.props["checked"] == false
    end
  end

  describe "checkbox/3 with opts" do
    test "extra opts become string-keyed props" do
      node = checkbox("agree", true, label: "I agree")
      assert node.props["label"] == "I agree"
      assert node.props["checked"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # text/1,2 macro
  # ---------------------------------------------------------------------------

  describe "text/1" do
    test "produces a text node with content prop" do
      node = text("hello")
      assert node.type == "text"
      assert node.props["content"] == "hello"
      assert node.children == []
    end

    test "auto-generates an id containing the module name" do
      node = text("hello")
      assert String.starts_with?(node.id, "auto:")
      assert String.contains?(node.id, "Julep.UITest")
    end

    test "auto-generated id is a string" do
      node = text("hello")
      assert is_binary(node.id)
    end
  end

  describe "text/2 with opts" do
    test "explicit id overrides auto-generated id" do
      node = text("hello", id: "my-label")
      assert node.id == "my-label"
    end

    test "extra opts become string-keyed props" do
      node = text("hello", size: 18, color: "red")
      assert node.props["size"] == 18
      assert node.props["color"] == "red"
    end

    test "content prop is always present alongside extra props" do
      node = text("world", size: 12)
      assert node.props["content"] == "world"
    end
  end

  # ---------------------------------------------------------------------------
  # column/0,1 macro
  # ---------------------------------------------------------------------------

  describe "column/0" do
    test "produces a column node" do
      node = column()
      assert node.type == "column"
      assert node.children == []
    end

    test "auto-generates a string id" do
      node = column()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end

    test "props is an empty map when no opts" do
      node = column()
      assert node.props == %{}
    end
  end

  describe "column/1 with opts" do
    test "opts become string-keyed props" do
      node = column(padding: 8, spacing: 4)
      assert node.props["padding"] == 8
      assert node.props["spacing"] == 4
    end

    test "children opt is not included in props" do
      child = button("b", "B")
      node = column(children: [child])
      refute Map.has_key?(node.props, "children")
      assert node.children == [child]
    end
  end

  describe "column do...end" do
    test "collects children from do block" do
      node = JulepUITestHelper.simple_column()
      assert node.type == "column"
      assert length(node.children) == 2
      [first, second] = node.children
      assert first.props["content"] == "hello"
      assert second.props["content"] == "world"
    end
  end

  describe "column opts do...end" do
    test "has both props and children" do
      node =
        column padding: 16, spacing: 8 do
          button("b", "Go")
        end

      assert node.props["padding"] == 16
      assert node.props["spacing"] == 8
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  # ---------------------------------------------------------------------------
  # row do...end
  # ---------------------------------------------------------------------------

  describe "row/0" do
    test "produces a row node with no children" do
      node = row()
      assert node.type == "row"
      assert node.children == []
    end
  end

  describe "row do...end" do
    test "collects children from do block" do
      node =
        row do
          button("yes", "Yes")
          button("no", "No")
        end

      assert node.type == "row"
      assert length(node.children) == 2
      ids = Enum.map(node.children, & &1.id)
      assert ids == ["yes", "no"]
    end
  end

  describe "row opts do...end" do
    test "has both props and children" do
      node =
        row spacing: 4 do
          button("ok", "OK")
        end

      assert node.props["spacing"] == 4
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # window macro
  # ---------------------------------------------------------------------------

  describe "window/1" do
    test "produces a window node with given id" do
      node = window("main")
      assert node.id == "main"
      assert node.type == "window"
      assert node.children == []
      assert node.props == %{}
    end
  end

  describe "window/2 with opts" do
    test "opts become string-keyed props" do
      node = window("app", title: "My App")
      assert node.id == "app"
      assert node.props["title"] == "My App"
    end
  end

  describe "window id do...end" do
    test "collects children" do
      node =
        window "main" do
          button("b", "Go")
        end

      assert node.id == "main"
      assert node.type == "window"
      assert length(node.children) == 1
      assert hd(node.children).id == "b"
    end
  end

  describe "window id, opts do...end" do
    test "has both props and children" do
      node =
        window "app", title: "Test" do
          button("b", "Go")
        end

      assert node.id == "app"
      assert node.props["title"] == "Test"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # container macro
  # ---------------------------------------------------------------------------

  describe "container/1" do
    test "produces a container node with given id" do
      node = container("hero")
      assert node.id == "hero"
      assert node.type == "container"
      assert node.children == []
    end
  end

  describe "container id do...end" do
    test "collects children" do
      node =
        container "hero" do
          text("Welcome")
        end

      assert node.id == "hero"
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "Welcome"
    end
  end

  describe "container id, opts do...end" do
    test "has both props and children" do
      node =
        container "hero", padding: 16 do
          text("Hello")
        end

      assert node.props["padding"] == 16
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # scrollable macro
  # ---------------------------------------------------------------------------

  describe "scrollable/1" do
    test "produces a scrollable node" do
      node = scrollable("feed")
      assert node.id == "feed"
      assert node.type == "scrollable"
      assert node.children == []
    end
  end

  describe "scrollable id do...end" do
    test "collects children" do
      node =
        scrollable "feed" do
          text("Item 1")
          text("Item 2")
        end

      assert node.id == "feed"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # stack macro
  # ---------------------------------------------------------------------------

  describe "stack/0" do
    test "produces a stack node" do
      node = stack()
      assert node.type == "stack"
      assert node.children == []
    end
  end

  describe "stack do...end" do
    test "collects children" do
      node =
        stack do
          container("bg")
          container("overlay")
        end

      assert node.type == "stack"
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # space macro
  # ---------------------------------------------------------------------------

  describe "space/0" do
    test "produces a space node with no children" do
      node = space()
      assert node.type == "space"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = space()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "space/1 with opts" do
    test "opts become props" do
      node = space(width: :fill)
      assert node.props["width"] == :fill
    end
  end

  # ---------------------------------------------------------------------------
  # rule macro
  # ---------------------------------------------------------------------------

  describe "rule/0" do
    test "produces a rule node with no children" do
      node = rule()
      assert node.type == "rule"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = rule()
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "rule/1 with opts" do
    test "explicit id is used when given" do
      node = rule(id: "divider")
      assert node.id == "divider"
    end
  end

  # ---------------------------------------------------------------------------
  # do block with for comprehension
  # ---------------------------------------------------------------------------

  describe "for comprehension inside do block" do
    test "flattens list children produced by for" do
      node = JulepUITestHelper.column_with_for()
      assert node.type == "column"
      assert length(node.children) == 3
      contents = Enum.map(node.children, & &1.props["content"])
      assert contents == ["a", "b", "c"]
    end
  end

  # ---------------------------------------------------------------------------
  # do block with if/nil filtering
  # ---------------------------------------------------------------------------

  describe "if/nil filtering inside do block" do
    test "nil children are filtered out (show? = false)" do
      node = JulepUITestHelper.column_with_if(false)
      assert node.type == "column"
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "always"
    end

    test "non-nil children are included (show? = true)" do
      node = JulepUITestHelper.column_with_if(true)
      assert length(node.children) == 2
      contents = Enum.map(node.children, & &1.props["content"])
      assert "always" in contents
      assert "sometimes" in contents
    end
  end

  # ---------------------------------------------------------------------------
  # Nested do blocks
  # ---------------------------------------------------------------------------

  describe "nested do blocks" do
    test "produces correct tree shape" do
      node = JulepUITestHelper.nested()

      assert node.id == "main"
      assert node.type == "window"
      assert node.props["title"] == "Test"

      assert length(node.children) == 1
      col = hd(node.children)
      assert col.type == "column"
      assert col.props["padding"] == 16

      # column has text + row
      assert length(col.children) == 2
      [txt, row_node] = col.children
      assert txt.type == "text"
      assert txt.props["content"] == "hello"

      assert row_node.type == "row"
      assert length(row_node.children) == 2
      [btn1, btn2] = row_node.children
      assert btn1.id == "btn1"
      assert btn2.id == "btn2"
    end
  end

  # ---------------------------------------------------------------------------
  # find/2 delegates to Tree.find
  # ---------------------------------------------------------------------------

  describe "find/2" do
    test "finds a node by id in the tree" do
      tree =
        window "app" do
          button("save", "Save")
        end

      result = Julep.UI.find(tree, "save")
      assert result != nil
      assert result.id == "save"
      assert result.type == "button"
    end

    test "returns nil when id is not in the tree" do
      tree = window("app")
      assert Julep.UI.find(tree, "ghost") == nil
    end
  end

  # ---------------------------------------------------------------------------
  # toggler/2,3
  # ---------------------------------------------------------------------------

  describe "toggler/2" do
    test "produces correct node shape" do
      node = toggler("dark_mode", true)
      assert node.id == "dark_mode"
      assert node.type == "toggler"
      assert node.props["is_toggled"] == true
      assert node.children == []
    end

    test "works with false value" do
      node = toggler("dark_mode", false)
      assert node.props["is_toggled"] == false
    end
  end

  describe "toggler/3 with opts" do
    test "extra opts become string-keyed props" do
      node = toggler("dark_mode", true, label: "Dark mode", spacing: 8)
      assert node.props["label"] == "Dark mode"
      assert node.props["spacing"] == 8
      assert node.props["is_toggled"] == true
    end
  end

  # ---------------------------------------------------------------------------
  # radio/3,4
  # ---------------------------------------------------------------------------

  describe "radio/3" do
    test "produces correct node shape" do
      node = radio("size_large", "large", "small")
      assert node.id == "size_large"
      assert node.type == "radio"
      assert node.props["value"] == "large"
      assert node.props["selected"] == "small"
      assert node.children == []
    end

    test "selected can be nil" do
      node = radio("size_large", "large", nil)
      assert node.props["selected"] == nil
    end
  end

  describe "radio/4 with opts" do
    test "extra opts become string-keyed props" do
      node = radio("size_large", "large", "large", label: "Large", spacing: 4)
      assert node.props["label"] == "Large"
      assert node.props["spacing"] == 4
    end
  end

  # ---------------------------------------------------------------------------
  # slider/3,4
  # ---------------------------------------------------------------------------

  describe "slider/3" do
    test "produces correct node shape" do
      node = slider("volume", {0, 100}, 50)
      assert node.id == "volume"
      assert node.type == "slider"
      assert node.props["range"] == [0, 100]
      assert node.props["value"] == 50
      assert node.children == []
    end
  end

  describe "slider/4 with opts" do
    test "extra opts become string-keyed props" do
      node = slider("volume", {0, 100}, 50, step: 5, width: :fill)
      assert node.props["step"] == 5
      assert node.props["width"] == :fill
      assert node.props["range"] == [0, 100]
    end
  end

  # ---------------------------------------------------------------------------
  # vertical_slider/3,4
  # ---------------------------------------------------------------------------

  describe "vertical_slider/3" do
    test "produces correct node shape" do
      node = vertical_slider("brightness", {0, 255}, 128)
      assert node.id == "brightness"
      assert node.type == "vertical_slider"
      assert node.props["range"] == [0, 255]
      assert node.props["value"] == 128
      assert node.children == []
    end
  end

  describe "vertical_slider/4 with opts" do
    test "extra opts become string-keyed props" do
      node = vertical_slider("brightness", {0, 255}, 128, step: 1, width: 20)
      assert node.props["step"] == 1
      assert node.props["width"] == 20
    end
  end

  # ---------------------------------------------------------------------------
  # pick_list/3,4
  # ---------------------------------------------------------------------------

  describe "pick_list/3" do
    test "produces correct node shape" do
      node = pick_list("country", ["UK", "US", "DE"], "UK")
      assert node.id == "country"
      assert node.type == "pick_list"
      assert node.props["options"] == ["UK", "US", "DE"]
      assert node.props["selected"] == "UK"
      assert node.children == []
    end

    test "selected can be nil" do
      node = pick_list("country", ["UK", "US"], nil)
      assert node.props["selected"] == nil
    end
  end

  describe "pick_list/4 with opts" do
    test "extra opts become string-keyed props" do
      node = pick_list("country", ["UK", "US"], "UK", placeholder: "Choose...", width: :fill)
      assert node.props["placeholder"] == "Choose..."
      assert node.props["width"] == :fill
    end
  end

  # ---------------------------------------------------------------------------
  # combo_box/3,4
  # ---------------------------------------------------------------------------

  describe "combo_box/3" do
    test "produces correct node shape" do
      node = combo_box("lang", ["Elixir", "Rust", "Go"], "Elixir")
      assert node.id == "lang"
      assert node.type == "combo_box"
      assert node.props["options"] == ["Elixir", "Rust", "Go"]
      assert node.props["value"] == "Elixir"
      assert node.children == []
    end
  end

  describe "combo_box/4 with opts" do
    test "extra opts become string-keyed props" do
      node = combo_box("lang", ["Elixir", "Rust"], "Elixir", placeholder: "Type...", width: 200)
      assert node.props["placeholder"] == "Type..."
      assert node.props["width"] == 200
    end
  end

  # ---------------------------------------------------------------------------
  # text_editor/2,3
  # ---------------------------------------------------------------------------

  describe "text_editor/2" do
    test "produces correct node shape" do
      node = text_editor("notes", "Hello world")
      assert node.id == "notes"
      assert node.type == "text_editor"
      assert node.props["content"] == "Hello world"
      assert node.children == []
    end
  end

  describe "text_editor/3 with opts" do
    test "extra opts become string-keyed props" do
      node = text_editor("notes", "Hello", width: :fill, height: 200)
      assert node.props["width"] == :fill
      assert node.props["height"] == 200
      assert node.props["content"] == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # image/2,3
  # ---------------------------------------------------------------------------

  describe "image/2" do
    test "produces correct node shape" do
      node = image("logo", "/assets/logo.png")
      assert node.id == "logo"
      assert node.type == "image"
      assert node.props["source"] == "/assets/logo.png"
      assert node.children == []
    end
  end

  describe "image/3 with opts" do
    test "extra opts become string-keyed props" do
      node = image("logo", "/assets/logo.png", width: 200, height: 100, content_fit: :cover)
      assert node.props["width"] == 200
      assert node.props["height"] == 100
      assert node.props["content_fit"] == :cover
    end
  end

  # ---------------------------------------------------------------------------
  # svg/2,3
  # ---------------------------------------------------------------------------

  describe "svg/2" do
    test "produces correct node shape" do
      node = svg("icon", "/assets/icon.svg")
      assert node.id == "icon"
      assert node.type == "svg"
      assert node.props["source"] == "/assets/icon.svg"
      assert node.children == []
    end
  end

  describe "svg/3 with opts" do
    test "extra opts become string-keyed props" do
      node = svg("icon", "/assets/icon.svg", width: 24, height: 24, content_fit: :contain)
      assert node.props["width"] == 24
      assert node.props["height"] == 24
      assert node.props["content_fit"] == :contain
    end
  end

  # ---------------------------------------------------------------------------
  # markdown/1,2 macro
  # ---------------------------------------------------------------------------

  describe "markdown/1" do
    test "produces a markdown node with content prop" do
      node = markdown("# Hello")
      assert node.type == "markdown"
      assert node.props["content"] == "# Hello"
      assert node.children == []
    end

    test "auto-generates an id" do
      node = markdown("# Hello")
      assert is_binary(node.id)
      assert String.starts_with?(node.id, "auto:")
    end
  end

  describe "markdown/2 with opts" do
    test "explicit id overrides auto-generated id" do
      node = markdown("# Hello", id: "my-md")
      assert node.id == "my-md"
    end

    test "extra opts become string-keyed props" do
      node = markdown("# Hello", size: 14)
      assert node.props["size"] == 14
      assert node.props["content"] == "# Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # tooltip macro
  # ---------------------------------------------------------------------------

  describe "tooltip/1" do
    test "produces a tooltip node with given id" do
      node = tooltip("tip1")
      assert node.id == "tip1"
      assert node.type == "tooltip"
      assert node.children == []
    end
  end

  describe "tooltip id do...end" do
    test "collects children" do
      node =
        tooltip "tip1" do
          button("save", "Save")
        end

      assert node.id == "tip1"
      assert node.type == "tooltip"
      assert length(node.children) == 1
      assert hd(node.children).id == "save"
    end
  end

  describe "tooltip id, opts do...end" do
    test "has both props and children" do
      node =
        tooltip "tip1", tip: "Save your work", position: :top do
          button("save", "Save")
        end

      assert node.props["tip"] == "Save your work"
      assert node.props["position"] == :top
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # tabs macro
  # ---------------------------------------------------------------------------

  describe "tabs/1" do
    test "produces a tabs node with given id" do
      node = tabs("settings_tabs")
      assert node.id == "settings_tabs"
      assert node.type == "tabs"
      assert node.children == []
    end
  end

  describe "tabs id do...end" do
    test "collects children" do
      node =
        tabs "settings_tabs" do
          container("general")
          container("advanced")
        end

      assert node.type == "tabs"
      assert length(node.children) == 2
    end
  end

  describe "tabs id, opts do...end" do
    test "has both props and children" do
      node =
        tabs "settings_tabs", active: "general" do
          container("general")
        end

      assert node.props["active"] == "general"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # nav macro
  # ---------------------------------------------------------------------------

  describe "nav/1" do
    test "produces a nav node with given id" do
      node = nav("main_nav")
      assert node.id == "main_nav"
      assert node.type == "nav"
      assert node.children == []
    end
  end

  describe "nav id do...end" do
    test "collects children" do
      node =
        nav "main_nav" do
          button("home", "Home")
          button("settings", "Settings")
        end

      assert node.type == "nav"
      assert length(node.children) == 2
    end
  end

  describe "nav id, opts do...end" do
    test "has both props and children" do
      node =
        nav "main_nav", active: "home" do
          button("home", "Home")
        end

      assert node.props["active"] == "home"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # modal macro
  # ---------------------------------------------------------------------------

  describe "modal/1" do
    test "produces a modal node with given id" do
      node = modal("dialog")
      assert node.id == "dialog"
      assert node.type == "modal"
      assert node.children == []
    end
  end

  describe "modal id do...end" do
    test "collects children" do
      node =
        modal "dialog" do
          text("Are you sure?")
          button("yes", "Yes")
        end

      assert node.type == "modal"
      assert length(node.children) == 2
    end
  end

  describe "modal id, opts do...end" do
    test "has both props and children" do
      node =
        modal "dialog", visible: true do
          text("Confirm")
        end

      assert node.props["visible"] == true
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # card macro
  # ---------------------------------------------------------------------------

  describe "card/1" do
    test "produces a card node with given id" do
      node = card("user_card")
      assert node.id == "user_card"
      assert node.type == "card"
      assert node.children == []
    end
  end

  describe "card id do...end" do
    test "collects children" do
      node =
        card "user_card" do
          text("Alice")
        end

      assert node.type == "card"
      assert length(node.children) == 1
    end
  end

  describe "card id, opts do...end" do
    test "has both props and children" do
      node =
        card "user_card", title: "Profile", padding: 16 do
          text("Alice")
        end

      assert node.props["title"] == "Profile"
      assert node.props["padding"] == 16
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # panel macro
  # ---------------------------------------------------------------------------

  describe "panel/1" do
    test "produces a panel node with given id" do
      node = panel("details")
      assert node.id == "details"
      assert node.type == "panel"
      assert node.children == []
    end
  end

  describe "panel id do...end" do
    test "collects children" do
      node =
        panel "details" do
          text("Some details")
        end

      assert node.type == "panel"
      assert length(node.children) == 1
    end
  end

  describe "panel id, opts do...end" do
    test "has both props and children" do
      node =
        panel "details", title: "Details", collapsed: false do
          text("Content")
        end

      assert node.props["title"] == "Details"
      assert node.props["collapsed"] == false
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # form macro
  # ---------------------------------------------------------------------------

  describe "form/1" do
    test "produces a form node with given id" do
      node = form("login_form")
      assert node.id == "login_form"
      assert node.type == "form"
      assert node.children == []
    end
  end

  describe "form id do...end" do
    test "collects children" do
      node =
        form "login_form" do
          text_input("user", "")
          button("submit", "Log in")
        end

      assert node.type == "form"
      assert length(node.children) == 2
    end
  end

  describe "form id, opts do...end" do
    test "has both props and children" do
      node =
        form "login_form", spacing: 8 do
          text_input("user", "")
        end

      assert node.props["spacing"] == 8
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # split_pane macro
  # ---------------------------------------------------------------------------

  describe "split_pane/1" do
    test "produces a split_pane node with given id" do
      node = split_pane("editor_split")
      assert node.id == "editor_split"
      assert node.type == "split_pane"
      assert node.children == []
    end
  end

  describe "split_pane id do...end" do
    test "collects children" do
      node =
        split_pane "editor_split" do
          container("sidebar")
          container("main")
        end

      assert node.type == "split_pane"
      assert length(node.children) == 2
    end
  end

  describe "split_pane id, opts do...end" do
    test "has both props and children" do
      node =
        split_pane "editor_split", ratio: 0.3, direction: :horizontal do
          container("sidebar")
          container("main")
        end

      assert node.props["ratio"] == 0.3
      assert node.props["direction"] == :horizontal
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # canvas/1,2
  # ---------------------------------------------------------------------------

  describe "canvas/1" do
    test "produces a canvas node with given id" do
      node = canvas("drawing")
      assert node.id == "drawing"
      assert node.type == "canvas"
      assert node.props == %{}
      assert node.children == []
    end
  end

  describe "canvas/2 with opts" do
    test "opts become string-keyed props" do
      shapes = [%{type: "rect", x: 0, y: 0, w: 100, h: 50}]
      node = canvas("drawing", shapes: shapes, width: 800, height: 600, background: "#000")

      assert node.props["shapes"] == shapes
      assert node.props["width"] == 800
      assert node.props["height"] == 600
      assert node.props["background"] == "#000"
      assert node.children == []
    end
  end

  # ---------------------------------------------------------------------------
  # table/1,2 macro
  # ---------------------------------------------------------------------------

  describe "table/1" do
    test "produces a table node with given id" do
      node = table("users")
      assert node.id == "users"
      assert node.type == "table"
      assert node.children == []
    end
  end

  describe "table/2 with opts" do
    test "columns and rows become string-keyed props" do
      cols = [%{key: "name", label: "Name", width: 200}]
      rows = [%{name: "Alice"}, %{name: "Bob"}]
      node = table("users", columns: cols, rows: rows)

      assert node.props["columns"] == cols
      assert node.props["rows"] == rows
      assert node.children == []
    end
  end

  describe "table id do...end" do
    test "collects children from do block" do
      node =
        table "users" do
          text("custom footer")
        end

      assert node.id == "users"
      assert node.type == "table"
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "custom footer"
    end
  end

  describe "table id, opts do...end" do
    test "has both props and children" do
      cols = [%{key: "name", label: "Name", width: 200}]
      rows = [%{name: "Alice"}]

      node =
        table "users", columns: cols, rows: rows do
          text("row template")
        end

      assert node.props["columns"] == cols
      assert node.props["rows"] == rows
      assert length(node.children) == 1
      assert hd(node.children).props["content"] == "row template"
    end
  end

  # ---------------------------------------------------------------------------
  # canvas edge cases
  # ---------------------------------------------------------------------------

  describe "canvas with empty shapes" do
    test "canvas with explicit empty shapes list" do
      node = canvas("cv", shapes: [])
      assert node.type == "canvas"
      assert node.props["shapes"] == []
    end

    test "canvas with no shapes prop at all" do
      node = canvas("cv")
      refute Map.has_key?(node.props, "shapes")
    end

    test "canvas with all shape types" do
      shapes = [
        %{type: "rect", x: 0, y: 0, w: 100, h: 50},
        %{type: "circle", cx: 50, cy: 50, r: 25},
        %{type: "line", x1: 0, y1: 0, x2: 100, y2: 100},
        %{type: "text", x: 10, y: 10, content: "hello"}
      ]

      node = canvas("cv", shapes: shapes, width: 800, height: 600)
      assert length(node.props["shapes"]) == 4
      types = Enum.map(node.props["shapes"], & &1.type)
      assert types == ["rect", "circle", "line", "text"]
    end
  end

  # ---------------------------------------------------------------------------
  # table edge cases
  # ---------------------------------------------------------------------------

  describe "table with empty rows" do
    test "table with columns but empty rows list" do
      cols = [%{key: "name", label: "Name", width: 200}]
      node = table("t", columns: cols, rows: [])
      assert node.props["columns"] == cols
      assert node.props["rows"] == []
    end
  end

  describe "table with empty columns" do
    test "table with rows but empty columns list" do
      rows = [%{name: "Alice"}]
      node = table("t", columns: [], rows: rows)
      assert node.props["columns"] == []
      assert node.props["rows"] == rows
    end
  end

  describe "table with no data props" do
    test "table with no columns or rows at all" do
      node = table("t")
      refute Map.has_key?(node.props, "columns")
      refute Map.has_key?(node.props, "rows")
    end
  end

  # ---------------------------------------------------------------------------
  # Counter example view produces expected tree shape
  # ---------------------------------------------------------------------------

  describe "Counter example view shape" do
    test "root node is a window" do
      tree = Julep.Examples.Counter.view(%{count: 0})
      assert tree.type == "window"
      assert tree.id == "main"
    end

    test "contains increment and decrement buttons" do
      tree = Julep.Examples.Counter.view(%{count: 0})
      inc = Julep.UI.find(tree, "increment")
      dec = Julep.UI.find(tree, "decrement")
      assert inc != nil
      assert inc.type == "button"
      assert dec != nil
      assert dec.type == "button"
    end

    test "contains a text node with the current count" do
      tree = Julep.Examples.Counter.view(%{count: 0})

      text_nodes = Julep.Tree.find_all(tree, fn node -> node.type == "text" end)
      count_node = Enum.find(text_nodes, fn n -> n.props["content"] == "Count: 0" end)
      assert count_node != nil
    end
  end
end
