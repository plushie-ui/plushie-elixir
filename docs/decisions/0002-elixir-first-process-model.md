# 0002: Elixir-first process model

## Status

Accepted.

## Context

The icing design docs specified Rust as the primary process (host) that
spawns the Elixir sidecar. This is the conventional model for native
desktop apps -- the native binary owns the event loop and process lifecycle.

However, our primary use cases are:

- Starting a GUI from a mix task during development.
- Launching a GUI from IEx for interactive exploration.
- Embedding a GUI as a library inside a larger OTP application (e.g.,
  observability console, admin panel).
- Testing UI logic without a renderer.

All of these are Elixir-first workflows. Making Rust the primary process
forces an awkward inversion where the BEAM must be loaded as a child,
complicating startup, supervision, and the developer experience.

## Decision

Elixir is the primary process. The Rust renderer is spawned as a child
process via `Port.open/2`. The renderer communicates over stdin/stdout.

## Consequences

**Advantages:**

- `mix julep.gui MyApp` just works. No separate binary to start first.
- IEx integration is natural: `Julep.start(MyApp)` from the shell.
- The renderer can be supervised by OTP and restarted on crash.
- Testing without the renderer is trivial -- skip the Port.
- Library embedding is standard OTP child spec.

**Tradeoffs:**

- For distribution (app stores, double-click launchers), having a native
  binary as the entrypoint is preferable. This can be addressed as a future
  packaging option where the Rust binary starts the BEAM, but it is not
  required for v1.
- The BEAM must be running before the GUI appears. For apps that want
  instant splash screens, this adds a small delay. Acceptable for v1.

## Future option

A Rust-first packaging mode can be added later without changing the
protocol or the app code. The UI tree format, JSONL transport, and event
model are the same regardless of which process spawns which. This is a
packaging concern, not an architectural one.
