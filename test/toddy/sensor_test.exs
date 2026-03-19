defmodule Toddy.SensorTest do
  use ExUnit.Case, async: true

  alias Toddy.Event.Sensor

  describe "sensor resize event dispatch" do
    test "decodes sensor_resize" do
      msg = %{
        "type" => "event",
        "family" => "sensor_resize",
        "id" => "s1",
        "data" => %{"width" => 450.0, "height" => 300.0}
      }

      assert %Sensor{type: :resize, id: "s1", width: 450.0, height: 300.0} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes sensor_resize with integer values" do
      msg = %{
        "type" => "event",
        "family" => "sensor_resize",
        "id" => "s1",
        "data" => %{"width" => 800, "height" => 600}
      }

      assert %Sensor{type: :resize, id: "s1", width: 800, height: 600} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end
  end

  describe "sensor widget construction" do
    test "sensor node with default props" do
      node = Toddy.Iced.sensor("s1", %{}, [])
      assert node.id == "s1"
      assert node.type == "sensor"
    end

    test "sensor node with children" do
      child = Toddy.Iced.text("inner", %{content: "content"})
      node = Toddy.Iced.sensor("s1", %{on_resize: true}, [child])
      assert node.props["on_resize"] == true
      assert length(node.children) == 1
      assert hd(node.children).type == "text"
    end

    test "sensor node with no args" do
      node = Toddy.Iced.sensor("s1")
      assert node.id == "s1"
      assert node.type == "sensor"
      assert node.props == %{}
      assert node.children == []
    end
  end
end
