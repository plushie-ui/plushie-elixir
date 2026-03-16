# Transport

The transport between Elixir and the renderer is MessagePack over stdio by
default, with JSONL available as an alternative for debugging and
observability. Elixir writes to the renderer's stdin. The renderer writes
to stdout. That is the entire transport.

## Why stdio

- **Simple.** No framing protocol, no handshake. MessagePack uses a 4-byte
  length prefix handled transparently by the Erlang Port driver.
- **Portable.** Works on every OS. No platform-specific IPC to maintain.
- **Fast enough.** A desktop UI updates at most ~60 times per second.
  MessagePack serialization at that rate is not a bottleneck for most apps.
- **Debuggable when needed.** JSON mode exists for observability: pipe the
  output to `jq` and you can see everything. Enable it with `format: :json`
  on the Elixir side or `--json` on the Rust side.

## Binary protocol (MessagePack)

### Overview

Julep supports both MessagePack and JSONL as wire formats. MessagePack is
the default. The message shapes are identical -- only the encoding differs.
MessagePack reduces serialization overhead for high-frequency messages.

Binary data handling differs by format:

- **MessagePack mode:** binary data (e.g. in-memory image pixels) uses the
  native msgpack binary type. The Rust codec decodes msgpack via `rmpv::Value`
  as an intermediate, which preserves binary fields as byte arrays. These are
  converted to JSON number arrays for tag dispatch through `serde_json::Value`
  (still needed for `#[serde(tag = "type")]` enums), then reconstructed into
  `Vec<u8>` by a custom deserializer in `protocol.rs`. No base64 overhead.
- **JSON mode:** binary data uses base64 encoding (JSON has no binary type).

Some commands (e.g. `set_icon/4`) still use base64 in both formats for
simplicity. The native binary path applies to image registry payloads.

### How to enable JSON mode

MessagePack is used by default. JSON is available for debugging and
observability.

**Elixir side:** pass `format: :json` to the Bridge when starting the
renderer.

**Rust side:**
- `--json` forces JSON mode.
- No flag: MessagePack is the default. The renderer also auto-detects from
  the first byte of stdin (see below).

### Framing

**JSON mode:** newline-delimited. Each message is one UTF-8 JSON object
terminated by `\n`. The Erlang Port uses `{:line, 65_536}`.

**MessagePack mode:** 4-byte big-endian u32 length prefix followed by the
msgpack payload. The Erlang Port uses `{:packet, 4}`, which handles the
length-prefix framing transparently on both send and receive. The Protocol
module deals only in raw payloads; framing is the Port driver's job.

### Auto-detection

When no flag is passed, the renderer peeks at the first byte of stdin via
`fill_buf()`. `{` (0x7B) means JSON -- all JSON messages are objects, so the
first byte is always `{`. Any other byte is treated as the first byte of a
4-byte length prefix, indicating MessagePack.

### Error handling

**Without a flag (auto-detect):** if the first message fails to decode, the
renderer emits a human-readable JSON error on stdout and exits. This ensures
the client always gets something readable regardless of what was sent.

**With a flag (`--json`):** if the first message fails to decode, the
renderer responds with an error in JSON format (so the client can decode it)
and exits.

### Mode locked at startup

The format is determined once from the first message and locked for the
session. There is no per-message switching.

### Libraries

- **Rust:** `rmp-serde`, using named serialization (`to_vec_named`).
- **Elixir:** `msgpax`.

Both are always compiled in. No feature gates.

## Message types

### Elixir -> Renderer

#### snapshot

Full UI tree. Sent on initial render and after renderer restart. On
restart, the runtime must send a `settings` message before the snapshot
-- the new renderer process always expects Settings as its first message.

```json
{"type": "snapshot", "tree": { ... }}
```

#### patch

Incremental update to the existing tree.

```json
{"type": "patch", "ops": [
  {"op": "props", "path": [0, 1], "props": {"label": "Updated"}},
  {"op": "insert", "path": [0, 2], "node": { ... }},
  {"op": "remove", "path": [0, 3]},
  {"op": "replace", "path": [0, 0], "node": { ... }}
]}
```

Paths are integer arrays representing the child index path from the root.
`[0, 1]` means "root's first child's second child."

Patch operations:

| Op | Fields | Meaning |
|---|---|---|
| `props` | `path`, `props` | Update props on existing node |
| `insert` | `path`, `node` | Insert new node at position |
| `remove` | `path` | Remove node at position |
| `replace` | `path`, `node` | Replace node entirely (type/id change) |

#### effect_request

Request the renderer to perform a native effect.

```json
{"type": "effect_request", "id": "req_1", "kind": "file_open", "payload": {"title": "Open File", "filters": ["*.txt"]}}
```

See [effects.md](effects.md) for details.

#### extension_command

Push data directly to a native extension widget, bypassing the normal
view/diff/patch cycle. Used for high-frequency updates (terminal output,
streaming log lines, real-time plot data).

```json
{"type": "extension_command", "node_id": "term-1", "op": "write", "payload": {"data": "hello"}}
```

#### extension_command_batch

Multiple extension commands processed in one cycle. The renderer handles
all commands before triggering a single view update.

```json
{"type": "extension_command_batch", "commands": [
  {"node_id": "term-1", "op": "write", "payload": {"data": "line 1"}},
  {"node_id": "log-1", "op": "append", "payload": {"line": "entry"}}
]}
```

#### settings (extension_config field)

The `settings` message may include an `extension_config` object. The
renderer routes each key to the extension whose `config_key()` matches.

```json
{"type": "settings", "settings": {
  "default_text_size": 16,
  "extension_config": {
    "terminal": {"shell": "/bin/bash", "rows": 24},
    "plot": {"gpu": true}
  }
}}
```

### Renderer -> Elixir

#### hello

Protocol version handshake. Emitted by the renderer on startup before
reading any messages from stdin. The Elixir bridge validates the
protocol version to ensure compatibility.

```json
{"type": "hello", "protocol": 1, "version": "0.1.0", "name": "julep-renderer"}
```

Fields:
- `protocol` -- integer protocol version; bumped on breaking wire changes
- `version` -- renderer semver (informational)
- `name` -- renderer binary identity

#### event

User interaction.

```json
{"type": "event", "family": "click", "id": "save_btn"}
{"type": "event", "family": "input", "id": "name_field", "value": "Alice"}
{"type": "event", "family": "toggle", "id": "dark_mode", "value": true}
{"type": "event", "family": "submit", "id": "name_field", "value": "Alice"}
{"type": "event", "family": "window_close_requested", "id": "main"}
{"type": "event", "family": "key_press", "value": "Escape", "modifiers": {"ctrl": true, "shift": false, "alt": false, "logo": false, "command": false}, "data": {"modified_key": "Escape", "physical_key": "Escape", "location": "standard", "text": null, "repeat": false}}
{"type": "event", "family": "key_release", "value": "Escape", "modifiers": {"ctrl": true, "shift": false, "alt": false, "logo": false, "command": false}, "data": {"modified_key": "Escape", "physical_key": "Escape", "location": "standard"}}
```

#### effect_response

Result of a native effect request.

```json
{"type": "effect_response", "id": "req_1", "status": "ok", "result": {"path": "/home/user/file.txt"}}
{"type": "effect_response", "id": "req_1", "status": "error", "error": "cancelled"}
```

## Buffering

**JSON mode:** the Elixir side reads from the Port in chunks. Chunks may
contain partial lines. The runtime buffers incomplete lines and processes
complete ones. This is standard JSONL handling.

**MessagePack mode:** the `{:packet, 4}` Port driver handles framing and
always delivers complete messages. No line buffering is needed.

## Reconnection

If the renderer process exits unexpectedly, the runtime:

1. Calls `handle_renderer_exit/2` on the app module (defaults to no-op).
2. Waits with exponential backoff (100ms, 200ms, 400ms...).
3. Respawns the renderer.
4. Sends a full snapshot (not a patch).
5. Resumes normal operation.

After a configurable number of failed restart attempts, the runtime gives
up and exits. The supervisor strategy determines what happens next.

## Float precision (f64 to f32)

Elixir floats are IEEE 754 f64 (64-bit double precision). The Rust renderer
uses f32 for pixel-level widget props -- width, height, spacing, padding,
border radius, font size, and similar visual parameters. This truncation is
intentional: sub-pixel precision beyond f32 (~7 significant digits) is
meaningless for rendering. No desktop display can distinguish 1.0000001px
from 1.0000002px.

Slider values are the exception. Sliders use f64 end-to-end to preserve
user data precision, since the slider value represents domain data (not
pixels).

If precision matters for your domain data, keep it in the Elixir model at
full f64 precision and only convert to display values in `view/1`. The
truncation happens at the wire boundary and only affects rendering props.

## No envelope, no lanes

This protocol intentionally omits features like message envelopes, priority
lanes, and trace context propagation. These add complexity and solve
problems we do not currently have.

The one exception is effect request/response messages, which use an `id`
field for correlation (e.g. `"req_1"`). This allows the runtime to match
asynchronous effect results back to the originating request. Outside of
effects, messages do not carry correlation IDs.

If profiling or operational experience reveals a need for envelopes or
priority lanes, they can be added as optional fields without breaking the
base protocol. The renderer ignores unrecognized top-level keys.
