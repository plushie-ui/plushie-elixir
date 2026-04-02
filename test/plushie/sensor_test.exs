defmodule Plushie.SensorTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent

  describe "sensor resize event dispatch" do
    test "decodes resize" do
      msg = %{
        "type" => "event",
        "family" => "resize",
        "id" => "s1",
        "window_id" => "main",
        "data" => %{"width" => 450.0, "height" => 300.0}
      }

      assert %WidgetEvent{type: :resize, id: "s1", data: %{width: 450.0, height: 300.0}} =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes resize with integer values" do
      msg = %{
        "type" => "event",
        "family" => "resize",
        "id" => "s1",
        "window_id" => "main",
        "data" => %{"width" => 800, "height" => 600}
      }

      assert %WidgetEvent{type: :resize, id: "s1", data: %{width: 800, height: 600}} =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end
  end

  describe "sensor widget construction" do
    test "sensor node with default props" do
      node = Plushie.Widget.Node.build("s1", "sensor", %{}, [])
      assert node.id == "s1"
      assert node.type == "sensor"
    end

    test "sensor node with children" do
      child = Plushie.Widget.Node.build("inner", "text", %{content: "content"})
      node = Plushie.Widget.Node.build("s1", "sensor", %{on_resize: true}, [child])
      assert node.props[:on_resize] == true
      assert length(node.children) == 1
      assert hd(node.children).type == "text"
    end

    test "sensor node with no args" do
      node = Plushie.Widget.Node.build("s1", "sensor", %{})
      assert node.id == "s1"
      assert node.type == "sensor"
      assert node.props == %{}
      assert node.children == []
    end
  end
end
