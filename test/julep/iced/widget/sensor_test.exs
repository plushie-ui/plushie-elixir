defmodule Julep.Iced.Widget.SensorTest do
  use ExUnit.Case, async: true

  alias Julep.Iced.Widget.Sensor

  describe "new/1" do
    test "creates a struct with the given id" do
      s = Sensor.new("s1")
      assert %Sensor{id: "s1"} = s
    end

    test "children default to empty list" do
      s = Sensor.new("s1")
      assert s.children == []
    end
  end

  describe "push/2" do
    test "appends a child" do
      child = %{id: "c1", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(child)
      assert s.children == [child]
    end

    test "preserves order across multiple pushes" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(c1) |> Sensor.push(c2)
      assert s.children == [c1, c2]
    end
  end

  describe "extend/2" do
    test "appends multiple children at once" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.extend([c1, c2])
      assert s.children == [c1, c2]
    end

    test "extends after push preserves all children" do
      c1 = %{id: "c1", type: "text", props: %{}, children: []}
      c2 = %{id: "c2", type: "text", props: %{}, children: []}
      c3 = %{id: "c3", type: "text", props: %{}, children: []}
      s = Sensor.new("s1") |> Sensor.push(c1) |> Sensor.extend([c2, c3])
      assert s.children == [c1, c2, c3]
    end
  end

  describe "build/1" do
    test "returns a ui_node map with correct type and id" do
      node = Sensor.new("s1") |> Sensor.build()
      assert node.id == "s1"
      assert node.type == "sensor"
    end

    test "props is an empty map" do
      node = Sensor.new("s1") |> Sensor.build()
      assert node.props == %{}
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
