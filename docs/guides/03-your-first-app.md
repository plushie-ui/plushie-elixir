# Your First App

In the previous chapter we built a counter and learned the init/update/view
cycle. Now we will start building **Plushie Pad** -- a live widget editor
that grows with you throughout this guide.

In this chapter we set up the pad's layout: a code editor on the left, a
preview area on the right, and a save button. We will make the preview
actually work in the next chapter -- for now the focus is on the DSL and
how views are composed.

## The DSL: three equivalent forms

Before we build the view, a quick note on how the Plushie DSL works. There
are three ways to set widget properties, and they all do the same thing:

**Keyword arguments on the call line:**

```elixir
column spacing: 8, padding: 16 do
  text("hello", "Hello")
end
```

**Inline declarations in the do-block:**

```elixir
column do
  spacing 8
  padding 16
  text("hello", "Hello")
end
```

**Nested do-blocks for struct-typed properties:**

```elixir
column do
  padding do
    top 16
    bottom 8
  end
  text("hello", "Hello")
end
```

You can mix all three in the same expression. Block declarations override
keyword arguments when they conflict. Use whichever form reads best for the
situation -- throughout this guide we will use different forms depending on
context.

One exception: canvas blocks work differently. We will cover that in
[chapter 12](12-canvas.md).

> Widgets also have a programmatic struct API (`Column.new/2`, setter
> pipelines) for use in helpers and tests. See the
> [DSL reference](../reference/dsl.md) for details.

## Introducing text_editor

`text_editor` is a multi-line editing widget -- think of it as `text_input`
for longer content. The `content` prop seeds the initial text, and
subsequent changes arrive as `:input` events with the full content as the
value.

```elixir
text_editor("editor", "Hello, world!",
  width: :fill,
  height: :fill,
  highlight_syntax: "ex"
)
```

The `highlight_syntax: "ex"` option enables Elixir syntax highlighting.
We will explore more `text_editor` options (key bindings, themes) in later
chapters -- for now this is all we need.

Like all stateful widgets, `text_editor` needs an explicit string ID.
Widgets that hold internal state -- `text_editor`, `text_input`, `combo_box`,
`scrollable`, `pane_grid` -- lose that state if their ID changes between
renders. Layout widgets like `column` and `row` are fine with auto-generated
IDs.

## The model

Our pad needs to track the editor content and an eventual preview:

```elixir
def init(_opts) do
  %{
    source: "# Write some Plushie code here\n",
    preview: nil,
    error: nil
  }
end
```

We will add the compile-and-preview logic in the next chapter. For now the
model just holds the source text.

## Building the view

Let us build the layout: a `window` containing a `row` that splits the
screen into an editor pane and a preview pane.

```elixir
def view(model) do
  window "main", title: "Plushie Pad" do
    column width: :fill, height: :fill do
      row width: :fill, height: :fill do
        # Editor pane (left)
        text_editor "editor", model.source do
          width {:fill_portion, 1}
          height :fill
          highlight_syntax "ex"
          font :monospace
        end

        # Preview pane (right)
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

      # Toolbar
      row padding: 8 do
        button("save", "Save")
      end
    end
  end
end
```

A few things to note:

- `{:fill_portion, 1}` gives the editor and preview equal width. Change one
  to `{:fill_portion, 2}` and it takes twice the space. We cover sizing in
  depth in [chapter 7](07-layout.md).
- The preview pane is wrapped in `container "preview"`. This named container
  will matter later when we need to distinguish events from preview widgets
  vs the pad's own widgets.
- `model.preview` will hold a compiled widget tree once we wire up
  compilation. For now it is `nil`, so the placeholder text shows.
- The `if` without `else` returns `nil`, which the layout filters out
  automatically.

## Handling events

The editor emits `:input` events on every keystroke. We track the content in
the model. The save button emits `:click` -- for now it does nothing, but we
will wire it up in the next chapter.

```elixir
alias Plushie.Event.WidgetEvent

def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
  %{model | source: source}
end

def update(model, _event), do: model
```

## The complete pad (so far)

Here is the full module. Save it as `lib/plushie_pad.ex`:

```elixir
defmodule PlushiePad do
  use Plushie.App

  alias Plushie.Event.WidgetEvent

  import Plushie.UI

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
mix plushie.gui PlushiePad
```

You should see the editor on the left with syntax highlighting and a
placeholder message on the right. The save button is there but does not do
anything yet -- we will fix that in the next chapter.

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
- Try the three DSL forms: rewrite the `row padding: 8` toolbar using
  inline declarations instead of keyword arguments.
- Add a second button to the toolbar row: `button("clear", "Clear")`. Save
  and see it appear.

The pad is a shell right now -- a text editor next to an empty preview. In
the next chapter, we will bring it to life by wiring up hot reload and code
compilation so you can write Plushie widgets and see them rendered instantly.
