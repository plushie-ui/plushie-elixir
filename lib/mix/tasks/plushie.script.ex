defmodule Mix.Tasks.Plushie.Script do
  @moduledoc """
  Run `.plushie` automation files.

      mix plushie.script [paths]

  If no paths given, runs all `.plushie` files in `test/scripts/`.
  Artifacts like screenshots are written under `tmp/plushie_automation/`.
  """

  use Mix.Task

  @shortdoc "Run .plushie scripts"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    paths =
      case args do
        [] -> Path.wildcard("test/scripts/**/*.plushie")
        given -> given
      end

    if paths == [] do
      Mix.shell().info("No .plushie scripts found")
      System.halt(0)
    end

    results = Enum.map(paths, &run_script/1)

    failures = Enum.count(results, &(&1 == :error))
    passes = Enum.count(results, &(&1 == :ok))

    Mix.shell().info("\n#{passes} passed, #{failures} failed")

    if failures > 0 do
      System.halt(1)
    end
  end

  defp run_script(path) do
    Mix.shell().info("Running #{path}...")

    case Plushie.Automation.File.parse_file(path) do
      {:ok, script} ->
        case Plushie.Automation.Runner.run(script) do
          :ok ->
            Mix.shell().info("  PASS")
            :ok

          {:error, failures} ->
            for {_instruction, reason} <- failures do
              Mix.shell().error("  FAIL: #{reason}")
            end

            :error
        end

      {:error, reason} ->
        Mix.shell().error("  Parse error: #{reason}")
        :error
    end
  end
end
