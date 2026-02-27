defmodule Julep.Test.ScriptTest do
  use ExUnit.Case, async: true

  alias Julep.Test.Script

  describe "parse/1" do
    test "parses a valid script with header and instructions" do
      input = """
      app: Julep.Examples.Counter
      viewport: 1024x768
      theme: light
      backend: sim
      -----
      click "#increment"
      expect "Count: 1"
      """

      assert {:ok, script} = Script.parse(input)
      assert script.header.app == Julep.Examples.Counter
      assert script.header.viewport == {1024, 768}
      assert script.header.theme == "light"
      assert script.header.backend == :sim
      assert length(script.instructions) == 2
      assert {:click, "#increment"} = hd(script.instructions)
    end

    test "uses defaults for missing optional header fields" do
      input = """
      app: Julep.Examples.Counter
      -----
      click "#btn"
      """

      assert {:ok, script} = Script.parse(input)
      assert script.header.viewport == {800, 600}
      assert script.header.theme == "dark"
      assert script.header.backend == :sim
    end

    test "returns error for missing app field" do
      input = """
      viewport: 800x600
      -----
      click "#btn"
      """

      assert {:error, msg} = Script.parse(input)
      assert msg =~ "app"
    end

    test "returns error for missing separator" do
      input = """
      app: Julep.Examples.Counter
      click "#increment"
      """

      assert {:error, msg} = Script.parse(input)
      assert msg =~ "separator"
    end

    test "parses all instruction types" do
      input = """
      app: Julep.Examples.Counter
      -----
      click "#btn"
      type "#input" "hello world"
      type enter
      expect "some text"
      snapshot "my-snap"
      assert_text "#label" "Count: 0"
      wait 500
      """

      assert {:ok, script} = Script.parse(input)
      instructions = script.instructions

      assert {:click, "#btn"} = Enum.at(instructions, 0)
      assert {:type_text, "#input", "hello world"} = Enum.at(instructions, 1)
      assert {:type_key, "enter"} = Enum.at(instructions, 2)
      assert {:expect, "some text"} = Enum.at(instructions, 3)
      assert {:snapshot, "my-snap"} = Enum.at(instructions, 4)
      assert {:assert_text, "#label", "Count: 0"} = Enum.at(instructions, 5)
      assert {:wait, 500} = Enum.at(instructions, 6)
    end

    test "ignores comments and blank lines" do
      input = """
      app: Julep.Examples.Counter
      # this is a header comment
      -----
      # this is a body comment

      click "#btn"

      # another comment
      expect "done"
      """

      assert {:ok, script} = Script.parse(input)
      assert length(script.instructions) == 2
    end

    test "handles quoted strings in instructions" do
      input = """
      app: Julep.Examples.Counter
      -----
      type "#search" "hello world with spaces"
      assert_text "#label" "Count: 42"
      """

      assert {:ok, script} = Script.parse(input)
      assert {:type_text, "#search", "hello world with spaces"} = hd(script.instructions)
      assert {:assert_text, "#label", "Count: 42"} = Enum.at(script.instructions, 1)
    end

    test "returns error for unknown instruction" do
      input = """
      app: Julep.Examples.Counter
      -----
      flurble "#wat"
      """

      assert {:error, msg} = Script.parse(input)
      assert msg =~ "unknown instruction"
    end

    test "parses headless and full backend values" do
      for {backend_str, expected} <- [{"headless", :headless}, {"full", :full}] do
        input = """
        app: Julep.Examples.Counter
        backend: #{backend_str}
        -----
        click "#btn"
        """

        assert {:ok, script} = Script.parse(input)
        assert script.header.backend == expected
      end
    end
  end
end
