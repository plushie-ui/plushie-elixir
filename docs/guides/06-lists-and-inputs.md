# Lists and Inputs

The pad from the previous chapters works with a single experiment in memory. In
this chapter we add file management: save experiments as `.ex` files, list
them in a sidebar, create new ones, switch between them, and delete the ones
you no longer need.

Along the way we will learn about dynamic list rendering, scoped IDs,
`text_input`, `checkbox`, and the `Command.focus/1` command.

## Saving experiments to files

Experiments are plain Elixir source files. We will store them in
`priv/experiments/` -- a directory outside the compilation paths so they
do not get compiled by Mix at startup. Each file is a module with a
`view/0` function, exactly like the starter code from chapter 4.

These are standard Elixir file operations, not Plushie concepts:

```elixir
@experiments_dir "priv/experiments"

defp list_experiments do
  File.mkdir_p!(@experiments_dir)

  @experiments_dir
  |> File.ls!()
  |> Enum.filter(&String.ends_with?(&1, ".ex"))
  |> Enum.sort()
end

defp save_experiment(name, source) do
  File.mkdir_p!(@experiments_dir)
  File.write!(Path.join(@experiments_dir, name), source)
end

defp load_experiment(name) do
  Path.join(@experiments_dir, name) |> File.read!()
end

defp delete_experiment(name) do
  Path.join(@experiments_dir, name) |> File.rm!()
end
```

We will call these from `update/2` when the user interacts with the file
management UI.

## Updating the model

The model needs a few new fields:

```elixir
%{
  source: "...",
  preview: nil,
  error: nil,
  event_log: [],
  # New fields
  files: [],              # list of filenames in experiments dir
  active_file: nil,       # currently selected filename, or nil
  new_name: "",           # text input for creating new experiments
  auto_save: false        # auto-save toggle (wired up in chapter 10)
}
```

In `init/1`, we load the file list and optionally load the first file:

```elixir
def init(_opts) do
  files = list_experiments()
  {source, active} = case files do
    [first | _] -> {load_experiment(first), first}
    [] -> {@starter_code, nil}
  end

  model = %{
    source: source,
    preview: nil,
    error: nil,
    event_log: [],
    files: files,
    active_file: active,
    new_name: "",
    auto_save: false
  }

  case compile_preview(source) do
    {:ok, tree} -> %{model | preview: tree}
    {:error, msg} -> %{model | error: msg}
  end
end
```

## Dynamic lists with keyed_column

To display the file list, we need to render a dynamic list of items. The
`for` comprehension works inside do-blocks just like in regular Elixir:

```elixir
column spacing: 4 do
  for file <- model.files do
    button(file, file)
  end
end
```

This works, but there is a subtlety. When you add or remove a file,
`column` matches children to their previous state by position. If you add
a file at the top of the list, every child shifts down one position -- the
second file inherits the first file's widget state (focus, scroll position,
text cursor), the third inherits the second's, and so on.

`keyed_column` solves this by matching children by their ID instead of
position. Items keep their state no matter where they move in the list:

```elixir
keyed_column spacing: 4 do
  for file <- model.files do
    button(file, file)
  end
end
```

Use `keyed_column` for any list that changes at runtime. Use `column` for
static layouts where the children are fixed.

## Scoped IDs

Each file in the list needs controls -- at least a delete button. But if
every delete button has `id: "delete"`, how does `update/2` know which file
to delete?

This is what **scoped IDs** solve. When you wrap widgets in a named
`container`, the container's ID becomes part of the scope chain. Events from
widgets inside carry that scope.

```elixir
container "hello.ex" do
  button("delete", "x")
end
```

When the delete button is clicked, the event arrives as:

```elixir
%WidgetEvent{type: :click, id: "delete", scope: ["hello.ex"]}
```

The `scope` list contains ancestor container IDs, nearest parent first. You
pattern match on it to extract the file name:

```elixir
def update(model, %WidgetEvent{type: :click, id: "delete", scope: [file | _]}) do
  delete_experiment(file)
  # ... update model
end
```

This works no matter how deeply nested the button is. Any named container
between the button and the root adds its ID to the scope chain. We will use
scoped IDs throughout the pad for any list where items have their own
controls.

For a full treatment of scoping rules, ID resolution, and edge cases, see the
[Scoped IDs reference](../reference/scoped-ids.md).

## The file list sidebar

Here is the sidebar view. It sits to the left of the editor in a `column`
with a fixed width:

```elixir
defp file_list(model) do
  column width: 180, height: :fill, padding: 8, spacing: 8 do
    text("sidebar-title", "Experiments", size: 14)

    scrollable "file-scroll", height: :fill do
      keyed_column spacing: 2 do
        for file <- model.files do
          container file do
            row spacing: 4 do
              button(
                "select",
                file,
                width: :fill,
                style: if(file == model.active_file, do: :primary, else: :text)
              )
              button("delete", "x")
            end
          end
        end
      end
    end

    # New experiment input (covered below)
    row spacing: 4 do
      text_input("new-name", model.new_name,
        placeholder: "name.ex",
        on_submit: true
      )
    end
  end
end
```

Each file gets a `container` scoped by the filename. Inside it, a select
button and a delete button. The active file is highlighted with `:primary`
style -- we will refine the styling in [chapter 8](08-styling.md).

## Text input

`text_input` is a single-line input widget. It takes an ID, the current
value (from your model), and options:

```elixir
text_input("new-name", model.new_name,
  placeholder: "name.ex",
  on_submit: true
)
```

- `placeholder:` -- grey hint text shown when the input is empty.
- `on_submit: true` -- enables the `:submit` event when the user presses
  Enter. Without this, only `:input` events (on every keystroke) are emitted.

The `:input` event delivers the current text as `value`:

```elixir
def update(model, %WidgetEvent{type: :input, id: "new-name", value: text}) do
  %{model | new_name: text}
end
```

The `:submit` event fires when Enter is pressed (and `on_submit: true`):

```elixir
def update(model, %WidgetEvent{type: :submit, id: "new-name"}) do
  create_new_experiment(model)
end
```

## Checkbox: auto-save toggle

`checkbox` is a boolean toggle widget:

```elixir
checkbox("auto-save", model.auto_save)
```

It emits a `:toggle` event with the new boolean value:

```elixir
def update(model, %WidgetEvent{type: :toggle, id: "auto-save", value: checked}) do
  %{model | auto_save: checked}
end
```

For now we just track the flag in the model. In [chapter 10](10-subscriptions.md)
we will wire it up with a debounce timer so saving happens automatically
when the checkbox is checked and the content changes.

## Commands: focus

Sometimes `update/2` needs to trigger a side effect. Instead of returning a
bare model, you return a `{model, command}` tuple.

`Plushie.Command.focus/1` sets keyboard focus on a widget by its scoped
path. After creating a new experiment, we want focus to jump back to the
editor:

```elixir
alias Plushie.Command

defp create_new_experiment(model) do
  name = String.trim(model.new_name)

  if name == "" or not String.ends_with?(name, ".ex") do
    model
  else
    template = """
    defmodule Pad.Experiments.#{name |> Path.rootname() |> Macro.camelize()} do
      import Plushie.UI

      def view do
        column padding: 16 do
          text("hello", "New experiment")
        end
      end
    end
    """

    save_experiment(name, template)
    files = list_experiments()
    model = %{model | files: files, active_file: name, source: template, new_name: ""}

    case compile_preview(template) do
      {:ok, tree} -> {%{model | preview: tree, error: nil}, Command.focus("editor")}
      {:error, msg} -> {%{model | error: msg, preview: nil}, Command.focus("editor")}
    end
  end
end
```

The `{model, Command.focus("editor")}` return tells the runtime to set focus
on the widget with ID `"editor"` after processing the update.

Commands are pure data -- `Plushie.Command` structs. The runtime executes
them after `update/2` returns. See the [Commands reference](../reference/commands.md)
for the full list.

## Wiring up file switching and deletion

Add these clauses to `update/2`:

```elixir
# Switch to a different file
def update(model, %WidgetEvent{type: :click, id: "select", scope: [file | _]}) do
  if model.active_file != nil do
    save_experiment(model.active_file, model.source)
  end

  source = load_experiment(file)
  model = %{model | active_file: file, source: source}

  case compile_preview(source) do
    {:ok, tree} -> %{model | preview: tree, error: nil}
    {:error, msg} -> %{model | error: msg, preview: nil}
  end
end

# Delete an experiment
def update(model, %WidgetEvent{type: :click, id: "delete", scope: [file | _]}) do
  delete_experiment(file)
  files = list_experiments()

  if file == model.active_file do
    case files do
      [first | _] ->
        source = load_experiment(first)
        model = %{model | files: files, active_file: first, source: source}
        case compile_preview(source) do
          {:ok, tree} -> %{model | preview: tree, error: nil}
          {:error, msg} -> %{model | error: msg, preview: nil}
        end

      [] ->
        %{model | files: [], active_file: nil, source: @starter_code, preview: nil, error: nil}
    end
  else
    %{model | files: files}
  end
end
```

Both use scope binding to extract the filename. File switching saves the
current content first, then loads the new file.

## Updating the view

The main view now includes the sidebar:

```elixir
def view(model) do
  window "main", title: "Plushie Pad" do
    column width: :fill, height: :fill do
      row width: :fill, height: :fill do
        # Sidebar
        file_list(model)

        # Editor
        text_editor "editor", model.source do
          width {:fill_portion, 1}
          height :fill
          highlight_syntax "ex"
          font :monospace
        end

        # Preview
        container "preview", width: {:fill_portion, 1}, height: :fill, padding: 8 do
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

      row padding: 4, spacing: 8 do
        button("save", "Save")
        checkbox("auto-save", model.auto_save)
        text("auto-label", "Auto-save")
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
```

The sidebar, editor, and preview sit side by side in a `row`. The sidebar
has a fixed width of 180 pixels; the editor and preview share the remaining
space equally via `{:fill_portion, 1}`.

## The complete pad

Here is the full module with file management. This is a substantial update
from chapter 5 -- if anything is not working, compare against this listing:

```elixir
defmodule PlushiePad do
  use Plushie.App

  import Plushie.UI

  alias Plushie.Command
  alias Plushie.Event.WidgetEvent

  @experiments_dir "priv/experiments"

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
    files = list_experiments()

    {source, active} =
      case files do
        [first | _] -> {load_experiment(first), first}
        [] -> {@starter_code, nil}
      end

    model = %{
      source: source,
      preview: nil,
      error: nil,
      event_log: [],
      files: files,
      active_file: active,
      new_name: "",
      auto_save: false
    }

    case compile_preview(source) do
      {:ok, tree} -> %{model | preview: tree}
      {:error, msg} -> %{model | error: msg}
    end
  end

  def update(model, %WidgetEvent{type: :input, id: "editor", value: source}) do
    %{model | source: source}
  end

  def update(model, %WidgetEvent{type: :click, id: "save"}) do
    case compile_preview(model.source) do
      {:ok, tree} ->
        if model.active_file, do: save_experiment(model.active_file, model.source)
        %{model | preview: tree, error: nil}
      {:error, msg} ->
        %{model | error: msg, preview: nil}
    end
  end

  def update(model, %WidgetEvent{type: :input, id: "new-name", value: text}) do
    %{model | new_name: text}
  end

  def update(model, %WidgetEvent{type: :submit, id: "new-name"}) do
    create_new_experiment(model)
  end

  def update(model, %WidgetEvent{type: :toggle, id: "auto-save", value: checked}) do
    %{model | auto_save: checked}
  end

  def update(model, %WidgetEvent{type: :click, id: "select", scope: [file | _]}) do
    if model.active_file, do: save_experiment(model.active_file, model.source)
    source = load_experiment(file)
    model = %{model | active_file: file, source: source}

    case compile_preview(source) do
      {:ok, tree} -> %{model | preview: tree, error: nil}
      {:error, msg} -> %{model | error: msg, preview: nil}
    end
  end

  def update(model, %WidgetEvent{type: :click, id: "delete", scope: [file | _]}) do
    delete_experiment(file)
    files = list_experiments()

    if file == model.active_file do
      case files do
        [first | _] ->
          source = load_experiment(first)
          model = %{model | files: files, active_file: first, source: source}
          case compile_preview(source) do
            {:ok, tree} -> %{model | preview: tree, error: nil}
            {:error, msg} -> %{model | error: msg, preview: nil}
          end
        [] ->
          %{model | files: [], active_file: nil, source: @starter_code, preview: nil, error: nil}
      end
    else
      %{model | files: files}
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
          file_list(model)

          text_editor "editor", model.source do
            width {:fill_portion, 1}
            height :fill
            highlight_syntax "ex"
            font :monospace
          end

          container "preview", width: {:fill_portion, 1}, height: :fill, padding: 8 do
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

        row padding: 4, spacing: 8 do
          button("save", "Save")
          checkbox("auto-save", model.auto_save)
          text("auto-label", "Auto-save")
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

  defp file_list(model) do
    column width: 180, height: :fill, padding: 8, spacing: 8 do
      text("sidebar-title", "Experiments", size: 14)

      scrollable "file-scroll", height: :fill do
        keyed_column spacing: 2 do
          for file <- model.files do
            container file do
              row spacing: 4 do
                button("select", file,
                  width: :fill,
                  style: if(file == model.active_file, do: :primary, else: :text)
                )
                button("delete", "x")
              end
            end
          end
        end
      end

      row spacing: 4 do
        text_input("new-name", model.new_name,
          placeholder: "name.ex",
          on_submit: true
        )
      end
    end
  end

  defp create_new_experiment(model) do
    name = String.trim(model.new_name)

    if name == "" or not String.ends_with?(name, ".ex") do
      model
    else
      template = """
      defmodule Pad.Experiments.#{name |> Path.rootname() |> Macro.camelize()} do
        import Plushie.UI

        def view do
          column padding: 16 do
            text("hello", "New experiment")
          end
        end
      end
      """

      save_experiment(name, template)
      files = list_experiments()
      model = %{model | files: files, active_file: name, source: template, new_name: ""}

      case compile_preview(template) do
        {:ok, tree} -> {%{model | preview: tree, error: nil}, Command.focus("editor")}
        {:error, msg} -> {%{model | error: msg, preview: nil}, Command.focus("editor")}
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

  defp list_experiments do
    File.mkdir_p!(@experiments_dir)
    @experiments_dir |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".ex")) |> Enum.sort()
  end

  defp save_experiment(name, source) do
    File.mkdir_p!(@experiments_dir)
    File.write!(Path.join(@experiments_dir, name), source)
  end

  defp load_experiment(name), do: Path.join(@experiments_dir, name) |> File.read!()
  defp delete_experiment(name), do: Path.join(@experiments_dir, name) |> File.rm!()
end
```

## Verify it

Test the file management flow -- create an experiment and switch between
files:

```elixir
test "create experiment and switch back" do
  type_text("#new-name", "test.ex")
  submit("#new-name")

  # New experiment appears in the sidebar
  assert_exists("#test.ex/select")

  # Switch back to the starter experiment
  click("#hello.ex/select")
  assert_text("#preview/greeting", "Hello, Plushie!")
end
```

This exercises scoped IDs, the create flow, file switching, and
compilation -- the core of what this chapter builds.

## Try it

With the updated pad running:

- Create a few experiments with different names. Each gets a starter
  template and appears in the sidebar.
- Switch between them. Notice the editor content changes and the preview
  updates.
- Delete an experiment. The sidebar updates and the next experiment loads
  automatically.
- Write a gallery experiment from chapter 5 and interact with the widgets.
  Switch to another experiment and back -- your content is preserved because
  we save on switch.
- Try the auto-save checkbox. It toggles in the model but does not save yet
  -- that comes in [chapter 10](10-subscriptions.md) when we learn about
  subscriptions.

Your pad now manages a library of experiments. Each one is a plain `.ex`
file in `priv/experiments/` that you can also open in your code editor.
In the next chapter, we will improve the layout so the panes are properly
sized and the spacing is consistent.

---

Next: [Layout](07-layout.md)
