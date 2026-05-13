defmodule Plushie.Type.RangeTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Range

  describe "cast/1" do
    test "accepts numeric min and max tuples" do
      assert Range.cast({0, 100}) == {:ok, {0, 100}}
      assert Range.cast({-1.5, 1.5}) == {:ok, {-1.5, 1.5}}
    end

    test "rejects non-range values" do
      assert Range.cast([0, 100]) == :error
      assert Range.cast({0, "100"}) == :error
      assert Range.cast({0, 50, 100}) == :error
    end
  end

  describe "guard/1" do
    test "checks only tuple arity" do
      guard = Range.guard(quote(do: value))

      assert Macro.to_string(guard) == "is_tuple(value) and tuple_size(value) == 2"
    end
  end
end
