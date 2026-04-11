defmodule Plushie.Type.LineHeightTest do
  use ExUnit.Case, async: true

  doctest Plushie.Type.LineHeight

  alias Plushie.Type.LineHeight

  describe "cast/1" do
    test "accepts integer" do
      assert {:ok, 2} = LineHeight.cast(2)
    end

    test "accepts float" do
      assert {:ok, 1.5} = LineHeight.cast(1.5)
    end

    test "accepts relative map" do
      assert {:ok, %{relative: 1.2}} = LineHeight.cast(%{relative: 1.2})
    end

    test "accepts absolute map" do
      assert {:ok, %{absolute: 24}} = LineHeight.cast(%{absolute: 24})
    end

    test "rejects atoms" do
      assert :error = LineHeight.cast(:bogus)
    end

    test "rejects strings" do
      assert :error = LineHeight.cast("1.5")
    end

    test "rejects maps with non-numeric values" do
      assert :error = LineHeight.cast(%{relative: "big"})
      assert :error = LineHeight.cast(%{absolute: :nope})
    end

    test "rejects maps with unrecognized keys" do
      assert :error = LineHeight.cast(%{custom: 1.5})
    end
  end

  describe "encode/1" do
    test "numbers pass through" do
      assert 1.5 = LineHeight.encode(1.5)
      assert 2 = LineHeight.encode(2)
    end

    test "relative map passes through" do
      assert %{relative: 1.2} = LineHeight.encode(%{relative: 1.2})
    end

    test "absolute map passes through" do
      assert %{absolute: 20} = LineHeight.encode(%{absolute: 20})
    end
  end
end
