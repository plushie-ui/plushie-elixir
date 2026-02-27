defmodule Julep.Test.Screenshot do
  @moduledoc """
  Pixel screenshot for visual regression testing.

  Captures RGBA pixel data from the :full backend and compares against
  golden files using SHA-256 hashes. No-op on :sim and :headless backends
  (returns an empty hash, which assert_match silently accepts).

  ## Golden file workflow

  On first run, creates a `.sha256` file in `test/screenshots/`. On subsequent
  runs, compares the current hash against the stored one. Set
  `JULEP_UPDATE_SCREENSHOTS=1` to force-update golden files.

  Screenshots with an empty hash (from sim/headless backends) are silently
  accepted -- no golden file is created or compared.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          hash: String.t(),
          size: {non_neg_integer(), non_neg_integer()},
          rgba_data: binary() | nil
        }

  defstruct [:name, :hash, :size, :rgba_data]

  @doc """
  Asserts that a screenshot matches its golden file.

  Screenshots with an empty hash (from sim/headless backends) are silently
  accepted. Otherwise, creates or compares golden files in `golden_dir`.
  Set `JULEP_UPDATE_SCREENSHOTS=1` to force-update golden files.
  """
  @spec assert_match(screenshot :: t(), golden_dir :: String.t()) :: :ok
  def assert_match(%__MODULE__{hash: ""}, _golden_dir), do: :ok

  def assert_match(%__MODULE__{} = screenshot, golden_dir) do
    File.mkdir_p!(golden_dir)
    golden_path = Path.join(golden_dir, "#{screenshot.name}.sha256")

    cond do
      System.get_env("JULEP_UPDATE_SCREENSHOTS") == "1" ->
        File.write!(golden_path, screenshot.hash)
        :ok

      not File.exists?(golden_path) ->
        File.write!(golden_path, screenshot.hash)
        :ok

      true ->
        expected = String.trim(File.read!(golden_path))

        if expected == screenshot.hash do
          :ok
        else
          raise ExUnit.AssertionError,
            message: """
            Screenshot mismatch for "#{screenshot.name}".

            Expected hash: #{expected}
            Actual hash:   #{screenshot.hash}

            Run with JULEP_UPDATE_SCREENSHOTS=1 to update the golden file.
            Golden file: #{golden_path}
            """
        end
    end
  end
end
