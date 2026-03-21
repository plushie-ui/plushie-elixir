defmodule Plushie.Widget.ThemerTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Themer

  describe "new/2" do
    test "creates a struct with the given id and theme" do
      t = Themer.new("th1", "Dark")
      assert %Themer{id: "th1", theme: "Dark"} = t
    end

    test "children default to empty list" do
      t = Themer.new("th1", "Nord")
      assert t.children == []
    end

    test "accepts a custom palette map as theme" do
      palette = %{"background" => "#1a1a2e", "text" => "#eaeaea"}
      t = Themer.new("th1", palette)
      assert t.theme == palette
    end
  end

  describe "push/2" do
    test "appends a child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      t = Themer.new("th1", "Dark") |> Themer.push(child)
      assert t.children == [child]
    end

    test "preserves order across multiple pushes" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      t = Themer.new("th1", "Dark") |> Themer.push(c1) |> Themer.push(c2)
      assert t.children == [c2, c1]
      node = Themer.build(t)
      assert node.children == [c1, c2]
    end
  end

  describe "extend/2" do
    test "appends multiple children at once" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      t = Themer.new("th1", "Dark") |> Themer.extend([c1, c2])
      assert t.children == [c2, c1]
      node = Themer.build(t)
      assert node.children == [c1, c2]
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Themer.new("th1", "Dark") |> Themer.build()
      assert node.id == "th1"
      assert node.type == "themer"
    end

    test "always includes theme in props" do
      node = Themer.new("th1", "Nord") |> Themer.build()
      assert node.props[:theme] == "Nord"
    end

    test "includes custom palette map in props" do
      palette = %{"background" => "#000", "text" => "#fff"}
      node = Themer.new("th1", palette) |> Themer.build()
      assert node.props[:theme] == palette
    end

    test "converts children to nodes" do
      child = %{id: "c1", type: "text", props: %{content: "hi"}, children: []}
      node = Themer.new("th1", "Dark") |> Themer.push(child) |> Themer.build()
      assert length(node.children) == 1
      assert hd(node.children).id == "c1"
    end

    test "empty children produces empty list" do
      node = Themer.new("th1", "Dark") |> Themer.build()
      assert node.children == []
    end
  end
end
