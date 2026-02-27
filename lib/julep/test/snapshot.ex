defmodule Julep.Test.Snapshot do
  @moduledoc """
  Pixel snapshot for visual regression testing.

  Captures RGBA pixel data from rendered backends (:headless, :full) and
  compares against golden files using SHA-256 hashes.

  ## Golden file workflow

  On first run, creates a `.sha256` file alongside the test. On subsequent
  runs, compares the current hash against the stored one. Set
  `JULEP_UPDATE_SNAPSHOTS=1` to force-update golden files.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hash: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          rgba_data: binary() | nil
        }

  defstruct [:name, :hash, :size, :rgba_data]

  @doc """
  Asserts that a snapshot matches its golden file.

  If no golden file exists, creates one (first run). If `JULEP_UPDATE_SNAPSHOTS=1`
  is set, updates the golden file. Otherwise, compares SHA-256 hashes and raises
  on mismatch.
  """
  @spec assert_match(snapshot :: t(), golden_dir :: String.t()) :: :ok
  def assert_match(%__MODULE__{} = snapshot, golden_dir) do
    File.mkdir_p!(golden_dir)
    golden_path = Path.join(golden_dir, "#{snapshot.name}.sha256")

    cond do
      System.get_env("JULEP_UPDATE_SNAPSHOTS") == "1" ->
        File.write!(golden_path, snapshot.hash)
        :ok

      not File.exists?(golden_path) ->
        File.write!(golden_path, snapshot.hash)
        :ok

      true ->
        expected = String.trim(File.read!(golden_path))

        if expected == snapshot.hash do
          :ok
        else
          raise ExUnit.AssertionError,
            message: """
            Snapshot mismatch for "#{snapshot.name}".

            Expected hash: #{expected}
            Actual hash:   #{snapshot.hash}

            Run with JULEP_UPDATE_SNAPSHOTS=1 to update the golden file.
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
