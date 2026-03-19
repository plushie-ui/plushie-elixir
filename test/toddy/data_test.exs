defmodule Toddy.DataTest do
  use ExUnit.Case, async: true

  alias Toddy.Data

  @records [
    %{id: 1, name: "Arthur", age: 30, dept: "research"},
    %{id: 2, name: "Ford", age: 25, dept: "field"},
    %{id: 3, name: "Trillian", age: 28, dept: "research"},
    %{id: 4, name: "Zaphod", age: 35, dept: "executive"},
    %{id: 5, name: "Marvin", age: 999, dept: "field"}
  ]

  describe "query/2 with no options" do
    test "returns all records paginated with defaults" do
      result = Data.query(@records)

      assert result.entries == @records
      assert result.total == 5
      assert result.page == 1
      assert result.page_size == 25
    end

    test "returns empty result for empty records" do
      result = Data.query([])

      assert result.entries == []
      assert result.total == 0
    end
  end

  describe "filter" do
    test "applies filter function" do
      result = Data.query(@records, filter: &(&1.age > 28))

      assert length(result.entries) == 3
      assert Enum.all?(result.entries, &(&1.age > 28))
    end

    test "filter that matches nothing returns empty" do
      result = Data.query(@records, filter: &(&1.age > 10_000))

      assert result.entries == []
      assert result.total == 0
    end
  end

  describe "sort" do
    test "ascending sort by field" do
      result = Data.query(@records, sort: {:asc, :name})
      names = Enum.map(result.entries, & &1.name)

      assert names == ["Arthur", "Ford", "Marvin", "Trillian", "Zaphod"]
    end

    test "descending sort by field" do
      result = Data.query(@records, sort: {:desc, :age})
      ages = Enum.map(result.entries, & &1.age)

      assert ages == [999, 35, 30, 28, 25]
    end

    test "multi-field sort" do
      records = [
        %{name: "B", age: 2},
        %{name: "A", age: 1},
        %{name: "A", age: 2},
        %{name: "B", age: 1}
      ]

      result = Data.query(records, sort: [{:asc, :name}, {:desc, :age}])
      entries = result.entries

      assert Enum.map(entries, &{&1.name, &1.age}) == [
               {"A", 2},
               {"A", 1},
               {"B", 2},
               {"B", 1}
             ]
    end
  end

  describe "search" do
    test "searches across specified fields" do
      result = Data.query(@records, search: {[:name], "art"})

      assert length(result.entries) == 1
      assert hd(result.entries).name == "Arthur"
    end

    test "case-insensitive search" do
      result = Data.query(@records, search: {[:name], "FORD"})

      assert length(result.entries) == 1
      assert hd(result.entries).name == "Ford"
    end

    test "search across multiple fields" do
      result = Data.query(@records, search: {[:name, :dept], "field"})

      assert length(result.entries) == 2
    end

    test "search with no matches" do
      result = Data.query(@records, search: {[:name], "slartibartfast"})

      assert result.entries == []
      assert result.total == 0
    end
  end

  describe "group" do
    test "groups entries by field" do
      result = Data.query(@records, group: :dept)

      assert Map.has_key?(result, :groups)
      assert length(result.groups["research"]) == 2
      assert length(result.groups["field"]) == 2
      assert length(result.groups["executive"]) == 1
    end

    test "groups is nil when group not specified" do
      result = Data.query(@records)

      assert result.groups == nil
    end
  end

  describe "pagination" do
    test "respects page_size" do
      result = Data.query(@records, page_size: 2)

      assert length(result.entries) == 2
      assert result.total == 5
      assert result.page == 1
    end

    test "returns correct page" do
      result = Data.query(@records, page_size: 2, page: 2)

      assert length(result.entries) == 2
      assert hd(result.entries).id == 3
    end

    test "last page may have fewer entries" do
      result = Data.query(@records, page_size: 2, page: 3)

      assert length(result.entries) == 1
      assert hd(result.entries).id == 5
    end

    test "page beyond total returns empty entries" do
      result = Data.query(@records, page_size: 2, page: 99)

      assert result.entries == []
      assert result.total == 5
    end
  end

  describe "combined operations" do
    test "filter + sort + pagination" do
      result =
        Data.query(@records,
          filter: &(&1.dept == "research" || &1.dept == "field"),
          sort: {:asc, :name},
          page_size: 2,
          page: 1
        )

      assert result.total == 4
      assert length(result.entries) == 2
      names = Enum.map(result.entries, & &1.name)
      assert names == ["Arthur", "Ford"]
    end

    test "search + sort + group" do
      result =
        Data.query(@records,
          search: {[:dept], "re"},
          sort: {:asc, :name},
          group: :dept
        )

      assert result.total == 2
      names = Enum.map(result.entries, & &1.name)
      assert names == ["Arthur", "Trillian"]
      assert Map.has_key?(result, :groups)
    end
  end
end
