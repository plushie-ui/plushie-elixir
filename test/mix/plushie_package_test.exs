defmodule Mix.PlushiePackageTest do
  use ExUnit.Case, async: true

  test "normalizes package target" do
    assert Mix.PlushiePackage.normalize_package_target({:unix, :linux}, ~c"x86_64-pc-linux-gnu") ==
             "linux-x86_64"

    assert Mix.PlushiePackage.normalize_package_target({:unix, :darwin}, ~c"aarch64-apple-darwin") ==
             "darwin-aarch64"

    assert Mix.PlushiePackage.normalize_package_target({:win32, :nt}, ~c"amd64") ==
             "windows-x86_64"
  end

  test "accepts Windows package targets" do
    assert Mix.PlushiePackage.validate_package_target!("windows-x86_64") == "windows-x86_64"
    assert Mix.PlushiePackage.validate_package_target!("windows-aarch64") == "windows-aarch64"
  end

  test "start_host_wrapper_name returns .cmd for Windows targets" do
    assert Mix.PlushiePackage.start_host_wrapper_name("windows-x86_64") == "bin/start_host.cmd"
    assert Mix.PlushiePackage.start_host_wrapper_name("windows-aarch64") == "bin/start_host.cmd"
    assert Mix.PlushiePackage.start_host_wrapper_name("linux-x86_64") == "bin/start_host"
    assert Mix.PlushiePackage.start_host_wrapper_name("darwin-aarch64") == "bin/start_host"
  end

  test "writes POSIX start_host wrapper through Plushie.Connect.run" do
    dir = tmp_dir()
    path = Path.join(dir, "start_host")

    Mix.PlushiePackage.write_start_host_wrapper!(path, "notes", Notes.App)

    assert Bitwise.band(File.stat!(path).mode, 0o111) != 0

    assert File.read!(path) =~
             "case Plushie.Connect.run(Notes.App, []) do :ok -> :ok; {:error, reason} -> raise RuntimeError"
  end

  test "writes Windows start_host.cmd wrapper invoking the Mix release .bat entrypoint" do
    dir = tmp_dir()
    path = Path.join(dir, "start_host.cmd")

    Mix.PlushiePackage.write_start_host_wrapper!(path, "notes", Notes.App)

    content = File.read!(path)
    assert content =~ "@echo off"
    assert content =~ ~r/notes\\bin\\notes\.bat/
    assert content =~ "Plushie.Connect.run(Notes.App, [])"
  end

  test "default_start_config uses bin/start_host.cmd for Windows targets" do
    config = Mix.PlushiePackage.default_start_config("notes", "windows-x86_64")
    assert config.start_command == ["bin/start_host.cmd"]
  end

  test "default_start_config uses bin/start_host for non-Windows targets" do
    config = Mix.PlushiePackage.default_start_config("notes", "linux-x86_64")
    assert config.start_command == ["bin/start_host"]

    config = Mix.PlushiePackage.default_start_config("notes")
    assert config.start_command == ["bin/start_host"]
  end

  test "writes partial manifest with SDK and protocol metadata" do
    manifest = %{
      app_id: "dev.plushie.test",
      app_name: "Test App",
      app_version: "0.1.0",
      target: "linux-x86_64",
      host_sdk_version: "0.7.2",
      plushie_rust_version: "0.7.0",
      protocol_version: 1,
      renderer: %{
        kind: :stock,
        source_path: "/tmp/plushie-renderer",
        payload_path: "bin/plushie-renderer"
      },
      start_command: ["bin/start_host"]
    }

    toml = Mix.PlushiePackage.partial_manifest_toml(manifest)

    assert toml =~ ~s(schema_version = 1)
    assert toml =~ ~s(app_id = "dev.plushie.test")
    assert toml =~ ~s(app_name = "Test App")
    assert toml =~ ~s(app_version = "0.1.0")
    assert toml =~ ~s(target = "linux-x86_64")
    assert toml =~ ~s(host_sdk = "elixir")
    assert toml =~ ~s(host_sdk_version = "0.7.2")
    assert toml =~ ~s(plushie_rust_version = "0.7.0")
    assert toml =~ ~s(protocol_version = 1)
    assert toml =~ ~s([start]\ncommand = ["bin/start_host"])
    assert toml =~ ~s([renderer]\npath = "bin/plushie-renderer")
    assert toml =~ ~s(kind = "stock")
  end

  test "partial manifest omits app_name when nil" do
    manifest = %{
      app_id: "dev.plushie.test",
      app_name: nil,
      app_version: "0.1.0",
      target: "linux-x86_64",
      host_sdk_version: "0.7.2",
      plushie_rust_version: "0.7.0",
      protocol_version: 1,
      renderer: %{
        kind: :stock,
        source_path: "/tmp/plushie-renderer",
        payload_path: "bin/plushie-renderer"
      },
      start_command: ["bin/start_host"]
    }

    toml = Mix.PlushiePackage.partial_manifest_toml(manifest)

    refute toml =~ "app_name"
    assert toml =~ ~s(app_id = "dev.plushie.test")
  end

  test "partial manifest uses bin/start_host.cmd for Windows targets" do
    manifest = %{
      app_id: "dev.plushie.test",
      app_name: nil,
      app_version: "0.1.0",
      target: "windows-x86_64",
      host_sdk_version: "0.7.2",
      plushie_rust_version: "0.7.0",
      protocol_version: 1,
      renderer: %{
        kind: :stock,
        source_path: "/tmp/plushie-renderer.exe",
        payload_path: "bin/plushie-renderer.exe"
      },
      start_command: ["bin/start_host.cmd"]
    }

    toml = Mix.PlushiePackage.partial_manifest_toml(manifest)

    assert toml =~ ~s(target = "windows-x86_64")
    assert toml =~ ~s(command = ["bin/start_host.cmd"])
  end

  test "partial manifest contains no [payload] section" do
    manifest = %{
      app_id: "dev.plushie.test",
      app_name: nil,
      app_version: "0.1.0",
      target: "linux-x86_64",
      host_sdk_version: "0.7.2",
      plushie_rust_version: "0.7.0",
      protocol_version: 1,
      renderer: %{
        kind: :custom,
        source_path: "/tmp/my-renderer",
        payload_path: "bin/my-renderer"
      },
      start_command: ["bin/start_host"]
    }

    toml = Mix.PlushiePackage.partial_manifest_toml(manifest)

    refute toml =~ "[payload]"
    refute toml =~ "archive"
    refute toml =~ "forward_env"
    assert toml =~ ~s(kind = "custom")
  end

  test "writes partial manifest to disk" do
    dir = tmp_dir()
    path = Path.join(dir, "plushie-package.toml")

    manifest = %{
      app_id: "dev.plushie.test",
      app_name: nil,
      app_version: "0.1.0",
      target: "linux-x86_64",
      host_sdk_version: "0.7.2",
      plushie_rust_version: "0.7.0",
      protocol_version: 1,
      renderer: %{
        kind: :stock,
        source_path: "/tmp/plushie-renderer",
        payload_path: "bin/plushie-renderer"
      },
      start_command: ["bin/start_host"]
    }

    Mix.PlushiePackage.write_partial_manifest!(path, manifest)

    toml = File.read!(path)
    assert toml =~ ~s(app_id = "dev.plushie.test")
    assert toml =~ ~s([renderer])
  end

  test "run_plushie! invokes bin/plushie with given args" do
    dir = tmp_dir()
    command = Path.join(dir, "plushie")
    args_log = Path.join(dir, "args.log")

    File.write!(command, """
    #!/bin/sh
    printf '%s\\n' "$@" > #{shell_quote(args_log)}
    """)

    File.chmod!(command, 0o755)

    assert :ok =
             Mix.PlushiePackage.run_plushie!(
               [
                 "package",
                 "assemble",
                 "--manifest",
                 "dist/plushie-package.toml",
                 "--payload-dir",
                 "dist/payload"
               ],
               command
             )

    assert File.read!(args_log) ==
             "package\nassemble\n--manifest\ndist/plushie-package.toml\n--payload-dir\ndist/payload\n"
  end

  test "run_plushie! forwards package-config when provided" do
    dir = tmp_dir()
    command = Path.join(dir, "plushie")
    args_log = Path.join(dir, "args.log")

    File.write!(command, """
    #!/bin/sh
    printf '%s\\n' "$@" > #{shell_quote(args_log)}
    """)

    File.chmod!(command, 0o755)

    assert :ok =
             Mix.PlushiePackage.run_plushie!(
               [
                 "package",
                 "assemble",
                 "--manifest",
                 "dist/plushie-package.toml",
                 "--payload-dir",
                 "dist/payload",
                 "--package-config",
                 "plushie-package.config.toml"
               ],
               command
             )

    content = File.read!(args_log)
    assert content =~ "--package-config\nplushie-package.config.toml\n"
  end

  test "requires managed package tools for renderer override packaging" do
    dir = tmp_dir()

    File.cd!(dir, fn ->
      assert_raise Mix.Error, ~r/managed Plushie tool set/, fn ->
        Mix.PlushiePackage.ensure_package_tools_available!()
      end

      File.mkdir_p!("bin")
      File.write!(Path.join("bin", Plushie.Binary.tool_name()), "tool")
      File.write!(Path.join("bin", Mix.PlushiePackage.launcher_name()), "launcher")

      assert :ok = Mix.PlushiePackage.ensure_package_tools_available!()
    end)
  end

  test "builds portable package command arguments" do
    assert Mix.PlushiePackage.portable_package_args("dist/plushie-package.toml", nil) == [
             "package",
             "portable",
             "--manifest",
             "dist/plushie-package.toml"
           ]

    assert Mix.PlushiePackage.portable_package_args(
             "dist/plushie-package.toml",
             "dist/app",
             true
           ) == [
             "package",
             "portable",
             "--manifest",
             "dist/plushie-package.toml",
             "--strict-tools",
             "--out",
             "dist/app"
           ]
  end

  test "runs portable package command with structured arguments" do
    dir = tmp_dir()
    command = Path.join(dir, "plushie")
    args_log = Path.join(dir, "args.log")

    File.write!(command, """
    #!/bin/sh
    printf '%s\\n' "$@" > #{shell_quote(args_log)}
    """)

    File.chmod!(command, 0o755)

    assert :ok =
             Mix.PlushiePackage.run_portable_package!(
               "dist/plushie-package.toml",
               "dist/app",
               true,
               command
             )

    assert File.read!(args_log) ==
             "package\nportable\n--manifest\ndist/plushie-package.toml\n--strict-tools\n--out\ndist/app\n"
  end

  test "writes package config template with real start values" do
    config = Mix.PlushiePackage.default_start_config("notes")
    toml = Mix.PlushiePackage.package_config_toml(config)

    assert toml =~ "config_version = 1"
    assert toml =~ "[start]"
    assert toml =~ ~s(working_dir = ".")
    assert toml =~ ~s(command = ["bin/start_host"])
    assert toml =~ ~s("WAYLAND_DISPLAY")
    assert toml =~ "# [assets]"
    assert toml =~ ~s(# dir = "package_assets")
  end

  defp tmp_dir do
    dir =
      Path.join(System.tmp_dir!(), "plushie-package-test-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  defp shell_quote(value) do
    "'" <> String.replace(value, "'", "'\\''") <> "'"
  end
end
