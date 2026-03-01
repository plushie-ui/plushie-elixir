defmodule Julep.Test.ScreenshotTest do
  use ExUnit.Case, async: true

  alias Julep.Test.Screenshot

  defmodule TestApp do
    @behaviour Julep.App

    def init(_opts), do: %{count: 0}
    def update(model, _event), do: model

    def view(_model),
      do: %{id: "main", type: "window", props: %{"title" => "Test"}, children: []}
  end

  describe "sim backend screenshot" do
    test "returns empty stub" do
      {:ok, pid} = Julep.Test.Backend.Sim.start(TestApp)

      screenshot = Julep.Test.Backend.Sim.screenshot(pid, "test_shot")

      assert %Screenshot{} = screenshot
      assert screenshot.hash == ""
      assert screenshot.size == {0, 0}
      assert screenshot.rgba_data == nil

      Julep.Test.Backend.Sim.stop(pid)
    end
  end

  describe "assert_match/2" do
    test "with empty hash is a no-op" do
      screenshot = %Screenshot{hash: "", name: "test", size: {0, 0}, rgba_data: nil}
      golden_dir = "/tmp/julep_screenshot_noop_#{System.unique_integer([:positive])}"

      assert :ok = Screenshot.assert_match(screenshot, golden_dir)

      # No golden file should have been created
      refute File.exists?(golden_dir)
    end

    test "with non-empty hash creates and checks golden file" do
      tmp_dir =
        Path.join(
          System.tmp_dir!(),
          "julep_screenshot_test_#{System.unique_integer([:positive])}"
        )

      on_exit(fn -> File.rm_rf!(tmp_dir) end)

      hash_a = "deadbeef1234567890abcdef"
      hash_b = "cafebabe0987654321fedcba"

      screenshot_a = %Screenshot{hash: hash_a, name: "shot", size: {100, 100}, rgba_data: nil}
      screenshot_b = %Screenshot{hash: hash_b, name: "shot", size: {100, 100}, rgba_data: nil}
      golden_path = Path.join(tmp_dir, "shot.sha256")

      # First call creates the golden file
      assert :ok = Screenshot.assert_match(screenshot_a, tmp_dir)
      assert File.exists?(golden_path)
      assert File.read!(golden_path) == hash_a

      # Same hash passes
      assert :ok = Screenshot.assert_match(screenshot_a, tmp_dir)

      # Different hash raises
      assert_raise ExUnit.AssertionError, ~r/Screenshot mismatch/, fn ->
        Screenshot.assert_match(screenshot_b, tmp_dir)
      end
    end
  end
end
