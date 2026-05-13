defmodule Plushie.Type.ThemeTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.Theme

  describe "custom/2" do
    test "accepts cursor and scrollbar colour tokens" do
      theme =
        Theme.custom("chrome",
          cursor_color: :white,
          scrollbar_color: "CornflowerBlue",
          scroller_color: "#FF00AA"
        )

      assert theme.cursor_color == "#ffffff"
      assert theme.scrollbar_color == "#6495ed"
      assert theme.scroller_color == "#ff00aa"
    end

    test "valid_custom_keys/0 includes cursor and scrollbar colour tokens" do
      keys = Theme.valid_custom_keys()

      assert MapSet.member?(keys, :cursor_color)
      assert MapSet.member?(keys, :scrollbar_color)
      assert MapSet.member?(keys, :scroller_color)
    end

    test "unknown keys still raise" do
      assert_raise ArgumentError, ~r/unknown key :scrollbar_width/, fn ->
        Theme.custom("chrome", scrollbar_width: 12)
      end
    end

    test "invalid colours raise validation errors" do
      assert_raise ArgumentError, ~r/invalid custom theme primary: :nope/, fn ->
        Theme.custom("bad", primary: :nope)
      end
    end

    test "invalid base raises a validation error" do
      assert_raise ArgumentError, ~r/invalid custom theme base: :bogus/, fn ->
        Theme.custom("bad", base: :bogus)
      end
    end
  end

  describe "cast/1" do
    test "casts custom theme maps" do
      theme = %{name: "custom", base: :dark, cursor_color: :white}

      assert Theme.cast(theme) == {:ok, %{name: "custom", base: "dark", cursor_color: "#ffffff"}}
    end

    test "preserves built-in theme casting" do
      assert Theme.cast(:dark) == {:ok, :dark}
      assert Theme.cast(:system) == {:ok, :system}
      assert Theme.cast(:bogus) == :error
    end

    test "rejects invalid custom theme maps" do
      assert Theme.cast(%{name: "custom", unknown: "#ffffff"}) == :error
      assert Theme.cast(%{name: "custom", primary: :nope}) == :error
      assert Theme.cast(%{name: :custom}) == :error
    end
  end
end
