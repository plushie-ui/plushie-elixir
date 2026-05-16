# Packaging and Distribution

`mix plushie.package` turns a Plushie app into a self-contained
artifact that ships with its own Erlang runtime and Plushie renderer.
The output is either a portable single-file executable or an OS-native
installer (AppImage, `.dmg`, `.msi`). The recipient does not need
Elixir, Erlang, or anything else installed.

When the artifact runs, the launcher extracts the payload, starts your
Elixir app, and the app starts its renderer from inside the payload.
The flow is the same as `mix plushie.gui`, just running from an
extracted directory instead of your project.

| Section | Topic |
|---|---|
| [Quickstart](#quickstart) | Three commands from a working app to a portable artifact |
| [The packaging pipeline](#the-packaging-pipeline) | How the SDK, cargo-plushie, and the launcher hand off |
| [mix plushie.package](#mix-plushiepackage) | Task flags and what the task owns |
| [The payload](#the-payload) | What goes in `dist/payload/` |
| [Source layout](#source-layout) | What to commit and what to gitignore |
| [Renderer selection](#renderer-selection) | Stock versus custom |
| [Bundled assets](#bundled-assets) | Icons, fonts, and other payload files |
| [The Mix release and ERTS](#the-mix-release-and-erts) | Release config and runtime slimming |
| [The managed tool set](#the-managed-tool-set) | `bin/plushie`, renderer, launcher |
| [The partial manifest](#the-partial-manifest) | TOML the SDK writes |
| [Package config](#package-config) | `plushie-package.config.toml` schema |
| [Forwarded environment](#forwarded-environment) | Host process environment policy |
| [Building artifacts](#building-artifacts) | Portable executable and OS installers |
| [Distribution](#distribution) | Release asset layout |
| [Continuous integration](#continuous-integration) | GitHub Actions workflow |
| [Signing](#signing) | Developer-driven signing hooks |
| [Updates](#updates) | `[updates]` schema |
| [Host-first versus renderer-parent](#host-first-versus-renderer-parent) | Default launch model and the alternative |

## Quickstart

Three commands take a working app to a portable artifact:

```bash
mix plushie.download                                                         # install Plushie tool set
MIX_ENV=prod mix plushie.package PlushiePad --app-id dev.example.plushie_pad # build payload + manifest
bin/plushie package portable --manifest dist/plushie-package.toml            # produce the artifact
```

Output lands under `target/plushie/package/`. `--app-id` is the only
required flag.

## The packaging pipeline

A packaged app moves through three stages:

1. **SDK build.** `mix plushie.package` builds the Mix release, copies
   it and a renderer into `dist/payload/`, writes a `bin/start_host`
   wrapper, and emits a partial `dist/plushie-package.toml` carrying
   SDK identity, version pins, target triple, and the renderer
   descriptor.
2. **Manifest assembly.** `mix plushie.package` then shells out to
   `bin/plushie package assemble`. cargo-plushie validates the payload,
   reads `plushie-package.config.toml` for `[start]` defaults and
   `[platform]` metadata, materializes the icon, archives the payload,
   computes its SHA-256 and size, and fills in the rest of
   `plushie-package.toml`.
3. **Artifact build.** `bin/plushie package portable` produces a
   self-extracting single-file executable. `bin/plushie package bundle`
   produces OS-native installers via
   [cargo-packager](https://github.com/crabnebula-dev/cargo-packager).
   Both consume the same completed manifest.

Stage 1 is Elixir-specific. Stages 2 and 3 are language-agnostic and
shared across every Plushie SDK; the same `bin/plushie` tool that
assembles an Elixir payload assembles a Python or Ruby payload.

## mix plushie.package

Stage 1 of the pipeline. The task compiles the project, builds the
Mix release, assembles the payload directory, writes the partial
manifest, and shells to `bin/plushie package assemble` to complete
it.

| Flag | Description |
|---|---|
| `--app-id ID` | Package app identifier. Required. |
| `--app-name NAME` | Display app name. Used by cargo-plushie for OS-native bundles. |
| `--release NAME` | Mix release name. Defaults to the current Mix app. |
| `--output DIR` | Output directory. Defaults to `dist`. |
| `--renderer-kind stock\|custom` | Renderer selection. Auto-detected when absent. |
| `--renderer-path PATH` | Use an existing renderer binary. |
| `--package-config PATH` | Use a non-default `plushie-package.config.toml` path. |
| `--write-package-config` | Write a `plushie-package.config.toml` template and exit. |
| `--load MODULE` | Load a module before native widget discovery. |

`--app-id` is a reverse-DNS identifier in the
`namespace.[subnamespace.]app` form (`dev.example.plushie_pad`,
`com.acme.invoice`). cargo-plushie validates the format during
assembly.

Run with `MIX_ENV=prod` for release builds. The task warns if the
environment is anything else.

The output directory is rebuilt from scratch on every run. Anything
under `dist/` from a previous run is removed before the new payload
is assembled.

## The payload

`dist/payload/` is the directory that gets archived into the artifact:

```
dist/
  plushie-package.toml           # manifest (partial then completed)
  payload/
    bin/
      start_host                 # POSIX entry script
      start_host.cmd             # Windows entry script (windows-* targets)
      plushie-renderer           # payload-local renderer copy
    rel/
      plushie_pad/               # full Mix release
        bin/                     # release scripts (plushie_pad, plushie_pad.bat)
        erts-X.Y.Z/              # bundled Erlang runtime (if include_erts: true)
        lib/                     # application beams
        releases/                # release metadata and config
    assets/                      # icon and other files from package_assets/
                                 #   (see Bundled assets below)
```

`bin/start_host` (or `bin/start_host.cmd` on Windows) is a small shell
wrapper that calls the Mix release with `eval Plushie.Connect.run/2`.
The shared package launcher runs this entry script with
`PLUSHIE_BINARY_PATH` set to the payload-local renderer, and
`Plushie.Connect.run/2` starts that renderer through the normal binary
resolution path. The packaged app never reaches out to the system
`PATH` or a download cache; everything it needs is inside the
extracted payload.

## Source layout

Packaging adds project-owned files that belong in version control and
generated files that do not. Knowing which is which avoids accidentally
committing platform-specific binaries or losing project-owned config.

| Path | What it is | Commit or gitignore |
|---|---|---|
| `plushie-package.config.toml` | Package config: start command, forward_env, platform metadata. Like `mix.exs`. | Commit. |
| `package_assets/` | Project-owned icon, fonts, and other files copied verbatim into the payload. | Commit. |
| `PLUSHIE_RUST_VERSION` | Renderer version pin. The SDK reads it to fetch the matching tool set. | Already committed. |
| `bin/` | Plushie tool set installed by `mix plushie.download`: `plushie`, `plushie-renderer`, `plushie-launcher`. Platform-specific binaries. | Gitignore. |
| `dist/` | Package output: payload directory and manifest. Rebuilt by every `mix plushie.package` run. | Gitignore. |
| `target/plushie/` | Portable and bundle artifacts produced by `bin/plushie package portable` / `bundle`. | Gitignore. |
| `_build/` | Standard Mix build output. | Already in default `.gitignore`. |

A minimum `.gitignore` for a packaging-enabled project looks like:

```
/_build/
/deps/
/bin/
/dist/
/target/
```

`mix plushie.download`, `mix plushie.package`, and
`bin/plushie package portable` each check whether their output path is
gitignored when run inside a git repository. If it is not, they print a
one-paragraph warning naming the directory and the line to add. The
command still succeeds; the warning is just a nudge.

## Renderer selection

The task picks a renderer based on whether your project declares
[native widgets](custom-widgets.md) (Rust-backed widgets that ship
their own crate):

- **No native widgets.** A stock renderer is bundled. By default, it
  comes from the managed tool set installed by `mix plushie.download`.
- **Native widgets present.** A custom renderer is built by shelling
  to `mix plushie.build --release`, which generates a Cargo workspace
  containing each widget crate.

Override the auto-detection with `--renderer-kind stock|custom`.
Requesting `--renderer-kind stock` for an app that declares native
widgets fails fast, because a stock renderer cannot include those
widget crates.

Use `--renderer-path PATH` to package a specific binary. This skips
the download or build step and copies the file you point at directly
into the payload. The payload-local path depends on the renderer kind
and how the source binary is selected:

- Stock: always `bin/plushie-renderer`.
- Custom without `--renderer-path`: `bin/<build-name>`, where
  `<build-name>` matches `config :plushie, :build_name` (the file
  `mix plushie.build` produces).
- Custom with `--renderer-path PATH`: `bin/<basename of PATH>`, so the
  packaged file keeps the name of the binary you pointed at.

`--load MODULE` ensures a module is loaded before native widget
discovery runs. Useful when a widget module would not otherwise be
loaded by Mix at task time, for example a widget defined in a
dependency that is loaded only at runtime.

## Bundled assets

A packaged app needs two kinds of files beyond the release itself: the
icon and other OS-bundle metadata that cargo-plushie reads from the
manifest, and runtime assets that your app loads at startup (fonts,
images, data files). Each has a different home.

### App-loaded assets (priv/)

Anything your app reads at runtime through `Application.app_dir/2`
goes in `priv/` at the project root (or inside a specific application
directory for umbrella projects). Mix release copies `priv/` into the
release tree at `lib/<app>-<vsn>/priv/`, and the resolver works the
same packaged or unpackaged:

```elixir
font_path = Application.app_dir(:plushie_pad, "priv/fonts/inter.ttf")
icon_path = Application.app_dir(:plushie_pad, "priv/window-icon.png")
```

Reference these paths from `settings.fonts`, `Plushie.Command.Image`,
or any widget that takes a file path. There is no separate packaging
step. If it works in `mix plushie.gui`, it works packaged.

### Package-level assets (package_assets/)

Files that need to live inside the payload at a known location, such
as the OS bundle icon referenced from `[platform].icon`, go in a
`package_assets/` directory next to `plushie-package.config.toml`.
cargo-plushie copies the contents verbatim into the payload root
during `bin/plushie package assemble`:

```
plushie_pad/
├── mix.exs
├── plushie-package.config.toml
└── package_assets/
    ├── icon.png                # ends up at payload/icon.png
    └── fonts/
        └── extra.ttf           # ends up at payload/fonts/extra.ttf
```

The convention is zero-config: if `package_assets/` exists, it is
used. To use a different directory name, set `[assets].dir` in the
package config:

```toml
[assets]
dir = "branding"
```

Asset files overwrite SDK-generated payload files when the names
collide, so a `package_assets/bin/start_host` would replace the
generated entry script. Use this for overrides, not by accident; the
default layout has no overlap.

### Icon

cargo-plushie looks for an icon at the path named in `[platform].icon`
inside the payload. If no path is set and a file already exists at
`assets/default-app-icon-512.png`, that path is recorded. If nothing
exists at either location, cargo-plushie writes the built-in default
icon to `assets/default-app-icon-512.png` and records that path.

**Format:** PNG with RGBA alpha channel for transparency.

**Dimensions:** square aspect ratio, 512x512 minimum. cargo-packager
scales this single source down for `.ico` (16/32/48/64/128/256) and
up or down for `.icns` (16/32/64/128/256/512/1024). Provide 1024x1024
or larger if the same icon will be used for retina displays or
high-DPI Windows installers.

To use a custom icon, put a PNG in `package_assets/` and reference it
from `[platform].icon`:

```toml
[platform]
icon = "icon.png"               # payload-relative; resolves to payload/icon.png
                                # after package_assets/icon.png is copied
```

The schema accepts a single icon path. Multi-size sources and
per-platform `.icns`/`.ico` overrides are not yet supported.

## The Mix release and ERTS

`mix plushie.package` delegates release building to
[`mix release`](https://hexdocs.pm/mix/Mix.Tasks.Release.html). It
runs the release task internally and copies the output into
`dist/payload/rel/<release_name>/`. Configure the release through
the standard Mix release config in `mix.exs`:

```elixir
def project do
  [
    app: :plushie_pad,
    version: "0.1.0",
    releases: [
      plushie_pad: [
        include_erts: true,
        include_executables_for: [:unix]
      ]
    ]
  ]
end
```

`include_erts` decides where the Erlang runtime comes from. The
packaging task does not constrain this choice, but the resulting
runtime must match the target triple:

- `include_erts: true` (default) copies the ERTS from the Erlang
  installation that built the release. Build on a runner that
  matches the target OS and architecture.
- `include_erts: "/path/to/erlang/root"` copies an explicit extracted
  Erlang runtime root. Use this when CI installs runtimes via
  [mise](https://mise.jdx.dev/), [asdf](https://asdf-vm.com/), or a
  similar tool and you want to point at the resolved path.
- `include_erts: false` produces a release that requires Erlang on
  the target machine. Not recommended for standalone distribution.

Cross-target runtime bundling (building a Linux runtime on macOS,
for example) is not currently a supported flow.

### Slimming the runtime

A `MIX_ENV=prod` release already does the standard things: `strip_beams`
is on, debug chunks are removed, and only the applications your project
actually depends on are pulled in. The packaged artifact is then
archived with cargo-plushie's compression, which absorbs another chunk
of size. For most apps, this is enough.

If you need to go further, the lever to reach for first is the
`:applications` key in the release config. It accepts a keyword list
where mode is `:permanent` (started), `:load` (loaded but not started),
or `:none` (not loaded). Use `:load` or `:none` to drop applications
your code does not actually call into. See the
[Mix release documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-options)
for the full option set; the packaging task does not constrain this
choice.

Hand-pruning files out of the ERTS directory (using
`include_erts: "/pre-stripped/path"`) is possible but brittle. ERTS
layout changes between OTP versions, and removing the wrong file
surfaces as a runtime crash that does not reproduce on the build
machine. If you go that route, gate it behind a smoke test that
launches the packaged app on a clean target machine before each
release.

## The managed tool set

`mix plushie.download` installs three executables under `bin/`:

| File | Role |
|---|---|
| `plushie` | Orchestration tool. Owns `tools sync`, `package assemble`, `package portable`, `package bundle`. |
| `plushie-renderer` | The renderer binary used at runtime. Resolved by `Plushie.Binary.path!/0`. |
| `plushie-launcher` | The shared launcher used by `package portable` to build the self-extracting artifact. |

The version of each file matches the `PLUSHIE_RUST_VERSION` pin in
the SDK. `mix plushie.download` downloads `plushie` first, then
invokes `bin/plushie tools sync --required-version VERSION` to fetch
the matching renderer and launcher.

`mix plushie.package` requires all three files. The renderer is
copied into the payload, `plushie` runs the assemble step, and
`plushie-launcher` is the substrate that `package portable` wraps
the payload with. The task raises early if any are missing and
prints a `mix plushie.download` hint.

The Windows variants of these files carry an `.exe` suffix. The
tool name (`plushie` versus `plushie.exe`) is platform-specific;
the role is the same.

## The partial manifest

`mix plushie.package` writes a TOML document with everything the SDK
knows: identity, versions, target, and the renderer descriptor. A
minimal partial manifest looks like:

```toml
schema_version = 1
app_id = "dev.example.plushie_pad"
app_version = "0.1.0"
target = "linux-x86_64"
host_sdk = "elixir"
host_sdk_version = "0.7.2"
plushie_rust_version = "0.7.0"
protocol_version = 1

[start]
command = ["bin/start_host"]

[renderer]
path = "bin/plushie-renderer"
kind = "stock"
```

`bin/plushie package assemble` reads this file plus the payload
directory and writes the completed manifest in place. The completed
manifest adds:

- A `[payload]` section with the archive hash, size, and compression
  format.
- `[start].working_dir` and `[start].forward_env` defaults from the
  package config.
- A `[platform]` block if one is set in the package config, with
  `[platform].icon` pointing at the materialized icon image (the icon
  is stored on the platform block; there is no separate `[icon]`
  table).

The split exists so that cargo-plushie owns the cross-SDK schema
once. Every Plushie SDK writes a partial manifest in this shape and
hands the rest to the same `package assemble` step.

## Package config

Optional defaults for the assemble step live in
`plushie-package.config.toml` at the project root. Generate a
template with:

```bash
mix plushie.package --write-package-config
```

The template includes all supported fields commented out:

```toml
config_version = 1

[start]
working_dir = "."
command = ["bin/start_host"]
forward_env = [
  "PATH",
  "HOME",
  "LANG",
  "LC_ALL",
  "XDG_RUNTIME_DIR",
  "WAYLAND_DISPLAY",
  "DISPLAY",
]

# [assets]
# # Project-relative directory copied verbatim into the payload root
# # during package assembly. When this section is absent, a directory
# # named `package_assets/` next to this config file is used by
# # convention if it exists.
# dir = "package_assets"

# [platform]
# publisher = "Your Name"
# copyright = "Copyright 2026 Your Name"
# category = "productivity"
# description = "Short app description"
# bundle_id = "com.example.app"

# [platform.macos]
# bundle_version = "1"

# [platform.windows]
# install_scope = "perUser"
```

`[start].working_dir` is relative to the extracted payload root.
`[start].command` is a structured argv; the first element is the
host entry script. The SDK substitutes `bin/start_host.cmd` for
`bin/start_host` automatically on `windows-*` targets.

`[start].forward_env` is the list of environment variable **names**
copied from the parent process into the host process at launch
time. Names only; values are never logged or recorded. The defaults
cover the variables a typical Linux GUI app needs. Add more entries
when your app reads additional environment, for example `RUST_LOG`
during development.

The `[platform]` block populates OS-native bundle metadata. All
fields are optional. `bundle_id` defaults to `app_id`. The
`[platform.macos]` and `[platform.windows]` subtables carry
OS-specific fields and are also optional.

Use `--package-config PATH` to point at a config file outside the
project root.

## Forwarded environment

The package launcher does not blanket-inherit the user's environment.
It builds the host process environment from two closed sources:

- The Plushie reserved namespace (`PLUSHIE_BINARY_PATH`, plus a small
  set of internal coordination variables that the launcher sets
  itself).
- The names listed in `[start].forward_env`.

Variables outside both sets are dropped. This matches the
`Plushie.RendererEnv` allowlist that the SDK uses to bound the
renderer subprocess environment, and gives packaged apps a
predictable, narrow runtime environment regardless of where the
launcher is invoked from.

## Building artifacts

Once the manifest is complete, the same payload feeds two artifact
shapes.

### Portable single-file launcher

```bash
bin/plushie package portable --manifest dist/plushie-package.toml
```

Produces a self-extracting executable wrapping `plushie-launcher` and
the archived payload. Output lands under `target/plushie/package/`
by default; pass `--out PATH` to override. The artifact is content-
addressed by the payload hash, so two builds of the same inputs
produce a byte-identical executable.

The launcher extracts the payload to a per-user cache directory
keyed by the payload hash. Repeated runs of the same artifact reuse
the extraction.

### OS-native installers

```bash
bin/plushie package bundle --manifest dist/plushie-package.toml --format appimage
bin/plushie package bundle --manifest dist/plushie-package.toml --format dmg --format app
bin/plushie package bundle --manifest dist/plushie-package.toml --format nsis
```

`--format` is repeatable; pass it once per format you want produced.

Delegates to [cargo-packager](https://github.com/crabnebula-dev/cargo-packager)
for AppImage (Linux), `.app` and `.dmg` (macOS), and `.msi` and `.exe`
(Windows, via the `wix` and `nsis` cargo-packager formats). Format
availability depends on the runner: Apple formats need a macOS runner,
Windows formats need a Windows runner.

Both commands default to a strict-tools check: they verify that the
launcher, renderer, and `plushie` itself match the SDK-pinned
version. Pass `--lax-tools` to bypass the check; this is intended
for local experimentation and not for release builds.

## Distribution

Artifacts are version-named and signed with SHA-256 sidecars in the
same layout the SDK uses to fetch its own managed tools:

```
BASE/vVERSION/ARTIFACT
BASE/vVERSION/ARTIFACT.sha256
```

GitHub releases match this layout naturally. Other hosting works
the same way: any HTTPS endpoint that serves
`vVERSION/ARTIFACT` and `vVERSION/ARTIFACT.sha256` is usable.

For local release verification, point `PLUSHIE_RELEASE_BASE_URL` at
a `file://` directory or a loopback HTTP server before assets are
uploaded. The download flow accepts both schemes alongside the
default HTTPS.

## Continuous integration

The following GitHub Actions workflow builds a portable artifact per
target on a `v*` tag push and uploads everything to a GitHub release
with SHA-256 sidecars. Drop it in at `.github/workflows/release.yml`
and edit the marked lines for your app:

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write          # for uploading release assets

jobs:
  package:
    name: Package (${{ matrix.target }})
    runs-on: ${{ matrix.runner }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - target: linux-x86_64
            runner: ubuntu-latest
          - target: darwin-x86_64
            runner: macos-13
          - target: darwin-aarch64
            runner: macos-14
          - target: windows-x86_64
            runner: windows-latest
    steps:
      - uses: actions/checkout@v4

      - uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.18"
          otp-version: "27"

      - name: Cache deps and build
        uses: actions/cache@v4
        with:
          path: |
            deps
            _build
          key: mix-${{ matrix.target }}-${{ hashFiles('mix.lock') }}

      - name: Fetch dependencies
        run: mix deps.get

      - name: Install Plushie tools
        run: mix plushie.download

      - name: Build the package payload
        env:
          MIX_ENV: prod
        # EDIT: replace PlushiePad and dev.example.plushie_pad below
        run: |
          mix plushie.package PlushiePad \
            --app-id dev.example.plushie_pad

      - name: Build the portable artifact
        run: bin/plushie package portable --manifest dist/plushie-package.toml

      - name: Compute SHA-256 sidecar
        shell: bash
        run: |
          cd target/plushie/package
          for f in *; do
            if [ -f "$f" ] && [[ "$f" != *.sha256 ]]; then
              shasum -a 256 "$f" | awk '{print $1}' > "$f.sha256"
            fi
          done

      - name: Upload to release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            target/plushie/package/*
          generate_release_notes: true
```

The workflow runs four parallel jobs, one per supported target. Each
fetches dependencies, installs the Plushie tool set, builds the Mix
release, assembles the payload, produces the portable artifact,
computes a SHA-256 sidecar, and uploads both files to the release
that the tag push creates.

Lines to tweak for your project:

- The matrix runner labels (`macos-13` for Intel macOS, `macos-14`
  for Apple Silicon). GitHub-hosted runner labels change over time;
  pin or update as needed. Add `ubuntu-24.04-arm` (or use a
  self-hosted runner) for Linux aarch64.
- The Elixir and OTP versions in `setup-beam`. Match what your
  project supports.
- The `mix plushie.package` arguments: app module and `--app-id`.
- Release notes: set `generate_release_notes` to `false` and add
  `body` (or `body_path`) if you write release notes by hand.

To also build OS-native installers, add a second matrix entry that
calls `bin/plushie package bundle --format <name>` (repeat per format) instead of
`package portable`, and adjust the upload glob accordingly. Apple
formats need a macOS runner with valid signing identities; Windows
formats need a Windows runner with the appropriate SDKs.

For private hosting, replace the upload step with whatever pushes
the artifact and sidecar to your release endpoint. Any service that
exposes the assets at `BASE/vVERSION/ARTIFACT` plus
`BASE/vVERSION/ARTIFACT.sha256` works with the download flow.

## Signing

`plushie-package.toml` carries a `[[signing.hooks]]` block: a list of
commands that run after the artifact is built. Pass
`--run-signing-hooks` to `package portable` or `package bundle` to
invoke them. Hooks are opt-in so release builds run them and local
experimentation does not.

Each hook is a structured argv. Use them for macOS notarization,
Windows code signing, Linux checksum attestation, or whatever else the
target platform needs. Plushie does not hold signing keys; the hook
commands do.

## Updates

`plushie-package.toml` reserves an `[updates]` block for update
channel metadata. The schema is in place. The runtime side that
consumes it, planned around
[cargo-packager-updater](https://github.com/crabnebula-dev/cargo-packager),
is not yet shipped.

## Host-first versus renderer-parent

Packaging is host-first. The launcher starts the Elixir app and the
app starts its own renderer.

A separate renderer-parent flow exists for development and embedding
hosts. The renderer starts first, binds a Unix socket, and spawns
the Elixir command with `PLUSHIE_SOCKET` pointing at it:

```bash
plushie-renderer --listen \
  --exec-bin mix \
  --exec-arg plushie.connect \
  --exec-arg PlushiePad
```

`mix plushie.connect` reads the socket and connects.
`Plushie.Connect.run/2` is the runtime entry point for both flows;
it detects `PLUSHIE_SOCKET` and either connects to the existing
renderer or spawns its own.

The same entry point is what `bin/start_host` calls in a packaged app,
so driving a packaged app from an external renderer is possible but
requires adding `PLUSHIE_SOCKET` to `[start].forward_env` so the
launcher passes the variable through. This is not a default-on
configuration.

## See also

- [Mix Tasks reference](mix-tasks.md) - all Mix tasks including
  `plushie.package`, `plushie.download`, `plushie.build`, and
  `plushie.connect`
- [Configuration reference](configuration.md) - environment variables,
  application config, and transport modes
- [Wire Protocol reference](wire-protocol.md) - message format, token
  handling, and renderer-parent startup
- `Plushie.Connect` - the runtime entry point used by `bin/start_host`
- `Plushie.Binary` - binary resolution, including how packaged apps
  find their payload-local renderer
- [Mix release documentation](https://hexdocs.pm/mix/Mix.Tasks.Release.html) -
  configuring `include_erts` and the release pipeline
