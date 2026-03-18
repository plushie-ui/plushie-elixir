defmodule Julep.Test.SnapshotTest do
  use ExUnit.Case, async: false

  alias Julep.Test.Snapshot

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "julep_snapshot_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    {:ok, golden_dir: tmp_dir}
  end

  describe "hash/1" do
    test "computes consistent SHA-256 for same input" do
      data = "the larch"
      assert Snapshot.hash(data) == Snapshot.hash(data)
    end

    test "returns a 64-character lowercase hex string" do
      result = Snapshot.hash("ni!")
      assert String.length(result) == 64
      assert result == String.downcase(result)
      assert result =~ ~r/^[0-9a-f]{64}$/
    end

    test "different inputs produce different hashes" do
      refute Snapshot.hash("spam") == Snapshot.hash("eggs")
    end

    test "matches known SHA-256 for empty string" do
      # SHA-256 of "" is a well-known value
      expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
      assert Snapshot.hash("") == expected
    end
  end

  describe "assert_match/2" do
    test "creates golden file on first run", %{golden_dir: dir} do
      snap = %Snapshot{name: "first-run", hash: "abc123", size: {100, 100}}
      golden_path = Path.join(dir, "first-run.sha256")

      refute File.exists?(golden_path)
      assert :ok = Snapshot.assert_match(snap, dir)
      assert File.exists?(golden_path)
      assert File.read!(golden_path) == "abc123"
    end

    test "passes when hashes match", %{golden_dir: dir} do
      hash = Snapshot.hash("pixel data")
      File.write!(Path.join(dir, "matching.sha256"), hash)

      snap = %Snapshot{name: "matching", hash: hash, size: {10, 10}}
      assert :ok = Snapshot.assert_match(snap, dir)
    end

    test "raises when hashes differ", %{golden_dir: dir} do
      File.write!(Path.join(dir, "stale.sha256"), "old_hash")

      snap = %Snapshot{name: "stale", hash: "new_hash", size: {10, 10}}

      assert_raise ExUnit.AssertionError, ~r/Snapshot mismatch/, fn ->
        Snapshot.assert_match(snap, dir)
      end
    end

    test "updates golden file when JULEP_UPDATE_SNAPSHOTS=1", %{golden_dir: dir} do
      golden_path = Path.join(dir, "updatable.sha256")
      File.write!(golden_path, "old_hash")

      snap = %Snapshot{name: "updatable", hash: "new_hash", size: {10, 10}}

      # Set env, run, then clean up
      System.put_env("JULEP_UPDATE_SNAPSHOTS", "1")

      try do
        assert :ok = Snapshot.assert_match(snap, dir)
        assert File.read!(golden_path) == "new_hash"
      after
        System.delete_env("JULEP_UPDATE_SNAPSHOTS")
      end
    end

    test "uses backend-scoped golden file when backend is set", %{golden_dir: dir} do
      snap = %Snapshot{name: "scoped", hash: "mock_hash", size: {0, 0}, backend: :mock}
      golden_path = Path.join(dir, "scoped.mock.sha256")

      refute File.exists?(golden_path)
      assert :ok = Snapshot.assert_match(snap, dir)
      assert File.exists?(golden_path)
      assert File.read!(golden_path) == "mock_hash"

      # Different backend creates a separate golden file
      snap2 = %Snapshot{name: "scoped", hash: "headless_hash", size: {0, 0}, backend: :headless}
      headless_path = Path.join(dir, "scoped.headless.sha256")

      refute File.exists?(headless_path)
      assert :ok = Snapshot.assert_match(snap2, dir)
      assert File.exists?(headless_path)
      assert File.read!(headless_path) == "headless_hash"
    end

    test "nil backend uses unscoped golden file (backwards compat)", %{golden_dir: dir} do
      snap = %Snapshot{name: "legacy", hash: "legacy_hash", size: {0, 0}, backend: nil}
      golden_path = Path.join(dir, "legacy.sha256")

      assert :ok = Snapshot.assert_match(snap, dir)
      assert File.exists?(golden_path)
    end

    test "error message includes expected and actual hashes", %{golden_dir: dir} do
      File.write!(Path.join(dir, "details.sha256"), "expected_hash")

      snap = %Snapshot{name: "details", hash: "actual_hash", size: {10, 10}}

      error =
        assert_raise ExUnit.AssertionError, fn ->
          Snapshot.assert_match(snap, dir)
        end

      assert error.message =~ "expected_hash"
      assert error.message =~ "actual_hash"
      assert error.message =~ "JULEP_UPDATE_SNAPSHOTS=1"
    end
  end
end
