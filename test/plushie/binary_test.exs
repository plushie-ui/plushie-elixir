defmodule Plushie.BinaryTest do
  use ExUnit.Case, async: false

  alias Plushie.Binary

  describe "download_name/0" do
    test "returns a string" do
      assert is_binary(Binary.download_name())
    end

    test "uses the stable renderer name" do
      assert Binary.download_name() in ["plushie-renderer", "plushie-renderer.exe"]
    end
  end

  describe "release_name/0" do
    test "starts with 'plushie-'" do
      assert String.starts_with?(Binary.release_name(), "plushie-")
    end

    test "includes an OS component" do
      name = Binary.release_name()
      # On this linux test host, the OS segment should be "linux"
      assert String.contains?(name, "linux") or
               String.contains?(name, "darwin") or
               String.contains?(name, "windows")
    end

    test "includes an architecture component" do
      name = Binary.release_name()

      assert String.contains?(name, "x86_64") or
               String.contains?(name, "aarch64") or
               String.contains?(name, "unknown")
    end

    test "does not end with .exe on non-windows" do
      refute String.ends_with?(Binary.release_name(), ".exe")
    end
  end

  describe "path!/0 with PLUSHIE_BINARY_PATH set" do
    setup do
      tmp_dir = System.tmp_dir!()
      fake_bin = Path.join(tmp_dir, "plushie_fake_#{System.unique_integer([:positive])}")
      File.write!(fake_bin, "#!/bin/sh\n")
      File.chmod!(fake_bin, 0o755)

      previous = System.get_env("PLUSHIE_BINARY_PATH")
      System.put_env("PLUSHIE_BINARY_PATH", fake_bin)

      on_exit(fn ->
        if previous,
          do: System.put_env("PLUSHIE_BINARY_PATH", previous),
          else: System.delete_env("PLUSHIE_BINARY_PATH")

        File.rm(fake_bin)
      end)

      %{fake_bin: fake_bin}
    end

    test "returns the env var path", %{fake_bin: fake_bin} do
      assert Binary.path!() == fake_bin
    end
  end

  describe "path!/0 with PLUSHIE_BINARY_PATH pointing to missing file" do
    setup do
      previous = System.get_env("PLUSHIE_BINARY_PATH")
      System.put_env("PLUSHIE_BINARY_PATH", "/tmp/nonexistent_plushie_binary")

      on_exit(fn ->
        if previous,
          do: System.put_env("PLUSHIE_BINARY_PATH", previous),
          else: System.delete_env("PLUSHIE_BINARY_PATH")
      end)
    end

    test "raises with a helpful message" do
      assert_raise RuntimeError,
                   ~r/PLUSHIE_BINARY_PATH is set to .* but the file does not exist/,
                   fn ->
                     Binary.path!()
                   end
    end
  end

  describe "path!/0 returns a valid path" do
    test "resolved binary exists on disk" do
      path = Binary.path!()
      assert File.exists?(path)
    end
  end

  describe "plushie_rust_version/0" do
    test "returns a valid version string" do
      version = Binary.plushie_rust_version()
      assert is_binary(version)
      assert version =~ ~r/^\d+\.\d+\.\d+$/
    end
  end

  describe "build_name/0" do
    setup do
      previous = Application.get_env(:plushie, :build_name)
      Application.delete_env(:plushie, :build_name)

      on_exit(fn ->
        if previous do
          Application.put_env(:plushie, :build_name, previous)
        else
          Application.delete_env(:plushie, :build_name)
        end
      end)

      :ok
    end

    test "defaults to app-renderer suffix" do
      name = Binary.build_name()
      assert is_binary(name)
      assert String.ends_with?(name, "-renderer")
    end

    test "uses configured build name" do
      Application.put_env(:plushie, :build_name, "custom-renderer")

      assert Binary.build_name() == "custom-renderer"
    end

    test "rejects non-string build name config" do
      Application.put_env(:plushie, :build_name, :custom_renderer)

      assert_raise RuntimeError, ~r/:build_name must be a string/, fn ->
        Binary.build_name()
      end
    end

    test "falls back when no Mix project is running" do
      ebin = Application.app_dir(:plushie, "ebin")
      elixir = System.find_executable("elixir")

      assert {output, 0} =
               System.cmd(elixir, [
                 "-pa",
                 ebin,
                 "-e",
                 "IO.write(Plushie.Binary.build_name())"
               ])

      assert output == "app-renderer"
    end
  end
end
