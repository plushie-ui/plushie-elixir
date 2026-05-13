defmodule Plushie.Data do
  @moduledoc """
  Query pipeline for in-memory record collections. Pure functions
  supporting filter, search, sort, group, and pagination.

  All operations are applied in order: filter, search, sort, then paginate.
  Grouping is applied to the paginated results. Repeated `:filter` and
  repeated `:search` entries compose in keyword-list order as successive
  narrowing steps within their stage.

  Each pipeline step creates intermediate list copies. For small to moderate
  collections (up to a few thousand records) this is fine. For very large
  datasets, consider filtering or paginating at the data source (database
  query, API call) rather than loading everything into memory.

  ## Example

      records = [
        %{name: "Alice", age: 30},
        %{name: "Bob", age: 25},
        %{name: "Carol", age: 35}
      ]

      result = Plushie.Data.query(records,
        filter: &(&1.age > 24),
        sort: {:asc, :name},
        page: 1,
        page_size: 10
      )

      result.entries
      #=> [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}, %{name: "Carol", age: 35}]
      result.total
      #=> 3
  """

  @typedoc """
  Query result with paginated entries, total count, and optional grouping.
  """
  @type result :: %{
          entries: [map()],
          total: non_neg_integer(),
          page: pos_integer(),
          page_size: pos_integer(),
          groups: %{optional(term()) => [map()]} | nil
        }

  @doc """
  Queries a list of records with optional filtering, searching, sorting,
  grouping, and pagination.

  ## Options

  - `:filter` - a function `(record -> boolean)` to filter records. Repeated
    `:filter` entries are applied in keyword-list order.
  - `:search` - a `{fields, query_string}` tuple. `fields` is a list of
    map keys to search; `query_string` is case-insensitive substring-matched.
    Repeated `:search` entries are applied in keyword-list order.
  - `:sort` - a `{direction, field}` tuple or list of tuples.
    Direction is `:asc` or `:desc`. Field is a map key.
  - `:group` - a map key to group paginated results by.
  - `:page` - page number (1-based). Default: 1.
  - `:page_size` - records per page. Default: 25.

  Returns a result map with `:entries`, `:total`, `:page`, and `:page_size`.
  If `:group` is specified, `:groups` is also included.
  """
  @spec query(records :: [map()], opts :: keyword()) :: result()
  def query(records, opts \\ []) when is_list(records) do
    filter_fns = Keyword.get_values(opts, :filter)
    sort_spec = Keyword.get(opts, :sort)
    group_field = Keyword.get(opts, :group)
    search_opts = Keyword.get_values(opts, :search)
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    result =
      records
      |> apply_filters(filter_fns)
      |> apply_searches(search_opts)
      |> maybe_sort(sort_spec)

    offset = (page - 1) * page_size

    {entries, total} =
      result
      |> Enum.with_index()
      |> Enum.reduce({[], 0}, fn {item, idx}, {acc, count} ->
        acc = if idx >= offset and idx < offset + page_size, do: [item | acc], else: acc
        {acc, count + 1}
      end)

    entries = Enum.reverse(entries)

    groups =
      if group_field,
        do: Enum.group_by(entries, &Map.get(&1, group_field)),
        else: nil

    %{entries: entries, total: total, page: page, page_size: page_size, groups: groups}
  end

  defp apply_filters(records, filters) do
    Enum.reduce(filters, records, fn filter, acc -> maybe_filter(acc, filter) end)
  end

  defp maybe_filter(records, nil), do: records
  defp maybe_filter(records, fun), do: Enum.filter(records, fun)

  defp apply_searches(records, searches) do
    Enum.reduce(searches, records, fn search, acc -> maybe_search(acc, search) end)
  end

  defp maybe_search(records, nil), do: records

  defp maybe_search(records, {fields, query_string}) do
    q = String.downcase(query_string)

    Enum.filter(records, fn record ->
      Enum.any?(fields, fn field ->
        record
        |> search_field(field)
        |> to_string()
        |> String.downcase()
        |> String.contains?(q)
      end)
    end)
  end

  defp search_field(record, field) do
    case Map.get(record, field) do
      nil -> ""
      value -> value
    end
  end

  defp maybe_sort(records, nil), do: records
  defp maybe_sort(records, {dir, field}), do: maybe_sort(records, [{dir, field}])

  defp maybe_sort(records, specs) when is_list(specs) do
    Enum.sort(records, fn a, b ->
      compare_records(a, b, specs)
    end)
  end

  defp compare_records(_a, _b, []), do: true

  defp compare_records(a, b, [{dir, field} | rest]) do
    va = Map.get(a, field)
    vb = Map.get(b, field)

    cond do
      va == vb ->
        compare_records(a, b, rest)

      dir == :asc ->
        compare_values(va, vb)

      dir == :desc ->
        compare_values(vb, va)
    end
  end

  defp compare_values(a, b) when is_number(a) and is_number(b), do: a < b
  defp compare_values(a, b) when is_binary(a) and is_binary(b), do: a < b
  defp compare_values(a, b) when is_atom(a) and is_atom(b), do: a < b
  defp compare_values(a, b), do: to_string(a) < to_string(b)
end
