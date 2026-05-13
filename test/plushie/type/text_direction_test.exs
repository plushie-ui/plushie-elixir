defmodule Plushie.Type.TextDirectionTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.TextDirection

  describe "cast/1" do
    test "accepts supported directions" do
      assert TextDirection.cast(:auto) == {:ok, :auto}
      assert TextDirection.cast(:ltr) == {:ok, :ltr}
      assert TextDirection.cast(:rtl) == {:ok, :rtl}
    end

    test "rejects unknown directions" do
      assert TextDirection.cast(:sideways) == :error
    end
  end
end
