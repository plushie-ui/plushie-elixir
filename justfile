# plushie-elixir - Development Tasks
#
# Run `just` to see available recipes.
# Run `just preflight` before pushing to catch CI failures locally.

set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Fetch and compile dependencies
deps:
    mix deps.get
    mix deps.compile

# Download the precompiled renderer binary
download:
    mix plushie.download

# Run all CI checks locally (same as CI pipeline).
# Auto-detects ../plushie-rust as PLUSHIE_RUST_SOURCE_PATH when not set.
# Set PLUSHIE_RUST_SOURCE_PATH="" to force non-local (skip auto-detect).
preflight: deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -z "${PLUSHIE_RUST_SOURCE_PATH+x}" ]] && [[ -d "../plushie-rust" ]]; then
        export PLUSHIE_RUST_SOURCE_PATH="$(cd ../plushie-rust && pwd)"
        echo "==> auto: PLUSHIE_RUST_SOURCE_PATH=$PLUSHIE_RUST_SOURCE_PATH"
    fi
    mix preflight

# Run tests (mock backend, default)
test:
    mix test

# Check code formatting
fmt-check:
    mix format --check-formatted

# Apply code formatting
fmt:
    mix format

# Run Credo linter
lint:
    mix credo --strict

# Run Dialyzer type checker
dialyzer:
    mix dialyzer

# Remove gitignored build artifacts
clean:
    git clean -fdX
