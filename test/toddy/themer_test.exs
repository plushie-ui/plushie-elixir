defmodule Toddy.ThemerTest do
  use ExUnit.Case, async: true

  describe "Toddy.Iced.themer/3" do
    test "creates themer node with theme prop" do
      node = Toddy.Iced.themer("t1", %{theme: "CatppuccinMocha"})
      assert node.id == "t1"
      assert node.type == "themer"
      assert node.props["theme"] == "CatppuccinMocha"
      assert node.children == []
    end

    test "creates themer with children" do
      child = Toddy.Iced.text("txt", %{content: "hello"})
      node = Toddy.Iced.themer("t1", %{theme: "Light"}, [child])
      assert length(node.children) == 1
      assert hd(node.children).type == "text"
    end

    test "creates themer with custom palette" do
      palette = %{background: "#1e1e2e", text: "#cdd6f4", primary: "#89b4fa"}
      node = Toddy.Iced.themer("t1", %{theme: palette})
      assert is_map(node.props["theme"])
    end

    test "creates themer with no props" do
      node = Toddy.Iced.themer("t1")
      assert node.id == "t1"
      assert node.type == "themer"
      assert node.props == %{}
      assert node.children == []
    end

    test "creates themer with multiple children" do
      children = [
        Toddy.Iced.text("a", %{content: "first"}),
        Toddy.Iced.text("b", %{content: "second"}),
        Toddy.Iced.button("c", %{label: "click"})
      ]

      node = Toddy.Iced.themer("t1", %{theme: "Dark"}, children)
      assert length(node.children) == 3
      assert Enum.map(node.children, & &1.type) == ["text", "text", "button"]
    end

    test "custom palette preserves all keys" do
      palette = %{
        background: "#1e1e2e",
        text: "#cdd6f4",
        primary: "#89b4fa",
        success: "#a6e3a1",
        danger: "#f38ba8"
      }

      node = Toddy.Iced.themer("t1", %{theme: palette})
      theme = node.props["theme"]
      assert theme.background == "#1e1e2e"
      assert theme.text == "#cdd6f4"
      assert theme.primary == "#89b4fa"
      assert theme.success == "#a6e3a1"
      assert theme.danger == "#f38ba8"
    end
  end
end
