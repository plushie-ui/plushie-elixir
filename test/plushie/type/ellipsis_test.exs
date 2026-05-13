defmodule Plushie.Type.EllipsisTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Ellipsis

  describe "cast/1" do
    test "accepts supported modes" do
      assert Ellipsis.cast(:none) == {:ok, :none}
      assert Ellipsis.cast(:start) == {:ok, :start}
      assert Ellipsis.cast(:middle) == {:ok, :middle}
      assert Ellipsis.cast(:end) == {:ok, :end}
    end

    test "rejects unknown modes" do
      assert Ellipsis.cast(:clip) == :error
    end
  end
end
