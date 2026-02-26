# Testing

The Elm architecture makes julep apps unusually easy to test. `update` is a
pure function. `view` returns plain maps. No mocks needed for the core loop.

## Unit testing update logic

`update/2` takes a model and an event, returns a model (or `{model, command}`).
Test it directly:

```elixir
defmodule MyAppTest do
  use ExUnit.Case

  describe "todo management" do
    test "adding a todo appends to list and clears input" do
      model = %{todos: [], input: "Buy milk"}
      model = MyApp.update(model, {:click, "add_todo"})

      assert [%{text: "Buy milk", done: false}] = model.todos
      assert model.input == ""
    end

    test "toggling a todo flips its done state" do
      model = %{todos: [%{id: 1, text: "Buy milk", done: false}]}
      model = MyApp.update(model, {:toggle, "todo:1", true})

      assert [%{id: 1, done: true}] = model.todos
    end

    test "adding a todo with empty input does nothing" do
      model = %{todos: [], input: ""}
      result = MyApp.update(model, {:click, "add_todo"})

      assert result.todos == []
    end
  end
end
```

No setup, no teardown, no processes, no renderer. Just functions and data.

## Testing commands

When `update` returns `{model, command}`, test both parts:

```elixir
test "submitting todo refocuses the input" do
  model = %{todos: [], input: "Buy milk"}
  {model, cmd} = MyApp.update(model, {:submit, "todo_input", "Buy milk"})

  assert [%{text: "Buy milk"}] = model.todos
  assert %Julep.Command{type: :focus, target: "todo_input"} = cmd
end

test "clicking fetch starts async load" do
  model = %{loading: false, data: nil}
  {model, cmd} = MyApp.update(model, {:click, "fetch"})

  assert model.loading == true
  assert %Julep.Command{type: :async, tag: :data_loaded} = cmd
end
```

Commands are data. You can inspect their type, target, and tag without
executing them.

## Testing views

`view/1` returns a plain map tree. Assert on its structure:

```elixir
test "view shows todo count" do
  model = %{todos: [%{id: 1, text: "Buy milk", done: false}], input: "", filter: :all}
  tree = MyApp.view(model)

  # Find a specific node
  counter = Julep.UI.find(tree, "todo_count")
  assert counter.props["content"] =~ "1"
end

test "view hides completed todos when filter is active" do
  model = %{
    todos: [
      %{id: 1, text: "Done task", done: true},
      %{id: 2, text: "Open task", done: false}
    ],
    input: "",
    filter: :active
  }
  tree = MyApp.view(model)

  assert Julep.UI.find(tree, "todo:2") != nil
  assert Julep.UI.find(tree, "todo:1") == nil
end

test "view disables add button when input is empty" do
  model = %{todos: [], input: "", filter: :all}
  tree = MyApp.view(model)

  add_btn = Julep.UI.find(tree, "add_todo")
  assert add_btn.props["disabled"] == true
end
```

### Tree query helpers

`Julep.UI` provides helpers for finding nodes in trees:

```elixir
# Find by ID
Julep.UI.find(tree, "my_button")

# Find by predicate
Julep.UI.find(tree, fn node -> node.type == "text" end)

# Find all matching nodes
Julep.UI.find_all(tree, fn node -> node.type == "button" end)

# Check if a node exists
Julep.UI.exists?(tree, "my_button")

# Get all node IDs (useful for debugging)
Julep.UI.ids(tree)
```

## Snapshot testing

For complex views, snapshot tests catch unintended changes:

```elixir
test "initial view snapshot" do
  model = MyApp.init([])
  tree = MyApp.view(model)

  Julep.Test.assert_snapshot(tree, "test/snapshots/initial_view.json")
end

test "settings view snapshot" do
  model = %{screen: :settings, theme: "dark", notifications: true}
  tree = MyApp.view(model)

  Julep.Test.assert_snapshot(tree, "test/snapshots/settings_view.json")
end
```

On first run, `assert_snapshot` writes the JSON file. On subsequent runs,
it compares the tree against the stored snapshot. If the tree has changed,
the test fails with a diff.

To update snapshots after intentional changes:

```bash
JULEP_UPDATE_SNAPSHOTS=1 mix test
```

### What makes a good snapshot test

Snapshot the view for a specific, named model state. Do not snapshot
random or time-dependent views. The snapshot file name should describe
what the state represents.

Good:
```elixir
test "empty state view" do ...
test "loading state view" do ...
test "error state view" do ...
```

Bad:
```elixir
test "the view" do ...  # which view? what state?
```

## Scenario testing

Test multi-step user flows by chaining updates:

```elixir
test "complete todo flow: add, toggle, filter" do
  model = MyApp.init([])

  # Type a todo
  model = MyApp.update(model, {:input, "todo_input", "Buy milk"})
  assert model.input == "Buy milk"

  # Add it
  model = MyApp.update(model, {:click, "add_todo"})
  assert length(model.todos) == 1
  assert model.input == ""

  # Mark it done
  [todo] = model.todos
  model = MyApp.update(model, {:toggle, "todo:#{todo.id}", true})
  assert hd(model.todos).done == true

  # Filter to active only
  model = MyApp.update(model, {:click, "filter_active"})
  tree = MyApp.view(model)
  assert Julep.UI.find(tree, "todo:#{todo.id}") == nil
end
```

This reads like a user story. Anyone can understand what it tests.

## Testing subscriptions

`subscribe/1` returns a list. Test it like any other function:

```elixir
test "timer subscription active when running" do
  model = %{timer_running: true}
  subs = MyApp.subscribe(model)

  assert Enum.any?(subs, fn sub -> sub.type == :every end)
end

test "no timer subscription when stopped" do
  model = %{timer_running: false}
  subs = MyApp.subscribe(model)

  refute Enum.any?(subs, fn sub -> sub.type == :every end)
end
```

## Testing init

```elixir
test "init returns valid initial state" do
  model = MyApp.init([])

  assert is_list(model.todos)
  assert model.input == ""
  assert model.filter == :all
end

test "init with options" do
  model = MyApp.init(theme: "dark")

  assert model.theme == "dark"
end

test "init with command" do
  {model, cmd} = MyApp.init([])

  assert model.loading == true
  assert %Julep.Command{type: :async} = cmd
end
```

## Integration testing with the renderer

For tests that need the actual renderer (visual verification, widget
interaction timing), julep provides a test helper:

```elixir
defmodule MyAppIntegrationTest do
  use Julep.IntegrationCase

  test "clicking increment updates the display" do
    {:ok, app} = start_app(MyApp)

    send_event(app, {:click, "increment"})

    assert_tree(app, fn tree ->
      text = Julep.UI.find(tree, fn n ->
        n.type == "text" and n.props["content"] =~ "1"
      end)
      text != nil
    end)
  end
end
```

Integration tests require the renderer binary to be built. They are slower
and should be used sparingly -- most logic can be tested with unit tests.

Tag integration tests so they can be excluded in CI when the renderer is
not available:

```elixir
@tag :integration
test "..." do ...
```

```bash
# Run all tests
mix test

# Skip integration tests
mix test --exclude integration

# Only integration tests
mix test --only integration
```

## Testing philosophy

1. **Most tests should be unit tests.** `update` and `view` are pure
   functions. Test them without processes or infrastructure.

2. **Test behaviour, not implementation.** Assert on what the model
   contains and what the tree looks like, not on internal helper calls.

3. **Tests are documentation.** Name them clearly. Write them so someone
   unfamiliar with the code can read the test and understand the feature.

4. **Avoid mocks.** The Elm architecture eliminates most reasons to mock.
   If you find yourself needing mocks, the design might need rethinking.

5. **Integration tests are for confidence, not coverage.** Use them to
   verify the full stack works, not to test every branch.
