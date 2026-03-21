defmodule Plushie.Widget.TogglerTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Toggler

  describe "disabled/2" do
    test "sets the disabled field" do
      tg = Toggler.new("tg1", false) |> Toggler.disabled(true)
      assert tg.disabled == true
    end

    test "defaults to nil" do
      tg = Toggler.new("tg1", false)
      assert tg.disabled == nil
    end
  end

  describe "build/1 with disabled" do
    test "includes disabled in props when true" do
      node = Toggler.new("tg1", false) |> Toggler.disabled(true) |> Toggler.build()
      assert node.props[:disabled] == true
    end

    test "includes disabled false in props" do
      node = Toggler.new("tg1", false) |> Toggler.disabled(false) |> Toggler.build()
      assert node.props[:disabled] == false
    end

    test "omits disabled from props when nil" do
      node = Toggler.new("tg1", false) |> Toggler.build()
      refute Map.has_key?(node.props, "disabled")
    end
  end

  describe "with_options/2 disabled" do
    test "handles disabled option" do
      tg = Toggler.new("tg1", false, disabled: true)
      assert tg.disabled == true
    end
  end
end
