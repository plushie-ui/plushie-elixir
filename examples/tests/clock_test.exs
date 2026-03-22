defmodule Examples.ClockTest do
  @moduledoc "Integration tests for the Clock example using the test DSL."

  use Plushie.Test.Case, app: Clock

  test "model contains a time string on init" do
    assert is_binary(model().time)
  end

  test "displays the time in the clock widget" do
    element = find!("#clock_display")
    assert text(element) != nil
  end

  test "subtitle text is present" do
    assert_text("#subtitle", "Updates every second")
  end
end
