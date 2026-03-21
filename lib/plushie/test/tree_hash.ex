defmodule Plushie.Test.TreeHash do
  @moduledoc """
  Structural tree hash for regression testing.

  Captures a SHA-256 hash of the serialized UI tree structure and compares
  against golden files. Works on all backends (:pooled_mock, :headless, :windowed).

  ## Golden file workflow

  On first run, creates a `.sha256` file alongside the test. On subsequent
  runs, compares the current hash against the stored one. Set
  `PLUSHIE_UPDATE_SNAPSHOTS=1` to force-update golden files.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hash: String.t(),
          backend: atom() | nil
        }

  defstruct [:name, :hash, :backend]

  @doc """
  Asserts that a tree hash matches its golden file.

  If no golden file exists, creates one (first run). If `PLUSHIE_UPDATE_SNAPSHOTS=1`
  is set, updates the golden file. Otherwise, compares SHA-256 hashes and raises
  on mismatch.
  """
  @spec assert_match(tree_hash :: t(), golden_dir :: String.t()) :: :ok
  def assert_match(%__MODULE__{} = tree_hash, golden_dir) do
    File.mkdir_p!(golden_dir)
    suffix = if tree_hash.backend, do: ".#{tree_hash.backend}", else: ""
    golden_path = Path.join(golden_dir, "#{tree_hash.name}#{suffix}.sha256")

    cond do
      System.get_env("PLUSHIE_UPDATE_SNAPSHOTS") == "1" ->
        File.write!(golden_path, tree_hash.hash)
        :ok

      not File.exists?(golden_path) ->
        File.write!(golden_path, tree_hash.hash)
        :ok

      true ->
        expected = String.trim(File.read!(golden_path))

        if expected == tree_hash.hash do
          :ok
        else
          raise ExUnit.AssertionError,
            message: """
            Tree hash mismatch for "#{tree_hash.name}".

            Expected hash: #{expected}
            Actual hash:   #{tree_hash.hash}

            Run with PLUSHIE_UPDATE_SNAPSHOTS=1 to update the golden file.
            Golden file: #{golden_path}
            """
        end
    end
  end

  @doc "Computes a SHA-256 hash of the given binary data."
  @spec hash(data :: binary()) :: String.t()
  def hash(data) when is_binary(data) do
    :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
  end
end
