defmodule Plushie.Test.RuntimeBackendTest do
  use Plushie.Test.Case, app: Counter

  @moduletag backend: :runtime

  setup _context do
    # Override the default backend with the Runtime backend for this test.
    session =
      Plushie.Test.Session.start(Counter, backend: Plushie.Test.Backend.Runtime)

    Process.put(:plushie_test_session, session)

    on_exit(fn ->
      try do
        Plushie.Test.Session.stop(session)
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, session: session}
  end

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
      element = find!("#increment")
      assert element != nil
    end

    test "click dispatches through the real Runtime" do
      click("#increment")
      assert model().count == 1
    end

    test "multiple interactions work" do
      click("#increment")
      click("#increment")
      click("#decrement")
      assert model().count == 1
    end
  end
end
