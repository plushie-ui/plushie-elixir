defmodule Plushie.Type.PointerTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Pointer

  describe "parse_pointer/1" do
    test "parses pointer type strings" do
      assert Pointer.parse_pointer("mouse") == {:ok, :mouse}
      assert Pointer.parse_pointer("touch") == {:ok, :touch}
      assert Pointer.parse_pointer("pen") == {:ok, :pen}
    end

    test "defaults missing pointer type to mouse" do
      assert Pointer.parse_pointer(nil) == {:ok, :mouse}
    end

    test "rejects unknown pointer types" do
      assert Pointer.parse_pointer("trackpad") == :error
      assert Pointer.parse_pointer(:mouse) == :error
    end
  end

  describe "parse_button/1" do
    test "parses button strings" do
      assert Pointer.parse_button("left") == {:ok, :left}
      assert Pointer.parse_button("right") == {:ok, :right}
      assert Pointer.parse_button("middle") == {:ok, :middle}
      assert Pointer.parse_button("back") == {:ok, :back}
      assert Pointer.parse_button("forward") == {:ok, :forward}
    end

    test "defaults missing buttons to left" do
      assert Pointer.parse_button(nil) == {:ok, :left}
    end

    test "rejects unknown buttons" do
      assert Pointer.parse_button("primary") == :error
      assert Pointer.parse_button(:left) == :error
    end
  end

  describe "cast/1" do
    test "casts through pointer parsing" do
      assert Pointer.cast("mouse") == {:ok, :mouse}
      assert Pointer.cast("bad") == :error
    end
  end
end
