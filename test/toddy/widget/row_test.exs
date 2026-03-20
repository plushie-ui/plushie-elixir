defmodule Toddy.Widget.RowTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Row

  describe "max_width/2" do
    test "sets the max_width field" do
      row = Row.new("r1") |> Row.max_width(500)
      assert row.max_width == 500
    end

    test "defaults to nil" do
      row = Row.new("r1")
      assert row.max_width == nil
    end
  end

  describe "build/1 with max_width" do
    test "includes max_width in props when set" do
      node = Row.new("r1") |> Row.max_width(500) |> Row.build()
      assert node.props[:max_width] == 500
    end

    test "omits max_width from props when nil" do
      node = Row.new("r1") |> Row.build()
      refute Map.has_key?(node.props, "max_width")
    end
  end

  describe "with_options/2 max_width" do
    test "handles max_width option" do
      row = Row.new("r1", max_width: 800)
      assert row.max_width == 800
    end
  end
end
