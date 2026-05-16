defmodule Mix.PlushieHelpersTest do
  use ExUnit.Case, async: false

  alias Mix.PlushieHelpers

  describe "resolve_cargo_plushie/0 with PLUSHIE_RUST_SOURCE_PATH set" do
    @describetag :tmp_dir

    setup %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "Cargo.toml"), "[workspace]\n")
      previous = System.get_env("PLUSHIE_RUST_SOURCE_PATH")
      System.put_env("PLUSHIE_RUST_SOURCE_PATH", tmp_dir)

      on_exit(fn ->
        if previous do
          System.put_env("PLUSHIE_RUST_SOURCE_PATH", previous)
        else
          System.delete_env("PLUSHIE_RUST_SOURCE_PATH")
        end
      end)

      :ok
    end

    test "returns cargo run args targeting the source checkout", %{tmp_dir: tmp_dir} do
      {cmd, args} = PlushieHelpers.resolve_cargo_plushie()

      assert cmd == "cargo"
      manifest = Path.join(Path.expand(tmp_dir), "Cargo.toml")

      assert args == [
               "run",
               "--manifest-path",
               manifest,
               "-p",
               "cargo-plushie",
               "--release",
               "--"
             ]
    end

    test "raises when source path has no Cargo.toml", %{tmp_dir: tmp_dir} do
      File.rm!(Path.join(tmp_dir, "Cargo.toml"))

      assert_raise Mix.Error, ~r/no Cargo.toml was found/, fn ->
        PlushieHelpers.resolve_cargo_plushie()
      end
    end
  end

  describe "resolve_cargo_plushie/0 without PLUSHIE_RUST_SOURCE_PATH" do
    setup do
      previous_source = System.get_env("PLUSHIE_RUST_SOURCE_PATH")
      System.delete_env("PLUSHIE_RUST_SOURCE_PATH")

      previous_config = Application.get_env(:plushie, :source_path)
      Application.delete_env(:plushie, :source_path)

      on_exit(fn ->
        if previous_source do
          System.put_env("PLUSHIE_RUST_SOURCE_PATH", previous_source)
        else
          System.delete_env("PLUSHIE_RUST_SOURCE_PATH")
        end

        if previous_config do
          Application.put_env(:plushie, :source_path, previous_config)
        else
          Application.delete_env(:plushie, :source_path)
        end

        :persistent_term.erase({PlushieHelpers, :cargo_plushie_version})
      end)

      :ok
    end

    test "returns bare cargo-plushie when installed version matches" do
      expected = Plushie.Binary.plushie_rust_version()
      :persistent_term.put({PlushieHelpers, :cargo_plushie_version}, {:ok, expected})

      assert {"cargo-plushie", []} == PlushieHelpers.resolve_cargo_plushie()
    end

    test "raises with install instruction when not installed" do
      :persistent_term.put({PlushieHelpers, :cargo_plushie_version}, :error)

      error =
        assert_raise Mix.Error, fn ->
          PlushieHelpers.resolve_cargo_plushie()
        end

      assert error.message =~ "cargo-plushie is not installed"
      assert error.message =~ "cargo install cargo-plushie --version"
      assert error.message =~ Plushie.Binary.plushie_rust_version()
      assert error.message =~ "--locked"
    end

    test "raises with mismatch message when version does not match" do
      :persistent_term.put({PlushieHelpers, :cargo_plushie_version}, {:ok, "0.0.1"})

      error =
        assert_raise Mix.Error, fn ->
          PlushieHelpers.resolve_cargo_plushie()
        end

      assert error.message =~ "version mismatch"
      assert error.message =~ "installed 0.0.1"
      assert error.message =~ "expected #{Plushie.Binary.plushie_rust_version()}"
    end
  end

  describe "source_path/0" do
    setup do
      previous_source = System.get_env("PLUSHIE_RUST_SOURCE_PATH")
      previous_config = Application.get_env(:plushie, :source_path)
      System.delete_env("PLUSHIE_RUST_SOURCE_PATH")
      Application.delete_env(:plushie, :source_path)

      on_exit(fn ->
        if previous_source do
          System.put_env("PLUSHIE_RUST_SOURCE_PATH", previous_source)
        else
          System.delete_env("PLUSHIE_RUST_SOURCE_PATH")
        end

        if previous_config do
          Application.put_env(:plushie, :source_path, previous_config)
        else
          Application.delete_env(:plushie, :source_path)
        end
      end)

      :ok
    end

    test "returns nil when nothing is set" do
      assert PlushieHelpers.source_path() == nil
    end

    test "returns the env var when set to a path" do
      System.put_env("PLUSHIE_RUST_SOURCE_PATH", "/some/path")
      assert PlushieHelpers.source_path() == "/some/path"
    end

    test "returns nil when the env var is explicitly empty" do
      System.put_env("PLUSHIE_RUST_SOURCE_PATH", "")
      assert PlushieHelpers.source_path() == nil
    end

    test "falls back to application config when env var is unset" do
      Application.put_env(:plushie, :source_path, "/from/config")
      assert PlushieHelpers.source_path() == "/from/config"
    end

    test "empty env var suppresses application config fallback" do
      Application.put_env(:plushie, :source_path, "/from/config")
      System.put_env("PLUSHIE_RUST_SOURCE_PATH", "")
      assert PlushieHelpers.source_path() == nil
    end
  end

  describe "validate_module!/1" do
    test "raises a clear error for non-atom input" do
      assert_raise Mix.Error, ~r/Module name must be an atom/, fn ->
        PlushieHelpers.validate_module!("Counter")
      end
    end
  end

  describe "warn_if_not_gitignored/1" do
    setup do
      tmp_dir =
        Path.join(System.tmp_dir!(), "plushie-helpers-test-#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp_dir)
      previous_cwd = File.cwd!()
      File.cd!(tmp_dir)

      on_exit(fn ->
        File.cd!(previous_cwd)
        File.rm_rf!(tmp_dir)
      end)

      {:ok, tmp_dir: tmp_dir}
    end

    test "stays silent when not inside a git work tree" do
      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = PlushieHelpers.warn_if_not_gitignored("bin")
        end)

      assert output == ""
    end

    test "stays silent when the path is already gitignored" do
      git!(["init", "--quiet"])
      File.write!(".gitignore", "/bin/\n")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = PlushieHelpers.warn_if_not_gitignored("bin")
        end)

      assert output == ""
    end

    test "warns when inside a git work tree but the path is not gitignored" do
      git!(["init", "--quiet"])

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          assert :ok = PlushieHelpers.warn_if_not_gitignored("bin")
        end)

      assert output =~ "warning: bin/ is not in .gitignore."
      assert output =~ "/bin/"
    end
  end

  defp git!(args) do
    {_, 0} =
      System.cmd("git", args,
        stderr_to_stdout: true,
        env: [
          {"GIT_CONFIG_GLOBAL", "/dev/null"},
          {"GIT_CONFIG_SYSTEM", "/dev/null"}
        ]
      )
  end
end
