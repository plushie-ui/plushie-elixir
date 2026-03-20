defmodule Toddy.Test do
  @moduledoc """
  Test helpers for Toddy applications.

  ## Tree snapshot testing

      test "initial view snapshot" do
        model = MyApp.init([])
        tree = MyApp.view(model)
        Toddy.Test.assert_tree_snapshot(tree, "test/snapshots/initial_view.json")
      end

  On first run, `assert_tree_snapshot/2` writes the snapshot file. On subsequent
  runs, it compares against the stored snapshot. Update snapshots with:

      TODDY_UPDATE_SNAPSHOTS=1 mix test
  """

  @doc """
  Asserts that `tree` matches the stored structural snapshot at `path`.

  On first run (file does not exist), writes the snapshot.
  On subsequent runs, compares and fails with a diff if different.
  Set `TODDY_UPDATE_SNAPSHOTS=1` to overwrite existing snapshots.
  """
  @spec assert_tree_snapshot(tree :: map(), path :: String.t()) :: :ok
  def assert_tree_snapshot(tree, path) do
    normalized = normalize_for_tree_snapshot(tree)
    current_json = Jason.encode!(normalized, pretty: true)

    update_mode = System.get_env("TODDY_UPDATE_SNAPSHOTS") == "1"

    if File.exists?(path) and not update_mode do
      stored_json = File.read!(path)

      if current_json != stored_json do
        raise ExUnit.AssertionError,
          message:
            "Snapshot mismatch at #{path}.\n\n" <>
              "Expected (stored):\n#{String.slice(stored_json, 0, 500)}\n\n" <>
              "Got (current):\n#{String.slice(current_json, 0, 500)}\n\n" <>
              "Run with TODDY_UPDATE_SNAPSHOTS=1 to update."
      end
    else
      path |> Path.dirname() |> File.mkdir_p!()
      File.write!(path, current_json)
    end

    :ok
  end

  # Normalize tree for stable JSON output: stringify atom keys and sort
  # them so the JSON representation is deterministic across Erlang/OTP
  # versions (small atom-keyed maps use a different internal order than
  # string-keyed maps in some OTP releases).
  defp normalize_for_tree_snapshot(data) when is_map(data) do
    data
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {to_string(k), normalize_for_tree_snapshot(v)} end)
    |> Jason.OrderedObject.new()
  end

  defp normalize_for_tree_snapshot(data) when is_list(data) do
    Enum.map(data, &normalize_for_tree_snapshot/1)
  end

  defp normalize_for_tree_snapshot(data), do: data
end
