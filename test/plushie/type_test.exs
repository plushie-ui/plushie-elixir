defmodule Plushie.TypeTest do
  use ExUnit.Case, async: true

  alias Plushie.Type

  # -- resolve/1 ---------------------------------------------------------------

  describe "resolve/1" do
    test "maps primitive shortcuts to modules" do
      assert Type.resolve(:integer) == Plushie.Type.Integer
      assert Type.resolve(:float) == Plushie.Type.Float
      assert Type.resolve(:string) == Plushie.Type.String
      assert Type.resolve(:boolean) == Plushie.Type.Boolean
      assert Type.resolve(:atom) == Plushie.Type.Atom
      assert Type.resolve(:any) == Plushie.Type.Any
      assert Type.resolve(:map) == Plushie.Type.Map
    end

    test "passes through arbitrary modules" do
      assert Type.resolve(Plushie.Type.Color) == Plushie.Type.Color
      assert Type.resolve(SomeApp.CustomType) == SomeApp.CustomType
    end

    test "wraps composite tuples" do
      assert Type.resolve({:enum, [:a, :b]}) == {:composite, {:enum, [:a, :b]}}
      assert Type.resolve({:list, :string}) == {:composite, {:list, :string}}
      assert Type.resolve({:tuple, [:float, :float]}) == {:composite, {:tuple, [:float, :float]}}

      assert Type.resolve({:union, [:integer, :string]}) ==
               {:composite, {:union, [:integer, :string]}}
    end
  end

  # -- Plushie.Type.Integer ----------------------------------------------------

  describe "Plushie.Type.Integer" do
    test "cast accepts integers" do
      assert {:ok, 42} = Plushie.Type.Integer.cast(42)
      assert {:ok, -1} = Plushie.Type.Integer.cast(-1)
      assert {:ok, 0} = Plushie.Type.Integer.cast(0)
    end

    test "cast rejects non-integers" do
      assert :error = Plushie.Type.Integer.cast(3.14)
      assert :error = Plushie.Type.Integer.cast("42")
      assert :error = Plushie.Type.Integer.cast(nil)
    end

    test "guard produces is_integer check" do
      ast = Plushie.Type.Integer.guard(quote(do: x))
      assert {:is_integer, _, [{:x, _, _}]} = ast
    end

    test "typespec returns integer()" do
      assert {:integer, _, _} = Plushie.Type.Integer.typespec()
    end

    test "field_options includes min and max" do
      assert :min in Plushie.Type.Integer.field_options()
      assert :max in Plushie.Type.Integer.field_options()
    end

    test "constrain_guard generates boundary checks" do
      var = quote(do: x)
      guards = Plushie.Type.Integer.constrain_guard(var, min: 0, max: 100)
      assert length(guards) == 2
    end

    test "constrain_guard with no options returns empty list" do
      assert [] = Plushie.Type.Integer.constrain_guard(quote(do: x), [])
    end
  end

  # -- Plushie.Type.Float ------------------------------------------------------

  describe "Plushie.Type.Float" do
    test "cast accepts integers and floats" do
      assert {:ok, 3.14} = Plushie.Type.Float.cast(3.14)
      assert {:ok, 42} = Plushie.Type.Float.cast(42)
    end

    test "cast rejects non-numbers" do
      assert :error = Plushie.Type.Float.cast("3.14")
      assert :error = Plushie.Type.Float.cast(nil)
    end

    test "guard produces is_number check" do
      ast = Plushie.Type.Float.guard(quote(do: x))
      assert {:is_number, _, [{:x, _, _}]} = ast
    end
  end

  # -- Plushie.Type.String -----------------------------------------------------

  describe "Plushie.Type.String" do
    test "cast accepts binaries" do
      assert {:ok, "hello"} = Plushie.Type.String.cast("hello")
      assert {:ok, ""} = Plushie.Type.String.cast("")
    end

    test "cast coerces atoms to strings" do
      assert {:ok, "hello"} = Plushie.Type.String.cast(:hello)
      assert {:ok, "ok"} = Plushie.Type.String.cast(:ok)
    end

    test "cast rejects non-binaries and non-atoms" do
      assert :error = Plushie.Type.String.cast(42)
      assert :error = Plushie.Type.String.cast(nil)
    end

    test "guard accepts binaries and non-nil atoms" do
      ast = Plushie.Type.String.guard(quote(do: x))
      assert {:or, _, _} = ast
    end

    test "field_options includes string constraints" do
      opts = Plushie.Type.String.field_options()
      assert :min_length in opts
      assert :max_length in opts
      assert :pattern in opts
    end

    test "constrain_guard generates byte_size checks" do
      var = quote(do: x)
      guards = Plushie.Type.String.constrain_guard(var, min_length: 1, max_length: 255)
      assert length(guards) == 2
    end
  end

  # -- Plushie.Type.Boolean ----------------------------------------------------

  describe "Plushie.Type.Boolean" do
    test "cast accepts booleans" do
      assert {:ok, true} = Plushie.Type.Boolean.cast(true)
      assert {:ok, false} = Plushie.Type.Boolean.cast(false)
    end

    test "cast rejects non-booleans" do
      assert :error = Plushie.Type.Boolean.cast(1)
      assert :error = Plushie.Type.Boolean.cast("true")
      assert :error = Plushie.Type.Boolean.cast(nil)
    end

    test "guard produces is_boolean check" do
      ast = Plushie.Type.Boolean.guard(quote(do: x))
      assert {:is_boolean, _, [{:x, _, _}]} = ast
    end
  end

  # -- Plushie.Type.Atom -------------------------------------------------------

  describe "Plushie.Type.Atom" do
    test "cast accepts atoms" do
      assert {:ok, :hello} = Plushie.Type.Atom.cast(:hello)
      assert {:ok, nil} = Plushie.Type.Atom.cast(nil)
      assert {:ok, true} = Plushie.Type.Atom.cast(true)
    end

    test "cast rejects non-atoms" do
      assert :error = Plushie.Type.Atom.cast("hello")
      assert :error = Plushie.Type.Atom.cast(42)
    end

    test "guard produces is_atom check" do
      ast = Plushie.Type.Atom.guard(quote(do: x))
      assert {:is_atom, _, [{:x, _, _}]} = ast
    end
  end

  # -- Plushie.Type.Any --------------------------------------------------------

  describe "Plushie.Type.Any" do
    test "cast accepts anything" do
      assert {:ok, 42} = Plushie.Type.Any.cast(42)
      assert {:ok, "hello"} = Plushie.Type.Any.cast("hello")
      assert {:ok, nil} = Plushie.Type.Any.cast(nil)
      assert {:ok, %{a: 1}} = Plushie.Type.Any.cast(%{a: 1})
    end

    test "typespec returns term()" do
      assert {:term, _, _} = Plushie.Type.Any.typespec()
    end
  end

  # -- Plushie.Type.Map --------------------------------------------------------

  describe "Plushie.Type.Map" do
    test "cast accepts maps" do
      assert {:ok, %{}} = Plushie.Type.Map.cast(%{})
      assert {:ok, %{a: 1}} = Plushie.Type.Map.cast(%{a: 1})
    end

    test "cast rejects non-maps" do
      assert :error = Plushie.Type.Map.cast([])
      assert :error = Plushie.Type.Map.cast("map")
      assert :error = Plushie.Type.Map.cast(nil)
    end

    test "guard produces is_map check" do
      ast = Plushie.Type.Map.guard(quote(do: x))
      assert {:is_map, _, [{:x, _, _}]} = ast
    end
  end
end

# -- Macro-generated enum type ------------------------------------------------

defmodule Plushie.TypeTest.EnumTypeViaUse do
  use Plushie.Type
  enum([:north, :south, :east, :west])
end

defmodule Plushie.TypeTest.EnumTest do
  use ExUnit.Case, async: true

  alias Plushie.TypeTest.EnumTypeViaUse

  describe "enum type via use Plushie.Type" do
    test "cast accepts declared atoms" do
      assert {:ok, :north} = EnumTypeViaUse.cast(:north)
      assert {:ok, :south} = EnumTypeViaUse.cast(:south)
      assert {:ok, :east} = EnumTypeViaUse.cast(:east)
      assert {:ok, :west} = EnumTypeViaUse.cast(:west)
    end

    test "cast rejects undeclared atoms" do
      assert :error = EnumTypeViaUse.cast(:up)
      assert :error = EnumTypeViaUse.cast(:down)
    end

    test "cast coerces strings to atoms" do
      assert {:ok, :north} = EnumTypeViaUse.cast("north")
      assert :error = EnumTypeViaUse.cast("nowhere")
    end

    test "cast rejects non-atom non-string values" do
      assert :error = EnumTypeViaUse.cast(42)
      assert :error = EnumTypeViaUse.cast(nil)
    end

    test "guard produces an in-check AST" do
      ast = EnumTypeViaUse.guard(quote(do: x))
      assert {:in, _, _} = ast
    end

    test "typespec produces a union of atoms" do
      spec = EnumTypeViaUse.typespec()
      # Should be a nested {:|, _, _} tree or a single atom for one-element enums
      assert spec != nil
    end

    test "encode converts atom to string" do
      assert "north" = EnumTypeViaUse.encode(:north)
      assert "west" = EnumTypeViaUse.encode(:west)
    end
  end
end

# -- Macro-generated struct type -----------------------------------------------

defmodule Plushie.TypeTest.PointType do
  use Plushie.Type

  struct do
    field(:x, :float)
    field(:y, :float)
  end
end

defmodule Plushie.TypeTest.StructTest do
  use ExUnit.Case, async: true

  alias Plushie.TypeTest.PointType

  describe "struct type via use Plushie.Type" do
    test "creates a struct" do
      point = %PointType{}
      assert point.x == nil
      assert point.y == nil
    end

    test "cast builds struct from atom-keyed map" do
      assert {:ok, %PointType{x: 1.0, y: 2.0}} = PointType.cast(%{x: 1.0, y: 2.0})
    end

    test "cast builds struct from string-keyed map" do
      assert {:ok, %PointType{x: 3, y: 4}} = PointType.cast(%{"x" => 3, "y" => 4})
    end

    test "cast rejects non-map" do
      assert :error = PointType.cast("not a map")
      assert :error = PointType.cast(42)
    end

    test "fields returns field type list" do
      assert [x: :float, y: :float] = PointType.fields()
    end

    test "cast builds struct from keyword list" do
      assert {:ok, %PointType{x: 5, y: 6}} = PointType.cast(x: 5, y: 6)
    end

    test "guard checks struct type" do
      ast = PointType.guard(quote(do: val))
      assert {:is_struct, _, _} = ast
    end

    test "encode strips __struct__ and nils" do
      encoded = PointType.encode(%PointType{x: 1.5, y: nil})
      assert encoded == %{x: 1.5}
      refute Map.has_key?(encoded, :__struct__)
    end
  end
end

# -- Macro-generated union type ------------------------------------------------

defmodule Plushie.TypeTest.DirectionOrInteger do
  use Plushie.Type

  union do
    enum([:north, :south, :east, :west])
    type(Plushie.Type.Integer)
  end
end

defmodule Plushie.TypeTest.UnionTest do
  use ExUnit.Case, async: true

  alias Plushie.TypeTest.DirectionOrInteger

  describe "union type via use Plushie.Type" do
    test "cast accepts enum members" do
      assert {:ok, :north} = DirectionOrInteger.cast(:north)
      assert {:ok, :west} = DirectionOrInteger.cast(:west)
    end

    test "cast accepts integer variant" do
      assert {:ok, 42} = DirectionOrInteger.cast(42)
      assert {:ok, -1} = DirectionOrInteger.cast(-1)
    end

    test "cast rejects values matching no variant" do
      assert :error = DirectionOrInteger.cast("hello")
      assert :error = DirectionOrInteger.cast(3.14)
      assert :error = DirectionOrInteger.cast([])
    end

    test "typespec returns union of variants" do
      spec = DirectionOrInteger.typespec()
      spec_string = Macro.to_string(spec)
      assert spec_string =~ "north"
      assert spec_string =~ "integer()"
    end
  end
end

# -- Map composite types ------------------------------------------------------

defmodule Plushie.TypeTest.MapCompositeTest do
  use ExUnit.Case, async: true

  describe "map dictionary form {:map, {key_type, val_type}}" do
    test "casts all keys and values" do
      assert {:ok, %{"a" => 1, "b" => 2}} =
               Plushie.Type.cast_composite({:map, {:string, :integer}}, %{"a" => 1, "b" => 2})
    end

    test "casts keys through the key type" do
      assert {:ok, %{"hello" => 1}} =
               Plushie.Type.cast_composite({:map, {:string, :integer}}, %{hello: 1})
    end

    test "rejects invalid values" do
      assert :error =
               Plushie.Type.cast_composite({:map, {:string, :integer}}, %{"a" => "not_int"})
    end

    test "rejects non-map input" do
      assert :error = Plushie.Type.cast_composite({:map, {:string, :integer}}, "nope")
    end

    test "accepts empty map" do
      assert {:ok, %{}} = Plushie.Type.cast_composite({:map, {:string, :integer}}, %{})
    end
  end

  describe "map record form {:map, [name: type]}" do
    test "casts named fields from atom-keyed map" do
      assert {:ok, %{name: "alice", age: 30}} =
               Plushie.Type.cast_composite(
                 {:map, [name: :string, age: :integer]},
                 %{name: "alice", age: 30}
               )
    end

    test "casts named fields from string-keyed map" do
      assert {:ok, %{name: "bob", age: 25}} =
               Plushie.Type.cast_composite(
                 {:map, [name: :string, age: :integer]},
                 %{"name" => "bob", "age" => 25}
               )
    end

    test "casts named fields from keyword list" do
      assert {:ok, %{name: "carol", age: 40}} =
               Plushie.Type.cast_composite(
                 {:map, [name: :string, age: :integer]},
                 name: "carol",
                 age: 40
               )
    end

    test "missing fields become nil" do
      assert {:ok, %{name: "dan", age: nil}} =
               Plushie.Type.cast_composite(
                 {:map, [name: :string, age: :integer]},
                 %{name: "dan"}
               )
    end

    test "rejects invalid field values" do
      assert :error =
               Plushie.Type.cast_composite(
                 {:map, [name: :string, age: :integer]},
                 %{name: "eve", age: "not_int"}
               )
    end

    test "preserves false and nil field values" do
      assert {:ok, %{enabled: false, label: nil}} =
               Plushie.Type.cast_composite(
                 {:map, [enabled: :boolean, label: :string]},
                 %{enabled: false}
               )
    end

    test "rejects non-keyword list input" do
      assert :error = Plushie.Type.cast_composite({:map, [name: :string]}, [1, 2, 3])
    end

    test "rejects non-map non-list input" do
      assert :error = Plushie.Type.cast_composite({:map, [name: :string]}, 42)
    end
  end
end
