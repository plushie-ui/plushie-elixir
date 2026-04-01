# DSL Reference

The `Plushie.UI` module provides the widget DSL used in `view/1` functions.
See `Plushie.UI` for the full module docs and widget list.

## Three equivalent forms

Widget properties can be set three ways. All produce the same result:

**Keyword arguments:**

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

**Nested do-blocks for struct-typed props:**

```elixir
column do
  padding do
    top 16
    bottom 8
  end
  text("hello", "Hello")
end
```

You can mix all three in the same expression. When a property is set both
on the call line and in the block, the block value wins.

### Exception: canvas blocks

Canvas do-blocks contain layers and shapes, not children and inline options.
The `canvas_scope` validation ensures shapes, transforms, and groups are
used only in the correct context. See the [Canvas reference](canvas.md).

## Compile-time validation

### Container option validation

The DSL validates option names at compile time. If you use an option that
does not belong to the current container, you get a `CompileError` with a
message listing which containers do support that option:

```
** (CompileError) spacing is not a valid option for tooltip.
Supported by: column, row, container, ...
```

This catches typos immediately.

### Canvas context validation

`canvas_scope` validates nesting rules at compile time:

- **Canvas context**: only `layer` is valid
- **Layer context**: shapes, `group`, and control flow
- **Group context**: shapes, transforms, clips, nested groups, control flow

Inside canvas and layer blocks, `text`, `image`, and `svg` calls are
rewritten to their canvas shape variants (not the widget versions). This is
automatic -- you do not need to qualify the function name.

## Multi-expression control flow

Inside container do-blocks, `if`, `case`, `for`, `cond`, `with`, and
`unless` preserve all expressions from each branch:

```elixir
column do
  if show_header? do
    text("title", "Header")
    rule()
  end

  for item <- items do
    text(item.id, item.name)
  end
end
```

Elixir's standard block semantics would discard all but the last expression.
The DSL macros wrap multi-expression branches in lists so all values
contribute to the parent's children. Single-branch `if` (without `else`)
returns `nil`, which is filtered out.

## Prop partitioning

Container do-blocks can mix option declarations with children. The macro
system partitions them at compile time:

- Option declarations become `{:__widget_prop__, key, value}` tuples
- Everything else is a child widget
- Options are extracted and merged with keyword arguments from the call line
- Block values override keyword values on conflict

## Buildable behaviour

Types that participate in the block-form syntax implement
`Plushie.DSL.Buildable`:

| Callback | Purpose |
|---|---|
| `from_opts/1` | Construct struct from keyword list |
| `__field_keys__/0` | Valid field names (compile-time validation) |
| `__field_types__/0` | Map of field names to nested struct modules |

`__field_types__/0` enables recursive do-block nesting. When a field maps to
a struct module that also implements Buildable, its value can be specified as
a nested do-block.

See `Plushie.DSL.Buildable` for the behaviour definition.

## Programmatic API

Every widget has a struct builder alongside the DSL macro. These are
equivalent:

```elixir
# DSL macro (in view functions)
column spacing: 8 do
  text("hello", "Hello")
end

# Struct builder (in helpers, tests, programmatic construction)
Column.new("col", spacing: 8)
|> Column.push(Text.new("hello", content: "Hello"))
```

Widget structs can be returned directly from `view/1` or passed as
children -- the runtime normalizes them automatically. No explicit
`build/1` call is needed.

Use macros in view functions for readability. Use struct builders in test
helpers, programmatic construction, and code that generates widgets
dynamically.

Each widget module provides:

- `new/2` -- create struct from ID and options
- `with_options/2` -- apply keyword options via setters
- Per-prop setter functions (e.g., `Column.spacing/2`, `Text.size/2`)
- `push/2`, `extend/2` -- add children (container widgets)

## See also

- `Plushie.UI` -- full module docs, widget macros, formatter config
- `Plushie.DSL.Buildable` -- Buildable behaviour definition
- [Your First App](../guides/03-your-first-app.md) -- DSL three-forms introduction
