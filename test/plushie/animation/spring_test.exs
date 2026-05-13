defmodule Plushie.Animation.SpringTest do
  use ExUnit.Case, async: true

  alias Plushie.Animation.Spring

  describe "new/1" do
    test "creates spring with required fields" do
      s = Spring.new(to: 1.05)
      assert s.to == 1.05
      assert s.stiffness == 100
      assert s.damping == 10
      assert s.mass == 1.0
      assert s.velocity == 0.0
    end

    test "accepts custom parameters" do
      s = Spring.new(to: 1.05, stiffness: 200, damping: 20, mass: 2.0)
      assert s.stiffness == 200
      assert s.damping == 20
      assert s.mass == 2.0
    end

    test "accepts preset" do
      s = Spring.new(to: 1.05, preset: :bouncy)
      assert s.stiffness == 300
      assert s.damping == 10
    end

    test "preset values can be overridden" do
      s = Spring.new(to: 1.05, preset: :bouncy, damping: 15)
      assert s.stiffness == 300
      assert s.damping == 15
    end

    test "raises without to:" do
      assert_raise ArgumentError, ~r/requires to:/, fn ->
        Spring.new(stiffness: 200)
      end
    end

    test "raises with invalid preset" do
      assert_raise ArgumentError, ~r/unknown spring preset/, fn ->
        Spring.new(to: 1.0, preset: :nonexistent)
      end
    end

    test "raises with unknown option" do
      assert_raise ArgumentError, ~r/unknown spring option/, fn ->
        Spring.new(to: 1.0, bogus: true)
      end
    end

    test "accepts from and on_complete" do
      s = Spring.new(to: 1.0, from: 0.0, on_complete: :settled)
      assert s.from == 0.0
      assert s.on_complete == :settled
    end
  end

  describe "pipeline" do
    test "chain setters" do
      s =
        Spring.new(to: 1.0)
        |> Spring.stiffness(200)
        |> Spring.damping(20)
        |> Spring.mass(1.5)
        |> Spring.velocity(5.0)
        |> Spring.from(0.0)
        |> Spring.on_complete(:done)

      assert s.stiffness == 200
      assert s.damping == 20
      assert s.mass == 1.5
      assert s.velocity == 5.0
      assert s.from == 0.0
      assert s.on_complete == :done
    end
  end

  describe "presets/0" do
    test "returns all preset names" do
      presets = Spring.presets()
      assert Map.has_key?(presets, :gentle)
      assert Map.has_key?(presets, :bouncy)
      assert Map.has_key?(presets, :stiff)
      assert Map.has_key?(presets, :snappy)
      assert Map.has_key?(presets, :molasses)
    end
  end

  describe "encode" do
    test "minimal spring encodes type, to, stiffness, damping" do
      s = Spring.new(to: 1.05)
      encoded = Spring.encode(s)

      assert encoded["type"] == "spring"
      assert encoded["to"] == 1.05
      assert encoded["stiffness"] == 100
      assert encoded["damping"] == 10
      refute Map.has_key?(encoded, "mass")
      refute Map.has_key?(encoded, "velocity")
    end

    test "non-default mass is included" do
      s = Spring.new(to: 1.0, mass: 2.0)
      encoded = Spring.encode(s)
      assert encoded["mass"] == 2.0
    end

    test "non-zero velocity is included" do
      s = Spring.new(to: 1.0, velocity: 5.0)
      encoded = Spring.encode(s)
      assert encoded["velocity"] == 5.0
    end

    test "near-zero velocity is omitted" do
      s = Spring.new(to: 1.0, velocity: 1.0e-17)
      encoded = Spring.encode(s)
      refute Map.has_key?(encoded, "velocity")
    end

    test "from and on_complete are included when set" do
      s = Spring.new(to: 1.0, from: 0.0, on_complete: :settled)
      encoded = Spring.encode(s)
      assert encoded["from"] == 0.0
      assert encoded["on_complete"] == "settled"
    end
  end

  describe "from_opts/1" do
    test "from_opts/1 builds a spring" do
      s = Spring.from_opts(to: 1.05, stiffness: 200, damping: 20)
      assert s.to == 1.05
      assert s.stiffness == 200
    end
  end
end
