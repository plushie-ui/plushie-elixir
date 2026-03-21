defmodule Plushie.UndoTest do
  use ExUnit.Case, async: true

  alias Plushie.Undo

  # Helper: a simple increment/decrement command pair.
  defp inc_cmd(opts \\ []) do
    Map.merge(
      %{apply: &(&1 + 1), undo: &(&1 - 1)},
      Map.new(opts)
    )
  end

  defp add_cmd(n, opts \\ []) do
    Map.merge(
      %{apply: &(&1 + n), undo: &(&1 - n)},
      Map.new(opts)
    )
  end

  # Sets the fake timestamp used by the Undo module's timestamp/0 seam.
  defp set_time(ms), do: Process.put(:plushie_undo_timestamp, ms)

  setup do
    # Clean up the process dictionary seam after each test.
    on_exit(fn -> Process.delete(:plushie_undo_timestamp) end)
  end

  describe "new/1" do
    test "creates an undo stack with the given initial model" do
      u = Undo.new(%{text: ""})
      assert Undo.current(u) == %{text: ""}
    end

    test "starts with empty undo and redo stacks" do
      u = Undo.new(0)
      refute Undo.can_undo?(u)
      refute Undo.can_redo?(u)
    end
  end

  describe "apply/2" do
    test "applies the command and updates current" do
      u = Undo.new(0) |> Undo.apply(inc_cmd())
      assert Undo.current(u) == 1
    end

    test "pushes onto the undo stack" do
      u = Undo.new(0) |> Undo.apply(inc_cmd())
      assert Undo.can_undo?(u)
    end

    test "clears the redo stack" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd())
        |> Undo.apply(inc_cmd())
        |> Undo.undo()

      assert Undo.can_redo?(u)

      # Applying a new command should clear redo.
      u = Undo.apply(u, add_cmd(10))
      refute Undo.can_redo?(u)
    end

    test "multiple applies accumulate on the undo stack" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd(label: "first"))
        |> Undo.apply(inc_cmd(label: "second"))
        |> Undo.apply(inc_cmd(label: "third"))

      assert Undo.current(u) == 3
      assert Undo.history(u) == ["third", "second", "first"]
    end
  end

  describe "undo/1" do
    test "reverses the last command" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd())
        |> Undo.undo()

      assert Undo.current(u) == 0
    end

    test "on empty stack returns unchanged" do
      u = Undo.new(42)
      assert Undo.undo(u) == u
    end

    test "moves entry to the redo stack" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd())
        |> Undo.undo()

      assert Undo.can_redo?(u)
      refute Undo.can_undo?(u)
    end

    test "multiple undos walk back in order" do
      u =
        Undo.new(0)
        |> Undo.apply(add_cmd(1))
        |> Undo.apply(add_cmd(10))
        |> Undo.apply(add_cmd(100))

      assert Undo.current(u) == 111

      u = Undo.undo(u)
      assert Undo.current(u) == 11

      u = Undo.undo(u)
      assert Undo.current(u) == 1

      u = Undo.undo(u)
      assert Undo.current(u) == 0

      # Further undo is a no-op.
      u = Undo.undo(u)
      assert Undo.current(u) == 0
    end
  end

  describe "redo/1" do
    test "re-applies after undo" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd())
        |> Undo.undo()
        |> Undo.redo()

      assert Undo.current(u) == 1
    end

    test "on empty stack returns unchanged" do
      u = Undo.new(42)
      assert Undo.redo(u) == u
    end

    test "multiple redo after multiple undo" do
      u =
        Undo.new(0)
        |> Undo.apply(add_cmd(1))
        |> Undo.apply(add_cmd(10))
        |> Undo.apply(add_cmd(100))
        |> Undo.undo()
        |> Undo.undo()
        |> Undo.undo()

      assert Undo.current(u) == 0

      u = Undo.redo(u)
      assert Undo.current(u) == 1

      u = Undo.redo(u)
      assert Undo.current(u) == 11

      u = Undo.redo(u)
      assert Undo.current(u) == 111

      # Further redo is a no-op.
      u = Undo.redo(u)
      assert Undo.current(u) == 111
    end
  end

  describe "undo/redo cycles" do
    test "interleaved undo and redo" do
      u =
        Undo.new(0)
        |> Undo.apply(add_cmd(1))
        |> Undo.apply(add_cmd(10))

      assert Undo.current(u) == 11

      u = Undo.undo(u)
      assert Undo.current(u) == 1

      u = Undo.redo(u)
      assert Undo.current(u) == 11

      u = Undo.undo(u)
      u = Undo.undo(u)
      assert Undo.current(u) == 0

      u = Undo.redo(u)
      assert Undo.current(u) == 1
    end

    test "applying after undo forks history (redo lost)" do
      u =
        Undo.new(0)
        |> Undo.apply(add_cmd(1))
        |> Undo.apply(add_cmd(10))
        |> Undo.undo()

      assert Undo.current(u) == 1

      u = Undo.apply(u, add_cmd(100))
      assert Undo.current(u) == 101
      refute Undo.can_redo?(u)

      # Only the original +1 and the new +100 are on the undo stack.
      u = Undo.undo(u)
      assert Undo.current(u) == 1

      u = Undo.undo(u)
      assert Undo.current(u) == 0
    end
  end

  describe "can_undo?/1 and can_redo?/1" do
    test "reflect stack state accurately" do
      u = Undo.new(0)
      refute Undo.can_undo?(u)
      refute Undo.can_redo?(u)

      u = Undo.apply(u, inc_cmd())
      assert Undo.can_undo?(u)
      refute Undo.can_redo?(u)

      u = Undo.undo(u)
      refute Undo.can_undo?(u)
      assert Undo.can_redo?(u)

      u = Undo.redo(u)
      assert Undo.can_undo?(u)
      refute Undo.can_redo?(u)
    end
  end

  describe "history/1" do
    test "returns labels in most-recent-first order" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd(label: "alpha"))
        |> Undo.apply(inc_cmd(label: "bravo"))
        |> Undo.apply(inc_cmd(label: "charlie"))

      assert Undo.history(u) == ["charlie", "bravo", "alpha"]
    end

    test "returns nil for commands without labels" do
      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd())
        |> Undo.apply(inc_cmd(label: "labelled"))

      assert Undo.history(u) == ["labelled", nil]
    end
  end

  describe "coalescing" do
    test "rapid applies with the same key merge into one undo entry" do
      set_time(1000)

      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      set_time(1100)
      u = Undo.apply(u, inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      set_time(1200)
      u = Undo.apply(u, inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      assert Undo.current(u) == 3

      # All three increments coalesced into a single undo entry.
      assert length(Undo.history(u)) == 1

      # One undo reverses all three.
      u = Undo.undo(u)
      assert Undo.current(u) == 0
    end

    test "coalesced entry can be redone" do
      set_time(1000)
      u = Undo.new(0) |> Undo.apply(inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      set_time(1100)
      u = Undo.apply(u, inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      u = Undo.undo(u)
      assert Undo.current(u) == 0

      u = Undo.redo(u)
      assert Undo.current(u) == 2
    end

    test "different coalesce keys do not merge" do
      set_time(1000)

      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      set_time(1100)
      u = Undo.apply(u, inc_cmd(coalesce: :formatting, coalesce_window_ms: 500))

      assert Undo.current(u) == 2
      assert length(Undo.history(u)) == 2
    end

    test "expired window does not merge" do
      set_time(1000)

      u =
        Undo.new(0)
        |> Undo.apply(inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      # Jump well past the 500ms window.
      set_time(2000)
      u = Undo.apply(u, inc_cmd(coalesce: :typing, coalesce_window_ms: 500))

      assert Undo.current(u) == 2
      assert length(Undo.history(u)) == 2
    end

    test "command without coalesce key never coalesces" do
      set_time(1000)
      u = Undo.new(0) |> Undo.apply(inc_cmd())

      set_time(1001)
      u = Undo.apply(u, inc_cmd())

      assert length(Undo.history(u)) == 2
    end
  end
end
