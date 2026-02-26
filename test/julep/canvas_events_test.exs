defmodule Julep.CanvasEventsTest do
  use ExUnit.Case, async: true

  describe "canvas event dispatch" do
    test "decodes canvas_press" do
      msg = %{"type" => "event", "family" => "canvas_press", "id" => "my_canvas",
              "data" => %{"x" => 42.5, "y" => 100.0, "button" => "left"}}
      assert {:canvas_press, "my_canvas", 42.5, 100.0, "left"} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end

    test "decodes canvas_release" do
      msg = %{"type" => "event", "family" => "canvas_release", "id" => "c1",
              "data" => %{"x" => 10.0, "y" => 20.0, "button" => "right"}}
      assert {:canvas_release, "c1", 10.0, 20.0, "right"} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end

    test "decodes canvas_move" do
      msg = %{"type" => "event", "family" => "canvas_move", "id" => "c1",
              "data" => %{"x" => 5.5, "y" => 3.2}}
      assert {:canvas_move, "c1", 5.5, 3.2} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end

    test "decodes canvas_scroll" do
      msg = %{"type" => "event", "family" => "canvas_scroll", "id" => "c1",
              "data" => %{"x" => 1.5, "y" => 2.5, "delta_x" => 0.5, "delta_y" => -3.0}}
      assert {:canvas_scroll, "c1", 1.5, 2.5, 0.5, -3.0} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end

    test "canvas_press defaults button to left when missing" do
      msg = %{"type" => "event", "family" => "canvas_press", "id" => "c1",
              "data" => %{"x" => 1.0, "y" => 2.0}}
      assert {:canvas_press, "c1", 1.0, 2.0, "left"} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end

    test "canvas_release defaults button to left when missing" do
      msg = %{"type" => "event", "family" => "canvas_release", "id" => "c1",
              "data" => %{"x" => 1.0, "y" => 2.0}}
      assert {:canvas_release, "c1", 1.0, 2.0, "left"} =
               Julep.Protocol.decode_message(Jason.encode!(msg))
    end
  end

  describe "canvas interactive props" do
    test "canvas node with interactive prop" do
      node = Julep.Iced.canvas("c1", %{interactive: true, shapes: []})
      assert node.props["interactive"] == true
    end

    test "canvas node with individual event props" do
      node = Julep.Iced.canvas("c1", %{on_press: true, on_move: true, shapes: []})
      assert node.props["on_press"] == true
      assert node.props["on_move"] == true
    end

    test "canvas node has correct type" do
      node = Julep.Iced.canvas("c1", %{shapes: []})
      assert node.id == "c1"
      assert node.type == "canvas"
    end

    test "canvas node has no children" do
      node = Julep.Iced.canvas("c1")
      assert node.children == []
    end
  end
end
