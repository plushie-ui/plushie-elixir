# The Development Loop

The pad has a layout but the preview does not work yet. In this chapter we
bring it to life with two complementary techniques: **hot reload** for
editing the pad's own source code, and **runtime compilation** for compiling
widget code typed into the pad's editor.

Along the way we will learn how to inspect a running app from `iex`, a
useful debugging skill.

## Hot reload

In chapter 2 you used `--watch` to enable hot reload on a per-run basis.
Let us make it the default for development. Create a `config/` directory
with the following files:

```elixir
# config/config.exs
import Config

import_config "#{config_env()}.exs"
```

```elixir
# config/dev.exs
import Config

config :plushie, code_reloader: true
```

You also need stub files for the other environments so the import does
not fail. Create `config/test.exs` and `config/prod.exs` each containing
just `import Config`.

With this in place, `mix plushie.gui` enables hot reload automatically
in dev without the `--watch` flag. Plushie watches your `lib/` directory.
Edit any `.ex` file, save it, and the running app recompiles in place --
your model state is preserved.

This is how you develop the pad itself. Change the view, save, see the
result. You have been using this already if you tried the "Try it" exercises
in previous chapters.

Hot reload works because the runtime re-calls `view/1` with the current
model after recompilation. The new view function produces a new tree, the
runtime diffs it against the old one, and only the changes are sent to the
renderer.

## Making the preview work

The pad's editor holds Plushie widget code. We want to compile that code
and render the result in the preview pane. This requires three steps:

1. **Parse** - check that the code is valid Elixir syntax
2. **Compile** - compile it into a module with macro expansion
3. **Render** - call the module's `view/0` function and embed the result

Here is the helper that does all three:

```elixir
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
```

`Code.string_to_quoted/1` parses the source without evaluating it. If the
syntax is invalid, we get an error with a line number.

`Code.compile_string/1` compiles the source into a module. This runs the
full Elixir compilation pipeline including macro expansion, so
`import Plushie.UI` and the DSL macros work exactly as they would in a
normal `.ex` file. We set `ignore_module_conflict` to suppress the warning
that appears when saving the same experiment twice (redefining the module).

The compiled module's `view/0` function returns a widget tree. Because
widget structs compose naturally, we can place this tree directly in the
pad's view.

Errors at any stage are caught and displayed as text in the preview pane.
The pad never crashes from bad experiment code.

## Wiring up the save button

Update `init/1` to compile a starter experiment on startup, and add a save
handler to `update/2`:

```elixir
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
    error: nil
  }

  case compile_preview(model.source) do
    {:ok, tree} -> %{model | preview: tree}
    {:error, msg} -> %{model | error: msg}
  end
end

def update(model, %WidgetEvent{type: :click, id: "save"}) do
  case compile_preview(model.source) do
    {:ok, tree} -> %{model | preview: tree, error: nil}
    {:error, msg} -> %{model | error: msg, preview: nil}
  end
end
```

Now when you type experiment code in the editor and click Save, the
preview updates with the rendered widgets. Syntax errors, compile errors, and
runtime errors all show as red text in the preview pane.

## The experiment format

Experiments are modules with a `view/0` function:

```elixir
defmodule Pad.Experiments.Hello do
  import Plushie.UI

  def view do
    column padding: 16, spacing: 8 do
      text("greeting", "Hello, Plushie!", size: 24)
      button("btn", "Click Me")
    end
  end
end
```

This is the same DSL code you write in an app's `view/1`. Experiments
just don't have a model, so the function takes no arguments.

## Inspecting a running app from iex

Sometimes you want to look at the model or tree of a running app. Start an
`iex` session and launch the app directly:

```bash
iex -S mix
```

```elixir
iex> {:ok, pid} = Plushie.start_link(PlushiePad, binary: Plushie.Binary.path!())
```

Now the app is running and you have the iex prompt. Query the runtime:

```elixir
iex> runtime = Plushie.runtime_for()
:"Plushie.Runtime"

iex> Plushie.Runtime.get_model(runtime)
%{source: "...", preview: ..., error: nil}

iex> Plushie.Runtime.get_tree(runtime)
%{id: "main", type: "window", children: [...]}
```

`get_model/1` returns the current model. `get_tree/1` returns the normalized
UI tree. These are the same values your `view/1` and `update/2` work with --
seeing them directly helps when debugging layout issues or unexpected state.

The default runtime process is registered as `:"Plushie.Runtime"`.
`Plushie.runtime_for/1` returns the right registered name for the default
instance or for a custom `name:` option.

## The complete pad

Here is the full module with compilation wired up:

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
      error: nil
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
end
```

Run it:

```bash
mix plushie.gui PlushiePad
```

The starter experiment compiles on init, so you should see "Hello, Plushie!"
and a "Click Me" button in the preview pane immediately. Edit the code in
the editor, click Save, and the preview updates.

## Verify it

Update the test to verify compilation works:

```elixir
test "starter code compiles and renders on init" do
  assert_text("#preview/greeting", "Hello, Plushie!")
  assert_exists("#preview/btn")
end
```

The preview widgets have scoped IDs (`preview/greeting`, `preview/btn`)
because they are inside `container "preview"`. This is how scoped IDs
work. We will use them more in chapter 6.

## Try it

- Change the starter experiment: add a `checkbox`, a `slider`, or a
  `text_input` to the column. Save and see them render.
- Deliberately break the syntax: delete a closing `end`. Save and see
  the error message in the preview. Fix it and save again.
- Try writing a completely different experiment: a row of coloured buttons,
  or a progress bar with a label.
- Start iex (`iex -S mix`), launch the pad with
  `Plushie.start_link(PlushiePad, binary: Plushie.Binary.path!())`,
  and inspect the model with
  `Plushie.Runtime.get_model(Plushie.runtime_for())`.

In the next chapter, we will add an event log to the pad so you can see
exactly what events widgets produce when you interact with them.

---

Next: [Events](05-events.md)
