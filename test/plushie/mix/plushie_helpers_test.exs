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

  describe "validate_module!/1" do
    test "raises a clear error for non-atom input" do
      assert_raise Mix.Error, ~r/Module name must be an atom/, fn ->
        PlushieHelpers.validate_module!("Counter")
      end
    end
  end
end
