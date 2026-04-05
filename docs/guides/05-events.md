# Events

Every interaction in a Plushie app produces an event. A button click, a
keystroke in a text input, a checkbox toggle. Each one arrives in your
`update/2` as a typed struct. Understanding what events look like and how to
match on them is essential for building anything beyond a static layout.

In this chapter we take a closer look at events and add an **event log** to
the pad that shows every event as it happens. This turns the pad into a
teaching tool: interact with a widget, see the event it produces.

## WidgetEvent

Most events from user interaction arrive as `Plushie.Event.WidgetEvent`
structs. Here are the key fields:

| Field | Type | Description |
|---|---|---|
| `type` | atom | The kind of interaction: `:click`, `:input`, `:toggle`, `:submit`, `:select`, `:slide`, etc. |
| `id` | string | The widget's local ID |
| `scope` | list of strings | Ancestor container IDs (nearest parent first, window ID last) |
| `value` | term or nil | Scalar payload: text content for `:input`, boolean for `:toggle`, number for `:slide` |
| `data` | map or nil | Structured payload for events with multiple fields |
| `window_id` | string | Which window the event came from |

You pattern match on these fields in `update/2`:

```elixir
# Match by widget ID
def update(model, %WidgetEvent{type: :click, id: "save"}) do
  save(model)
end

# Match with a value
def update(model, %WidgetEvent{type: :input, id: "search", value: text}) do
  %{model | query: text}
end

# Match a boolean toggle
def update(model, %WidgetEvent{type: :toggle, id: "dark_mode", value: on?}) do
  %{model | dark_mode: on?}
end
```

Always include a catch-all clause at the end of your update/2 to handle
events you do not care about:

```elixir
def update(model, _event), do: model
```

## Scope: identifying widgets in lists

When multiple widgets share the same local ID (like a "delete" button in
each row of a list), the `scope` field tells you which container they belong
to. We will use this extensively in [chapter 6](06-lists-and-inputs.md) when
building the file list. For now, know that scope exists and carries the
container ancestry.

## Other event types

Not all events are `WidgetEvent`. Plushie also delivers:

- `Plushie.Event.KeyEvent` - keyboard events (from subscriptions)
- `Plushie.Event.TimerEvent` - timer ticks (from subscriptions)
- `Plushie.Event.AsyncEvent` - results from background tasks
- `Plushie.Event.EffectEvent` - responses from platform effects (file dialogs, clipboard)
- `Plushie.Event.WindowEvent` - window lifecycle (opened, closed, resized)

Pointer events (mouse, touch, pen) from subscriptions and widgets like
`pointer_area` are also delivered as `WidgetEvent` structs using the
unified pointer event types (`:press`, `:release`, `:move`, `:scroll`,
`:enter`, `:exit`). There are no separate MouseEvent or TouchEvent
structs. The `pointer` field in the event data identifies the input
device (`:mouse`, `:touch`, `:pen`).

We will cover each of these in the chapters where they are introduced. For
now, `WidgetEvent` is the one you use most. See the
[Events reference](../reference/events.md) for the full taxonomy.

## Adding an event log to the pad

The best way to learn events is to see them. We will add an event log at the
bottom of the pad that shows every event from the preview pane.

### Updating the model

Add an `event_log` field:

```elixir
def init(_opts) do
  model = %{
    source: @starter_code,
    preview: nil,
    error: nil,
    event_log: []       # new
  }

  case compile_preview(model.source) do
    {:ok, tree} -> %{model | preview: tree}
    {:error, msg} -> %{model | error: msg}
  end
end
```

### Logging events

The catch-all clause at the bottom of `update/2` is the perfect place to
log events. Anything not handled by a specific clause gets logged:

```elixir
def update(model, event) do
  entry = format_event(event)
  %{model | event_log: Enum.take([entry | model.event_log], 20)}
end
```

This replaces the old `def update(model, _event), do: model` catch-all.
It prepends the formatted event to the log and caps it at 20 entries.

### Formatting events

We format events as struct literals so you can see exactly what to
pattern match on:

```elixir
defp format_event(%mod{} = event) do
  name = mod |> Module.split() |> List.last()

  fields =
    event
    |> Map.from_struct()
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join(", ")

  "%#{name}{#{fields}}"
end
```

This works for any event type, not just `WidgetEvent`. When you click a
button in the preview, the log shows all fields:

    %WidgetEvent{type: :click, id: "btn", value: nil, value: nil, scope: ["preview", "main"], window_id: "main"}

When you type in a text input:

    %WidgetEvent{type: :input, id: "name", value: "hello", ...}

### The event log view

Add a scrollable log below the toolbar:

```elixir
# In view/1, after the toolbar row:
scrollable "log", height: 120 do
  column spacing: 2, padding: 4 do
    for {entry, i} <- Enum.with_index(model.event_log) do
      text("log-#{i}", entry, size: 12, font: :monospace)
    end
  end
end
```

### The complete pad with event log

Here is the full module:

```elixir
defmodule PlushiePad do
  use Plushie.App

  import Plushie.UI

  alias Plushie.Event.WidgetEvent

  @starter_code """
  defmodule Pad.Experiments.Hello do
    import Plushie.UI

    def view do
      column padding: 16, spacing: 8 do
        text("greeting", "Hello, Plushie!", size: 24)
        button("btn", "Click Me")
      end
    end
  end
  """

  def init(_opts) do
    model = %{
      source: @starter_code,
      preview: nil,
      error: nil,
      event_log: []
    }

    case compile_preview(model.source) do
      {:ok, tree} -> %{model | preview: tree}
      {:error, msg} -> %{model | error: msg}
    end
  end

  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source}
  end

  def update(model, %WidgetEvent{type: :click, id: "save"}) do
    case compile_preview(model.source) do
      {:ok, tree} -> %{model | preview: tree, error: nil}
      {:error, msg} -> %{model | error: msg, preview: nil}
    end
  end

  # Log everything else
  def update(model, event) do
    entry = format_event(event)
    %{model | event_log: Enum.take([entry | model.event_log], 20)}
  end

  def view(model) do
    window "main", title: "Plushie Pad" do
      column width: :fill, height: :fill do
        row width: :fill, height: :fill do
          text_editor "editor", model.source do
            width {:fill_portion, 1}
            height :fill
            highlight_syntax "ex"
            font :monospace
          end

          container "preview", width: {:fill_portion, 1}, height: :fill, padding: 16 do
            if model.error do
              text("error", model.error, color: :red)
            else
              if model.preview do
                model.preview
              else
                text("placeholder", "Press Save to compile and preview")
              end
            end
          end
        end

        row padding: 8 do
          button("save", "Save")
        end

        scrollable "log", height: 120 do
          column spacing: 2, padding: 4 do
            for {entry, i} <- Enum.with_index(model.event_log) do
              text("log-#{i}", entry, size: 12, font: :monospace)
            end
          end
        end
      end
    end
  end

  defp compile_preview(source) do
    case Code.string_to_quoted(source) do
      {:error, {meta, message, token}} ->
        line = Keyword.get(meta, :line, "?")
        {:error, "Line #{line}: #{message}#{token}"}

      {:ok, _ast} ->
        try do
          Code.put_compiler_option(:ignore_module_conflict, true)
          [{module, _}] = Code.compile_string(source)

          if function_exported?(module, :view, 0) do
            {:ok, module.view()}
          else
            {:error, "Module must export a view/0 function"}
          end
        rescue
          e -> {:error, Exception.message(e)}
        after
          Code.put_compiler_option(:ignore_module_conflict, false)
        end
    end
  end

  defp format_event(%mod{} = event) do
    name = mod |> Module.split() |> List.last()

    fields =
      event
      |> Map.from_struct()
      |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
      |> Enum.join(", ")

    "%#{name}{#{fields}}"
  end
end
```

## Verify it

Test that clicking a preview widget produces an event log entry:

```elixir
test "clicking preview button logs an event" do
  click("#preview/btn")
  assert_exists("#log-0")
end
```

After clicking the button in the preview, the event log should contain at
least one entry. This test proves the full chain: click -> event -> scope
match -> format -> display.

## A gallery experiment

Try replacing the editor content with a gallery of common widgets:

```elixir
defmodule Pad.Experiments.Gallery do
  import Plushie.UI

  def view do
    column padding: 16, spacing: 12 do
      text("title", "Widget Gallery", size: 20)

      button("btn", "Button")
      checkbox("check", false)
      text_input("input", "", placeholder: "Type here...")
      slider("slide", {0, 100}, 50)
      progress_bar("progress", {0, 100}, 75)
      toggler("toggle", false)
    end
  end
end
```

Click Save. Each widget renders in the preview. Interact with them and watch
the event log:

- Click the button: `:click` with `id: "btn"`
- Toggle the checkbox: `:toggle` with `value: true` or `false`
- Type in the input: `:input` with the current text as `value`
- Drag the slider: `:slide` with the numeric value
- Toggle the toggler: `:toggle` with the value

The event log shows you exactly what to pattern match on in `update/2`.

## Try it

- Write an experiment with a `text_input` that has `on_submit: true`. Type
  some text and press Enter. Watch for the `:submit` event in the log. It
  carries the submitted text as `value`.
- Add a `pick_list` with a few options. Select one and see the `:select`
  event.
- Write an experiment with two buttons that have the same label but
  different IDs. Click each one and notice the `id` field distinguishes
  them.

The event log is your best teacher from here on. Every new widget you
encounter produces events, and the log shows you their shape without having
to check the documentation.

In the next chapter, we will add a file list to the pad so you can save
multiple experiments and switch between them.

---

Next: [Lists and Inputs](06-lists-and-inputs.md)
