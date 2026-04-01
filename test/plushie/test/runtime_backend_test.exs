defmodule Plushie.Test.RuntimeBackendTest do
  use Plushie.Test.Case, app: Counter

  @moduletag backend: :runtime

  describe "Runtime backend" do
    test "starts with initial model" do
      assert model().count == 0
    end

    test "model query returns the current model" do
      m = model()
      assert is_map(m)
      assert Map.has_key?(m, :count)
    end

    test "tree query returns the current tree" do
      t = tree()
      assert t != nil
      assert t.type == "window"
    end

    test "find locates elements by ID" do
      element = find!("#inc")
      assert element != nil
    end

    test "click dispatches through the real Runtime" do
      click("#inc")
      assert model().count == 1
    end

    test "multiple interactions work" do
      click("#inc")
      click("#inc")
      click("#dec")
      assert model().count == 1
    end
  end
end
