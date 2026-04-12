defmodule Plushie.Widget.TableTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Table

  @string_columns [%{key: "name", label: "Name"}, %{key: "age", label: "Age"}]
  @string_rows [%{"name" => "Alice", "age" => 30}, %{"name" => "Bob", "age" => 25}]

  @atom_columns [%{key: :name, label: "Name"}, %{key: :age, label: "Age"}]
  @atom_rows [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}]

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
      tbl = Table.new("tbl1", columns: @string_columns, rows: @string_rows)
      assert tbl.columns == @string_columns
      assert tbl.rows == @string_rows
    end
  end

  describe "columns/2" do
    test "sets string-keyed columns" do
      tbl = Table.new("tbl1") |> Table.columns(@string_columns)
      assert tbl.columns == @string_columns
    end

    test "sets atom-keyed columns" do
      tbl = Table.new("tbl1") |> Table.columns(@atom_columns)
      assert tbl.columns == @atom_columns
    end

    test "raises on mixed key types" do
      mixed = [%{key: :name, label: "Name"}, %{key: "age", label: "Age"}]

      assert_raise ArgumentError, ~r/all column :key values must be the same type/, fn ->
        Table.new("tbl1") |> Table.columns(mixed)
      end
    end

    test "raises when column is missing :key" do
      assert_raise ArgumentError, ~r/missing a :key field/, fn ->
        Table.new("tbl1") |> Table.columns([%{label: "Name"}])
      end
    end
  end

  describe "rows/2 with string keys" do
    test "sets string-keyed rows" do
      tbl = Table.new("tbl1") |> Table.rows(@string_rows)
      assert tbl.rows == @string_rows
    end

    test "accepts empty list" do
      tbl = Table.new("tbl1") |> Table.rows([])
      assert tbl.rows == []
    end

    test "validates all rows, not just the first" do
      rows = [%{"name" => "Alice"}, %{name: "Bob"}]

      assert_raise ArgumentError, ~r/row 1 uses atom keys/, fn ->
        Table.new("tbl1")
        |> Table.columns(@string_columns)
        |> Table.rows(rows)
      end
    end
  end

  describe "rows/2 with atom keys" do
    test "accepts atom-keyed rows when columns use atom keys" do
      tbl =
        Table.new("tbl1")
        |> Table.columns(@atom_columns)
        |> Table.rows(@atom_rows)

      assert tbl.rows == @atom_rows
    end

    test "rejects atom-keyed rows when columns use string keys" do
      assert_raise ArgumentError, ~r/columns use string keys, but row 0 uses atom keys/, fn ->
        Table.new("tbl1")
        |> Table.columns(@string_columns)
        |> Table.rows(@atom_rows)
      end
    end

    test "rejects string-keyed rows when columns use atom keys" do
      assert_raise ArgumentError, ~r/columns use atom keys, but row 0 uses string keys/, fn ->
        Table.new("tbl1")
        |> Table.columns(@atom_columns)
        |> Table.rows(@string_rows)
      end
    end

    test "rejects mixed keys within a single row" do
      mixed_row = [%{"name" => "Alice", age: 30}]

      assert_raise ArgumentError, ~r/row 0 has mixed atom and string keys/, fn ->
        Table.new("tbl1") |> Table.rows(mixed_row)
      end
    end
  end

  describe "rows/2 with structs" do
    defmodule User do
      defstruct [:name, :age, :email]
    end

    test "converts structs to maps" do
      users = [%User{name: "Alice", age: 30, email: "a@b.com"}]

      tbl =
        Table.new("tbl1")
        |> Table.columns(@atom_columns)
        |> Table.rows(users)

      # Struct is converted to a plain map (extra fields are fine)
      assert [%{name: "Alice", age: 30, email: "a@b.com"}] = tbl.rows
      refute Map.has_key?(hd(tbl.rows), :__struct__)
    end

    test "struct rows work with atom-keyed columns" do
      users = [
        %User{name: "Alice", age: 30, email: "a@b.com"},
        %User{name: "Bob", age: 25, email: "b@c.com"}
      ]

      tbl =
        Table.new("tbl1")
        |> Table.columns(@atom_columns)
        |> Table.rows(users)

      assert length(tbl.rows) == 2
    end

    test "struct rows rejected with string-keyed columns" do
      users = [%User{name: "Alice", age: 30, email: "a@b.com"}]

      assert_raise ArgumentError, ~r/columns use string keys, but row 0 uses atom keys/, fn ->
        Table.new("tbl1")
        |> Table.columns(@string_columns)
        |> Table.rows(users)
      end
    end
  end

  describe "rows/2 without columns set" do
    test "accepts atom-keyed rows when columns not yet set" do
      tbl = Table.new("tbl1") |> Table.rows(@atom_rows)
      assert tbl.rows == @atom_rows
    end

    test "accepts string-keyed rows when columns not yet set" do
      tbl = Table.new("tbl1") |> Table.rows(@string_rows)
      assert tbl.rows == @string_rows
    end
  end

  describe "cross-validation on set order" do
    test "columns set after mismatched rows raises" do
      assert_raise ArgumentError, ~r/columns use string keys, but row 0 uses atom keys/, fn ->
        Table.new("tbl1")
        |> Table.rows(@atom_rows)
        |> Table.columns(@string_columns)
      end
    end

    test "columns set after matching rows succeeds" do
      tbl =
        Table.new("tbl1")
        |> Table.rows(@atom_rows)
        |> Table.columns(@atom_columns)

      assert tbl.columns == @atom_columns
      assert tbl.rows == @atom_rows
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
      tbl = Table.new("tbl1") |> Table.separator(2.0)
      assert tbl.separator == 2.0
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
    end

    test "includes non-nil props" do
      node =
        Table.new("tbl1")
        |> Table.columns(@string_columns)
        |> Table.rows(@string_rows)
        |> Table.header(true)
        |> Table.sort_by("age")
        |> Table.sort_order(:desc)
        |> Table.build()

      assert node.props[:columns] == @string_columns
      assert node.props[:rows] == @string_rows
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
        |> Table.striped(false)
        |> Table.build()

      assert node.props[:header] == false
      assert node.props[:striped] == false
    end
  end

  describe "with_options/2" do
    test "routes all known options" do
      tbl =
        Table.new("tbl1",
          columns: @string_columns,
          rows: @string_rows,
          header: true,
          separator: 1.0,
          width: :fill,
          padding: 8,
          sort_by: "name",
          sort_order: :asc,
          striped: true,
          selected: ["u1"]
        )

      assert tbl.columns == @string_columns
      assert tbl.rows == @string_rows
      assert tbl.header == true
      assert tbl.separator == 1.0
      assert tbl.width == :fill
      assert tbl.padding == 8
      assert tbl.sort_by == "name"
      assert tbl.sort_order == :asc
      assert tbl.striped == true
      assert tbl.selected == ["u1"]
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Table.new("tbl1", bogus: true)
      end
    end
  end
end
