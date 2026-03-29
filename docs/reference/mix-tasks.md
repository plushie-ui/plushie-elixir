# Mix tasks reference

Plushie ships mix tasks for building, running, downloading, and
debugging renderer binaries and applications.

## Task summary

| Task | Description | Common flags | Module |
|---|---|---|---|
| `mix plushie.build` | Build the renderer binary (auto-detects native widgets) | `--release`, `--wasm`, `--clean` | `Mix.Tasks.Plushie.Build` |
| `mix plushie.gui` | Run a Plushie app | `--build`, `--no-watch`, `--release` | `Mix.Tasks.Plushie.Gui` |
| `mix plushie.download` | Download a precompiled renderer binary | `--wasm`, `--force` | `Mix.Tasks.Plushie.Download` |
| `mix plushie.connect` | Connect to a renderer started with `plushie --listen --exec` | | `Mix.Tasks.Plushie.Connect` |
| `mix plushie.inspect` | Print the initial UI tree as JSON (no renderer needed) | | `Mix.Tasks.Plushie.Inspect` |
| `mix plushie.script` | Run `.plushie` automation scripts | | `Mix.Tasks.Plushie.Script` |
| `mix plushie.replay` | Replay a script against real windows | | `Mix.Tasks.Plushie.Replay` |
| `mix preflight` | Run all CI checks (format, compile, credo, test, dialyzer) | | `Mix.Tasks.Preflight` |

## Binary resolution

Several tasks need the renderer binary. `Plushie.Binary.path!/0`
resolves it in this order:

1. `PLUSHIE_BINARY_PATH` environment variable
2. Application config `:binary_path`
3. Custom widget build in `_build/<env>/plushie/target/`
4. Downloaded binary in `_build/plushie/bin/`

Steps 1 and 2 are explicit -- if set but pointing to a missing
file, they raise immediately. Steps 3 and 4 are implicit discovery
and silently try the next option.

The resolved binary is validated for the current OS and
architecture before use. See `Plushie.Binary` for full details.

## See also

- [Configuration reference](configuration.md) -- environment
  variables and application config
- `Plushie.Binary` -- binary path resolution and version
