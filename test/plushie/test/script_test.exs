defmodule Plushie.Automation.FileTest do
  use ExUnit.Case, async: true

  defmodule ScriptHeaderApp do
    use Plushie.App

    def init(opts) do
      %{script: Keyword.fetch!(opts, :script)}
    end

    def update(model, _event), do: model

    def view(model) do
      %{theme: theme, viewport: {width, height}} = model.script

      %{
        id: "main",
        type: "window",
        props: %{},
        children: [
          %{
            id: "root",
            type: "column",
            props: %{},
            children: [
              %{id: "theme", type: "text", props: %{content: "Theme: #{theme}"}, children: []},
              %{
                id: "viewport",
                type: "text",
                props: %{content: "Viewport: #{width}x#{height}"},
                children: []
              }
            ]
          }
        ]
      }
    end
  end

  alias Plushie.Automation.File
  alias Plushie.Automation.Runner

  describe "parse/1" do
    test "parses a valid script with header and instructions" do
      input = """
      app: Counter
      viewport: 1024x768
      theme: light
      backend: mock
      -----
      click "#increment"
      expect "Count: 1"
      """

      assert {:ok, script} = File.parse(input)
      assert script.header.app == Counter
      assert script.header.viewport == {1024, 768}
      assert script.header.theme == "light"
      assert script.header.backend == :mock
      assert length(script.instructions) == 2
      assert {:click, "#increment"} = hd(script.instructions)
    end

    test "uses defaults for missing optional header fields" do
      input = """
      app: Counter
      -----
      click "#btn"
      """

      assert {:ok, script} = File.parse(input)
      assert script.header.viewport == {800, 600}
      assert script.header.theme == "dark"
      assert script.header.backend == :mock
    end

    test "returns error for missing app field" do
      input = """
      viewport: 800x600
      -----
      click "#btn"
      """

      assert {:error, msg} = File.parse(input)
      assert msg =~ "app"
    end

    test "returns error for missing separator" do
      input = """
      app: Counter
      click "#increment"
      """

      assert {:error, msg} = File.parse(input)
      assert msg =~ "separator"
    end

    test "parses all instruction types" do
      input = """
      app: Counter
      -----
      click "#btn"
      type "#input" "hello world"
      type enter
      expect "some text"
      assert_text "#label" "Count: 0"
      wait 500
      """

      assert {:ok, script} = File.parse(input)
      instructions = script.instructions

      assert {:click, "#btn"} = Enum.at(instructions, 0)
      assert {:type_text, "#input", "hello world"} = Enum.at(instructions, 1)
      assert {:type_key, "enter"} = Enum.at(instructions, 2)
      assert {:expect, "some text"} = Enum.at(instructions, 3)
      assert {:assert_text, "#label", "Count: 0"} = Enum.at(instructions, 4)
      assert {:wait, 500} = Enum.at(instructions, 5)
    end

    test "ignores comments and blank lines" do
      input = """
      app: Counter
      # this is a header comment
      -----
      # this is a body comment

      click "#btn"

      # another comment
      expect "done"
      """

      assert {:ok, script} = File.parse(input)
      assert length(script.instructions) == 2
    end

    test "handles quoted strings in instructions" do
      input = """
      app: Counter
      -----
      type "#search" "hello world with spaces"
      assert_text "#label" "Count: 42"
      """

      assert {:ok, script} = File.parse(input)
      assert {:type_text, "#search", "hello world with spaces"} = hd(script.instructions)
      assert {:assert_text, "#label", "Count: 42"} = Enum.at(script.instructions, 1)
    end

    test "returns error for unknown instruction" do
      input = """
      app: Counter
      -----
      flurble "#wat"
      """

      assert {:error, msg} = File.parse(input)
      assert msg =~ "unknown instruction"
    end

    test "parses screenshot instruction" do
      input = """
      app: Test
      -----
      screenshot "home-screen"
      """

      assert {:ok, script} = File.parse(input)
      assert script.instructions == [{:screenshot, "home-screen"}]
    end

    test "parses headless and windowed backend values" do
      for {backend_str, expected} <- [{"headless", :headless}, {"windowed", :windowed}] do
        input = """
        app: Counter
        backend: #{backend_str}
        -----
        click "#btn"
        """

        assert {:ok, script} = File.parse(input)
        assert script.header.backend == expected
      end
    end
  end

  describe "run/2" do
    test "starts a temporary app instance and executes a simple script" do
      script = %{
        header: %{app: Counter, viewport: {800, 600}, theme: "dark", backend: :mock},
        instructions: [
          {:click, "#increment"},
          {:assert_text, "#count", "Count: 1"}
        ]
      }

      assert :ok = Runner.run(script)
    end

    test "forwards the parsed script header to app init" do
      script = %{
        header: %{app: ScriptHeaderApp, viewport: {1024, 768}, theme: "light", backend: :mock},
        instructions: [
          {:assert_text, "#theme", "Theme: light"},
          {:assert_text, "#viewport", "Viewport: 1024x768"}
        ]
      }

      assert :ok = Runner.run(script)
    end
  end
end
