# Your First App

In the previous chapter we built a counter and learned the init/update/view
cycle. Now we will start building **Plushie Pad** -- a live widget editor
that grows with you throughout this guide.

In this chapter we set up the pad's layout: a code editor on the left, a
preview area on the right, and a save button. We will make the preview
actually work in the next chapter -- for now the focus is on the DSL and
how views are composed.

## The DSL: three equivalent forms

Before we look at the code, a quick note on how the Plushie DSL works. There
are three ways to set widget properties, and they all produce the same result.

**Keyword arguments** on the call line, **inline declarations** mixed with
children in the do-block, and **nested do-blocks** for struct-typed
properties like padding -- all in one expression:

```elixir
column spacing: 8 do
  padding do
    top 16
    bottom 8
  end
  text("hello", "Hello")
end
```

This is equivalent to:

```elixir
column spacing: 8, padding: %{top: 16, bottom: 8} do
  text("hello", "Hello")
end
```

You can mix all three in the same expression. Block declarations override
keyword arguments when they conflict. Use whichever form reads best for the
situation -- throughout this guide we will use different forms depending on
context.

Widgets also have a programmatic struct API that you can use instead of the
macro-based DSL. The same column from above:

```elixir
alias Plushie.Widget.{Column, Text}

Column.new("my_col", spacing: 8, padding: %{top: 16, bottom: 8})
|> Column.push(Text.new("hello", "Hello"))
```

The struct API produces the same output as the DSL. It is useful for helper
functions, dynamic generation, or anywhere you prefer working with data
structures directly. We will use the DSL throughout this guide.

## The complete pad

Here is the full module for this chapter. Save it as `lib/plushie_pad.ex`
and we will walk through the key parts below.

```elixir
defmodule PlushiePad do
  use Plushie.App

  import Plushie.UI

  alias Plushie.Event.WidgetEvent

  def init(_opts) do
    %{
      source: "# Write some Plushie code here\n",
      preview: nil,
      error: nil
    }
  end

  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source}
  end

  def update(model, _event), do: model

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
      end
    end
  end
end
```

Run it:

```bash
mix plushie.gui PlushiePad --watch
```

You should see the editor on the left with syntax highlighting and a
placeholder message on the right. The save button is there but does not do
anything yet -- we will fix that in the next chapter.

## Walking through the code

### The model

`init/1` receives a keyword list passed via the `app_opts:` option when
starting the app (e.g. `Plushie.start_link(PlushiePad, app_opts: [key: val])`).
We do not need it yet, so we ignore it. The returned map becomes the initial
model -- here we track the editor source text and leave slots for a compiled
preview and an error message.

### text_editor

`text_editor` is a multi-line editing widget with syntax highlighting
support. The `content` argument seeds the initial text, and subsequent
changes arrive as `:input` events with the full content as the value.
The `highlight_syntax: "ex"` option enables Elixir syntax highlighting.

Some widgets hold renderer-side state -- cursor position, scroll offset,
text selection. `text_editor`, `text_input`, `combo_box`, `scrollable`,
and `pane_grid` all fall into this category. These widgets need an explicit
string ID so the renderer can match them to their state across renders. If
the ID changes, the state resets. Layout widgets like `column` and `row`
have no renderer-side state, so auto-generated IDs work fine for them.

### The view

The view is a `window` containing a `column` that splits vertically into
a main content `row` and a toolbar `row` at the bottom.

- `{:fill_portion, 1}` gives the editor and preview equal width. Change one
  to `{:fill_portion, 2}` and it takes twice the space. We cover sizing in
  depth in [chapter 7](07-layout.md).
- The preview pane is wrapped in `container "preview"`. This named container
  will matter later when we need to distinguish events from preview widgets
  vs the pad's own widgets.
- `model.preview` will hold a compiled widget tree once we wire up
  compilation. For now it is `nil`, so the placeholder text shows.
- An `if` without an `else` returns `nil`, which the layout filters out
  automatically. This is a useful pattern throughout Plushie views for
  conditionally showing widgets.

### Events

The editor emits `:input` events on every keystroke. We pattern-match on the
widget ID and update the model. The catch-all clause ignores everything
else, including save button clicks -- we will wire those up in the next
chapter.

## Verify it

Add a test for the pad layout in `test/pad_test.exs`:

```elixir
defmodule PlushiePad.PadTest do
  use Plushie.Test.Case, app: PlushiePad

  test "pad has editor and preview panes" do
    assert_exists("#editor")
    assert_exists("#preview")
    assert_text("#preview/placeholder", "Press Save to compile and preview")
  end
end
```

This verifies the split-pane layout is rendering correctly.

## Try it

With the pad running and hot reload active:

- Type some Elixir code in the editor. The syntax highlighting updates as
  you type.
- Change `{:fill_portion, 1}` to `{:fill_portion, 2}` on the editor pane.
  Save the file. The editor takes twice the width.
- Add a second button to the toolbar row: `button("clear", "Clear")`. Save
  and see it appear.

The pad is a shell right now -- a text editor next to an empty preview. In
the next chapter, we will bring it to life by wiring up hot reload and code
compilation so you can write Plushie widgets and see them rendered instantly.

---

Next: [The Development Loop](04-the-development-loop.md)
