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
  end

  describe "cast/1" do
    test "preserves custom theme maps" do
      theme = %{name: "custom", cursor_color: "#ffffff"}

      assert Theme.cast(theme) == {:ok, theme}
    end

    test "preserves built-in theme casting" do
      assert Theme.cast(:dark) == {:ok, :dark}
      assert Theme.cast(:system) == {:ok, :system}
      assert Theme.cast(:bogus) == :error
    end
  end
end
