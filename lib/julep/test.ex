defmodule Julep.Test do
  @moduledoc """
  Test helpers for Julep applications.

  ## Snapshot testing

      test "initial view snapshot" do
        model = MyApp.init([])
        tree = MyApp.view(model)
        Julep.Test.assert_snapshot(tree, "test/snapshots/initial_view.json")
      end

  On first run, `assert_snapshot/2` writes the snapshot file. On subsequent
  runs, it compares against the stored snapshot. Update snapshots with:

      JULEP_UPDATE_SNAPSHOTS=1 mix test
  """

  @doc """
  Asserts that `tree` matches the stored snapshot at `path`.

  On first run (file does not exist), writes the snapshot.
  On subsequent runs, compares and fails with a diff if different.
  Set `JULEP_UPDATE_SNAPSHOTS=1` to overwrite existing snapshots.
  """
  @spec assert_snapshot(tree :: map(), path :: String.t()) :: :ok
  def assert_snapshot(tree, path) do
    normalized = normalize_for_snapshot(tree)
    current_json = Jason.encode!(normalized, pretty: true)

    update_mode = System.get_env("JULEP_UPDATE_SNAPSHOTS") == "1"

    if File.exists?(path) and not update_mode do
      stored_json = File.read!(path)

      if current_json != stored_json do
        raise ExUnit.AssertionError,
          message:
            "Snapshot mismatch at #{path}.\n\n" <>
              "Expected (stored):\n#{String.slice(stored_json, 0, 500)}\n\n" <>
              "Got (current):\n#{String.slice(current_json, 0, 500)}\n\n" <>
              "Run with JULEP_UPDATE_SNAPSHOTS=1 to update."
      end
    else
      path |> Path.dirname() |> File.mkdir_p!()
      File.write!(path, current_json)
    end

    :ok
  end

  # Normalize tree for stable JSON output: sort map keys recursively.
  defp normalize_for_snapshot(data) when is_map(data) do
    data
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> {k, normalize_for_snapshot(v)} end)
    |> Map.new()
  end

  defp normalize_for_snapshot(data) when is_list(data) do
    Enum.map(data, &normalize_for_snapshot/1)
  end

  defp normalize_for_snapshot(data), do: data
end
