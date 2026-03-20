defmodule Toddy.Widget.WindowTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Window

  describe "new/2" do
    test "creates a window with the given id and nil defaults" do
      w = Window.new("main")
      assert w.id == "main"
      assert w.title == nil
      assert w.size == nil
      assert w.width == nil
      assert w.height == nil
      assert w.position == nil
      assert w.min_size == nil
      assert w.max_size == nil
      assert w.maximized == nil
      assert w.fullscreen == nil
      assert w.visible == nil
      assert w.resizable == nil
      assert w.closeable == nil
      assert w.minimizable == nil
      assert w.decorations == nil
      assert w.transparent == nil
      assert w.blur == nil
      assert w.level == nil
      assert w.exit_on_close_request == nil
      assert w.children == []
    end

    test "accepts keyword options" do
      w = Window.new("main", title: "My App", size: {800, 600})
      assert w.title == "My App"
      assert w.size == {800, 600}
    end
  end

  describe "builder functions" do
    test "title/2 sets the title" do
      w = Window.new("w") |> Window.title("Hello")
      assert w.title == "Hello"
    end

    test "size/2 sets the size tuple" do
      w = Window.new("w") |> Window.size({1024, 768})
      assert w.size == {1024, 768}
    end

    test "width/2 sets the width" do
      w = Window.new("w") |> Window.width(800)
      assert w.width == 800
    end

    test "height/2 sets the height" do
      w = Window.new("w") |> Window.height(600)
      assert w.height == 600
    end

    test "position/2 sets the position" do
      w = Window.new("w") |> Window.position({100, 200})
      assert w.position == {100, 200}
    end

    test "min_size/2 sets the minimum size" do
      w = Window.new("w") |> Window.min_size({320, 240})
      assert w.min_size == {320, 240}
    end

    test "max_size/2 sets the maximum size" do
      w = Window.new("w") |> Window.max_size({1920, 1080})
      assert w.max_size == {1920, 1080}
    end

    test "boolean props accept true/false" do
      w =
        Window.new("w")
        |> Window.maximized(true)
        |> Window.fullscreen(false)
        |> Window.visible(true)
        |> Window.resizable(false)
        |> Window.closeable(true)
        |> Window.minimizable(false)
        |> Window.decorations(true)
        |> Window.transparent(false)
        |> Window.blur(true)
        |> Window.exit_on_close_request(true)

      assert w.maximized == true
      assert w.fullscreen == false
      assert w.visible == true
      assert w.resizable == false
      assert w.closeable == true
      assert w.minimizable == false
      assert w.decorations == true
      assert w.transparent == false
      assert w.blur == true
      assert w.exit_on_close_request == true
    end

    test "level/2 sets the stacking level" do
      w = Window.new("w") |> Window.level(:always_on_top)
      assert w.level == :always_on_top
    end
  end

  describe "push/2 and extend/2" do
    test "push/2 appends a single child" do
      child = %{id: "txt", type: "text", props: %{}, children: []}
      w = Window.new("w") |> Window.push(child)
      assert length(w.children) == 1
    end

    test "extend/2 appends multiple children" do
      children = [
        %{id: "t1", type: "text", props: %{}, children: []},
        %{id: "t2", type: "text", props: %{}, children: []}
      ]

      w = Window.new("w") |> Window.extend(children)
      assert length(w.children) == 2
    end
  end

  describe "build/1" do
    test "returns a ui_node map with type \"window\"" do
      node = Window.new("main") |> Window.build()
      assert node.type == "window"
      assert node.id == "main"
    end

    test "includes non-nil props" do
      node =
        Window.new("main", title: "App", size: {800, 600}, resizable: false) |> Window.build()

      assert node.props["title"] == "App"
      assert node.props["resizable"] == false
      # size is encoded via Toddy.Encode -- tuples become lists on the wire
      assert node.props["size"] == [800, 600]
    end

    test "omits nil props" do
      node = Window.new("main") |> Window.build()
      refute Map.has_key?(node.props, "title")
      refute Map.has_key?(node.props, "size")
      refute Map.has_key?(node.props, "resizable")
    end

    test "converts children to node maps" do
      child = %{id: "c", type: "text", props: %{}, children: []}
      node = Window.new("main") |> Window.push(child) |> Window.build()
      assert [%{id: "c", type: "text"}] = node.children
    end
  end

  describe "with_options/2" do
    test "routes all options correctly" do
      w =
        Window.new("w")
        |> Window.with_options(
          title: "Test",
          size: {800, 600},
          width: 800,
          height: 600,
          position: {50, 50},
          min_size: {320, 240},
          max_size: {1920, 1080},
          maximized: false,
          fullscreen: false,
          visible: true,
          resizable: true,
          closeable: true,
          minimizable: true,
          decorations: true,
          transparent: false,
          blur: false,
          level: :normal,
          exit_on_close_request: true
        )

      assert w.title == "Test"
      assert w.size == {800, 600}
      assert w.width == 800
      assert w.height == 600
      assert w.position == {50, 50}
      assert w.min_size == {320, 240}
      assert w.max_size == {1920, 1080}
      assert w.maximized == false
      assert w.fullscreen == false
      assert w.visible == true
      assert w.resizable == true
      assert w.closeable == true
      assert w.minimizable == true
      assert w.decorations == true
      assert w.transparent == false
      assert w.blur == false
      assert w.level == :normal
      assert w.exit_on_close_request == true
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Window.new("w", bogus: 42)
      end
    end
  end
end
