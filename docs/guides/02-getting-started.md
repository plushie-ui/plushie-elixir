# Getting Started

## Prerequisites

You need **Elixir** 1.15 or later (with **Erlang/OTP** 25+). Plushie works
on Linux, macOS, and Windows.

## Creating a project

We will build the pad application from scratch. Start with a new Mix
project:

```bash
mix new plushie_pad
cd plushie_pad
```

Open `mix.exs` and add `:plushie` to your dependencies:

```elixir
defp deps do
  [
    {:plushie, "== 0.7.2"},
    {:file_system, "~> 1.0"}
  ]
end
```

Pin to an exact version pre-1.0. The API may change between minor
releases. Check the [CHANGELOG](https://github.com/plushie-ui/plushie-elixir/blob/main/CHANGELOG.md)
when upgrading. `file_system` is required for hot reload (`--watch`).

Next, configure the formatter so the Plushie DSL macros are formatted
correctly. In `.formatter.exs`:

```elixir
[
  import_deps: [:plushie],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

Fetch dependencies:

```bash
mix deps.get
```

## Installing the renderer

Plushie apps communicate with a Rust binary (built on
[Iced](https://github.com/iced-rs/iced)) that handles rendering and
platform input. Download the precompiled binary:

```bash
mix plushie.download
```

The binary is placed under `_build/` and Plushie resolves it
automatically at runtime.

If you prefer to build the renderer yourself (or need to for
[native widgets](13-custom-widgets.md)), see the
[build instructions](../reference/mix-tasks.md). You will need a Rust
toolchain installed.

## Your first window

Create `lib/plushie_pad/hello.ex`:

```elixir
defmodule PlushiePad.Hello do
  use Plushie.App

  import Plushie.UI

  def init(_opts), do: %{}

  def update(model, _event), do: model

  def view(_model) do
    window "main", title: "Plushie Pad" do
      text("greeting", "Hello from Plushie")
    end
  end
end
```

Run it:

```bash
mix plushie.gui PlushiePad.Hello
```

A native window appears with the text "Hello from Plushie". Close the
window or press Ctrl+C in the terminal to stop.

Here is what each piece does:

- `use Plushie.App` - declares that this module implements the
  `Plushie.App` behaviour. This gives you the `init/1`, `update/2`, and
  `view/1` callbacks that the runtime calls to drive your application.
- `import Plushie.UI` - brings the widget DSL into scope. Every widget
  you place in a view (`window`, `text`, `button`, `column`, `row`,
  and the rest) comes from this import.
- `window` - creates a native OS window. The first argument is the
  window's ID (here `"main"`). The `title:` option sets the title bar
  text. Every view must return at least one window.
- `text` - displays a read-only string. The first argument is the
  widget ID, the second is the content to display.

## The Elm loop: a counter

Let us add interactivity. Replace the contents of
`lib/plushie_pad/hello.ex` with a counter:

```elixir
defmodule PlushiePad.Hello do
  use Plushie.App

  import Plushie.UI

  alias Plushie.Event.WidgetEvent

  def init(_opts), do: %{count: 0}

  def update(model, %WidgetEvent{type: :click, id: "increment"}) do
    %{model | count: model.count + 1}
  end

  def update(model, %WidgetEvent{type: :click, id: "decrement"}) do
    %{model | count: model.count - 1}
  end

  def update(model, _event), do: model

  def view(model) do
    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("count", "Count: #{model.count}")

        row spacing: 8 do
          button("increment", "+")
          button("decrement", "-")
        end
      end
    end
  end
end
```

Run it:

```bash
mix plushie.gui PlushiePad.Hello
```

Click the "+" and "-" buttons. The count updates on every click.

Here is what is new:

- `alias Plushie.Event.WidgetEvent` - `Plushie.Event.WidgetEvent` is
  the struct delivered when a user interacts with a widget. It carries a
  `type` (`:click`, `:toggle`, `:submit`, etc.) and the `id` of the
  widget that emitted it.
- `column` - a vertical layout container. Children stack top to bottom.
  `padding:` adds space around the edges, `spacing:` adds space between
  children.
- `row` - a horizontal layout container. Children flow left to right.
- `button` - a clickable button. The first argument is the widget ID,
  the second is the label text. When clicked, the runtime delivers a
  `%WidgetEvent{type: :click, id: "increment"}` to your `update/2`.

The cycle works like this: you click "+". The renderer sends a click
event. The runtime calls `update/2` with your current model and the
event. Your function pattern-matches on the ID, increments the count,
and returns the new model. The runtime calls `view/1` with that new
model, diffs the resulting tree against the previous one, and sends
patches to the renderer. The renderer updates the display. The whole
round trip happens in milliseconds.

One thing worth knowing early: if `update/2` raises an exception, the
runtime catches it, logs the error, and reverts to the previous model.
Your app keeps running. This makes it safe to experiment. A bad
pattern match or a missing function clause will not crash the window.

## Your first test

Plushie apps are easy to test. Set up the test helper first. In
`test/test_helper.exs`:

```elixir
Plushie.Test.setup!()  # starts the shared renderer backend for tests
ExUnit.start()
```

Then write a test for the counter in `test/hello_test.exs`:

```elixir
defmodule PlushiePad.HelloTest do
  use Plushie.Test.Case, app: PlushiePad.Hello

  test "clicking + increments the count" do
    click("#increment")
    assert_text("#count", "Count: 1")
  end
end
```

Run it:

```bash
mix test
```

The test starts a real app instance, clicks the increment button, and
verifies the display text changed. We will add tests throughout the guide
-- just enough to verify each chapter's work. The full testing framework
is covered in [chapter 15](15-testing.md).

## Enabling hot reload

During development, you want to see changes reflected immediately
without restarting the application. Pass `--watch` to enable hot code
reloading:

```bash
mix plushie.gui PlushiePad.Hello --watch
```

Try it now: start the counter, then change the `padding:` value in
`view/1` from `16` to `32`. Save the file. The window updates with the
new spacing, and the count stays where it was.

This is how we will develop throughout the guide. Keep the app running,
edit code, save, and see the result. In [chapter 4](04-the-development-loop.md)
we will make hot reload the permanent default via a config file.

## Try it

With the counter running and hot reload active, try these changes one
at a time. Save after each one and watch the window update:

- Add `size: 24` to the `text` call to make the count display larger:
  `text("count", "Count: #{model.count}", size: 24)`
- Add a reset button. Put `button("reset", "Reset")` in the row next
  to the other buttons, and add a matching `update/2` clause that sets
  `count` back to `0`.
- Change `column` to `row` and `row` to `column` to flip the layout.
  See how the same widgets rearrange with a single keyword change.

When you are comfortable with the init/update/view cycle and hot reload,
you are ready for the next chapter where we start building the pad.

---

Next: [Your First App](03-your-first-app.md)
