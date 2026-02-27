defmodule Mix.Tasks.Julep.Preflight do
  @moduledoc """
  Runs all CI checks locally. Exits with a non-zero status on first failure.

  ## Usage

      mix preflight

  ## What it runs

  1. `mix format --check-formatted`
  2. `mix compile --warnings-as-errors`
  3. `mix test`
  4. `mix dialyzer`
  5. `cargo build` (renderer)
  6. `cargo test` (renderer)
  7. `cargo fmt -- --check` (renderer)
  8. `cargo clippy -- -D warnings` (renderer)
  """

  use Mix.Task

  @shortdoc "Run all CI checks locally"

  defp cargo_manifest do
    Path.join(File.cwd!(), "native/julep_gui/Cargo.toml")
  end

  @impl Mix.Task
  def run(_args) do
    steps = [
      {"mix format --check-formatted", fn -> mix_format() end},
      {"mix compile --warnings-as-errors", fn -> mix_compile() end},
      {"mix test", fn -> mix_test() end},
      {"mix dialyzer", fn -> mix_dialyzer() end},
      {"cargo build", fn -> cargo(["build"]) end},
      {"cargo test", fn -> cargo(["test"]) end},
      {"cargo fmt --check", fn -> cargo_fmt() end},
      {"cargo clippy -D warnings", fn -> cargo_clippy() end}
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

  defp mix_format do
    case cmd("mix", ["format", "--check-formatted"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp mix_compile do
    case Mix.Task.run("compile", ["--warnings-as-errors"]) do
      {:error, _} -> {:error, 1}
      _ -> :ok
    end
  end

  defp mix_dialyzer do
    case cmd("mix", ["dialyzer"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp mix_test do
    case cmd("mix", ["test"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo(args) do
    case cmd("cargo", args ++ ["--manifest-path", cargo_manifest()]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo_fmt do
    case cmd("cargo", ["fmt", "--manifest-path", cargo_manifest(), "--", "--check"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cargo_clippy do
    case cmd("cargo", ["clippy", "--manifest-path", cargo_manifest(), "--", "-D", "warnings"]) do
      0 -> :ok
      code -> {:error, code}
    end
  end

  defp cmd(command, args) do
    {_, code} =
      System.cmd(command, args,
        stderr_to_stdout: true,
        into: IO.stream(:stdio, :line)
      )

    code
  end
end
