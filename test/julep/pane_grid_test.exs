defmodule Julep.PaneGridTest do
  use ExUnit.Case, async: true

  alias Julep.Event.Pane

  describe "Julep.Iced.pane_grid/3" do
    test "creates pane_grid node with children" do
      left = Julep.Iced.text("left", %{content: "Left"})
      right = Julep.Iced.text("right", %{content: "Right"})
      node = Julep.Iced.pane_grid("pg1", %{spacing: 4}, [left, right])
      assert node.id == "pg1"
      assert node.type == "pane_grid"
      assert node.props["spacing"] == 4
      assert length(node.children) == 2
    end

    test "creates pane_grid with default props" do
      node = Julep.Iced.pane_grid("pg1")
      assert node.props == %{}
      assert node.children == []
    end
  end

  describe "pane commands" do
    test "pane_split creates widget_op command" do
      cmd = Julep.Command.pane_split("pg1", "left", :vertical, "center")
      assert cmd.type == :widget_op
      assert cmd.payload.op == "pane_split"
      assert cmd.payload.target == "pg1"
      assert cmd.payload.pane == "left"
      assert cmd.payload.axis == "vertical"
      assert cmd.payload.new_pane_id == "center"
    end

    test "pane_close creates widget_op command" do
      cmd = Julep.Command.pane_close("pg1", "left")
      assert cmd.type == :widget_op
      assert cmd.payload.op == "pane_close"
      assert cmd.payload.pane == "left"
    end

    test "pane_swap creates widget_op command" do
      cmd = Julep.Command.pane_swap("pg1", "left", "right")
      assert cmd.type == :widget_op
      assert cmd.payload.op == "pane_swap"
      assert cmd.payload.a == "left"
      assert cmd.payload.b == "right"
    end

    test "pane_maximize creates widget_op command" do
      cmd = Julep.Command.pane_maximize("pg1", "left")
      assert cmd.type == :widget_op
      assert cmd.payload.op == "pane_maximize"
    end

    test "pane_restore creates widget_op command" do
      cmd = Julep.Command.pane_restore("pg1")
      assert cmd.type == :widget_op
      assert cmd.payload.op == "pane_restore"
    end

    test "pane_split with horizontal axis" do
      cmd = Julep.Command.pane_split("pg1", "top", :horizontal, "bottom")
      assert cmd.payload.axis == "horizontal"
      assert cmd.payload.pane == "top"
      assert cmd.payload.new_pane_id == "bottom"
    end

    test "pane_close includes target" do
      cmd = Julep.Command.pane_close("grid1", "p2")
      assert cmd.payload.target == "grid1"
      assert cmd.payload.pane == "p2"
    end

    test "pane_swap includes target" do
      cmd = Julep.Command.pane_swap("grid1", "a", "b")
      assert cmd.payload.target == "grid1"
    end
  end

  describe "pane event dispatch" do
    test "decodes pane_resized" do
      msg = %{
        "type" => "event",
        "family" => "pane_resized",
        "id" => "pg1",
        "data" => %{"split" => 0, "ratio" => 0.45}
      }

      assert %Pane{type: :resized, id: "pg1", split: 0, ratio: 0.45} =
               Julep.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes pane_dragged" do
      msg = %{
        "type" => "event",
        "family" => "pane_dragged",
        "id" => "pg1",
        "data" => %{"pane" => "left", "target" => "right"}
      }

      assert %Pane{type: :dragged, id: "pg1", pane: "left", target: "right"} =
               Julep.Protocol.decode_message(Jason.encode!(msg), :json)
    end

    test "decodes pane_clicked" do
      msg = %{
        "type" => "event",
        "family" => "pane_clicked",
        "id" => "pg1",
        "data" => %{"pane" => "left"}
      }

      assert %Pane{type: :clicked, id: "pg1", pane: "left"} =
               Julep.Protocol.decode_message(Jason.encode!(msg), :json)
    end
  end
end
