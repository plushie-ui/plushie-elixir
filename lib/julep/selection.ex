defmodule Julep.Selection do
  @moduledoc """
  Selection state for lists and tables. Pure data structure supporting
  single, multi, and range selection modes.
  """

  defstruct mode: :single, selected: MapSet.new(), anchor: nil, order: []

  def new(opts \\ []) do
    %__MODULE__{
      mode: Keyword.get(opts, :mode, :single),
      order: Keyword.get(opts, :order, []),
      selected: MapSet.new(),
      anchor: nil
    }
  end

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

  def deselect(%__MODULE__{} = sel, id) do
    %{sel | selected: MapSet.delete(sel.selected, id)}
  end

  def clear(%__MODULE__{} = sel) do
    %{sel | selected: MapSet.new(), anchor: nil}
  end

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

  def selected(%__MODULE__{selected: selected}), do: selected

  def selected?(%__MODULE__{selected: selected}, id) do
    MapSet.member?(selected, id)
  end
end
