defmodule Julep.MixTasksTest do
  use ExUnit.Case, async: true

  describe "Mix.Tasks.Julep.Inspect" do
    test "prints the initial tree for a known app as JSON" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Mix.Tasks.Julep.Inspect.run(["Julep.Examples.Counter"])
        end)

      # Should be valid JSON
      assert {:ok, tree} = Jason.decode(output)
      assert is_map(tree)
      assert Map.has_key?(tree, "type")
    end

    test "raises on missing module" do
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Julep.Inspect.run(["NonExistent.Module"])
      end
    end

    test "raises with no arguments" do
      assert_raise Mix.Error, fn ->
        Mix.Tasks.Julep.Inspect.run([])
      end
    end
  end

  describe "Mix.Tasks.Julep.Build" do
    test "module is loadable and exports run/1" do
      Code.ensure_loaded!(Mix.Tasks.Julep.Build)
      assert function_exported?(Mix.Tasks.Julep.Build, :run, 1)
    end
  end
end
