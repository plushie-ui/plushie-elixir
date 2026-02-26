defmodule Julep.Data do
  @moduledoc """
  Query pipeline for in-memory record collections. Pure functions
  supporting filter, search, sort, group, and pagination.

  All operations are applied in order: filter, search, sort, then paginate.
  Grouping is applied to the paginated results.

  ## Example

      records = [
        %{name: "Alice", age: 30},
        %{name: "Bob", age: 25},
        %{name: "Carol", age: 35}
      ]

      result = Julep.Data.query(records,
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
  Query result map with keys `:entries`, `:total`, `:page`, `:page_size`,
  and optionally `:groups`.
  """
  @type result :: map()

  @doc """
  Queries a list of records with optional filtering, searching, sorting,
  grouping, and pagination.

  ## Options

  - `:filter` -- a function `(record -> boolean)` to filter records.
  - `:search` -- a `{fields, query_string}` tuple. `fields` is a list of
    map keys to search; `query_string` is case-insensitive substring-matched.
  - `:sort` -- a `{direction, field}` tuple or list of tuples.
    Direction is `:asc` or `:desc`. Field is a map key.
  - `:group` -- a map key to group paginated results by.
  - `:page` -- page number (1-based). Default: 1.
  - `:page_size` -- records per page. Default: 25.

  Returns a result map with `:entries`, `:total`, `:page`, and `:page_size`.
  If `:group` is specified, `:groups` is also included.
  """
  @spec query([map()], keyword()) :: result()
  def query(records, opts \\ []) when is_list(records) do
    filter_fn = Keyword.get(opts, :filter)
    sort_spec = Keyword.get(opts, :sort)
    group_field = Keyword.get(opts, :group)
    search_opts = Keyword.get(opts, :search)
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    result =
      records
      |> maybe_filter(filter_fn)
      |> maybe_search(search_opts)
      |> maybe_sort(sort_spec)

    total = length(result)

    entries =
      result
      |> Enum.drop((page - 1) * page_size)
      |> Enum.take(page_size)

    base = %{entries: entries, total: total, page: page, page_size: page_size}

    if group_field do
      Map.put(base, :groups, Enum.group_by(entries, &Map.get(&1, group_field)))
    else
      base
    end
  end

  defp maybe_filter(records, nil), do: records
  defp maybe_filter(records, fun), do: Enum.filter(records, fun)

  defp maybe_search(records, nil), do: records

  defp maybe_search(records, {fields, query_string}) do
    q = String.downcase(query_string)

    Enum.filter(records, fn record ->
      Enum.any?(fields, fn field ->
        record
        |> Map.get(field, "")
        |> to_string()
        |> String.downcase()
        |> String.contains?(q)
      end)
    end)
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
