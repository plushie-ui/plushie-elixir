defmodule Toddy.Iced.Widget.SensorTest do
  use ExUnit.Case, async: true

  alias Toddy.Iced.Widget.Sensor

  describe "new/2" do
    test "creates a struct with the given id" do
      s = Sensor.new("s1")
      assert %Sensor{id: "s1"} = s
    end

    test "children default to empty list" do
      s = Sensor.new("s1")
      assert s.children == []
    end

    test "delay defaults to nil" do
      s = Sensor.new("s1")
      assert s.delay == nil
    end

    test "accepts keyword options" do
      s = Sensor.new("s1", delay: 500)
      assert s.delay == 500
    end
  end

  describe "delay/2" do
    test "sets the delay field" do
      s = Sensor.new("s1") |> Sensor.delay(250)
      assert s.delay == 250
    end
  end

  describe "with_options/2" do
    test "routes delay option" do
      s = Sensor.new("s1") |> Sensor.with_options(delay: 100)
      assert s.delay == 100
    end

    test "raises on unknown option" do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Sensor.new("s1", bogus: true)
      end
    end
  end

  describe "push/2" do
    test "appends a child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(child)
      assert s.children == [child]
    end

    test "preserves order across multiple pushes (internal reverse, build restores)" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(c1) |> Sensor.push(c2)
      # Internal list is prepend-order (reversed); build/1 reverses back
      assert s.children == [c2, c1]
      node = Sensor.build(s)
      assert node.children == [c1, c2]
    end
  end

  describe "extend/2" do
    test "appends multiple children at once" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.extend([c1, c2])
      # Internal list is reversed; build/1 reverses back
      assert s.children == [c2, c1]
      node = Sensor.build(s)
      assert node.children == [c1, c2]
    end

    test "extends after push preserves all children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      c3 = %{id: "c3", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(c1) |> Sensor.extend([c2, c3])
      # Internal: extend reverses [c2,c3] to [c3,c2], prepends to [c1] -> [c3, c2, c1]
      assert s.children == [c3, c2, c1]
      node = Sensor.build(s)
      assert node.children == [c1, c2, c3]
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Sensor.new("s1") |> Sensor.build()
      assert node.id == "s1"
      assert node.type == "sensor"
    end

    test "props is an empty map when no delay set" do
      node = Sensor.new("s1") |> Sensor.build()
      assert node.props == %{}
    end

    test "includes delay in props when set" do
      node = Sensor.new("s1", delay: 500) |> Sensor.build()
      assert node.props["delay"] == 500
    end

    test "omits delay from props when nil" do
      node = Sensor.new("s1") |> Sensor.build()
      refute Map.has_key?(node.props, "delay")
    end

    test "converts children to nodes" do
      child = %{id: "c1", type: "text", props: %{"content" => "hi"}, children: []}
      node = Sensor.new("s1") |> Sensor.push(child) |> Sensor.build()
      assert length(node.children) == 1
      assert hd(node.children).id == "c1"
    end

    test "empty children produces empty list" do
      node = Sensor.new("s1") |> Sensor.build()
      assert node.children == []
    end
  end
end
