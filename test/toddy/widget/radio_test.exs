defmodule Toddy.Widget.RadioTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Radio

  describe "new/4" do
    test "creates struct with id, value, and selected" do
      r = Radio.new("r1", "option_a", "option_a")
      assert %Radio{} = r
      assert r.id == "r1"
      assert r.value == "option_a"
      assert r.selected == "option_a"
    end

    test "optional fields default to nil" do
      r = Radio.new("r1", "a", "b")
      assert r.label == nil
      assert r.group == nil
      assert r.spacing == nil
      assert r.width == nil
      assert r.size == nil
      assert r.text_size == nil
      assert r.font == nil
      assert r.line_height == nil
      assert r.text_shaping == nil
      assert r.wrapping == nil
      assert r.style == nil
    end

    test "accepts keyword options" do
      r = Radio.new("r1", "a", "a", label: "Option A", group: "grp1")
      assert r.label == "Option A"
      assert r.group == "grp1"
    end
  end

  describe "builders" do
    test "label/2 sets label" do
      r = Radio.new("id", "a", "b") |> Radio.label("My Label")
      assert r.label == "My Label"
    end

    test "group/2 sets group" do
      r = Radio.new("id", "a", "b") |> Radio.group("colors")
      assert r.group == "colors"
    end

    test "spacing/2 sets spacing" do
      r = Radio.new("id", "a", "b") |> Radio.spacing(10)
      assert r.spacing == 10
    end

    test "width/2 sets width" do
      r = Radio.new("id", "a", "b") |> Radio.width(:fill)
      assert r.width == :fill
    end

    test "size/2 sets radio button size" do
      r = Radio.new("id", "a", "b") |> Radio.size(24)
      assert r.size == 24
    end

    test "text_size/2 sets text_size" do
      r = Radio.new("id", "a", "b") |> Radio.text_size(14)
      assert r.text_size == 14
    end

    test "text_shaping/2 sets text_shaping" do
      r = Radio.new("id", "a", "b") |> Radio.text_shaping(:advanced)
      assert r.text_shaping == :advanced
    end

    test "wrapping/2 sets wrapping" do
      r = Radio.new("id", "a", "b") |> Radio.wrapping(:word)
      assert r.wrapping == :word
    end

    test "style/2 sets style" do
      r = Radio.new("id", "a", "b") |> Radio.style(:default)
      assert r.style == :default
    end
  end

  describe "build/1" do
    test "returns correct type and id" do
      node = Radio.new("r1", "opt_a", "opt_a") |> Radio.build()
      assert node.type == "radio"
      assert node.id == "r1"
      assert node.children == []
    end

    test "includes value and selected in props" do
      node = Radio.new("r1", "a", "b") |> Radio.build()
      assert node.props["value"] == "a"
      assert node.props["selected"] == "b"
    end

    test "includes group in props when set" do
      node = Radio.new("r1", "a", "b") |> Radio.group("grp") |> Radio.build()
      assert node.props["group"] == "grp"
    end

    test "omits nil props" do
      node = Radio.new("r1", "a", "b") |> Radio.build()
      refute Map.has_key?(node.props, "label")
      refute Map.has_key?(node.props, "group")
      refute Map.has_key?(node.props, "spacing")
      refute Map.has_key?(node.props, "style")
    end
  end

  describe "with_options/2" do
    test "routes multiple options" do
      r =
        Radio.new("id", "a", "b")
        |> Radio.with_options(label: "A", group: "g", spacing: 8, size: 20)

      assert r.label == "A"
      assert r.group == "g"
      assert r.spacing == 8
      assert r.size == 20
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:checked/, fn ->
        Radio.new("id", "a", "b", checked: true)
      end
    end
  end
end
