defmodule Plushie.Test.Screenshot do
  @moduledoc """
  Test helpers for screenshot golden-file assertions.
  """

  alias Plushie.Automation.Screenshot

  defdelegate from_response(msg, format \\ :msgpack, backend \\ nil), to: Screenshot
  defdelegate save_png(screenshot, path), to: Screenshot

  @type t :: Screenshot.t()

  @spec assert_match(
          screenshot :: Screenshot.t(),
          golden_dir :: String.t(),
          opts :: keyword()
        ) :: :ok
  def assert_match(screenshot, golden_dir, opts \\ [])
  def assert_match(%Screenshot{hash: ""}, _golden_dir, _opts), do: :ok

  def assert_match(%Screenshot{} = screenshot, golden_dir, opts) do
    File.mkdir_p!(golden_dir)
    suffix = if screenshot.backend, do: ".#{screenshot.backend}", else: ""
    golden_path = Path.join(golden_dir, "#{screenshot.name}#{suffix}.sha256")

    if Keyword.get(opts, :png, true) && screenshot.rgba_data do
      save_png(screenshot, Path.join(golden_dir, "#{screenshot.name}#{suffix}.png"))
    end

    cond do
      System.get_env("PLUSHIE_UPDATE_SCREENSHOTS") == "1" ->
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

            Run with PLUSHIE_UPDATE_SCREENSHOTS=1 to update the golden file.
            Golden file: #{golden_path}
            """
        end
    end
  end
end
