defmodule Julep.SnapshotTest do
  use ExUnit.Case, async: false

  # async: false because we manipulate JULEP_UPDATE_SNAPSHOTS env var
  # and write to the filesystem; parallel runs would stomp on each other.

  import Julep.UI, only: [button: 2, button: 3, text_input: 3, checkbox: 3]

  @moduledoc false

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp tmp_snapshot_path(name) do
    Path.join([
      System.tmp_dir!(),
      "julep_snapshot_test_#{System.unique_integer([:positive])}",
      name
    ])
  end

  defp simple_tree do
    %{
      id: "main",
      type: "window",
      props: %{"title" => "Test App"},
      children: [
        button("ok", "OK")
      ]
    }
  end

  defp nested_tree do
    %{
      id: "main",
      type: "window",
      props: %{"title" => "Counter"},
      children: [
        %{
          id: "col",
          type: "column",
          props: %{"padding" => 16, "spacing" => 8},
          children: [
            %{
              id: "label",
              type: "text",
              props: %{"content" => "Count: 42"},
              children: []
            },
            %{
              id: "controls",
              type: "row",
              props: %{"spacing" => 4},
              children: [
                button("increment", "+", style: :primary),
                button("decrement", "-"),
                text_input("search", "", placeholder: "Filter..."),
                checkbox("dark_mode", true, label: "Dark mode")
              ]
            }
          ]
        }
      ]
    }
  end

  setup do
    # Clean the env var before each test to prevent bleed-over
    System.delete_env("JULEP_UPDATE_SNAPSHOTS")
    :ok
  end

  # ---------------------------------------------------------------------------
  # 1. First run creates a snapshot file
  # ---------------------------------------------------------------------------

  describe "first run (no existing snapshot)" do
    test "creates the snapshot file and returns :ok" do
      path = tmp_snapshot_path("first_run.json")
      refute File.exists?(path)

      result = Julep.Test.assert_tree_snapshot(simple_tree(), path)

      assert result == :ok
      assert File.exists?(path)
    end

    test "creates parent directories if they don't exist" do
      path = tmp_snapshot_path("deeply/nested/dir/snap.json")
      refute File.exists?(Path.dirname(path))

      assert :ok = Julep.Test.assert_tree_snapshot(simple_tree(), path)
      assert File.exists?(path)
    end
  end

  # ---------------------------------------------------------------------------
  # 2. Matching snapshot passes
  # ---------------------------------------------------------------------------

  describe "matching snapshot" do
    test "returns :ok when tree matches stored snapshot" do
      path = tmp_snapshot_path("match.json")
      tree = simple_tree()

      # First run -- writes
      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
      # Second run -- compares
      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
    end

    test "passes on identical nested trees" do
      path = tmp_snapshot_path("match_nested.json")
      tree = nested_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
    end
  end

  # ---------------------------------------------------------------------------
  # 3. Mismatched snapshot fails with useful diff info
  # ---------------------------------------------------------------------------

  describe "mismatched snapshot" do
    test "raises ExUnit.AssertionError on mismatch" do
      path = tmp_snapshot_path("mismatch.json")
      original = simple_tree()
      changed = put_in(original, [:props, "title"], "Changed Title")

      # Write the original
      assert :ok = Julep.Test.assert_tree_snapshot(original, path)

      # Compare with the changed tree -- should blow up
      error =
        assert_raise ExUnit.AssertionError, fn ->
          Julep.Test.assert_tree_snapshot(changed, path)
        end

      assert error.message =~ "Snapshot mismatch"
      assert error.message =~ path
      assert error.message =~ "JULEP_UPDATE_SNAPSHOTS=1"
    end

    test "error message includes both stored and current representations" do
      path = tmp_snapshot_path("mismatch_diff.json")
      original = simple_tree()
      changed = put_in(original, [:props, "title"], "New Title")

      assert :ok = Julep.Test.assert_tree_snapshot(original, path)

      error =
        assert_raise ExUnit.AssertionError, fn ->
          Julep.Test.assert_tree_snapshot(changed, path)
        end

      assert error.message =~ "Expected (stored):"
      assert error.message =~ "Got (current):"
      # The stored version should contain the original title
      assert error.message =~ "Test App"
      # The current version should contain the new title
      assert error.message =~ "New Title"
    end
  end

  # ---------------------------------------------------------------------------
  # 4. JULEP_UPDATE_SNAPSHOTS=1 overwrites existing snapshots
  # ---------------------------------------------------------------------------

  describe "JULEP_UPDATE_SNAPSHOTS=1" do
    test "overwrites an existing snapshot instead of failing" do
      path = tmp_snapshot_path("update.json")
      original = simple_tree()
      changed = put_in(original, [:props, "title"], "Updated Title")

      # Write original
      assert :ok = Julep.Test.assert_tree_snapshot(original, path)
      original_contents = File.read!(path)

      # Enable update mode
      System.put_env("JULEP_UPDATE_SNAPSHOTS", "1")

      # Should not raise -- should overwrite
      assert :ok = Julep.Test.assert_tree_snapshot(changed, path)

      updated_contents = File.read!(path)
      refute original_contents == updated_contents
      assert updated_contents =~ "Updated Title"
    end

    test "subsequent comparison without update mode passes against new snapshot" do
      path = tmp_snapshot_path("update_then_compare.json")
      original = simple_tree()
      changed = put_in(original, [:props, "title"], "V2 Title")

      # Write original
      assert :ok = Julep.Test.assert_tree_snapshot(original, path)

      # Overwrite
      System.put_env("JULEP_UPDATE_SNAPSHOTS", "1")
      assert :ok = Julep.Test.assert_tree_snapshot(changed, path)

      # Now compare without update mode
      System.delete_env("JULEP_UPDATE_SNAPSHOTS")
      assert :ok = Julep.Test.assert_tree_snapshot(changed, path)
    end

    test "does not overwrite when env var is set to something other than 1" do
      path = tmp_snapshot_path("update_not_1.json")
      original = simple_tree()
      changed = put_in(original, [:props, "title"], "Nope")

      assert :ok = Julep.Test.assert_tree_snapshot(original, path)

      System.put_env("JULEP_UPDATE_SNAPSHOTS", "yes")

      assert_raise ExUnit.AssertionError, fn ->
        Julep.Test.assert_tree_snapshot(changed, path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 5. Nested tree structures snapshot correctly
  # ---------------------------------------------------------------------------

  describe "nested tree snapshots" do
    test "deeply nested tree round-trips through snapshot" do
      path = tmp_snapshot_path("nested_roundtrip.json")
      tree = nested_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
    end

    test "nested tree snapshot preserves all node types and props" do
      path = tmp_snapshot_path("nested_contents.json")
      tree = nested_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)

      stored = File.read!(path)
      decoded = Jason.decode!(stored)

      # Verify root
      assert decoded["type"] == "window"
      assert decoded["id"] == "main"
      assert decoded["props"]["title"] == "Counter"

      # Verify column child
      [col] = decoded["children"]
      assert col["type"] == "column"
      assert col["props"]["padding"] == 16
      assert col["props"]["spacing"] == 8

      # Verify text and row inside column
      [label, row] = col["children"]
      assert label["type"] == "text"
      assert label["props"]["content"] == "Count: 42"
      assert row["type"] == "row"

      # Verify buttons inside row
      [inc, dec, search, dark] = row["children"]
      assert inc["id"] == "increment"
      assert inc["props"]["label"] == "+"
      assert inc["props"]["style"] == "primary"
      assert dec["id"] == "decrement"
      assert dec["props"]["label"] == "-"
      assert search["type"] == "text_input"
      assert search["props"]["placeholder"] == "Filter..."
      assert dark["type"] == "checkbox"
      assert dark["props"]["label"] == "Dark mode"
    end

    test "detects changes in deeply nested children" do
      path = tmp_snapshot_path("nested_change.json")
      tree = nested_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)

      # Mutate a deeply nested label
      changed =
        update_in(tree, [:children, Access.at(0), :children, Access.at(0), :props], fn props ->
          Map.put(props, "content", "Count: 99")
        end)

      assert_raise ExUnit.AssertionError, fn ->
        Julep.Test.assert_tree_snapshot(changed, path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 6. Snapshot files are valid JSON with sorted keys
  # ---------------------------------------------------------------------------

  describe "snapshot file format" do
    test "output is valid JSON" do
      path = tmp_snapshot_path("valid_json.json")
      tree = simple_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
      contents = File.read!(path)

      # Should parse without error
      assert {:ok, _decoded} = Jason.decode(contents)
    end

    test "output is pretty-printed (contains newlines and indentation)" do
      path = tmp_snapshot_path("pretty.json")

      assert :ok = Julep.Test.assert_tree_snapshot(simple_tree(), path)
      contents = File.read!(path)

      assert String.contains?(contents, "\n")
      assert String.contains?(contents, "  ")
    end

    test "output is deterministic across multiple writes" do
      path_a = tmp_snapshot_path("deterministic_a.json")
      path_b = tmp_snapshot_path("deterministic_b.json")
      tree = nested_tree()

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path_a)
      assert :ok = Julep.Test.assert_tree_snapshot(tree, path_b)

      assert File.read!(path_a) == File.read!(path_b)
    end

    test "keys are sorted inside props maps too" do
      path = tmp_snapshot_path("sorted_props.json")

      # Build a tree with multiple props to verify ordering
      tree = %{
        id: "test",
        type: "widget",
        props: %{"zebra" => 1, "alpha" => 2, "middle" => 3},
        children: []
      }

      assert :ok = Julep.Test.assert_tree_snapshot(tree, path)
      contents = File.read!(path)

      # The props object should have keys in order: alpha, middle, zebra
      assert contents =~ ~r/"alpha".*"middle".*"zebra"/s
    end

    test "atom keys are converted to strings in JSON output" do
      path = tmp_snapshot_path("atom_keys.json")

      assert :ok = Julep.Test.assert_tree_snapshot(simple_tree(), path)
      contents = File.read!(path)
      decoded = Jason.decode!(contents)

      # All keys should be strings (JSON standard), not atoms
      assert is_binary(hd(Map.keys(decoded)))
      assert Map.has_key?(decoded, "id")
      assert Map.has_key?(decoded, "type")
      assert Map.has_key?(decoded, "props")
      assert Map.has_key?(decoded, "children")
    end
  end
end
