defmodule Plushie.TestTest do
  use ExUnit.Case, async: true

  describe "assert_tree_snapshot/2" do
    @tag :tmp_dir
    test "creates snapshot on first run", %{tmp_dir: tmp_dir} do
      tree = %{id: "root", type: "text", props: %{content: "hello"}, children: []}
      path = Path.join(tmp_dir, "snapshot.json")

      Plushie.Test.assert_tree_snapshot(tree, path)
      assert File.exists?(path)
      stored = Jason.decode!(File.read!(path))
      assert stored["id"] == "root"
    end

    @tag :tmp_dir
    test "passes when snapshot matches", %{tmp_dir: tmp_dir} do
      tree = %{id: "root", type: "text", props: %{content: "hello"}, children: []}
      path = Path.join(tmp_dir, "snapshot.json")

      Plushie.Test.assert_tree_snapshot(tree, path)
      # Second call should pass
      Plushie.Test.assert_tree_snapshot(tree, path)
    end

    @tag :tmp_dir
    test "fails when snapshot differs", %{tmp_dir: tmp_dir} do
      tree1 = %{id: "root", type: "text", props: %{content: "hello"}, children: []}
      tree2 = %{id: "root", type: "text", props: %{content: "world"}, children: []}
      path = Path.join(tmp_dir, "snapshot.json")

      Plushie.Test.assert_tree_snapshot(tree1, path)

      assert_raise ExUnit.AssertionError, fn ->
        Plushie.Test.assert_tree_snapshot(tree2, path)
      end
    end
  end
end
