defmodule Toddy.CanvasEventsTest do
  use ExUnit.Case, async: true

  alias Toddy.Event.Canvas

  describe "canvas event dispatch" do
    test "decodes canvas_press" do
      msg = %{
        "type" => "event",
        "family" => "canvas_press",
        "id" => "my_canvas",
        "data" => %{"x" => 42.5, "y" => 100.0, "button" => "left"}
      }

      assert %Canvas{type: :press, id: "my_canvas", x: 42.5, y: 100.0, button: "left"} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes canvas_release" do
      msg = %{
        "type" => "event",
        "family" => "canvas_release",
        "id" => "c1",
        "data" => %{"x" => 10.0, "y" => 20.0, "button" => "right"}
      }

      assert %Canvas{type: :release, id: "c1", x: 10.0, y: 20.0, button: "right"} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes canvas_move" do
      msg = %{
        "type" => "event",
        "family" => "canvas_move",
        "id" => "c1",
        "data" => %{"x" => 5.5, "y" => 3.2}
      }

      assert %Canvas{type: :move, id: "c1", x: 5.5, y: 3.2} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes canvas_scroll" do
      msg = %{
        "type" => "event",
        "family" => "canvas_scroll",
        "id" => "c1",
        "data" => %{"x" => 1.5, "y" => 2.5, "delta_x" => 0.5, "delta_y" => -3.0}
      }

      assert %Canvas{type: :scroll, id: "c1", x: 1.5, y: 2.5, delta_x: 0.5, delta_y: -3.0} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "canvas_press defaults button to left when missing" do
      msg = %{
        "type" => "event",
        "family" => "canvas_press",
        "id" => "c1",
        "data" => %{"x" => 1.0, "y" => 2.0}
      }

      assert %Canvas{type: :press, id: "c1", x: 1.0, y: 2.0, button: "left"} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "canvas_release defaults button to left when missing" do
      msg = %{
        "type" => "event",
        "family" => "canvas_release",
        "id" => "c1",
        "data" => %{"x" => 1.0, "y" => 2.0}
      }

      assert %Canvas{type: :release, id: "c1", x: 1.0, y: 2.0, button: "left"} =
               Toddy.Protocol.decode_message(Jason.encode!(msg), :json)
    end
  end

  describe "canvas interactive props" do
    test "canvas node with interactive prop" do
      node = Toddy.Widget.Node.build("c1", "canvas", %{interactive: true, layers: %{}})
      assert node.props[:interactive] == true
    end

    test "canvas node with individual event props" do
      node =
        Toddy.Widget.Node.build("c1", "canvas", %{on_press: true, on_move: true, layers: %{}})

      assert node.props[:on_press] == true
      assert node.props[:on_move] == true
    end

    test "canvas node has correct type" do
      node = Toddy.Widget.Node.build("c1", "canvas", %{layers: %{}})
      assert node.id == "c1"
      assert node.type == "canvas"
    end

    test "canvas node has no children" do
      node = Toddy.Widget.Node.build("c1", "canvas", %{})
      assert node.children == []
    end
  end
end
