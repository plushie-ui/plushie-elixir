# 0003: JSONL over stdio transport

## Status

Accepted.

## Context

The icing design docs specified a versioned binary protocol with envelope
metadata (correlation IDs, priority lanes, deadlines, trace context),
`{:packet, 4}` framing, and socket-based transport with endpoint hardening.

None of this was implemented in the actual transport. The working code used
raw JSONL over stdio, which was sufficient for everything it needed to do.

## Decision

Use JSONL (newline-delimited JSON) over stdio as the transport. No
envelopes, no framing, no sockets, no binary encoding.

## Rationale

1. **Simplicity.** One JSON object per line, terminated by `\n`. No
   framing protocol to implement, debug, or version.

2. **Debuggability.** Pipe the renderer's stdin/stdout through `tee` or
   `jq` and you can see every message. This is invaluable during
   development.

3. **Performance is not a concern.** A desktop UI updates at most ~60 FPS.
   A typical patch is a few hundred bytes of JSON. Even a full snapshot of
   a complex UI is single-digit kilobytes. JSON encoding/decoding at this
   rate is negligible compared to actual rendering time.

4. **No trust boundary.** The renderer is a child process on the same
   machine. There is no network, no authentication, no multi-tenant
   isolation. The complexity of a hardened IPC protocol is not justified.

## Consequences

- No priority lanes. Messages are processed in order. If this becomes a
  problem (e.g., telemetry flooding starves interactive updates), it can
  be addressed by batching or rate-limiting on the Elixir side.

- No request/response correlation. Effect requests use an `id` field for
  matching. Regular events do not need correlation.

- No binary encoding. If profiling reveals JSON as a bottleneck, a binary
  format (MessagePack, Protobuf) can replace it by changing the
  encode/decode functions. The tree model and patch semantics stay the same.

## Reversibility

High. Switching to a different encoding or adding envelope fields is a
localized change in the bridge and renderer. The app API does not change.
