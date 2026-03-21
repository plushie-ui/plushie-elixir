defmodule PlushieUIParityTestHelper do
  @moduledoc false
  import Plushie.UI

  # -- grid --

  def grid_empty do
    grid()
  end

  def grid_with_opts do
    grid(column_count: 3, spacing: 4)
  end

  def grid_with_do_block do
    grid do
      text("a")
      text("b")
    end
  end

  def grid_with_opts_and_do do
    grid column_count: 2 do
      text("x")
    end
  end

  def grid_with_explicit_id do
    grid(id: "my_grid", column_count: 3)
  end

  # -- keyed_column --

  def keyed_column_empty do
    keyed_column()
  end

  def keyed_column_with_do do
    keyed_column spacing: 8 do
      text("item1")
      text("item2")
    end
  end

  # -- responsive --

  def responsive_empty do
    responsive()
  end

  def responsive_with_do do
    responsive do
      text("adapts")
    end
  end

  # -- pin --

  def pin_empty do
    pin("p1")
  end

  def pin_with_do do
    pin "p1" do
      text("pinned")
    end
  end

  def pin_with_opts_and_do do
    pin "p1", width: 200 do
      text("abs")
    end
  end

  # -- floating --

  def float_empty do
    floating("f1")
  end

  def float_with_do do
    floating "f1" do
      text("overlay")
    end
  end

  def float_with_opts_and_do do
    floating "f1", width: 300 do
      text("popup")
    end
  end

  # -- mouse_area --

  def mouse_area_empty do
    mouse_area("ma1")
  end

  def mouse_area_with_do do
    mouse_area "ma1", on_press: :clicked do
      button("btn1", "Click")
    end
  end

  def mouse_area_with_opts_and_do do
    mouse_area "ma1", on_press: :p, on_release: :r do
      text("interactive")
    end
  end

  # -- sensor --

  def sensor_empty do
    sensor("s1")
  end

  def sensor_with_do do
    sensor "s1", on_resize: :resized do
      text("watched")
    end
  end

  # -- pane_grid (function, not macro) --

  def pane_grid_empty do
    pane_grid("pg1")
  end

  def pane_grid_with_opts do
    pane_grid("pg1", panes: [:a, :b], spacing: 2)
  end

  # -- rich_text (function, not macro) --

  def rich_text_empty do
    rich_text("rt1")
  end

  def rich_text_with_spans do
    rich_text("rt1", spans: [%{text: "hello", weight: :bold}])
  end
end

defmodule Plushie.UIParityTest do
  @moduledoc """
  Tests for all new widgets in Plushie.UI added in the iced parity pass.
  Does not duplicate tests from ui_test.exs.
  """
  use ExUnit.Case, async: true

  alias PlushieUIParityTestHelper, as: H

  # ---------------------------------------------------------------------------
  # grid
  # ---------------------------------------------------------------------------

  describe "grid macro" do
    test "empty grid has correct shape" do
      node = H.grid_empty()
      assert node.type == "grid"
      assert node.props == %{}
      assert node.children == []
    end

    test "grid with opts sets props" do
      node = H.grid_with_opts()
      assert node.props[:column_count] == 3
      assert node.props[:spacing] == 4
    end

    test "grid with do block collects children" do
      node = H.grid_with_do_block()
      assert length(node.children) == 2
      assert Enum.all?(node.children, &(&1.type == "text"))
    end

    test "grid with opts and do block" do
      node = H.grid_with_opts_and_do()
      assert node.props[:column_count] == 2
      assert length(node.children) == 1
    end

    test "grid with explicit id" do
      node = H.grid_with_explicit_id()
      assert node.id == "my_grid"
    end

    test "grid without explicit id gets auto-id" do
      node = H.grid_empty()
      assert String.starts_with?(node.id, "auto:")
    end
  end

  # ---------------------------------------------------------------------------
  # keyed_column
  # ---------------------------------------------------------------------------

  describe "keyed_column macro" do
    test "empty keyed_column has correct shape" do
      node = H.keyed_column_empty()
      assert node.type == "keyed_column"
      assert node.children == []
    end

    test "keyed_column with opts and do block" do
      node = H.keyed_column_with_do()
      assert node.props[:spacing] == 8
      assert length(node.children) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # responsive
  # ---------------------------------------------------------------------------

  describe "responsive macro" do
    test "empty responsive has correct shape" do
      node = H.responsive_empty()
      assert node.type == "responsive"
      assert node.children == []
    end

    test "responsive with do block" do
      node = H.responsive_with_do()
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # pin
  # ---------------------------------------------------------------------------

  describe "pin macro" do
    test "empty pin has correct shape" do
      node = H.pin_empty()
      assert node.type == "pin"
      assert node.id == "p1"
      assert node.children == []
    end

    test "pin with do block collects children" do
      node = H.pin_with_do()
      assert length(node.children) == 1
    end

    test "pin with opts and do block" do
      node = H.pin_with_opts_and_do()
      assert node.props[:width] == 200
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # floating
  # ---------------------------------------------------------------------------

  describe "floating macro" do
    test "empty float has correct type" do
      node = H.float_empty()
      assert node.type == "float"
      assert node.id == "f1"
      assert node.children == []
    end

    test "float with do block" do
      node = H.float_with_do()
      assert length(node.children) == 1
    end

    test "float with opts and do block" do
      node = H.float_with_opts_and_do()
      assert node.props[:width] == 300
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # mouse_area
  # ---------------------------------------------------------------------------

  describe "mouse_area macro" do
    test "empty mouse_area has correct shape" do
      node = H.mouse_area_empty()
      assert node.type == "mouse_area"
      assert node.id == "ma1"
      assert node.children == []
    end

    test "mouse_area with event props and do block" do
      node = H.mouse_area_with_do()
      assert node.props[:on_press] == "clicked"
      assert length(node.children) == 1
    end

    test "mouse_area with multiple event props" do
      node = H.mouse_area_with_opts_and_do()
      assert node.props[:on_press] == "p"
      assert node.props[:on_release] == "r"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # sensor
  # ---------------------------------------------------------------------------

  describe "sensor macro" do
    test "empty sensor has correct shape" do
      node = H.sensor_empty()
      assert node.type == "sensor"
      assert node.id == "s1"
      assert node.children == []
    end

    test "sensor with event props and do block" do
      node = H.sensor_with_do()
      assert node.props[:on_resize] == "resized"
      assert length(node.children) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # pane_grid (function)
  # ---------------------------------------------------------------------------

  describe "pane_grid function" do
    test "empty pane_grid has correct shape" do
      node = H.pane_grid_empty()
      assert node.type == "pane_grid"
      assert node.id == "pg1"
      assert node.props == %{}
      assert node.children == []
    end

    test "pane_grid with options" do
      node = H.pane_grid_with_opts()
      assert node.props[:panes] == ["a", "b"]
      assert node.props[:spacing] == 2
    end
  end

  # ---------------------------------------------------------------------------
  # rich_text (function)
  # ---------------------------------------------------------------------------

  describe "rich_text function" do
    test "empty rich_text has correct shape" do
      node = H.rich_text_empty()
      assert node.type == "rich_text"
      assert node.id == "rt1"
      assert node.props == %{}
      assert node.children == []
    end

    test "rich_text with spans" do
      node = H.rich_text_with_spans()
      assert node.props[:spans] == [%{text: "hello", weight: :bold}]
    end
  end

  # ---------------------------------------------------------------------------
  # All new UI widgets produce well-formed nodes
  # ---------------------------------------------------------------------------

  describe "node shape consistency" do
    test "all new widget nodes have id, type, props, children keys" do
      nodes = [
        H.grid_empty(),
        H.keyed_column_empty(),
        H.responsive_empty(),
        H.pin_empty(),
        H.float_empty(),
        H.mouse_area_empty(),
        H.sensor_empty(),
        H.pane_grid_empty(),
        H.rich_text_empty()
      ]

      for node <- nodes do
        assert Map.has_key?(node, :id), "#{node.type} missing :id"
        assert Map.has_key?(node, :type), "#{node.type} missing :type"
        assert Map.has_key?(node, :props), "#{node.type} missing :props"
        assert Map.has_key?(node, :children), "#{node.type} missing :children"
        assert is_binary(node.id), "#{node.type} id should be a string"
        assert is_binary(node.type), "#{node.type} type should be a string"
        assert is_map(node.props), "#{node.type} props should be a map"
        assert is_list(node.children), "#{node.type} children should be a list"
      end
    end

    test "all new widget prop keys are atoms" do
      nodes = [
        H.grid_with_opts(),
        H.keyed_column_with_do(),
        H.pin_with_opts_and_do(),
        H.float_with_opts_and_do(),
        H.mouse_area_with_opts_and_do(),
        H.sensor_with_do(),
        H.pane_grid_with_opts(),
        H.rich_text_with_spans()
      ]

      for node <- nodes do
        for key <- Map.keys(node.props) do
          assert is_atom(key),
                 "#{node.type} has non-atom prop key: #{inspect(key)}"
        end
      end
    end
  end
end
