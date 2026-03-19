defmodule Toddy.SelectionTest do
  use ExUnit.Case, async: true

  alias Toddy.Selection

  @order [:a, :b, :c, :d, :e]

  describe "new/1" do
    test "defaults to single mode with empty selection" do
      sel = Selection.new()

      assert sel.mode == :single
      assert sel.selected == MapSet.new()
      assert sel.anchor == nil
      assert sel.order == []
    end

    test "accepts mode and order options" do
      sel = Selection.new(mode: :multi, order: @order)

      assert sel.mode == :multi
      assert sel.order == @order
    end
  end

  describe "select/3 in :single mode" do
    test "replaces the current selection" do
      sel =
        Selection.new()
        |> Selection.select(:a)
        |> Selection.select(:b)

      assert Selection.selected(sel) == MapSet.new([:b])
    end

    test "ignores extend option" do
      sel =
        Selection.new()
        |> Selection.select(:a)
        |> Selection.select(:b, extend: true)

      assert Selection.selected(sel) == MapSet.new([:b])
    end
  end

  describe "select/3 in :multi mode" do
    test "replaces selection without extend" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.select(:b)

      assert Selection.selected(sel) == MapSet.new([:b])
    end

    test "adds to selection with extend: true" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.select(:b, extend: true)

      assert Selection.selected(sel) == MapSet.new([:a, :b])
    end

    test "sets anchor on select" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)

      assert sel.anchor == :a
    end
  end

  describe "select/3 in :range mode" do
    test "works like multi -- extend adds, no extend replaces" do
      sel =
        Selection.new(mode: :range, order: @order)
        |> Selection.select(:a)
        |> Selection.select(:c, extend: true)

      assert Selection.selected(sel) == MapSet.new([:a, :c])
      assert sel.anchor == :c
    end
  end

  describe "toggle/2" do
    test "selects unselected item in single mode" do
      sel =
        Selection.new()
        |> Selection.toggle(:a)

      assert Selection.selected?(sel, :a)
    end

    test "deselects selected item in single mode" do
      sel =
        Selection.new()
        |> Selection.select(:a)
        |> Selection.toggle(:a)

      refute Selection.selected?(sel, :a)
      assert sel.anchor == nil
    end

    test "adds unselected item in multi mode" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.toggle(:b)

      assert Selection.selected(sel) == MapSet.new([:a, :b])
    end

    test "removes selected item in multi mode" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.select(:b, extend: true)
        |> Selection.toggle(:a)

      assert Selection.selected(sel) == MapSet.new([:b])
    end
  end

  describe "deselect/2" do
    test "removes item from selection" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.select(:b, extend: true)
        |> Selection.deselect(:a)

      assert Selection.selected(sel) == MapSet.new([:b])
    end

    test "no-op when item not selected" do
      sel =
        Selection.new()
        |> Selection.deselect(:z)

      assert Selection.selected(sel) == MapSet.new()
    end
  end

  describe "clear/1" do
    test "empties selection and clears anchor" do
      sel =
        Selection.new(mode: :multi)
        |> Selection.select(:a)
        |> Selection.select(:b, extend: true)
        |> Selection.clear()

      assert Selection.selected(sel) == MapSet.new()
      assert sel.anchor == nil
    end
  end

  describe "range_select/2" do
    test "selects range from anchor to target based on order" do
      sel =
        Selection.new(mode: :range, order: @order)
        |> Selection.select(:b)
        |> Selection.range_select(:d)

      assert Selection.selected(sel) == MapSet.new([:b, :c, :d])
    end

    test "works in reverse direction" do
      sel =
        Selection.new(mode: :range, order: @order)
        |> Selection.select(:d)
        |> Selection.range_select(:b)

      assert Selection.selected(sel) == MapSet.new([:b, :c, :d])
    end

    test "with no anchor, selects just the target" do
      sel =
        Selection.new(mode: :range, order: @order)
        |> Selection.range_select(:c)

      assert Selection.selected(sel) == MapSet.new([:c])
      assert sel.anchor == :c
    end

    test "anchor not in order falls back to selecting target only" do
      sel = %Selection{mode: :range, order: @order, anchor: :z, selected: MapSet.new()}

      sel = Selection.range_select(sel, :c)

      assert Selection.selected(sel) == MapSet.new([:c])
    end

    test "target not in order falls back to selecting target only" do
      sel =
        Selection.new(mode: :range, order: @order)
        |> Selection.select(:b)
        |> Selection.range_select(:z)

      assert Selection.selected(sel) == MapSet.new([:z])
    end
  end

  describe "selected?/2" do
    test "returns true for selected items" do
      sel = Selection.new() |> Selection.select(:a)

      assert Selection.selected?(sel, :a)
      refute Selection.selected?(sel, :b)
    end
  end
end
