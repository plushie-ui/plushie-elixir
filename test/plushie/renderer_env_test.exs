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

    test "PLUSHIE_* prefix is allowed" do
      assert RendererEnv.whitelisted?("PLUSHIE_NO_CATCH_UNWIND")
      assert RendererEnv.whitelisted?("PLUSHIE_DEBUG_SOMETHING")
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
      System.put_env("PLUSHIE_SMOKE_TEST", "ok")

      try do
        env = RendererEnv.build()

        # Whitelisted PLUSHIE_* var forwarded.
        assert {~c"PLUSHIE_SMOKE_TEST", ~c"ok"} in env

        # Non-whitelisted vars get unset via {name, false}.
        assert {~c"AWS_ACCESS_KEY_ID", false} in env
      after
        System.delete_env("AWS_ACCESS_KEY_ID")
        System.delete_env("PLUSHIE_SMOKE_TEST")
      end
    end
  end
end
