defmodule Mix.Tasks.Preflight do
  @moduledoc """
  Runs all CI checks locally. Exits with a non-zero status on first failure.

  ## Usage

      mix preflight

  ## What it runs

  1. `mix format --check-formatted`
  2. `mix compile --warnings-as-errors`
  3. `mix credo --strict`
  4. `mix test`
  5. `mix dialyzer`
  """

  use Mix.Task

  @shortdoc "Run all CI checks locally"

  @typep step_result :: :ok | {:error, pos_integer()}

  @impl Mix.Task
  def run(_args) do
    steps = [
      {"mix format --check-formatted", fn -> mix_cmd(["format", "--check-formatted"]) end},
      {"mix compile --warnings-as-errors", fn -> mix_compile() end},
      {"mix credo --strict", fn -> mix_cmd(["credo", "--strict"]) end},
      {"mix test", fn -> mix_cmd(["test"]) end},
      {"mix dialyzer", fn -> mix_cmd(["dialyzer"]) end}
    ]

    Enum.each(steps, fn {label, fun} ->
      Mix.shell().info([:cyan, "==> ", :reset, label])

      case fun.() do
        :ok ->
          Mix.shell().info([:green, "    PASS", :reset])

        {:error, code} ->
          Mix.shell().error("    FAIL (exit code #{code})")
          System.halt(code)
      end
    end)

    Mix.shell().info([:green, "\nAll checks passed.", :reset])
  end

  # -- Steps -------------------------------------------------------------------

  @spec mix_compile() :: step_result()
  defp mix_compile do
    case Mix.Task.run("compile", ["--warnings-as-errors"]) do
      {:error, _} -> {:error, 1}
      _ -> :ok
    end
  end

  @spec mix_cmd([String.t()]) :: step_result()
  defp mix_cmd(args), do: exit_code_to_result(stream_cmd("mix", args))

  # -- Subprocess streaming ----------------------------------------------------

  # Streams a subprocess to the terminal, returning its exit code.
  # Uses Port directly instead of System.cmd because some test output
  # can contain raw bytes (non-UTF-8). :file.write/2 bypasses encoding
  # validation.
  @spec stream_cmd(String.t(), [String.t()]) :: non_neg_integer()
  defp stream_cmd(command, args) do
    executable =
      System.find_executable(command) ||
        raise "#{command} not found in PATH"

    port_opts = [:binary, :exit_status, :stderr_to_stdout, {:args, args}]
    port = Port.open({:spawn_executable, executable}, port_opts)
    drain_port(port)
  end

  @spec drain_port(port()) :: non_neg_integer()
  defp drain_port(port) do
    receive do
      {^port, {:data, data}} ->
        :file.write(:standard_io, data)
        drain_port(port)

      {^port, {:exit_status, code}} ->
        code
    end
  end

  @spec exit_code_to_result(non_neg_integer()) :: step_result()
  defp exit_code_to_result(0), do: :ok
  defp exit_code_to_result(code), do: {:error, code}
end
