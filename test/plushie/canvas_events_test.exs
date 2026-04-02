defmodule Plushie.CanvasEventsTest do
  use ExUnit.Case, async: true

  alias Plushie.Event.WidgetEvent

  describe "unified pointer event dispatch (canvas)" do
    test "decodes press" do
      msg = %{
        "type" => "event",
        "family" => "press",
        "id" => "my_canvas",
        "window_id" => "main",
        "data" => %{
          "x" => 42.5,
          "y" => 100.0,
          "button" => "left",
          "pointer" => "mouse",
          "modifiers" => %{"shift" => false, "ctrl" => false, "alt" => false}
        }
      }

      assert %WidgetEvent{
               type: :press,
               id: "my_canvas",
               data: %{x: 42.5, y: 100.0, button: :left, pointer: :mouse}
             } =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes release" do
      msg = %{
        "type" => "event",
        "family" => "release",
        "id" => "c1",
        "window_id" => "main",
        "data" => %{
          "x" => 10.0,
          "y" => 20.0,
          "button" => "right",
          "pointer" => "mouse",
          "modifiers" => %{}
        }
      }

      assert %WidgetEvent{
               type: :release,
               id: "c1",
               data: %{x: 10.0, y: 20.0, button: :right, pointer: :mouse}
             } =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes move" do
      msg = %{
        "type" => "event",
        "family" => "move",
        "id" => "c1",
        "window_id" => "main",
        "data" => %{
          "x" => 5.5,
          "y" => 3.2,
          "pointer" => "mouse",
          "modifiers" => %{}
        }
      }

      assert %WidgetEvent{type: :move, id: "c1", data: %{x: 5.5, y: 3.2, pointer: :mouse}} =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes pointer scroll (wire family 'scroll' with pointer field)" do
      msg = %{
        "type" => "event",
        "family" => "scroll",
        "id" => "c1",
        "window_id" => "main",
        "data" => %{
          "x" => 1.5,
          "y" => 2.5,
          "delta_x" => 0.5,
          "delta_y" => -3.0,
          "pointer" => "mouse",
          "modifiers" => %{}
        }
      }

      assert %WidgetEvent{
               type: :pointer_scroll,
               id: "c1",
               data: %{x: 1.5, y: 2.5, delta_x: 0.5, delta_y: -3.0, pointer: :mouse}
             } =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "scrollable widget scroll (wire family 'scroll' without pointer field)" do
      msg = %{
        "type" => "event",
        "family" => "scroll",
        "id" => "scroller",
        "window_id" => "main",
        "data" => %{
          "absolute_x" => 0.0,
          "absolute_y" => 50.0,
          "relative_x" => 0.0,
          "relative_y" => 0.5,
          "bounds_width" => 400.0,
          "bounds_height" => 300.0,
          "content_width" => 400.0,
          "content_height" => 600.0
        }
      }

      assert %WidgetEvent{
               type: :scroll,
               id: "scroller",
               data: %{absolute_y: 50.0, relative_y: 0.5}
             } =
               Plushie.Protocol.decode_message(Jason.encode!(msg), :json)
    end
  end

  describe "canvas interactive props" do
    test "canvas node with interactive prop" do
      node = Plushie.Widget.Node.build("c1", "canvas", %{interactive: true, layers: %{}})
      assert node.props[:interactive] == true
    end

    test "canvas node with individual event props" do
      node =
        Plushie.Widget.Node.build("c1", "canvas", %{on_press: true, on_move: true, layers: %{}})

      assert node.props[:on_press] == true
      assert node.props[:on_move] == true
    end

    test "canvas node has correct type" do
      node = Plushie.Widget.Node.build("c1", "canvas", %{layers: %{}})
      assert node.id == "c1"
      assert node.type == "canvas"
    end

    test "canvas node has no children" do
      node = Plushie.Widget.Node.build("c1", "canvas", %{})
      assert node.children == []
    end
  end
end
