defmodule Mix.Tasks.Julep.Replay do
  @moduledoc """
  Replay a `.julep` script with real timing and windows.

      mix julep.replay path.julep

  Uses the `:windowed` backend, shows real windows, and respects `wait` timings.
  Useful for demos and debugging.
  """

  use Mix.Task

  @shortdoc "Replay a .julep script with real windows"

  @impl Mix.Task
  def run([path | _rest]) do
    Mix.Task.run("app.start")

    case Julep.Test.Script.parse_file(path) do
      {:ok, script} ->
        # Force windowed backend for replay
        script = put_in(script, [:header, :backend], :windowed)

        case Julep.Test.Script.Runner.run(script, replay: true) do
          :ok ->
            Mix.shell().info("Replay complete.")

          {:error, failures} ->
            for {_instruction, reason} <- failures do
              Mix.shell().error("FAIL: #{reason}")
            end

            System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Parse error: #{reason}")
        System.halt(1)
    end
  end

  def run([]) do
    Mix.shell().error("Usage: mix julep.replay path.julep")
    System.halt(1)
  end
end
