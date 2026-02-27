defmodule Julep.Selection do
  @moduledoc """
  Selection state for lists and tables. Pure data structure supporting
  single, multi, and range selection modes.

  ## Modes

  - `:single` -- at most one item selected at a time.
  - `:multi` -- multiple items selectable; `extend: true` adds to the set.
  - `:range` -- like multi, but `range_select/2` selects a contiguous
    slice of the `order` list between the anchor and the target.

  ## Example

      sel = Julep.Selection.new(mode: :multi, order: ["a", "b", "c", "d"])
      sel = Julep.Selection.select(sel, "b")
      sel = Julep.Selection.select(sel, "d", extend: true)
      Julep.Selection.selected(sel)
      #=> MapSet.new(["b", "d"])
  """

  defstruct mode: :single, selected: MapSet.new(), anchor: nil, order: []

  @type t :: %__MODULE__{
          mode: :single | :multi | :range,
          selected: MapSet.t(),
          anchor: term() | nil,
          order: [term()]
        }

  @doc """
  Creates a new selection state.

  ## Options

  - `:mode` -- selection mode: `:single` (default), `:multi`, or `:range`.
  - `:order` -- ordered list of item IDs for range selection.
  """
  @spec new(opts :: keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      mode: Keyword.get(opts, :mode, :single),
      order: Keyword.get(opts, :order, []),
      selected: MapSet.new(),
      anchor: nil
    }
  end

  @doc """
  Selects `id`. In `:single` mode, replaces the selection. In `:multi`
  and `:range` modes, replaces unless `extend: true` is passed, in which
  case `id` is added to the existing selection.

  Sets the anchor to `id` for subsequent range selections.
  """
  @spec select(sel :: t(), id :: term(), opts :: keyword()) :: t()
  def select(sel, id, opts \\ [])

  def select(%__MODULE__{mode: :single} = sel, id, _opts) do
    %{sel | selected: MapSet.new([id]), anchor: id}
  end

  def select(%__MODULE__{mode: :multi} = sel, id, opts) do
    if Keyword.get(opts, :extend, false) do
      %{sel | selected: MapSet.put(sel.selected, id), anchor: id}
    else
      %{sel | selected: MapSet.new([id]), anchor: id}
    end
  end

  def select(%__MODULE__{mode: :range} = sel, id, opts) do
    if Keyword.get(opts, :extend, false) do
      %{sel | selected: MapSet.put(sel.selected, id), anchor: id}
    else
      %{sel | selected: MapSet.new([id]), anchor: id}
    end
  end

  @doc """
  Toggles `id` in the selection. If already selected, removes it;
  otherwise adds it. In `:single` mode, toggling a selected item
  clears the selection entirely.
  """
  @spec toggle(sel :: t(), id :: term()) :: t()
  def toggle(%__MODULE__{mode: :single} = sel, id) do
    if MapSet.member?(sel.selected, id) do
      %{sel | selected: MapSet.new(), anchor: nil}
    else
      %{sel | selected: MapSet.new([id]), anchor: id}
    end
  end

  def toggle(%__MODULE__{} = sel, id) do
    if MapSet.member?(sel.selected, id) do
      %{sel | selected: MapSet.delete(sel.selected, id)}
    else
      %{sel | selected: MapSet.put(sel.selected, id), anchor: id}
    end
  end

  @doc "Removes `id` from the selection."
  @spec deselect(sel :: t(), id :: term()) :: t()
  def deselect(%__MODULE__{} = sel, id) do
    %{sel | selected: MapSet.delete(sel.selected, id)}
  end

  @doc "Clears all selected items and resets the anchor."
  @spec clear(sel :: t()) :: t()
  def clear(%__MODULE__{} = sel) do
    %{sel | selected: MapSet.new(), anchor: nil}
  end

  @doc """
  Selects all items in `order` between the current anchor and `id`
  (inclusive). If there is no anchor, selects only `id`.

  Requires `order` to have been set at creation time via `new/1`.
  """
  @spec range_select(sel :: t(), id :: term()) :: t()
  def range_select(%__MODULE__{anchor: nil} = sel, id) do
    %{sel | selected: MapSet.new([id]), anchor: id}
  end

  def range_select(%__MODULE__{order: order, anchor: anchor} = sel, id) do
    anchor_idx = Enum.find_index(order, &(&1 == anchor))
    id_idx = Enum.find_index(order, &(&1 == id))

    case {anchor_idx, id_idx} do
      {nil, _} ->
        %{sel | selected: MapSet.new([id]), anchor: id}

      {_, nil} ->
        %{sel | selected: MapSet.new([id]), anchor: id}

      {a, b} ->
        {lo, hi} = if a <= b, do: {a, b}, else: {b, a}
        range_ids = Enum.slice(order, lo..hi)
        %{sel | selected: MapSet.new(range_ids)}
    end
  end

  @doc "Returns the `MapSet` of currently selected item IDs."
  @spec selected(sel :: t()) :: MapSet.t()
  def selected(%__MODULE__{selected: selected}), do: selected

  @doc "Returns `true` if `id` is currently selected."
  @spec selected?(sel :: t(), id :: term()) :: boolean()
  def selected?(%__MODULE__{selected: selected}, id) do
    MapSet.member?(selected, id)
  end
end
