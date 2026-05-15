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

  test "writes connect wrapper through Plushie.Connect.run" do
    dir = tmp_dir()
    path = Path.join(dir, "connect")

    Mix.PlushiePackage.write_connect_wrapper!(path, "notes", Notes.App)

    assert Bitwise.band(File.stat!(path).mode, 0o111) != 0

    assert File.read!(path) =~
             "case Plushie.Connect.run(Notes.App, []) do :ok -> :ok; {:error, reason} -> raise RuntimeError"
  end

  test "writes package manifest with SDK and protocol metadata" do
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
        source: "local-resolve",
        source_path: "/tmp/plushie-renderer",
        payload_path: "bin/plushie-renderer"
      },
      platform: %{
        icon: "assets/app-icon.png"
      },
      start_command: ["bin/connect"],
      working_dir: ".",
      forward_env: ["PATH", "HOME"],
      payload_archive: "payload.tar.zst",
      payload_hash: String.duplicate("a", 64),
      payload_size: 123
    }

    toml = Mix.PlushiePackage.manifest_toml(manifest)

    assert toml =~ ~s(host_sdk = "elixir")
    assert toml =~ ~s(app_name = "Test App")
    assert toml =~ ~s(host_sdk_version = "0.7.2")
    assert toml =~ ~s(plushie_rust_version = "0.7.0")
    assert toml =~ ~s(protocol_version = 1)
    assert toml =~ ~s([start]\nworking_dir = ".")
    assert toml =~ ~s(command = ["bin/connect"])
    assert toml =~ ~s(forward_env = ["PATH", "HOME"])
    assert toml =~ ~s([platform]\nicon = "assets/app-icon.png")
    assert toml =~ ~s([renderer]\npath = "bin/plushie-renderer")
    assert toml =~ ~s(kind = "stock")
    assert toml =~ ~s(archive = "payload.tar.zst")
    assert toml =~ ~s(hash = "sha256:#{String.duplicate("a", 64)}")
  end

  test "reads package config with start settings" do
    dir = tmp_dir()
    path = Path.join(dir, "plushie-package.config.toml")

    File.write!(path, """
    config_version = 1

    [start]
    working_dir = "app"
    command = ["app/bin/connect", "--profile", "release"]
    forward_env = [
      "PATH",
      "HOME",
    ]
    """)

    assert Mix.PlushiePackage.read_package_config!(path) == %{
             working_dir: "app",
             start_command: ["app/bin/connect", "--profile", "release"],
             forward_env: ["PATH", "HOME"]
           }
  end

  test "writes package config template with real start values" do
    config = Mix.PlushiePackage.default_start_config("notes")
    toml = Mix.PlushiePackage.package_config_toml(config)

    assert toml =~ "config_version = 1"
    assert toml =~ "[start]"
    assert toml =~ ~s(working_dir = ".")
    assert toml =~ ~s(command = ["bin/connect"])
    assert toml =~ ~s("WAYLAND_DISPLAY")
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

  test "rejects unsafe package config start settings" do
    dir = tmp_dir()
    path = Path.join(dir, "plushie-package.config.toml")

    for contents <- [
          """
          config_version = 2

          [start]
          working_dir = "."
          command = ["bin/connect"]
          forward_env = []
          """,
          """
          config_version = 1

          [start]
          working_dir = "../app"
          command = ["bin/connect"]
          forward_env = []
          """,
          """
          config_version = 1

          [start]
          working_dir = "."
          command = ["/usr/bin/connect"]
          forward_env = []
          """,
          """
          config_version = 1

          [start]
          working_dir = "."
          command = ["bin/connect"]
          forward_env = ["PLUSHIE_PACKAGE_DIR"]
          """,
          """
          config_version = 1

          [start]
          working_dir = "."
          command = ["bin/connect"]
          forward_env = ["PLUSHIE_PACKAGE_READY_FILE"]
          """
        ] do
      File.write!(path, contents)
      assert_raise Mix.Error, fn -> Mix.PlushiePackage.read_package_config!(path) end
    end
  end

  test "rejects non-string package config arrays" do
    dir = tmp_dir()
    path = Path.join(dir, "plushie-package.config.toml")

    for contents <- [
          """
          config_version = 1

          [start]
          working_dir = "."
          command = ["bin/connect", 1]
          forward_env = []
          """,
          """
          config_version = 1

          [start]
          working_dir = "."
          command = ["bin/connect"]
          forward_env = ["PATH", 1]
          """
        ] do
      File.write!(path, contents)
      assert_raise Mix.Error, fn -> Mix.PlushiePackage.read_package_config!(path) end
    end
  end

  test "materializes default icons through cargo-plushie" do
    dir = tmp_dir()
    assets_dir = Path.join(dir, "assets")
    args_log = Path.join(dir, "args.log")

    script = """
    printf '%s\\n' "$@" > #{shell_quote(args_log)}
    while [ "$#" -gt 0 ]; do
      case "$1" in
        --out)
          shift
          out="$1"
          ;;
      esac
      shift
    done
    mkdir -p "$out"
    printf icon > "$out/plushie-checkbox-512x512.png"
    """

    assert Mix.PlushiePackage.materialize_default_icons!(assets_dir, {"sh", ["-c", script, "sh"]}) ==
             "assets/plushie-checkbox-512x512.png"

    assert File.read!(args_log) == "default-icons\n--out\n#{assets_dir}\n"
    assert File.read!(Path.join(assets_dir, "plushie-checkbox-512x512.png")) == "icon"
  end

  test "copies an app icon into payload assets" do
    dir = tmp_dir()
    assets_dir = Path.join(dir, "payload/assets")
    icon_path = Path.join(dir, "app-icon.png")
    File.write!(icon_path, "icon")

    assert Mix.PlushiePackage.copy_app_icon!(icon_path, assets_dir) == "assets/app-icon.png"
    assert File.read!(Path.join(assets_dir, "app-icon.png")) == "icon"
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
