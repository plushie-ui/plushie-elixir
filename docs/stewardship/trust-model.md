# Trust model

What plushie-elixir's role is in the wider Plushie trust model,
what it implements on its own side, and where the broader picture
lives. The authoritative trust-model doc lives in plushie-rust
(`docs/stewardship/trust-model.md`); this doc describes the host
SDK's half.

## The asymmetric model

Plushie's wire boundary is asymmetric:

- **Renderer-to-host.** Closed and typed. The renderer can only
  push the fixed enumeration of event variants and structured
  responses defined by the wire protocol. There is no opaque-blob
  path, no string-eval, no generic "run this on the host"
  instruction. The host is therefore structurally protected from
  a compromised or malicious renderer. The remote-rendering use
  case relies on this.
- **Host-to-renderer.** Broader by design. The host asks the
  renderer to load fonts and images by path, render screenshots,
  exercise effects (clipboard, file dialogs, notifications),
  spawn subprocesses through structured renderer exec args. A compromised host can
  drive the full operation set against the user's machine
  wherever the renderer runs. Bounding this is the
  capability-manifest direction in plushie-rust's roadmap, not
  current work.

plushie-elixir is on the trusted side of this boundary. The
runtime, the bridge, the macro DSL, and user code all run as the
host. Concerns that frame the host as adversary are out of scope
under the current model.

## What plushie-elixir implements on its side

Renderer-to-host integrity depends on the host SDK actually
holding up the closed-shape contract on the receiving end.
plushie-elixir's load-bearing pieces:

- **Typed event decoding.** `Plushie.Protocol.Decode` parses
  incoming messages against the fixed event variant set. Unknown
  variants raise `Plushie.Protocol.Error`; they are not silently
  forwarded to user code as opaque maps. An unsafe decoder that
  passes through arbitrary shapes would undermine the host-
  protection claim.
- **Effect and query response correlation.** Effect commands and
  window queries get an internal wire ID and a timeout timer.
  Responses are routed back to the originating tag only after
  the wire ID matches an outstanding request. A response with an
  unknown or stale wire ID is dropped. A spoofable correlation
  (e.g., delivering by tag without checking the wire ID) would
  let a malicious renderer drive the wrong handler.
- **No host-side eval surface.** The runtime never `eval`s,
  `Code.eval_string/1`s, or `apply/3`s data sourced from the
  renderer. The codec uses `String.to_existing_atom/1` (not
  `String.to_atom/1`) when converting renderer-supplied strings,
  so the renderer cannot grow the atom table by sending novel
  strings. Strict enums (mouse buttons, named keys, etc.) parse
  through `Plushie.Protocol.Parsers` against a closed
  enumeration.
- **App-level hygiene is the app's choice.** An app that wires
  user-provided event content into shell-out commands or
  filesystem paths is making its own choice. The protocol cannot
  enforce app-side hygiene.

## What is not protected today

- **DoS and resource exhaustion.** A malicious renderer can flood
  typed events at the protocol rate. The runtime has frame-level
  coalescing for high-frequency event types and configurable
  `default_event_rate`; a host SDK still has to handle the firehose
  gracefully (see `resilience.md`).
- **Host-to-renderer surface.** Effect dispatch, file path
  inputs, and renderer-owned child process spawn are full-trust today. Bounding them
  is the capability-manifest direction.
- **Same-access channels.** A user with shell access on the
  machine running the host can read its memory and files
  directly. plushie-elixir does not protect against the user
  acting on themselves.

## Channel posture

The wire protocol is byte-stream agnostic. Confidentiality and
integrity are delegated to the outer transport (OS pipe, named
pipe, SSH, mTLS). The wire is not its own crypto layer, by
design. Proposals to add per-message MACs or encrypted fields
to the wire format are misframed; that responsibility belongs
with the outer transport.

The session token at the wire boundary binds a host to a
particular renderer instance. Settings carry `token_sha256`, not
the plaintext token. It is not a confidentiality mechanism.

## Implications

- Work that loosens renderer-to-host integrity (an unsafe
  decoder shape, an opaque-blob delivery path, spoofable
  response correlation, a string-eval path) is a deliberate
  decision, not a routine refactor; default to no.
- Memory-corruption or RCE-shaped findings on either side are
  in scope today regardless of the broader capability-manifest
  direction.
- Host-to-renderer concerns (file path inputs, effect dispatch,
  spawn surface) defer to the capability-manifest roadmap in
  plushie-rust.
- Wire-level confidentiality or integrity expectations belong
  with the outer transport.
- DoS and resource-exhaustion concerns are low priority;
  configurable knobs (`default_event_rate`) are preferred over
  aggressive defaults.
