defmodule Examples.CounterTest do
  @moduledoc "Integration tests for the Counter example using the test DSL."

  use Plushie.Test.Case, app: Counter

  test "starts with count of zero" do
    assert model().count == 0
  end

  test "displays initial count" do
    assert_text("#count", "Count: 0")
  end

  test "increment button increases count" do
    click("#inc")
    assert model().count == 1
    assert_text("#count", "Count: 1")
  end

  test "decrement button decreases count" do
    click("#dec")
    assert model().count == -1
    assert_text("#count", "Count: -1")
  end

  test "multiple clicks accumulate" do
    click("#inc")
    click("#inc")
    click("#inc")
    click("#dec")
    assert model().count == 2
    assert_text("#count", "Count: 2")
  end
end
