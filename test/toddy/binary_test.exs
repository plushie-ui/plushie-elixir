defmodule Toddy.BinaryTest do
  use ExUnit.Case, async: false

  alias Toddy.Binary

  # ---------------------------------------------------------------------------
  # download_name/0
  # ---------------------------------------------------------------------------

  describe "download_name/0" do
    test "returns a string" do
      assert is_binary(Binary.download_name())
    end

    test "starts with 'toddy-'" do
      assert String.starts_with?(Binary.download_name(), "toddy-")
    end

    test "includes an OS component" do
      name = Binary.download_name()
      # On this linux test host, the OS segment should be "linux"
      assert String.contains?(name, "linux") or
               String.contains?(name, "darwin") or
               String.contains?(name, "windows")
    end

    test "includes an architecture component" do
      name = Binary.download_name()

      assert String.contains?(name, "x86_64") or
               String.contains?(name, "aarch64") or
               String.contains?(name, "arm") or
               String.contains?(name, "unknown")
    end

    test "does not end with .exe on non-windows" do
      refute String.ends_with?(Binary.download_name(), ".exe")
    end
  end

  # ---------------------------------------------------------------------------
  # path!/0 -- env var override
  # ---------------------------------------------------------------------------

  describe "path!/0 with TODDY_BINARY_PATH set" do
    setup do
      tmp_dir = System.tmp_dir!()
      fake_bin = Path.join(tmp_dir, "toddy_fake_#{System.unique_integer([:positive])}")
      File.write!(fake_bin, "#!/bin/sh\n")
      File.chmod!(fake_bin, 0o755)

      previous = System.get_env("TODDY_BINARY_PATH")
      System.put_env("TODDY_BINARY_PATH", fake_bin)

      on_exit(fn ->
        if previous,
          do: System.put_env("TODDY_BINARY_PATH", previous),
          else: System.delete_env("TODDY_BINARY_PATH")

        File.rm(fake_bin)
      end)

      %{fake_bin: fake_bin}
    end

    test "returns the env var path", %{fake_bin: fake_bin} do
      assert Binary.path!() == fake_bin
    end
  end

  describe "path!/0 with TODDY_BINARY_PATH pointing to missing file" do
    setup do
      previous = System.get_env("TODDY_BINARY_PATH")
      System.put_env("TODDY_BINARY_PATH", "/tmp/nonexistent_toddy_binary")

      on_exit(fn ->
        if previous,
          do: System.put_env("TODDY_BINARY_PATH", previous),
          else: System.delete_env("TODDY_BINARY_PATH")
      end)
    end

    test "raises with a helpful message" do
      assert_raise RuntimeError,
                   ~r/TODDY_BINARY_PATH is set to .* but the file does not exist/,
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
end
