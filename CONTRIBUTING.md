# Contributing

## Setup

```bash
git clone https://github.com/plushie-ui/plushie-elixir.git
cd plushie-elixir
mix deps.get
mix plushie.download
```

Requires Elixir 1.15+. The precompiled binary has no additional
dependencies.

To build the renderer from source instead, see the
[mix tasks reference](https://hexdocs.pm/plushie/mix-tasks.html)
for `mix plushie.build` options and platform dependencies.

## Before committing

```bash
mix preflight
```

Mirrors CI and stops on first failure: format, compile (warnings as
errors), credo, test, dialyzer. Preflight must be clean before
committing.

## Tests

```bash
mix test                                       # mock backend (default)
PLUSHIE_TEST_BACKEND=headless mix test         # real rendering, no display
```

On Linux, windowed tests can run without a display using headless
weston:

```bash
export XDG_RUNTIME_DIR=$(mktemp -d)
weston -B headless --socket=plushie-test &
WAYLAND_DISPLAY=plushie-test XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
  PLUSHIE_TEST_BACKEND=windowed mix test
```

## Code style

- `mix format` for formatting
- `mix credo --strict` for linting
- Follow existing patterns in the codebase

## Commit conventions

Use conventional commits:

    feat: add gradient fill support
    fix: handle missing window on close
    docs: update animation reference
    test: add msgpack round-trip tests
    refactor: extract common prop parsing
    perf: skip render-only widgets in handler registry

## Pull requests

1. Create a branch from `main`
2. Make changes, ensure `mix preflight` passes
3. Submit PR with a clear description
