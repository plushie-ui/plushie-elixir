defmodule Examples.ShortcutsTest do
  @moduledoc "Integration tests for the Shortcuts example using the test DSL."

  use Plushie.Test.Case, app: Shortcuts

  test "starts with empty log and zero count" do
    assert model().log == []
    assert model().count == 0
  end

  test "header text is present" do
    assert_text("#header", "Press any key")
  end

  test "count label displays zero events initially" do
    assert_text("#count", "0 key events captured")
  end

  test "scrollable log container exists" do
    assert_exists("#log")
  end
end
