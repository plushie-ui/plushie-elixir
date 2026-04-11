# DSL

The `Plushie.UI` module provides the widget DSL used in `view/1`
functions. A single `import Plushie.UI` brings every widget macro,
canvas shape, animation descriptor, and layout container into scope.
This reference covers the DSL's forms, compile-time validation,
variable scoping, auto-IDs, and the programmatic struct API.

## Three equivalent forms

Widget properties can be set three ways. All produce the same result.

**Keyword arguments** on the call line:

```elixir
column spacing: 8, padding: 16 do
  text("hello", "Hello")
end
```

**Inline declarations** mixed with children in the do-block:

```elixir
column do
  spacing 8
  padding 16
  text("hello", "Hello")
end
```

**Nested do-blocks** for struct-typed props (Border, Shadow, Padding,
Font, StyleMap, etc.):

```elixir
column do
  padding do
    top 16
    bottom 8
  end
  text("hello", "Hello")
end
```

You can mix all three in the same expression. When a property is set
both on the call line and in the block, the block value wins.

## Variable scoping

Variables from the enclosing scope are accessible inside all do-blocks.
The DSL does not create isolated scopes:

```elixir
count = length(model.items)

column do
  text("count", "#{count} items")  # count is accessible

  for {item, i} <- Enum.with_index(model.items) do
    text(item.id, "#{i + 1}. #{item.name}")  # i is accessible
  end
end
```

Variables assigned inside a block are also visible in subsequent lines
of the same block. This applies to containers, canvas layers, and
canvas groups.

## Auto-IDs

Layout widgets that don't hold renderer-side state support auto-generated
IDs. You can omit the ID argument:

```elixir
column spacing: 8 do
  row spacing: 4 do
    text("hello", "Hello")
  end
end
```

Auto-IDs use the format `"auto:ModuleName:line"` (e.g.
`"auto:MyApp.Home:42"`). They are stable across re-renders as long as
the code doesn't move. Because auto-IDs are based on source position,
dynamic lists (`for` comprehensions, `Enum.map`) must use explicit IDs
to avoid sibling collisions.

### Widgets with auto-ID support

`column`, `row`, `stack`, `grid`, `keyed_column`, `responsive`

### Widgets requiring explicit IDs

All interactive and stateful widgets require an explicit string ID:

- **Stateful containers**: `scrollable`, `pane_grid`, `combo_box`.
  These hold renderer-side state (scroll position, pane sizes, search
  text). If the ID changes, the state resets.
- **Named containers**: `container`, `themer`, `window`, `tooltip`,
  `overlay`, `pin`, `floating`, `pointer_area`, `sensor`
- **Input widgets**: `button`, `text_input`, `text_editor`, `checkbox`,
  `toggler`, `radio`, `slider`, `vertical_slider`, `pick_list`

`scrollable` and `pane_grid` produce a compile-time error if you forget
the ID:

```
** (CompileError) scrollable requires an explicit ID because it holds
renderer-side state. Use scrollable("my-id") do ... end
```

## Compile-time validation

### Container option validation

The DSL validates option names at compile time against each widget's
known option set. An unknown option produces a `CompileError` with a
helpful message listing which containers DO support that option:

```
** (CompileError) spacing is not a valid option for tooltip.
Supported by: column, row, grid, keyed_column
```

This catches typos and wrong-widget options immediately.

### Canvas context validation

Canvas blocks enforce structural nesting rules at compile time:

| Context | Allowed contents |
|---|---|
| **Canvas** | `layer` blocks, canvas-level options (`width`, `height`, `background`) |
| **Layer** | Shapes (`rect`, `circle`, `line`, `text`, `path`, `image`, `svg`), `group` blocks, control flow |
| **Group** | Shapes, transforms (`translate`, `rotate`, `scale`), `clip`, nested `group` blocks, control flow |

Inside canvas and layer blocks, `text`, `image`, and `svg` are
automatically rewritten to their canvas shape variants. You use the
same names without qualification; the compiler resolves them based
on context.

Attempting to use a widget macro inside a canvas block or a canvas
shape outside a canvas block produces a compile error.

## Multi-expression control flow

Inside container and canvas do-blocks, `if`, `case`, `for`, `cond`,
`with`, and `unless` preserve all expressions from each branch:

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

Normally, Elixir's block semantics discard all but the last expression.
The DSL macros wrap multi-expression branches in lists so all values
contribute to the parent's children list. Single-branch `if` (without
`else`) returns `nil`, which is filtered out automatically.

## Prop partitioning

Container do-blocks can mix option declarations with children. The
macro system partitions them at build time:

1. Bare calls like `spacing 8` become `{:__widget_prop__, :spacing, 8}`
   tuples
2. Everything else is a child widget
3. Prop tuples are extracted and merged with keyword arguments from the
   call line
4. Block values override keyword values on conflict

This partitioning is invisible to the user. You just write options
and children in any order inside the block.

## Animation macros

The DSL includes macros for declaring renderer-side animations as prop
values:

```elixir
container "panel", max_width: transition(300, to: 200, easing: :ease_out) do
  text("content", "Animated panel")
end
```

| Macro | Creates | Purpose |
|---|---|---|
| `transition(duration, opts)` | `Plushie.Animation.Transition` | Timed transition with easing |
| `loop(duration, opts)` | `Plushie.Animation.Transition` | Repeating transition (auto-reverse by default) |
| `spring(opts)` | `Plushie.Animation.Spring` | Physics-based spring animation |
| `sequence(steps)` | `Plushie.Animation.Sequence` | Chain of transitions and springs |

All support keyword, pipeline, and do-block forms:

```elixir
# Keyword
max_width: transition(300, to: 200, easing: :ease_out)

# Do-block
max_width: transition 300 do
  to 200
  easing :ease_out
end

# Pipeline
alias Plushie.Animation.Transition
max_width: Transition.new(300, to: 200) |> Transition.easing(:ease_out)
```

See the [Animation reference](animation.md) for the full animation
system.

## Do-block types

Types that participate in the do-block syntax implement three
functions:

| Function | Purpose |
|---|---|
| `from_opts/1` | Construct struct from keyword list |
| `__field_keys__/0` | Valid field names (for compile-time validation) |
| `__field_types__/0` | Map of field names to nested struct modules |

`__field_types__/0` enables recursive nesting. When a field maps to a
module that exports these functions, that field can be specified as a
nested do-block:

```elixir
container "card" do
  border do          # Border supports do-block syntax
    color "#e5e7eb"
    width 1
    rounded 8
  end
  shadow do          # Shadow supports do-block syntax
    color "#0000001a"
    offset 0, 2
    blur_radius 4
  end
end
```

### Modules supporting do-block syntax

**Styling types**: `Plushie.Type.A11y`, `Plushie.Type.Border`,
`Plushie.Type.Font`, `Plushie.Type.Padding`, `Plushie.Type.Shadow`,
`Plushie.Type.StyleMap`

**Animation descriptors**: `Plushie.Animation.Transition`,
`Plushie.Animation.Spring`

**Canvas property types**: `Plushie.Canvas.Stroke`,
`Plushie.Canvas.Dash`, `Plushie.Canvas.DragBounds`,
`Plushie.Canvas.HitRect`, `Plushie.Canvas.ShapeStyle`,
`Plushie.Canvas.Gradient`

## Programmatic struct API

Every widget has a typed struct builder alongside the DSL macro. These
produce identical output:

```elixir
# DSL macro
column spacing: 8 do
  text("hello", "Hello")
end

# Struct builder
alias Plushie.Widget.{Column, Text}

Column.new("col", spacing: 8)
|> Column.push(Text.new("hello", "Hello"))
```

Widget structs can be returned directly from `view/1` or passed as
children. The runtime normalises them automatically via
`Plushie.Tree.normalize/1`. No explicit `build/1` call is needed.

Use macros in view functions for readability. Use struct builders in
helper functions, dynamic widget generation, and anywhere you prefer
working with data structures directly.

Each widget module provides:

- `new/2` - create struct from ID and options
- `with_options/2` - apply keyword options via setter functions
- Per-prop setter functions (e.g. `Column.spacing/2`, `Text.size/2`)
- `push/2`, `extend/2` - add children (container widgets only)

## Formatter configuration

Add `import_deps: [:plushie]` to your `.formatter.exs`:

```elixir
[
  import_deps: [:plushie],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]
```

This imports Plushie's `locals_without_parens` configuration, which
tells the formatter to leave parentheses off DSL macro calls. Without
it, the formatter would add parentheses to calls like `column do ...`
and `spacing 8`, breaking the visual style of the DSL.

## See also

- `Plushie.UI` - full module docs with the complete widget macro list
- [Themes and Styling](themes-and-styling.md) - do-block types for styling
- [Layout reference](windows-and-layout.md) - layout containers with full prop
  tables
- [Styling reference](themes-and-styling.md) - Border, Shadow, StyleMap, and
  their do-block syntax
- [Canvas reference](canvas.md) - canvas scope rules and shape macros
- [Animation reference](animation.md) - transition, spring, loop,
  sequence descriptors
- [Guide: Your First App](../guides/03-your-first-app.md) - DSL forms
  introduction
