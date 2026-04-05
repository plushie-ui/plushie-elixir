# WASM Deployment

Plushie apps can run in the browser via WebAssembly. The renderer
compiles to WASM using `wasm-pack`, producing a JavaScript module
and a `.wasm` binary that can be served from any static file host.

## Prerequisites

- **Rust toolchain** with the `wasm32-unknown-unknown` target:
  `rustup target add wasm32-unknown-unknown`
- **wasm-pack**: install via https://rustwasm.github.io/wasm-pack/
- **Plushie Rust source checkout**: set `PLUSHIE_SOURCE_PATH` to
  the local `plushie-renderer` directory. The WASM build requires
  the `plushie-renderer-wasm` crate, which lives in the source
  checkout.

## Building

```bash
# Build the WASM renderer (debug, for development)
PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer mix plushie.build --wasm

# Build with optimizations (for production)
PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer mix plushie.build --wasm --release

# Build both native binary and WASM in one command
PLUSHIE_SOURCE_PATH=~/projects/plushie-renderer mix plushie.build --bin --wasm
```

The build produces two files:

- `plushie_renderer_wasm.js` (JavaScript glue module)
- `plushie_renderer_wasm_bg.wasm` (compiled WebAssembly binary)

By default these are installed to the WASM output directory configured
via `config :plushie, :wasm_dir` or the `--wasm-dir` CLI flag.

## Configuration

Set artifact and output preferences in `config.exs`:

```elixir
config :plushie,
  artifacts: [:bin, :wasm],              # build both by default
  wasm_dir: "priv/static/wasm"          # WASM output directory
```

CLI flags override config:

```bash
mix plushie.build --wasm --wasm-dir assets/wasm
```

## Serving the output

The WASM files are static assets. Serve them from any web server or
CDN. The `.wasm` file should be served with the `application/wasm`
MIME type for optimal browser loading.

With Phoenix:

```elixir
# In endpoint.ex, ensure the WASM directory is served as static:
plug Plug.Static,
  at: "/",
  from: :my_app,
  gzip: true,
  only: ~w(wasm css fonts images js favicon.ico robots.txt)
```

With a standalone static server:

```bash
cd priv/static
python3 -m http.server 8080
```

## Web page integration

The JavaScript module exports an initialization function. Load it
from an HTML page:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <title>My Plushie App</title>
  <style>
    body { margin: 0; overflow: hidden; }
    canvas { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <canvas id="plushie-canvas"></canvas>
  <script type="module">
    import init from "./plushie_renderer_wasm.js";
    await init();
  </script>
</body>
</html>
```

The WASM renderer connects back to the Elixir backend over a
WebSocket to receive the wire protocol messages (snapshots, patches)
and send events. Your Elixir app runs on the server; the WASM
renderer runs in the browser.

## Limitations vs native

The WASM renderer has several differences from the native renderer:

- **No native file dialogs.** Platform effects like `Effect.file_open`
  are not available. File operations must use browser APIs (e.g.,
  `<input type="file">` via JavaScript interop) or be handled
  server-side.
- **No clipboard access** without user gesture. Browser security
  policies restrict clipboard operations to user-initiated events.
- **No system notifications.** The Web Notifications API can be used
  as an alternative via JavaScript interop.
- **No multi-window.** WASM apps render into a single canvas element.
  Multiple windows are not supported.
- **Performance.** The WASM renderer uses software rendering. Complex
  scenes with many animated elements may be slower than the native
  GPU-accelerated renderer.
- **Startup time.** The `.wasm` binary must be downloaded and compiled
  by the browser on first load. Use `--release` builds and enable
  gzip/brotli compression on your server to minimize this.
- **No native widgets.** Native widget crates that compile Rust code
  for the renderer are not currently supported in WASM builds. Only
  pure Elixir widgets work.

## Development workflow

During development, use the native renderer (`mix plushie.gui`) for
fast iteration. Build and test the WASM version periodically to catch
browser-specific issues:

```bash
# Develop with native renderer
mix plushie.gui MyApp --watch

# Periodically verify WASM build
mix plushie.build --wasm
# Serve and test in browser
```

## Download vs build

`mix plushie.download --wasm` downloads a precompiled WASM renderer
for released versions. This skips the Rust toolchain requirement but
does not support native widgets (which require a custom build). For
most apps using only built-in and pure Elixir widgets, the precompiled
download is sufficient.
