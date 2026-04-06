# Wire Protocol

The wire protocol defines the message format between the Elixir SDK and
the Rust renderer. The protocol is language-agnostic and shared across
all Plushie SDKs. This reference covers the Elixir perspective: how
the SDK encodes, decodes, and manages the protocol lifecycle.

For the complete message format specification (every field, every patch
operation, every event family), see the
[Renderer Protocol Spec](https://github.com/plushie-ui/plushie-renderer/blob/main/docs/protocol.md).

## Wire formats

Two formats carry the same message structures. Controlled by the
`:format` option on `Plushie.start_link/2` or the `--json` flag on
`mix plushie.gui`.

### MessagePack (default)

Each message is prefixed with a 4-byte big-endian unsigned integer
indicating the payload size:

```
<<size::32-big, payload::binary-size(size)>>
```

The Bridge opens the Erlang Port with `{:packet, 4}`, which handles
framing automatically in both directions. For custom transports
(iostream adapters, SSH channels), use
`Plushie.Transport.Framing.encode_packet/1` and `decode_packets/1`.

MessagePack is more efficient for binary data (images, pixel buffers)
and high update rates.

### JSON (JSONL)

Each message is a single JSON object terminated by `\n`. Messages must
not contain embedded newlines.

The Bridge opens the Port with `{:line, 65_536}`. For custom transports,
use `Plushie.Transport.Framing.encode_line/1` and `decode_lines/1`.

JSON is human-readable, making it useful for debugging. Combine with
`RUST_LOG=plushie=debug` for full visibility:

```bash
RUST_LOG=plushie=debug mix plushie.gui MyApp --json 2>protocol.log
```

### Format auto-detection

The renderer auto-detects the format from the first byte of stdin:
`0x7B` (`{`) means JSON, anything else means MessagePack. The `--json`
and `--msgpack` CLI flags override auto-detection.

### Maximum message size

64 MiB. Messages exceeding this are rejected by the renderer.

## Protocol version

The current protocol version is `1`. It is sent in the `settings`
message as `protocol_version` and returned in the renderer's `hello`
response. A version mismatch indicates an SDK/renderer version skew.

Read the version programmatically: `Plushie.Protocol.protocol_version/0`.

## Startup handshake

The SDK and renderer follow a fixed startup sequence:

1. **SDK sends Settings** - `Plushie.Protocol.encode_settings/2`
   serialises the app's `settings/0` callback result plus the protocol
   version. The Bridge writes this as the first message.
2. **Renderer auto-detects format** from the first byte and reads the
   Settings.
3. **Renderer sends Hello** - reports its version, mode (`mock`,
   `headless`, `windowed`), backend, transport, and registered
   extensions.
4. **SDK sends Snapshot** - the Runtime calls `view/1`, normalises the
   tree via `Plushie.Tree.normalize/1`, and sends the full tree via
   `Plushie.Protocol.encode_snapshot/2`.
5. **Normal message exchange begins.**

If the renderer restarts (crash recovery), the handshake repeats from
step 1. The Runtime re-sends settings and a fresh snapshot.

## Encoding (SDK -> renderer)

The `Plushie.Protocol` module delegates encoding to an internal Encode
module for all outbound messages:

| Function | Message type | When sent |
|---|---|---|
| `encode_settings/2` | `settings` | Startup, renderer restart |
| `encode_snapshot/2` | `snapshot` | First render, renderer restart |
| `encode_patch/2` | `patch` | Incremental tree updates |
| `encode_effect/4` | `effect` | Platform effect requests |
| `encode_subscribe/5` | `subscribe` | Subscription activation |
| `encode_unsubscribe/3` | `unsubscribe` | Subscription removal |
| `encode_widget_op/3` | `widget_op` | Focus, scroll, select, cursor, announce |
| `encode_widget_command/4` | `extension_command` | Native widget commands |
| `encode_window_op/4` | `window_op` | Window open, close, update |
| `encode_image_op/3` | `image_op` | In-memory image lifecycle |
| `encode_interact/5` | `interact` | Test interactions |
| `encode_advance_frame/2` | `advance_frame` | Manual frame step (test/headless) |

### Key stringification

The Elixir SDK works with atom keys internally (`%{type: "text",
props: %{content: "Hello"}}`). During encoding, all map keys are
converted to strings for the wire format. The `stringify_tree/1`
function in the encode module recursively walks the tree, converting
atom keys to strings and encoding type-specific values (colours,
lengths, paddings, borders, etc.) via `Plushie.Type.encode_value/1`.

This means you never need to think about string vs atom keys in your
view code. The encoding layer handles it.

## Decoding (renderer -> SDK)

The decode layer (`Plushie.Protocol.decode_message/2`) deserialises inbound
messages and dispatches them to typed structs:

| Wire type | Decoded to | Delivered via |
|---|---|---|
| `hello` | `{:hello, map}` | Bridge stores and notifies Runtime |
| `event` | `WidgetEvent`, `KeyEvent`, `WindowEvent`, etc. | `update/2` |
| `effect_response` | `{:effect_response, wire_id, result}` | Runtime maps to `%EffectEvent{tag: tag}` |
| `interact_step` | `{:interact_step, id, events}` | Test backend processes |
| `interact_response` | `{:interact_response, id, events}` | Test backend resolves |
| `screenshot_response` | `{:screenshot_response, data}` | `update/2` as raw tuple |
| `effect_stub_registered` | `{:effect_stub_ack, kind}` | Runtime resolves pending stub call |
| `session_error` | `{:session_error, data}` | Session pool handles |
| `session_closed` | `{:session_closed, data}` | Session pool handles |

### Safe atomisation

Inbound maps from the renderer use string keys. The decode layer
converts known keys to atoms via `String.to_existing_atom/1` with a
rescue fallback that preserves unknown keys as strings. This prevents
atom table exhaustion from arbitrary renderer data while giving you
atom keys for standard fields.

Effect results and system query data pass through `safe_atomize_keys/1`
recursively, so nested maps also get atom keys for known fields.

## Snapshots vs patches

The Runtime decides whether to send a snapshot or a patch:

- **Snapshot** - sent when there is no previous tree to diff against
  (startup, renderer restart, first render). Resets all renderer-side
  caches.
- **Patch** - sent when the tree changes incrementally.
  `Plushie.Tree.diff/2` compares the old and new normalised trees and
  produces a list of patch operations (`replace_node`, `update_props`,
  `insert_child`, `remove_child`). Child reordering is handled by
  replacing the parent node. If the diff is empty (identical trees),
  no message is sent.

Patches are more efficient for large trees with small changes. The
renderer preserves widget caches (layer tessellation, text layout) for
unchanged subtrees.

See the [Renderer Protocol Spec](https://github.com/plushie-ui/plushie-renderer/blob/main/docs/protocol.md)
for the complete patch operation format.

## Session multiplexing

Every wire message carries a `session` field (string). In single-session
mode (the default), this is `""`. In multiplexed mode (test session
pool with `--max-sessions N`), each test session gets an isolated
session ID. The renderer maintains per-session state (tree,
subscriptions, effects, caches) keyed by this field.

Session lifecycle in multiplexed mode:
- Sessions are created implicitly on first message
- `Reset` tears down a session (thread exits, state freed)
- The session ID can be reused after reset
- `--max-sessions` limits concurrent sessions

See `Plushie.Test.SessionPool` for the Elixir-side multiplexing
implementation.

## The interact protocol

Test interactions (`click`, `type_text`, etc.) use a synchronous
request-response protocol:

1. SDK sends `interact` message with an action, selector, and payload.
2. Renderer resolves the selector, simulates the interaction, and sends
   back one or more `interact_step` messages with intermediate events.
3. Renderer sends a final `interact_response` with the last batch of
   events.
4. The test backend processes all events through `run_update` and
   returns the final state to the test process.

This ensures test interactions are fully synchronous. `click("#save")`
blocks until the full update cycle (event -> update -> view -> patch)
completes.

## iostream adapters

Custom transports use `{:iostream, pid}` and must implement a message
protocol for bidirectional communication with the Bridge. See the
[Configuration reference](configuration.md#iostream-pid) for the full
message contract.

The adapter is responsible for framing. For byte-stream transports
(TCP sockets, SSH channels), use `Plushie.Transport.Framing` for
4-byte length-prefixed framing (MessagePack) or newline-delimited
framing (JSON).

## See also

- `Plushie.Protocol` - encode/decode API (delegates to internal
  Encode and Decode modules)
- `Plushie.Transport.Framing` - frame encode/decode for raw streams
- `Plushie.Bridge` - transport management, Port lifecycle, restart
- [Configuration reference](configuration.md) - transport modes and
  iostream adapter contract
- [Renderer Protocol Spec](https://github.com/plushie-ui/plushie-renderer/blob/main/docs/protocol.md)
  - the authoritative message format reference with every field,
  patch operation, event family, and widget prop
