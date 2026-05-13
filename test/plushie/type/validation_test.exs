defmodule Plushie.Type.ValidationTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Validation

  describe "cast/1" do
    test "accepts valid and pending atoms" do
      assert Validation.cast(:valid) == {:ok, :valid}
      assert Validation.cast(:pending) == {:ok, :pending}
    end

    test "normalizes invalid tuples to renderer map shape" do
      assert Validation.cast({:invalid, "Required"}) ==
               {:ok, %{state: :invalid, message: "Required"}}
    end

    test "accepts invalid maps" do
      assert Validation.cast(%{state: "invalid", message: "Required"}) ==
               {:ok, %{state: :invalid, message: "Required"}}
    end

    test "rejects malformed states" do
      assert Validation.cast(:unknown) == :error
      assert Validation.cast({:invalid, 123}) == :error
      assert Validation.cast(%{state: :invalid}) == :error
    end
  end
end
