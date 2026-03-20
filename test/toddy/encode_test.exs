defmodule Toddy.EncodeTest.BogusStruct do
  defstruct [:x]
end

defmodule Toddy.EncodeTest do
  use ExUnit.Case, async: true

  alias Toddy.Encode
  alias Toddy.Type.Shadow

  describe "Atom" do
    test "true passes through" do
      assert Encode.encode(true) == true
    end

    test "false passes through" do
      assert Encode.encode(false) == false
    end

    test "nil passes through" do
      assert Encode.encode(nil) == nil
    end

    test "named atoms become strings" do
      assert Encode.encode(:primary) == "primary"
      assert Encode.encode(:center) == "center"
    end
  end

  describe "BitString" do
    test "strings pass through" do
      assert Encode.encode("hello") == "hello"
      assert Encode.encode("#ff0000") == "#ff0000"
    end
  end

  describe "Integer" do
    test "integers pass through" do
      assert Encode.encode(42) == 42
      assert Encode.encode(0) == 0
      assert Encode.encode(-1) == -1
    end
  end

  describe "Float" do
    test "floats pass through" do
      assert Encode.encode(3.14) == 3.14
      assert Encode.encode(0.0) == 0.0
    end
  end

  describe "Tuple" do
    test "converts to list" do
      assert Encode.encode({1, 2}) == [1, 2]
      assert Encode.encode({10, 20, 30}) == [10, 20, 30]
    end

    test "recursively encodes elements" do
      assert Encode.encode({:left, :right}) == ["left", "right"]
      assert Encode.encode({1, {2, 3}}) == [1, [2, 3]]
    end
  end

  describe "Map" do
    test "recursively encodes values" do
      assert Encode.encode(%{"a" => :primary, "b" => 42}) == %{"a" => "primary", "b" => 42}
    end

    test "handles nested maps" do
      assert Encode.encode(%{"outer" => %{"inner" => :value}}) ==
               %{"outer" => %{"inner" => "value"}}
    end
  end

  describe "List" do
    test "recursively encodes elements" do
      assert Encode.encode([:a, :b, :c]) == ["a", "b", "c"]
      assert Encode.encode([1, 2, 3]) == [1, 2, 3]
    end

    test "handles nested lists" do
      assert Encode.encode([[1, 2], [3, 4]]) == [[1, 2], [3, 4]]
    end

    test "handles mixed types" do
      assert Encode.encode([:primary, 42, "hello"]) == ["primary", 42, "hello"]
    end
  end

  describe "Any (fallback)" do
    test "unknown values raise Protocol.UndefinedError" do
      ref = make_ref()

      assert_raise Protocol.UndefinedError, fn ->
        Encode.encode(ref)
      end
    end

    test "unknown structs raise with module name in message" do
      bogus = struct(Toddy.EncodeTest.BogusStruct, x: 1)

      assert_raise Protocol.UndefinedError, ~r/BogusStruct/, fn ->
        Encode.encode(bogus)
      end
    end
  end

  describe "Shadow" do
    test "encodes to wire format with string keys" do
      shadow =
        Shadow.new()
        |> Shadow.color("#333333")
        |> Shadow.offset(4, 8)
        |> Shadow.blur_radius(6.0)

      assert Encode.encode(shadow) == %{
               "color" => "#333333",
               "offset" => [4, 8],
               "blur_radius" => 6.0
             }
    end

    test "encodes default shadow" do
      assert Encode.encode(Shadow.new()) == %{
               "color" => "#000000",
               "offset" => [0, 0],
               "blur_radius" => 0
             }
    end
  end
end
