defmodule Plushie.EncodeTest.BogusStruct do
  defstruct [:x]
end

defmodule Plushie.EncodeTest do
  use ExUnit.Case, async: true

  alias Plushie.Type
  alias Plushie.Type.Shadow

  describe "Atom" do
    test "true passes through" do
      assert Type.encode_value(true) == true
    end

    test "false passes through" do
      assert Type.encode_value(false) == false
    end

    test "nil passes through" do
      assert Type.encode_value(nil) == nil
    end

    test "named atoms become strings" do
      assert Type.encode_value(:primary) == "primary"
      assert Type.encode_value(:center) == "center"
    end
  end

  describe "BitString" do
    test "strings pass through" do
      assert Type.encode_value("hello") == "hello"
      assert Type.encode_value("#ff0000") == "#ff0000"
    end
  end

  describe "Integer" do
    test "integers pass through" do
      assert Type.encode_value(42) == 42
      assert Type.encode_value(0) == 0
      assert Type.encode_value(-1) == -1
    end
  end

  describe "Float" do
    test "floats pass through" do
      assert Type.encode_value(3.14) == 3.14
      assert Type.encode_value(0.0) == 0.0
    end
  end

  describe "Tuple" do
    test "converts to list" do
      assert Type.encode_value({1, 2}) == [1, 2]
      assert Type.encode_value({10, 20, 30}) == [10, 20, 30]
    end

    test "recursively encodes elements" do
      assert Type.encode_value({:left, :right}) == ["left", "right"]
      assert Type.encode_value({1, {2, 3}}) == [1, [2, 3]]
    end
  end

  describe "Map" do
    test "recursively encodes values" do
      assert Type.encode_value(%{"a" => :primary, "b" => 42}) == %{"a" => "primary", "b" => 42}
    end

    test "handles nested maps" do
      assert Type.encode_value(%{"outer" => %{"inner" => :value}}) ==
               %{"outer" => %{"inner" => "value"}}
    end
  end

  describe "List" do
    test "recursively encodes elements" do
      assert Type.encode_value([:a, :b, :c]) == ["a", "b", "c"]
      assert Type.encode_value([1, 2, 3]) == [1, 2, 3]
    end

    test "handles nested lists" do
      assert Type.encode_value([[1, 2], [3, 4]]) == [[1, 2], [3, 4]]
    end

    test "handles mixed types" do
      assert Type.encode_value([:primary, 42, "hello"]) == ["primary", 42, "hello"]
    end
  end

  describe "Any (fallback)" do
    test "unknown structs pass through" do
      bogus = struct(Plushie.EncodeTest.BogusStruct, x: 1)
      assert Type.encode_value(bogus) == bogus
    end
  end

  describe "Shadow" do
    test "encodes to wire format with atom keys" do
      shadow =
        Shadow.new()
        |> Shadow.color("#333333")
        |> Shadow.offset(4, 8)
        |> Shadow.blur_radius(6.0)

      assert Type.encode_value(shadow) == %{
               color: "#333333",
               offset: [4, 8],
               blur_radius: 6.0
             }
    end

    test "encodes default shadow" do
      assert Type.encode_value(Shadow.new()) == %{
               color: "#000000",
               offset: [0, 0],
               blur_radius: 0
             }
    end
  end
end
