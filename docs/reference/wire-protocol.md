# Wire protocol reference

The wire protocol defines the message format between an SDK and the
Rust renderer. The protocol is language-agnostic and shared across all
Plushie SDKs (Elixir, Gleam, Python, Ruby, TypeScript). This reference
covers the Elixir perspective -- for transport implementers, debuggers,
and anyone building custom iostream adapters.

See `Plushie.Protocol` for encoding/decoding API and
`Plushie.Transport.Framing` for raw byte stream framing.

## Outbound messages (SDK -> renderer)

| Type | Purpose | Key fields |
|---|---|---|
| `settings` | Application settings and protocol version | `settings`, `protocol_version` |
| `snapshot` | Full UI tree (initial or after restart) | `tree` |
| `patch` | Incremental tree diff operations | `ops` |
| `effect` | Platform effect request (file dialog, clipboard, etc.) | `id`, `kind`, `payload` |
| `subscribe` | Start a renderer-side subscription | `kind`, `tag`, `max_rate` (optional) |
| `unsubscribe` | Stop a renderer-side subscription | `kind` |
| `interact` | Test/script interaction request | `id`, `action`, `selector`, `payload` |
| `widget_op` | Widget operation (focus, scroll, select, cursor) | `op`, `payload` |
| `extension_command` | Direct command to a native widget | `node_id`, `op`, `payload` |
| `extension_commands` | Batch of native widget commands | `commands` |
| `window_op` | Window lifecycle operation (open, close, update) | `op`, `window_id`, `settings` |
| `image_op` | In-memory image lifecycle | `op`, `handle`, `data`/`pixels` |
| `system_op` | System-wide operation | `op`, `settings` |
| `system_query` | System-wide query | `op`, `settings` |
| `advance_frame` | Manual frame advance (headless/test) | `timestamp` |
| `register_effect_stub` | Register a test effect stub | `kind`, `response` |
| `unregister_effect_stub` | Remove a test effect stub | `kind` |

## Inbound messages (renderer -> SDK)

| Type | Purpose | Key fields |
|---|---|---|
| `hello` | Renderer handshake (version, capabilities) | `version` |
| `event` | User interaction or system event | `family`, `id`, `window_id`, `value`/`data` |
| `interact_step` | Intermediate events during an interaction | `id`, `events` |
| `interact_response` | Final response to an interact request | `id`, `events`, `tree` |
| `effect_response` | Result of a platform effect request | `id`, `kind`, `result` |
| `screenshot_response` | Screenshot data (headless/test) | `id`, `data`, `width`, `height` |

## Framing

Two wire formats are supported, controlled by the `:format` option
to `Plushie.start_link/1`:

### MessagePack (default)

Each message is prefixed with a 4-byte big-endian unsigned integer
indicating the payload size:

```
<<size::32-big, payload::binary-size(size)>>
```

The Erlang Port is opened with `{:packet, 4}`, which handles
framing automatically in both directions. For custom transports,
use `Plushie.Transport.Framing.encode_packet/1` and
`decode_packets/1`.

### JSON (JSONL)

Each message is a single JSON object terminated by `\n`. Messages
must not contain embedded newlines.

The Erlang Port is opened with `{:line, 65_536}`. Partial lines
exceeding the buffer are accumulated and flushed on the terminating
newline. For custom transports, use
`Plushie.Transport.Framing.encode_line/1` and `decode_lines/1`.

## Protocol version

The current protocol version is embedded in the `settings` message
as `protocol_version`. The renderer validates this on receipt. A
version mismatch indicates an SDK/renderer version skew and the
renderer will reject the connection.

Read the current version programmatically via
`Plushie.Protocol.protocol_version/0`.

## Session multiplexing

Every wire message carries a `session` field. In single-session
mode (the default), this is an empty string `""`. In multiplexed
mode (headless test pool), each test session gets an isolated
session ID. The renderer maintains per-session state -- tree,
subscriptions, effects -- keyed by this field.

See `Plushie.Test.SessionPool` for the multiplexing implementation.

## iostream adapter contract

Custom transports use `{:iostream, pid}` and must implement the
iostream message protocol. See the
[configuration reference](configuration.md#iostream-adapter-contract)
for the full message table.

## See also

- [Configuration reference](configuration.md) -- transport modes
  and environment variables
- `Plushie.Protocol` -- encode/decode API (includes
  Protocol.Encode and Protocol.Decode internally)
- `Plushie.Transport.Framing` -- frame encode/decode for raw streams
- `Plushie.Bridge` -- transport management and restart logic
- [Renderer Protocol Spec](https://github.com/plushie-ui/plushie-renderer/blob/main/docs/protocol.md) -- renderer-side protocol documentation and message reference
