# Developer experience

## Getting started

### Add the dependency

```elixir
# mix.exs
defp deps do
  [
    {:julep, "~> 0.1"}
  ]
end
```

### Write an app

```elixir
defmodule MyApp do
  @behaviour Julep.App

  def init(_opts), do: %{count: 0}

  def update(model, {:click, "inc"}), do: %{model | count: model.count + 1}
  def update(model, _event), do: model

  def view(model) do
    import Julep.UI

    window "main", title: "Counter" do
      column padding: 16, spacing: 8 do
        text("Count: #{model.count}", size: 24)
        button("inc", "+1")
      end
    end
  end
end
```

### Run it

```bash
mix julep.gui MyApp
```

That is the entire workflow. No generators, no boilerplate files, no
configuration.

## Mix tasks

### mix julep.gui

Builds (if needed) and launches the renderer with your app.

```bash
mix julep.gui MyApp                # debug build, auto-build renderer
mix julep.gui MyApp --release      # release build
mix julep.gui MyApp --no-build     # skip cargo build, use existing binary
mix julep.gui MyApp --renderer /path/to/julep_gui  # explicit binary path
```

### mix julep.build

Builds the renderer binary without running it.

```bash
mix julep.build              # debug
mix julep.build --release    # release
```

### mix julep.inspect

Runs your app without the renderer and prints the UI tree as JSON. Useful
for debugging view functions and verifying tree output.

```bash
mix julep.inspect MyApp
mix julep.inspect MyApp --events '["click:inc", "click:inc"]'
mix julep.inspect MyApp --pretty
```

## IEx workflow

```elixir
iex -S mix

# Start the GUI
{:ok, pid} = Julep.start(MyApp)

# Or start without the renderer (headless, for inspection)
{:ok, pid} = Julep.start(MyApp, renderer: false)

# Inspect current state
Julep.snapshot(pid)

# Inspect current UI tree
Julep.tree(pid)
Julep.tree(pid) |> Jason.encode!(pretty: true) |> IO.puts()

# Dispatch events manually
Julep.dispatch(pid, {:click, "inc"})

# Stop
Julep.stop(pid)
```

The headless mode is particularly useful for:

- Developing view functions without waiting for the renderer to build.
- Running the app in CI for snapshot testing.
- Using julep as a state management library without any GUI.

## Testing

### Unit tests (no renderer)

```elixir
defmodule MyAppTest do
  use ExUnit.Case

  test "increment" do
    model = MyApp.init([])
    model = MyApp.update(model, {:click, "inc"})
    assert model.count == 1
  end

  test "view contains counter" do
    model = %{count: 42}
    tree = MyApp.view(model)
    text_node = Julep.UI.find(tree, fn node -> node.type == "text" end)
    assert text_node.props["content"] =~ "42"
  end
end
```

### Tree snapshots

```elixir
test "initial view snapshot" do
  model = MyApp.init([])
  tree = MyApp.view(model)
  Julep.Test.assert_tree_snapshot(tree, "test/snapshots/initial_view.json")
end
```

`assert_tree_snapshot` compares the tree against a stored JSON file. On
first run (or with `JULEP_UPDATE_SNAPSHOTS=1`), it writes the file. On
subsequent runs, it asserts equality. This is a pure JSON comparison at the
unit test level -- no backend or session needed.

For framework-level structural snapshots (SHA-256 hash comparison via a
test session), use `assert_snapshot("name")`. For pixel-level screenshots
(full backend only, no-op on sim/headless), use `assert_screenshot("name")`
with `JULEP_UPDATE_SCREENSHOTS=1` to update golden files. See
[testing.md](testing.md) for full details.

### Integration tests (with test framework)

For tests that need interaction simulation (clicking buttons, typing text,
verifying widgets appear), use the test framework:

```elixir
defmodule MyAppIntegrationTest do
  use Julep.Test.Case, app: MyApp

  test "clicking increment updates the count" do
    click("#inc")
    assert_text "#count", "Count: 1"
  end
end
```

The default backend is `:sim` (pure Elixir, no renderer needed). Set
`JULEP_TEST_BACKEND=headless` or `JULEP_TEST_BACKEND=full` for higher
fidelity. See [testing.md](testing.md) for the full guide.

## Project structure

A minimal julep app:

```
my_app/
  lib/
    my_app.ex          # Julep.App implementation
  mix.exs
```

A larger app might organize by feature:

```
my_app/
  lib/
    my_app.ex              # Julep.App, delegates to feature modules
    my_app/
      views/
        sidebar.ex         # view helper functions
        main_content.ex
      models/
        todo.ex            # domain structs
      events.ex            # event handling, delegates per feature
  test/
    my_app_test.exs
    snapshots/             # UI tree snapshots
  mix.exs
```

The point is: there is no prescribed structure. A julep app is a normal
Elixir project. Organize it however makes sense for your domain.

## Error handling

If `update/2` raises, the runtime catches the exception, logs it, and
continues with the previous model. The app does not crash. This is a
development convenience -- in production, you should handle errors
explicitly.

If `view/1` raises, the runtime logs the error and sends the previous tree
(no update to the renderer). The app stays running.

This means a bug in your event handler or view function does not crash the
GUI. You see the error in the console, fix it, and the next event works.
