# Elixir Plushie SDK

Build native desktop apps in Elixir. **[Pre-1.0](#status)**

Write your entire application in Elixir (state, events, UI) and get
native windows on Linux, macOS, and Windows. Available on
[Hex](https://hex.pm/packages/plushie) as `:plushie`. The
[renderer](https://github.com/plushie-ui/plushie-renderer) is built on
[Iced](https://github.com/iced-rs/iced) and ships as a precompiled
binary, no Rust toolchain required.

SDKs are also available for
[Gleam](https://github.com/plushie-ui/plushie-gleam),
[Python](https://github.com/plushie-ui/plushie-python),
[Ruby](https://github.com/plushie-ui/plushie-ruby), and
[TypeScript](https://github.com/plushie-ui/plushie-typescript).

## Quick start

<!-- test: readme_counter_init_test, readme_counter_increment_test, readme_counter_decrement_test, readme_counter_unknown_event_test, readme_counter_view_structure_test, readme_counter_view_after_increment_test -- keep this code block in sync with the test -->
```elixir
defmodule Counter do
  use Plushie.App
  alias Plushie.Event.WidgetEvent
  import Plushie.UI

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "inc"}),
    do: %{model | count: model.count + 1}

  def update(model, %WidgetEvent{type: :click, id: "dec"}),
    do: %{model | count: model.count - 1}

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")
        row spacing: 8 do
          button("inc", "+")
          button("dec", "-")
        end
      end
    end
  end
end
```

Download and run the counter example:

```bash
git clone https://github.com/plushie-ui/plushie-elixir.git
cd plushie-elixir

mix deps.get
mix plushie.download
mix plushie.gui Counter
```

The repo includes [several other examples](examples/) you can try.
Edit them while the GUI is running and see changes instantly. For
multi-file projects (custom widgets, collaborative transports, real
project scaffolding), see the
[plushie-demos](https://github.com/plushie-ui/plushie-demos/tree/main/elixir)
repo.

To add Plushie to your own project, see the
[getting started guide](https://hexdocs.pm/plushie/02-getting-started.html),
or browse the [docs](docs/) for all guides and references.

## How it works

Your Elixir application and the renderer run as two OS processes
that exchange messages. Think of it like talking to a database,
except the database is a GPU-accelerated GUI toolkit. The SDK builds
UI trees and handles events; the renderer draws native windows and
captures input.

The SDK diffs each new tree against the previous one and sends only
the changes. If the renderer crashes, Plushie restarts it and
re-syncs your state. If your code raises, the SDK reverts to the
last good state. Neither process can take the other down.

The same protocol works over a local pipe, an SSH connection, or
any bidirectional byte stream. Your code doesn't need to change.

## Features

- **Elm architecture** - init, update, view. State lives in
  Elixir, pure functions, predictable updates
- **Built-in widgets** - layout, input, display, and interactive
  widgets out of the box
- **Canvas** - shapes, paths, gradients, transforms, and
  interactive elements for custom 2D drawing
- **Themes** - dark, light, nord, catppuccin, tokyo night, and
  more, with custom palettes and per-widget style overrides
- **Animation** - renderer-side transitions, springs, and
  sequences with no wire traffic per frame
- **Multi-window** - declare windows in your view; the framework
  manages the rest
- **Platform effects** - native file dialogs, clipboard, OS
  notifications
- **Accessibility** - keyboard navigation, screen readers, and
  focus management via [AccessKit](https://accesskit.dev)
- **Custom widgets** - compose existing widgets in pure Elixir,
  draw on the canvas, or extend with native Rust
- **Hot reload** - edit code, see changes instantly with full
  state preservation
- **Remote rendering** - app on a server or embedded device,
  renderer on a display machine over SSH or any byte stream
- **Fault-tolerant** - renderer crashes auto-recover; app
  exceptions are caught and state reverted

## Testing and automation

Tests run through the real renderer binary, not mocks. Interact like
a user: click, type, find elements, assert on text. All backends
support concurrent test execution to keep your suite fast as it
grows. Three interchangeable backends:

- **Mock** - millisecond tests, no display server
- **Headless** - real rendering via
  [tiny-skia](https://github.com/linebender/tiny-skia), supports
  screenshots for pixel regression in CI
- **Windowed** - real windows with GPU rendering, platform effects,
  real input

```elixir
defmodule TodoTest do
  use Plushie.Test.Case, app: Todo

  test "add and complete a todo" do
    type_text("#new_todo", "Buy milk")
    submit("#new_todo")

    assert_text "#todo_count", "1 item"
    assert_exists "#todo:1"

    toggle("#todo:1")
    click("#filter_completed")

    assert_text "#todo_count", "0 items"
    assert_not_exists "#todo:1"
  end
end
```

The same interaction API is available outside ExUnit via
`Plushie.Automation.Session`. Attach to any running app and drive
it programmatically. Agent-friendly by design.

## Status

Pre-1.0. The core works (built-in widgets, event system, themes,
multi-window, testing framework, accessibility) but the API is
still evolving. Pin to an exact version and read the
[CHANGELOG](CHANGELOG.md) when upgrading.

## License

MIT
