defmodule Toddy.Widget.CheckboxTest do
  use ExUnit.Case, async: true

  alias Toddy.Widget.Checkbox

  describe "disabled/2" do
    test "sets the disabled field" do
      cb = Checkbox.new("cb1", "Accept", false) |> Checkbox.disabled(true)
      assert cb.disabled == true
    end

    test "defaults to nil" do
      cb = Checkbox.new("cb1", "Accept", false)
      assert cb.disabled == nil
    end
  end

  describe "build/1 with disabled" do
    test "includes disabled in props when true" do
      node = Checkbox.new("cb1", "Accept", false) |> Checkbox.disabled(true) |> Checkbox.build()
      assert node.props["disabled"] == true
    end

    test "includes disabled false in props" do
      node = Checkbox.new("cb1", "Accept", false) |> Checkbox.disabled(false) |> Checkbox.build()
      assert node.props["disabled"] == false
    end

    test "omits disabled from props when nil" do
      node = Checkbox.new("cb1", "Accept", false) |> Checkbox.build()
      refute Map.has_key?(node.props, "disabled")
    end
  end

  describe "with_options/2 disabled" do
    test "handles disabled option" do
      cb = Checkbox.new("cb1", "Accept", false, disabled: true)
      assert cb.disabled == true
    end
  end
end
