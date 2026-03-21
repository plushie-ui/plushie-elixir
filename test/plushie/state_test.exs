defmodule Plushie.StateTest do
  use ExUnit.Case, async: true

  alias Plushie.State

  @sample_data %{
    user: %{
      name: "Arthur Dent",
      prefs: %{theme: "dark", font_size: 14},
      tags: ["mostly_harmless"]
    },
    counter: 0
  }

  describe "new/1" do
    test "creates state with data and revision 0" do
      state = State.new(@sample_data)

      assert state.data == @sample_data
      assert state.revision == 0
      assert state.transaction == nil
    end
  end

  describe "get/2" do
    test "reads nested paths" do
      state = State.new(@sample_data)

      assert State.get(state, [:user, :name]) == "Arthur Dent"
      assert State.get(state, [:user, :prefs, :theme]) == "dark"
    end

    test "returns nil for missing paths" do
      state = State.new(@sample_data)

      assert State.get(state, [:nonexistent]) == nil
      assert State.get(state, [:user, :email]) == nil
      assert State.get(state, [:user, :prefs, :missing, :deep]) == nil
    end

    test "empty path returns the root data" do
      state = State.new(@sample_data)

      assert State.get(state, []) == @sample_data
    end

    test "deep nesting beyond 3 levels" do
      deep = %{a: %{b: %{c: %{d: %{e: "deep_value"}}}}}
      state = State.new(deep)

      assert State.get(state, [:a, :b, :c, :d, :e]) == "deep_value"
    end
  end

  describe "put/3" do
    test "sets nested values and increments revision" do
      state =
        State.new(@sample_data)
        |> State.put([:user, :name], "Ford Prefect")

      assert State.get(state, [:user, :name]) == "Ford Prefect"
      assert state.revision == 1
    end

    test "increments revision on each put" do
      state =
        State.new(@sample_data)
        |> State.put([:counter], 1)
        |> State.put([:counter], 2)
        |> State.put([:counter], 3)

      assert State.get(state, [:counter]) == 3
      assert state.revision == 3
    end

    test "sets deeply nested values" do
      state = State.new(@sample_data)
      state = State.put(state, [:user, :prefs, :font_size], 18)

      assert State.get(state, [:user, :prefs, :font_size]) == 18
      # Other values untouched
      assert State.get(state, [:user, :prefs, :theme]) == "dark"
    end
  end

  describe "update/3" do
    test "applies function to nested value and increments revision" do
      state =
        State.new(@sample_data)
        |> State.update([:counter], &(&1 + 42))

      assert State.get(state, [:counter]) == 42
      assert state.revision == 1
    end

    test "works with deeply nested paths" do
      state =
        State.new(@sample_data)
        |> State.update([:user, :prefs, :font_size], &(&1 * 2))

      assert State.get(state, [:user, :prefs, :font_size]) == 28
    end
  end

  describe "revision/1" do
    test "returns current revision" do
      state = State.new(@sample_data)
      assert State.revision(state) == 0

      state = State.put(state, [:counter], 1)
      assert State.revision(state) == 1
    end
  end

  describe "transactions" do
    test "begin_transaction snapshots current state" do
      state =
        State.new(@sample_data)
        |> State.begin_transaction()

      assert state.transaction == %{data: @sample_data, revision: 0}
    end

    test "put during transaction increments revision normally" do
      state =
        State.new(@sample_data)
        |> State.begin_transaction()
        |> State.put([:counter], 1)
        |> State.put([:counter], 2)

      assert state.revision == 2
      assert State.get(state, [:counter]) == 2
    end

    test "commit_transaction collapses revisions to snapshot.revision + 1" do
      state =
        State.new(@sample_data)
        |> State.put([:counter], 1)

      assert state.revision == 1

      state =
        state
        |> State.begin_transaction()
        |> State.put([:counter], 2)
        |> State.put([:counter], 3)
        |> State.put([:counter], 4)

      # During transaction, revision incremented to 4
      assert state.revision == 4

      state = State.commit_transaction(state)

      # Collapsed to snapshot revision (1) + 1
      assert state.revision == 2
      assert state.transaction == nil
      # Data kept from transaction
      assert State.get(state, [:counter]) == 4
    end

    test "rollback_transaction restores data and revision" do
      state =
        State.new(@sample_data)
        |> State.put([:counter], 10)

      assert state.revision == 1

      state =
        state
        |> State.begin_transaction()
        |> State.put([:counter], 999)
        |> State.put([:user, :name], "Zaphod")

      assert State.get(state, [:counter]) == 999

      state = State.rollback_transaction(state)

      assert State.get(state, [:counter]) == 10
      assert State.get(state, [:user, :name]) == "Arthur Dent"
      assert state.revision == 1
      assert state.transaction == nil
    end

    test "nested transactions not supported - returns error on active transaction" do
      state =
        State.new(@sample_data)
        |> State.begin_transaction()

      assert State.begin_transaction(state) == {:error, :transaction_already_active}
    end
  end
end
