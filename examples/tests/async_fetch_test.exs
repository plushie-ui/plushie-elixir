defmodule Examples.AsyncFetchTest do
  @moduledoc "Integration tests for the AsyncFetch example using the test DSL."

  use Plushie.Test.Case, app: AsyncFetch

  test "starts in idle state" do
    assert model().status == :idle
    assert model().result == nil
  end

  test "fetch button exists" do
    assert_exists("#fetch")
  end

  test "displays idle status message" do
    assert_text("#status", "Press the button to start")
  end

  test "clicking fetch triggers async work" do
    click("#fetch")
    # The mock backend executes async commands synchronously, so the
    # status may already be :done by the time we inspect the model.
    assert model().status in [:loading, :done]
  end

  test "async fetch produces a result" do
    click("#fetch")
    await_async(:fetch_result)
    assert model().status == :done
    assert is_binary(model().result)
  end
end
