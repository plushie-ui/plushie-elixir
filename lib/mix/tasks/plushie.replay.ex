defmodule Mix.Tasks.Plushie.Replay do
  @moduledoc """
  Replay a `.plushie` automation file with real timing and windows.

      mix plushie.replay path.plushie

  Uses the `:windowed` backend, shows real windows, respects `wait` timings,
  and writes captures under `tmp/plushie_automation/`.
  """

  use Mix.Task

  @shortdoc "Replay a .plushie script with real windows"

  @impl Mix.Task
  def run([path | _rest]) do
    Mix.Task.run("app.start")

    case Plushie.Automation.File.parse_file(path) do
      {:ok, script} ->
        # Force windowed backend for replay
        script = put_in(script, [:header, :backend], :windowed)

        case Plushie.Automation.Runner.run(script, replay: true) do
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
    Mix.shell().error("Usage: mix plushie.replay path.plushie")
    System.halt(1)
  end
end
