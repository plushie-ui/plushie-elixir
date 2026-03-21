defmodule Plushie.Widget.StackTest do
  use ExUnit.Case, async: true

  alias Plushie.Widget.Stack

  describe "clip/2" do
    test "sets the clip field" do
      stack = Stack.new("s1") |> Stack.clip(true)
      assert stack.clip == true
    end

    test "defaults to nil" do
      stack = Stack.new("s1")
      assert stack.clip == nil
    end
  end

  describe "build/1 with clip" do
    test "includes clip in props when set" do
      node = Stack.new("s1") |> Stack.clip(true) |> Stack.build()
      assert node.props[:clip] == true
    end

    test "omits clip from props when nil" do
      node = Stack.new("s1") |> Stack.build()
      refute Map.has_key?(node.props, "clip")
    end

    test "includes clip false in props" do
      node = Stack.new("s1") |> Stack.clip(false) |> Stack.build()
      assert node.props[:clip] == false
    end
  end

  describe "with_options/2 clip" do
    test "handles clip option" do
      stack = Stack.new("s1", clip: true)
      assert stack.clip == true
    end
  end
end
