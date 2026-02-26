# julep

Native desktop GUIs from Elixir, powered by [iced](https://github.com/iced-rs/iced).

Julep is an Elixir library for building native cross-platform desktop applications.
You write your app logic, state management, and UI trees entirely in Elixir. A thin
Rust binary handles rendering via the iced GUI toolkit and sends user events back
over a simple JSONL-over-stdio transport.

## Goals

- **Elixir-first.** App teams write Elixir, not Rust. The Rust renderer is a
  dependency, not a framework.
- **Simple.** Elm architecture: model, update, view. No ceremony.
- **Pragmatic.** Start a GUI from `mix julep.gui`, from IEx, or embed it as a
  library in a larger OTP application.
- **Powerful.** Full access to iced's widget catalog, theming, multi-window,
  and native platform features -- without writing Rust.

## Status

Early development. Not yet published on Hex.

## Quick taste

```elixir
defmodule MyApp do
  @behaviour Julep.App

  def init(_opts), do: %{count: 0}

  def update(model, {:click, "increment"}), do: %{model | count: model.count + 1}
  def update(model, {:click, "decrement"}), do: %{model | count: model.count - 1}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Counter" do
      column do
        text("Count: #{model.count}")
        row do
          button("increment", "+" )
          button("decrement", "-")
        end
      end
    end
  end
end
```

```bash
mix julep.gui MyApp
```

## Documentation

Core:

- [Charter](docs/charter.md) -- what and why
- [Architecture](docs/architecture.md) -- the three pieces
- [App behaviour](docs/app-behaviour.md) -- the Elixir API contract
- [UI trees](docs/ui-trees.md) -- node format and widget catalog
- [Transport](docs/transport.md) -- JSONL protocol between Elixir and Rust
- [Renderer](docs/renderer.md) -- what the Rust binary does
- [Effects](docs/effects.md) -- native platform features
- [Theming](docs/theming.md) -- themes, custom palettes, styling
- [State helpers](docs/state-helpers.md) -- optional state management modules
- [Developer experience](docs/developer-experience.md) -- mix tasks, IEx, testing
- [Roadmap](docs/roadmap.md) -- phased build plan

Decisions:

- [0001: Clean break from icing](docs/decisions/0001-clean-break-from-icing.md)
- [0002: Elixir-first process model](docs/decisions/0002-elixir-first-process-model.md)
- [0003: JSONL over stdio transport](docs/decisions/0003-jsonl-over-stdio-transport.md)

## License

MIT
