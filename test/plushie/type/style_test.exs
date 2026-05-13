defmodule Plushie.Type.StyleTest do
  use ExUnit.Case, async: true

  alias Plushie.Type.{Style, StyleMap}

  describe "cast/1" do
    test "accepts built-in style atoms" do
      assert Style.cast(:default) == {:ok, :default}
      assert Style.cast(:primary) == {:ok, :primary}
      assert Style.cast(:rounded_box) == {:ok, :rounded_box}
    end

    test "accepts style maps" do
      style = StyleMap.new() |> StyleMap.background(:red)

      assert Style.cast(style) == {:ok, style}
    end

    test "casts plain maps through StyleMap" do
      assert {:ok, %StyleMap{background: "#ff0000"}} = Style.cast(%{background: :red})
    end

    test "rejects unknown styles" do
      assert Style.cast(:unknown) == :error
      assert Style.cast(%{background: :unknown}) == :error
    end
  end

  describe "decode/1" do
    test "decodes style atoms from wire strings" do
      assert Style.decode("primary") == {:ok, :primary}
    end
  end
end
