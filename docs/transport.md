# Transport

The transport between Elixir and the renderer is JSONL (newline-delimited
JSON) over stdio. Elixir writes to the renderer's stdin. The renderer writes
to stdout. That is the entire transport.

## Why JSONL over stdio

- **Simple.** No framing protocol, no length prefixes, no handshake. One
  JSON object per line, terminated by `\n`.
- **Debuggable.** Pipe the output to `jq` and you can see everything.
- **Portable.** Works on every OS. No platform-specific IPC to maintain.
- **Fast enough.** A desktop UI updates at most ~60 times per second. JSON
  encoding/decoding at that rate is not a bottleneck. If it ever becomes
  one, we measure first and optimize second.

## Message types

### Elixir -> Renderer

#### snapshot

Full UI tree. Sent on initial render and after renderer restart.

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

### Renderer -> Elixir

#### event

User interaction.

```json
{"type": "event", "family": "click", "id": "save_btn"}
{"type": "event", "family": "input", "id": "name_field", "value": "Alice"}
{"type": "event", "family": "toggle", "id": "dark_mode", "value": true}
{"type": "event", "family": "submit", "id": "name_field", "value": "Alice"}
{"type": "event", "family": "window", "action": "close_requested", "window_id": "main"}
{"type": "event", "family": "key", "key": "Escape", "modifiers": ["ctrl"]}
```

#### effect_response

Result of a native effect request.

```json
{"type": "effect_response", "id": "req_1", "status": "ok", "result": {"path": "/home/user/file.txt"}}
{"type": "effect_response", "id": "req_1", "status": "error", "error": "cancelled"}
```

## Buffering

The Elixir side reads from the Port in chunks. Chunks may contain partial
lines. The runtime buffers incomplete lines and processes complete ones.
This is standard JSONL handling.

## Reconnection

If the renderer process exits unexpectedly, the runtime:

1. Calls `handle_renderer_exit/2` on the app module (defaults to no-op).
2. Waits with exponential backoff (100ms, 200ms, 400ms...).
3. Respawns the renderer.
4. Sends a full snapshot (not a patch).
5. Resumes normal operation.

After a configurable number of failed restart attempts, the runtime gives
up and exits. The supervisor strategy determines what happens next.

## No envelope, no lanes, no correlation IDs

This protocol intentionally omits features like message envelopes, priority
lanes, request/response correlation, and trace context propagation. These
add complexity and solve problems we do not currently have.

If profiling or operational experience reveals a need for any of these, they
can be added as optional envelope fields without breaking the base protocol.
The renderer ignores unrecognized top-level keys.
