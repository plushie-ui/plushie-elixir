defmodule Julep.Examples.ExtensionsDemoTest do
  use ExUnit.Case, async: false

  # Skip all tests when extension packages aren't compiled into the project.
  # The demo module references JulepSparkline, JulepHexView, etc. which live
  # in separate repos (julep_sparkline, julep_hex_view, ...).
  if Code.ensure_loaded?(Julep.Examples.ExtensionsDemo) do
    alias Julep.Examples.ExtensionsDemo

    # ---------------------------------------------------------------------------
    # init/1
    # ---------------------------------------------------------------------------

    describe "init/1" do
      test "returns initial model" do
        model = ExtensionsDemo.init(nil)
        assert model.tick == 0
        assert model.paused == false
        assert model.hex_text == "Hello, Julep!"
        assert model.language == "rust"
        assert model.selected_interval == nil
      end
    end

    # ---------------------------------------------------------------------------
    # update/2
    # ---------------------------------------------------------------------------

    describe "update/2 -- tick" do
      test "increments tick and produces sparkline command" do
        model = ExtensionsDemo.init(nil)
        {updated, commands} = ExtensionsDemo.update(model, :tick)
        assert updated.tick == 1
        assert [%Julep.Command{type: :extension_command}] = commands
      end

      test "tick is a no-op when paused" do
        model = %{ExtensionsDemo.init(nil) | paused: true}
        result = ExtensionsDemo.update(model, :tick)
        # Bare model return, no commands
        assert result.tick == 0
      end
    end

    describe "update/2 -- toggle_pause" do
      test "toggles paused state" do
        model = ExtensionsDemo.init(nil)
        updated = ExtensionsDemo.update(model, :toggle_pause)
        assert updated.paused == true
        updated2 = ExtensionsDemo.update(updated, :toggle_pause)
        assert updated2.paused == false
      end
    end

    describe "update/2 -- unknown" do
      test "returns model unchanged" do
        model = ExtensionsDemo.init(nil)
        assert ExtensionsDemo.update(model, {:nonsense}) == model
      end
    end

    # ---------------------------------------------------------------------------
    # view/1 -- coexistence: all 5 extension widgets in one tree
    # ---------------------------------------------------------------------------

    describe "view/1 -- tree structure" do
      test "root is a window node" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        assert tree.type == "window"
        assert tree.id == "extensions-demo"
      end

      test "all 5 extension widget types appear in tree" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))

        assert find_type(tree, "sparkline"), "sparkline widget not found in tree"
        assert find_type(tree, "hex_view"), "hex_view widget not found in tree"
        assert find_type(tree, "code_view"), "code_view widget not found in tree"
        assert find_type(tree, "plot"), "plot widget not found in tree"
        assert find_type(tree, "timeline"), "timeline widget not found in tree"
      end

      test "sparkline has expected props" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        spark = Julep.Tree.find(tree, "spark")
        assert spark != nil
        assert spark.type == "sparkline"
        assert spark.props["color"] == "#4fc3f7"
        assert spark.props["width"] == 200
        assert spark.props["height"] == 60
      end

      test "hex_view has data prop" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        hex = Julep.Tree.find(tree, "hex")
        assert hex != nil
        assert hex.type == "hex_view"
        assert hex.props["bytes_per_row"] == 8
      end

      test "code_view has code and language props" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        code = Julep.Tree.find(tree, "code")
        assert code != nil
        assert code.type == "code_view"
        assert code.props["language"] == "rust"
        assert code.props["line_numbers"] == true
      end

      test "plot has series data" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        plot = Julep.Tree.find(tree, "plot")
        assert plot != nil
        assert plot.type == "plot"
        assert is_list(plot.props["series"])
        assert length(plot.props["series"]) == 2
      end

      test "timeline has intervals" do
        tree = ExtensionsDemo.view(ExtensionsDemo.init(nil))
        timeline = Julep.Tree.find(tree, "timeline")
        assert timeline != nil
        assert timeline.type == "timeline"
        assert is_list(timeline.props["intervals"])
        assert length(timeline.props["intervals"]) == 3
      end
    end

    # ---------------------------------------------------------------------------
    # No type name collisions
    # ---------------------------------------------------------------------------

    describe "type name collisions" do
      test "all 5 extensions have unique type names" do
        all_types =
          [JulepSparkline, JulepHexView, JulepCodeView, JulepPlot, JulepTimeline]
          |> Enum.flat_map(& &1.type_names())

        assert length(all_types) == length(Enum.uniq(all_types)),
               "type name collision: #{inspect(all_types)}"
      end
    end

    # ---------------------------------------------------------------------------
    # Extension discovery
    # ---------------------------------------------------------------------------

    describe "extension discovery" do
      test "register_all finds all 5 extensions" do
        Julep.Test.ExtensionEvents.register_all()

        for type <- ["sparkline", "hex_view", "code_view", "plot", "timeline"] do
          assert :persistent_term.get({Julep.Test.ExtensionEvents, type}, :missing) != :missing,
                 "extension type #{type} not registered"
        end
      end
    end

    # ---------------------------------------------------------------------------
    # sim_events dispatch
    # ---------------------------------------------------------------------------

    describe "sim_events" do
      test "plot click produces click event matching real protocol" do
        element = %Julep.Test.Element{type: "plot", id: "p1", props: %{}, children: []}
        assert {:ok, {:click, "p1"}} = JulepPlot.sim_events(:click, element, [])
      end

      test "timeline click produces click event matching real protocol" do
        element = %Julep.Test.Element{type: "timeline", id: "t1", props: %{}, children: []}
        assert {:ok, {:click, "t1"}} = JulepTimeline.sim_events(:click, element, [])
      end
    end

    # ---------------------------------------------------------------------------
    # subscribe/1
    # ---------------------------------------------------------------------------

    describe "subscribe/1" do
      test "returns timer when not paused" do
        model = ExtensionsDemo.init(nil)
        subs = ExtensionsDemo.subscribe(model)
        assert length(subs) == 1
      end

      test "returns empty list when paused" do
        model = %{ExtensionsDemo.init(nil) | paused: true}
        assert ExtensionsDemo.subscribe(model) == []
      end
    end

    # ---------------------------------------------------------------------------
    # Helpers
    # ---------------------------------------------------------------------------

    defp find_type(%{type: type}, target) when type == target, do: true

    defp find_type(%{children: children}, target) when is_list(children) do
      Enum.any?(children, &find_type(&1, target))
    end

    defp find_type(_, _), do: false
  end
end
