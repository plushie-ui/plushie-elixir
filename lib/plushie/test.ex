defmodule Plushie.Test do
  @moduledoc """
  Test helpers for Plushie applications.

  ## Setup

  Call `Plushie.Test.setup!()` in your `test/test_helper.exs` before
  `ExUnit.start()`:

      # test/test_helper.exs
      Plushie.Test.setup!()
      ExUnit.start()

  This starts the shared renderer session pool and configures ExUnit
  to exclude tests tagged for backends not currently active.

  ### Backend selection

  Set `PLUSHIE_TEST_BACKEND` to choose the backend:

      mix test                                    # mock (default)
      PLUSHIE_TEST_BACKEND=headless mix test       # headless rendering
      PLUSHIE_TEST_BACKEND=windowed mix test       # real windows

  ### Backend-specific tests

  Tag tests with the **minimum backend** they require:

      @tag backend: :headless   # runs in headless + windowed, skipped in mock
      test "renders correctly" do ... end

      @tag backend: :windowed   # runs only in windowed
      test "screenshot matches" do ... end

  Backend capability is hierarchical: mock < headless < windowed.
  Tag with the lowest backend that provides what the test needs.
  Untagged tests run in all modes.

  ## Tree snapshot testing

      test "initial view snapshot" do
        model = MyApp.init([])
        tree = MyApp.view(model)
        Plushie.Test.assert_tree_snapshot(tree, "test/snapshots/initial_view.json")
      end

  On first run, `assert_tree_snapshot/2` writes the snapshot file. On subsequent
  runs, it compares against the stored snapshot. Update snapshots with:

      PLUSHIE_UPDATE_SNAPSHOTS=1 mix test
  """

  @doc """
  Sets up the Plushie test infrastructure.

  Call this from your `test/test_helper.exs` before `ExUnit.start()`.
  Starts the shared renderer session pool and configures backend-based
  test exclusions.

  Returns the ExUnit exclusion options -- pass them to `ExUnit.start/1`:

      # test/test_helper.exs
      plushie_opts = Plushie.Test.setup!()
      ExUnit.start(plushie_opts)
  """
  @spec setup!(opts :: keyword()) :: keyword()
  def setup!(opts \\ []) do
    binary = Plushie.Binary.path!()
    Application.put_env(:plushie, :test_binary_path, binary)

    test_backend =
      case System.get_env("PLUSHIE_TEST_BACKEND") do
        "headless" -> :headless
        "windowed" -> :windowed
        _ -> :mock
      end

    Application.put_env(:plushie, :test_backend, test_backend)

    pool_name = Keyword.get(opts, :pool_name, Plushie.TestPool)
    max_sessions = Keyword.get(opts, :max_sessions, max(System.schedulers_online() * 8, 128))

    {:ok, _} =
      Plushie.Test.SessionPool.start_link(
        name: pool_name,
        renderer: binary,
        mode: test_backend,
        max_sessions: max_sessions
      )

    # Exclude tests tagged for backends more capable than the current one.
    # Backend capability: mock < headless < windowed.
    excludes =
      case test_backend do
        :mock -> [backend: :headless, backend: :windowed]
        :headless -> [backend: :windowed]
        :windowed -> []
      end

    [exclude: excludes]
  end

  @doc """
  Asserts that `tree` matches the stored structural snapshot at `path`.

  On first run (file does not exist), writes the snapshot.
  On subsequent runs, compares and fails with a diff if different.
  Set `PLUSHIE_UPDATE_SNAPSHOTS=1` to overwrite existing snapshots.
  """
  @spec assert_tree_snapshot(tree :: map(), path :: String.t()) :: :ok
  def assert_tree_snapshot(tree, path) do
    normalized = normalize_for_tree_snapshot(tree)
    current_json = Jason.encode!(normalized, pretty: true)

    update_mode = System.get_env("PLUSHIE_UPDATE_SNAPSHOTS") == "1"

    if File.exists?(path) and not update_mode do
      stored_json = File.read!(path)

      if current_json != stored_json do
        raise ExUnit.AssertionError,
          message:
            "Snapshot mismatch at #{path}.\n\n" <>
              "Expected (stored):\n#{String.slice(stored_json, 0, 500)}\n\n" <>
              "Got (current):\n#{String.slice(current_json, 0, 500)}\n\n" <>
              "Run with PLUSHIE_UPDATE_SNAPSHOTS=1 to update."
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
