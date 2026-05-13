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

  describe "height/2" do
    test "sets the height field" do
      tbl = Table.new("tbl1") |> Table.height(400)
      assert tbl.height == 400
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
      # rows: prop is expanded to children, not kept as prop
      assert node.props[:rows] == nil
      assert length(node.children) == 2
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
        |> Table.build()

      assert node.props[:header] == false
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
          sort_order: :asc
        )

      assert tbl.columns == @string_columns
      assert tbl.rows == @string_rows
      assert tbl.header == true
      assert tbl.separator == 1.0
      assert tbl.width == :fill
      assert tbl.padding == 8
      assert tbl.sort_by == "name"
      assert tbl.sort_order == :asc
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Table.new("tbl1", bogus: true)
      end
    end
  end

  describe "rows/children mutual exclusivity" do
    test "raises when rows: and children are both set" do
      assert_raise ArgumentError, ~r/cannot combine.*rows:.*with.*do-block/, fn ->
        Table.new("tbl1", rows: @string_rows)
        |> Table.push(%{id: "r1", type: "table_row", props: %{}, children: []})
        |> Table.build()
      end
    end

    test "rows: without children expands to table_row children" do
      node =
        Table.new("tbl1",
          columns: @string_columns,
          rows: @string_rows
        )
        |> Table.build()

      # rows: prop is consumed (nil), expanded to children
      assert node.props[:rows] == nil
      assert length(node.children) == 2

      row = hd(node.children)
      assert row.type == "table_row"
    end

    test "rows: expansion preserves false cell values" do
      node =
        Table.new("tbl1",
          columns: [%{key: :active, label: "Active"}, %{key: :name, label: "Name"}],
          rows: [%{active: false, name: nil}]
        )
        |> Table.build()

      [active_cell, name_cell] = node.children |> hd() |> Map.fetch!(:children)
      [active_text] = active_cell.children
      [name_text] = name_cell.children

      assert active_text.props.content == "false"
      assert name_text.props.content == ""
    end

    test "children without rows: is allowed" do
      node =
        Table.new("tbl1")
        |> Table.push(%{id: "r1", type: "table_row", props: %{}, children: []})
        |> Table.build()

      assert length(node.children) == 1
      assert node.props[:rows] == nil
    end
  end

  describe "table_row and cell macro output" do
    import Plushie.UI

    test "table_row produces correct node structure" do
      node =
        table_row "u1" do
          cell("name", text("Alice"))
        end

      assert node.id == "u1"
      assert node.type == "table_row"
      assert length(node.children) == 1

      cell_node = hd(node.children)
      assert cell_node.type == "table_cell"
      assert cell_node.props[:column] == "name"
      assert length(cell_node.children) == 1
      assert hd(cell_node.children).type == "text"
    end

    test "cell with single child" do
      import Plushie.UI
      node = cell("email", text("alice@example.com"))
      assert node.type == "table_cell"
      assert node.props[:column] == "email"
      assert length(node.children) == 1
    end

    test "cell with do-block for multiple children" do
      import Plushie.UI

      node =
        cell "actions" do
          button("edit", "Edit")
          button("del", "Delete")
        end

      assert node.type == "table_cell"
      assert node.props[:column] == "actions"
      assert length(node.children) == 2
    end

    test "table with columns and table_row children" do
      import Plushie.UI

      node =
        table "users", columns: [%{key: "name", label: "Name"}] do
          table_row "u1" do
            cell("name", text("Alice"))
          end
        end

      assert node.type == "table"
      assert node.props[:columns] == [%{key: "name", label: "Name"}]
      assert length(node.children) == 1

      row = hd(node.children)
      assert row.type == "table_row"
      assert row.id =~ "u1"
    end
  end
end
