defmodule Plushie.Type.PaddingTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Padding

  doctest Plushie.Type.Padding

  describe "cast/1" do
    test "uniform number validates and returns as-is" do
      assert Padding.cast(8) == {:ok, 8}
    end

    test "zero padding" do
      assert Padding.cast(0) == {:ok, 0}
    end

    test "float padding" do
      assert Padding.cast(4.5) == {:ok, 4.5}
    end

    test "{vertical, horizontal} tuple validates and returns as-is" do
      assert Padding.cast({4, 12}) == {:ok, {4, 12}}
    end

    test "per-side map passes through" do
      input = %{top: 1, right: 2, bottom: 3, left: 4}
      assert Padding.cast(input) == {:ok, %{top: 1, right: 2, bottom: 3, left: 4}}
    end
  end

  describe "encode/1" do
    test "uniform number encodes as-is" do
      assert Padding.encode(8) == 8
    end

    test "tuple encodes to four-side map" do
      assert Padding.encode({4, 12}) == %{top: 4, right: 12, bottom: 4, left: 12}
    end

    test "struct encodes to four-side map" do
      padding = %Padding{top: 1, right: 2, bottom: 3, left: 4}
      assert Padding.encode(padding) == %{top: 1, right: 2, bottom: 3, left: 4}
    end
  end
end
