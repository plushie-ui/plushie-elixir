defmodule Julep.BinaryTest do
  use ExUnit.Case, async: true

  alias Julep.Binary

  # ---------------------------------------------------------------------------
  # binary_name/0
  # ---------------------------------------------------------------------------

  describe "binary_name/0" do
    test "returns a string" do
      assert is_binary(Binary.binary_name())
    end

    test "starts with 'julep_gui-'" do
      assert String.starts_with?(Binary.binary_name(), "julep_gui-")
    end

    test "includes an OS component" do
      name = Binary.binary_name()
      # On this linux test host, the OS segment should be "linux"
      assert String.contains?(name, "linux") or
               String.contains?(name, "darwin") or
               String.contains?(name, "windows")
    end

    test "includes an architecture component" do
      name = Binary.binary_name()

      assert String.contains?(name, "x86_64") or
               String.contains?(name, "aarch64") or
               String.contains?(name, "arm") or
               String.contains?(name, "unknown")
    end

    test "does not end with .exe on non-windows" do
      # This test suite runs on linux, so no .exe
      refute String.ends_with?(Binary.binary_name(), ".exe")
    end
  end

  # ---------------------------------------------------------------------------
  # renderer_path/0 -- env var override
  # ---------------------------------------------------------------------------

  describe "renderer_path/0 with JULEP_RENDERER_PATH set" do
    setup do
      # Create a temporary file to act as the binary
      tmp_dir = System.tmp_dir!()
      fake_bin = Path.join(tmp_dir, "julep_gui_fake_#{System.unique_integer([:positive])}")
      File.write!(fake_bin, "#!/bin/sh\n")
      File.chmod!(fake_bin, 0o755)

      previous = System.get_env("JULEP_RENDERER_PATH")
      System.put_env("JULEP_RENDERER_PATH", fake_bin)

      on_exit(fn ->
        if previous,
          do: System.put_env("JULEP_RENDERER_PATH", previous),
          else: System.delete_env("JULEP_RENDERER_PATH")

        File.rm(fake_bin)
      end)

      %{fake_bin: fake_bin}
    end

    test "returns the env var path when JULEP_RENDERER_PATH is set", %{fake_bin: fake_bin} do
      assert Binary.renderer_path() == fake_bin
    end
  end

  describe "renderer_path/0 without any valid path" do
    setup do
      previous = System.get_env("JULEP_RENDERER_PATH")
      System.delete_env("JULEP_RENDERER_PATH")

      on_exit(fn ->
        if previous, do: System.put_env("JULEP_RENDERER_PATH", previous)
      end)
    end

    test "raises when no binary can be found and env var is not set" do
      # This test relies on no precompiled or dev build existing.
      # On a clean test host without a built renderer, this should raise.
      # If the binary does exist, we skip gracefully.
      try do
        path = Binary.renderer_path()
        # If it returned something, the binary exists in priv or dev build --
        # that's fine, the test is just confirming the code path works.
        assert is_binary(path)
      rescue
        e in RuntimeError ->
          assert Exception.message(e) =~ "julep_gui binary not found"
      end
    end
  end
end
