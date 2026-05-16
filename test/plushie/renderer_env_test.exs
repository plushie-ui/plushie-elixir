defmodule Plushie.RendererEnvTest do
  use ExUnit.Case, async: true

  alias Plushie.RendererEnv

  describe "whitelisted?/1" do
    test "exact entries from the canonical list are allowed" do
      assert RendererEnv.whitelisted?("DISPLAY")
      assert RendererEnv.whitelisted?("PATH")
      assert RendererEnv.whitelisted?("HOME")
      assert RendererEnv.whitelisted?("RUST_LOG")
      assert RendererEnv.whitelisted?("WGPU_BACKEND")
      assert RendererEnv.whitelisted?("XDG_RUNTIME_DIR")
    end

    test "prefix entries from the canonical list are allowed" do
      assert RendererEnv.whitelisted?("LC_ALL")
      assert RendererEnv.whitelisted?("MESA_GL_VERSION_OVERRIDE")
      assert RendererEnv.whitelisted?("VK_ICD_FILENAMES")
      assert RendererEnv.whitelisted?("FONTCONFIG_PATH")
      assert RendererEnv.whitelisted?("AT_SPI_BUS_ADDRESS")
    end

    test "PLUSHIE_NO_CATCH_UNWIND is allowed" do
      assert RendererEnv.whitelisted?("PLUSHIE_NO_CATCH_UNWIND")
    end

    test "other PLUSHIE_* names are rejected (closed list, not prefix)" do
      # Host-side, launcher-set, or secrets that must not leak to the renderer.
      refute RendererEnv.whitelisted?("PLUSHIE_TOKEN")
      refute RendererEnv.whitelisted?("PLUSHIE_SOCKET")
      refute RendererEnv.whitelisted?("PLUSHIE_TRANSPORT")
      refute RendererEnv.whitelisted?("PLUSHIE_FORMAT")
      refute RendererEnv.whitelisted?("PLUSHIE_RUST_SOURCE_PATH")
      refute RendererEnv.whitelisted?("PLUSHIE_BINARY_PATH")
      refute RendererEnv.whitelisted?("PLUSHIE_PACKAGE_DIR")
      refute RendererEnv.whitelisted?("PLUSHIE_PACKAGE_READY_FILE")
      refute RendererEnv.whitelisted?("PLUSHIE_RELEASE_BASE_URL")
      refute RendererEnv.whitelisted?("PLUSHIE_CACHE_DIR")
    end

    test "secrets and unrelated vars are rejected" do
      refute RendererEnv.whitelisted?("AWS_ACCESS_KEY_ID")
      refute RendererEnv.whitelisted?("GITHUB_TOKEN")
      refute RendererEnv.whitelisted?("DATABASE_URL")
      refute RendererEnv.whitelisted?("SECRET_KEY_BASE")
      refute RendererEnv.whitelisted?("SSH_AUTH_SOCK")
    end
  end

  describe "build/1" do
    test "forwards whitelisted parent vars and unsets the rest" do
      System.put_env("AWS_ACCESS_KEY_ID", "should-not-leak")
      System.put_env("PLUSHIE_NO_CATCH_UNWIND", "1")

      try do
        env = RendererEnv.build()

        # PLUSHIE_NO_CATCH_UNWIND is the one renderer-read toggle: forwarded.
        assert {~c"PLUSHIE_NO_CATCH_UNWIND", ~c"1"} in env

        # Non-whitelisted vars get unset via {name, false}.
        assert {~c"AWS_ACCESS_KEY_ID", false} in env
      after
        System.delete_env("AWS_ACCESS_KEY_ID")
        System.delete_env("PLUSHIE_NO_CATCH_UNWIND")
      end
    end

    test "other PLUSHIE_* vars are unset in the child env" do
      System.put_env("PLUSHIE_TOKEN", "secret")
      System.put_env("PLUSHIE_BINARY_PATH", "/some/path")

      try do
        env = RendererEnv.build()

        assert {~c"PLUSHIE_TOKEN", false} in env
        assert {~c"PLUSHIE_BINARY_PATH", false} in env
      after
        System.delete_env("PLUSHIE_TOKEN")
        System.delete_env("PLUSHIE_BINARY_PATH")
      end
    end
  end
end
