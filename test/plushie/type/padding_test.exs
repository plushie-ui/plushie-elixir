defmodule Plushie.Type.PaddingTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Padding

  doctest Plushie.Type.Padding

  describe "encode/1" do
    test "uniform number produces four equal sides" do
      assert Padding.encode(8) == %{top: 8, right: 8, bottom: 8, left: 8}
    end

    test "zero padding" do
      assert Padding.encode(0) == %{top: 0, right: 0, bottom: 0, left: 0}
    end

    test "float padding" do
      assert Padding.encode(4.5) == %{top: 4.5, right: 4.5, bottom: 4.5, left: 4.5}
    end

    test "{vertical, horizontal} tuple" do
      assert Padding.encode({4, 12}) == %{top: 4, right: 12, bottom: 4, left: 12}
    end

    test "per-side map passes through" do
      input = %{top: 1, right: 2, bottom: 3, left: 4}
      assert Padding.encode(input) == %{top: 1, right: 2, bottom: 3, left: 4}
    end
  end
end
