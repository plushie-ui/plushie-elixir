defmodule Mix.Tasks.Julep.Script do
  @moduledoc """
  Run `.julep` test scripts.

      mix julep.script [paths]

  If no paths given, runs all `.julep` files in `test/scripts/`.
  """

  use Mix.Task

  @shortdoc "Run .julep test scripts"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    paths =
      case args do
        [] -> Path.wildcard("test/scripts/**/*.julep")
        given -> given
      end

    if paths == [] do
      Mix.shell().info("No .julep scripts found")
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

    case Julep.Test.Script.parse_file(path) do
      {:ok, script} ->
        case Julep.Test.Script.Runner.run(script) do
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
