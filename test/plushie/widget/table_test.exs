defmodule Plushie.Widget.TableTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Table

  @columns [%{key: "name", label: "Name"}, %{key: "age", label: "Age"}]
  @rows [%{"name" => "Alice", "age" => 30}, %{"name" => "Bob", "age" => 25}]

  describe "new/2" do
    test "creates a struct with the given id" do
      tbl = Table.new("tbl1")
      assert %Table{id: "tbl1"} = tbl
    end

    test "defaults all optional fields to nil" do
      tbl = Table.new("tbl1")
      assert tbl.columns == nil
      assert tbl.rows == nil
      assert tbl.header == nil
      assert tbl.separator == nil
      assert tbl.width == nil
      assert tbl.padding == nil
      assert tbl.sort_by == nil
      assert tbl.sort_order == nil
    end

    test "accepts keyword options" do
      tbl = Table.new("tbl1", columns: @columns, rows: @rows)
      assert tbl.columns == @columns
      assert tbl.rows == @rows
    end
  end

  describe "columns/2" do
    test "sets the columns field" do
      tbl = Table.new("tbl1") |> Table.columns(@columns)
      assert tbl.columns == @columns
    end
  end

  describe "rows/2" do
    test "sets the rows field" do
      tbl = Table.new("tbl1") |> Table.rows(@rows)
      assert tbl.rows == @rows
    end
  end

  describe "header/2" do
    test "sets the header field" do
      tbl = Table.new("tbl1") |> Table.header(false)
      assert tbl.header == false
    end
  end

  describe "separator/2" do
    test "sets the separator field" do
      tbl = Table.new("tbl1") |> Table.separator(false)
      assert tbl.separator == false
    end
  end

  describe "sort_by/2" do
    test "sets the sort_by field" do
      tbl = Table.new("tbl1") |> Table.sort_by("name")
      assert tbl.sort_by == "name"
    end
  end

  describe "sort_order/2" do
    test "sets the sort_order to :asc" do
      tbl = Table.new("tbl1") |> Table.sort_order(:asc)
      assert tbl.sort_order == :asc
    end

    test "sets the sort_order to :desc" do
      tbl = Table.new("tbl1") |> Table.sort_order(:desc)
      assert tbl.sort_order == :desc
    end
  end

  describe "width/2" do
    test "sets the width field" do
      tbl = Table.new("tbl1") |> Table.width(:fill)
      assert tbl.width == :fill
    end
  end

  describe "padding/2" do
    test "sets the padding field" do
      tbl = Table.new("tbl1") |> Table.padding(10)
      assert tbl.padding == 10
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Table.new("tbl1") |> Table.build()
      assert node.id == "tbl1"
      assert node.type == "table"
      assert node.children == []
    end

    test "includes non-nil props" do
      node =
        Table.new("tbl1")
        |> Table.columns(@columns)
        |> Table.rows(@rows)
        |> Table.header(true)
        |> Table.sort_by("age")
        |> Table.sort_order(:desc)
        |> Table.build()

      assert node.props[:columns] == @columns
      assert node.props[:rows] == @rows
      assert node.props[:header] == true
      assert node.props[:sort_by] == "age"
      assert node.props[:sort_order] == :desc
    end

    test "omits nil props" do
      node = Table.new("tbl1") |> Table.build()
      refute Map.has_key?(node.props, :columns)
      refute Map.has_key?(node.props, :rows)
      refute Map.has_key?(node.props, :header)
      refute Map.has_key?(node.props, :separator)
      refute Map.has_key?(node.props, :width)
      refute Map.has_key?(node.props, :padding)
      refute Map.has_key?(node.props, :sort_by)
      refute Map.has_key?(node.props, :sort_order)
    end

    test "includes false values in props (put_if skips nil not false)" do
      node =
        Table.new("tbl1")
        |> Table.header(false)
        |> Table.separator(false)
        |> Table.build()

      assert node.props[:header] == false
      assert node.props[:separator] == false
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      tbl =
        Table.new("tbl1",
          columns: @columns,
          rows: @rows,
          header: true,
          separator: false,
          width: :fill,
          padding: 8,
          sort_by: "name",
          sort_order: :asc
        )

      assert tbl.columns == @columns
      assert tbl.rows == @rows
      assert tbl.header == true
      assert tbl.separator == false
      assert tbl.width == :fill
      assert tbl.padding == 8
      assert tbl.sort_by == "name"
      assert tbl.sort_order == :asc
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:striped/, fn ->
        Table.new("tbl1", striped: true)
      end
    end
  end
end
