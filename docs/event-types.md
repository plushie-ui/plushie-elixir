# Event Types

Custom types for event field declarations. Use these when
built-in atomic types (`:number`, `:string`, `:boolean`, `:any`)
are not specific enough.

## Built-in atomic types

These validate values without transformation:

| Type       | Accepts                          |
|------------|----------------------------------|
| `:number`  | integers and floats              |
| `:string`  | binaries and nil                 |
| `:boolean` | `true` and `false`               |
| `:any`     | any value, no validation         |

## Built-in module types

These parse wire-format values into Elixir types:

| Module                      | Parses                                        |
|-----------------------------|-----------------------------------------------|
| `Plushie.Type.Key`          | `"ArrowRight"` to `:arrow_right`, etc.        |
| `Plushie.Type.KeyModifiers` | `%{"ctrl" => true}` to `%KeyModifiers{}`      |
| `Plushie.Type.MouseButton`  | `"left"` to `:left`, `nil` to `:left`         |

## Writing a custom type

Implement the `Plushie.Event.EventType` behaviour with a `parse/1`
callback. Return `{:ok, parsed}` on success or `:error` on failure.

```elixir
defmodule MyApp.Direction do
  @behaviour Plushie.Event.EventType

  @impl true
  def parse("up"), do: {:ok, :up}
  def parse("down"), do: {:ok, :down}
  def parse("left"), do: {:ok, :left}
  def parse("right"), do: {:ok, :right}
  def parse(_), do: :error
end
```

Use it in event declarations:

```elixir
defmodule MyApp.SwipeWidget do
  use Plushie.Extension, :widget

  widget :swipe
  event :swiped, data: [direction: MyApp.Direction, velocity: :number]

  # ...
end
```

The consumer receives parsed atoms:

```elixir
def update(model, %WidgetEvent{type: {:swipe, :swiped}, data: %{direction: :left, velocity: v}}) do
  # direction is :left (atom), not "left" (string)
end
```

## When to use a custom type

Use a custom type when:

- You have a bounded set of string values from the renderer that
  should be atoms (directions, modes, statuses)
- You need to parse a wire-format structure into an Elixir struct
  (like `KeyModifiers`)
- Multiple events share the same field type and you want
  consistent parsing

Use `:any` when the value shape is genuinely dynamic or when you
don't need parsing (the value is already in the right form).

## Type validation

Types are validated at two points:

1. **Compile time** -- the `event` macro checks that all type
   identifiers are either built-in atoms or modules that implement
   `Plushie.Event.EventType` (i.e., export `parse/1`).

2. **Emit time** -- when a canvas widget emits an event, the
   framework validates the emitted data against the declared types.
   Type mismatches raise `ArgumentError` immediately.

For native widget events arriving from the renderer, type parsing
happens during event normalization. Parse failures are logged as
warnings and the raw value is preserved.
