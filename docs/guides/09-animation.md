# Animation and Transitions

Your widgets are styled. Now make them move. Animation turns a
functional UI into one that feels responsive and alive. Elements
that slide, fade, and spring give the user feedback that the
interface is reacting to their actions.

Plushie's animation system is built around a key insight: the
renderer is closer to the screen than your Elixir code. By
declaring animation *intent* in `view/1` and letting the renderer
handle interpolation, you get smooth 60fps animation with zero
wire traffic. No subscriptions, no frame events, no model state.

## Transitions

A transition animates a numeric prop from its current value to
a target. Declare it inline:

```elixir
container "box", max_width: transition(300, to: 200) do
  text("hello", "Hello!")
end
```

When the target changes (say the model toggles a boolean), the
renderer smoothly interpolates from the current value to the new
target. One descriptor over the wire, then silence while the
renderer handles the rest.

```elixir
container "panel",
  max_width: transition(300, to: if(model.expanded, do: 400, else: 200)) do
  text("content", "Expandable panel")
end
```

Toggle `model.expanded` in your `update/2` and the panel width
animates smoothly.

### Options

```elixir
# Easing (default: :ease_in_out)
max_width: transition(300, to: 200, easing: :ease_out)

# Delay before starting
max_width: transition(300, to: 200, delay: 100)

# Completion event
max_width: transition(300, to: 200, on_complete: :panel_resized)
```

See `Plushie.Animation.Easing` for the full catalogue of 31
easing curves plus cubic bezier support.

## Enter animations

Use `from:` to animate a prop when a widget first appears:

```elixir
container "item",
  max_width: transition(200, to: 300, from: 0) do
  text("name", item.name)
end
```

On mount, the renderer starts at `from: 0` and animates to
`to: 300`. On subsequent renders, `from:` is ignored and the
animation runs from the current value.

### Staggered enter

Delay each item in a list for a cascade effect:

```elixir
for {item, i} <- Enum.with_index(model.items) do
  container item.id,
    max_width: transition(200, to: 300, from: 0, delay: i * 50) do
    text(item.id <> "-name", item.name)
  end
end
```

## Looping animations

`loop` cycles between two values:

```elixir
# Pulse forever
max_width: loop(800, to: 250, from: 300)

# Finite: 3 cycles
max_width: loop(800, to: 250, from: 300, cycles: 3)
```

By default, loops auto-reverse (ping-pong). For continuous
forward motion (like a spinner rotation):

```elixir
rotation: loop(1000, to: 360, from: 0, auto_reverse: false)
```

## Springs

Springs use physics simulation instead of timed curves. They
have no fixed duration. They settle naturally based on
stiffness and damping:

```elixir
# Using a preset
scale: spring(to: 1.05, preset: :bouncy)

# Custom parameters
scale: spring(to: 1.05, stiffness: 200, damping: 20)
```

Springs handle interruption gracefully. If the target changes
mid-animation, the spring preserves velocity and smoothly
redirects. This makes them ideal for interactive elements.

### Presets

| Preset | Feel |
|--------|------|
| `:gentle` | Slow, smooth, no overshoot |
| `:snappy` | Quick, minimal overshoot |
| `:bouncy` | Quick with visible overshoot |
| `:stiff` | Very quick, crisp stop |
| `:molasses` | Slow, heavy, deliberate |

## Sequences

Chain animations that play one after another:

```elixir
max_width: sequence([
  transition(200, to: 300, from: 0),
  loop(800, to: 250, from: 300, cycles: 3),
  transition(300, to: 0)
])
```

Each step's starting value defaults to the previous step's
ending value.

## Three DSL forms

Like all Plushie DSL, transitions support keyword, pipeline,
and do-block forms:

```elixir
# Keyword
max_width: transition(300, to: 200, easing: :ease_out)

# Pipeline
alias Plushie.Animation.Transition
max_width: Transition.new(300, to: 200) |> Transition.easing(:ease_out)

# Do-block
max_width: transition 300 do
  to 200
  easing :ease_out
end
```

## Reusable helpers

Define common animation patterns as private functions:

```elixir
defp fade_in(to, delay \\ 0) do
  transition(200, to: to, from: 0, easing: :ease_out, delay: delay)
end

defp slide_in(to, delay \\ 0) do
  transition(300, to: to, from: 20, easing: :ease_out, delay: delay)
end
```

This is plain Elixir, no framework feature, just functions
returning structs.

## SDK-side animation

For complex cases that need frame-by-frame control (canvas
animations, physics simulations, chained model updates), use
`Plushie.Animation.Tween`:

```elixir
anim = Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
```

This requires a subscription for frame events (covered in the
[next chapter](10-subscriptions.md)) and manual advancement in
`update/2`. See `Plushie.Animation.Tween` and the
[animation reference](../reference/animation.md) for details.

For most property animations, renderer-side transitions are
simpler and more performant.

## Applying it: animated pad

Add a staggered entrance to the file list. Each file fades in with a
slight delay, creating a cascade effect when the pad starts or new files
are created:

```elixir
# In file_list, wrap each file entry:
for {file, i} <- Enum.with_index(model.files) do
  container file, opacity: transition(200, to: 1.0, from: 0.0, delay: i * 40) do
    row spacing: 4 do
      button("select", file,
        width: :fill,
        style: if(file == model.active_file, do: :primary, else: :text)
      )
      button("delete", "x")
    end
  end
end
```

The `from: 0.0` makes each item start fully transparent and fade to
`1.0`. The `delay: i * 40` offsets each item by 40ms, so they appear
one after another. When a new file is created, it enters the tree for
the first time and gets its own entrance animation. Existing files
that are already in the tree are unaffected. `from:` only applies
on first appearance.

## Verify it

Animations resolve to their target values in mock mode, so tests
work without waiting for frames:

```elixir
test "file list renders with animation descriptors" do
  assert_exists("#hello.ex/select")
  click("#save")
  assert_text("#preview/greeting", "Hello, Plushie!")
end
```

## Try it

- Try different easing curves on the file list stagger: `:ease_out`,
  `:ease_in_out`, `:ease_out_back`.
- Add a `spring` to the preview pane width and toggle it with a button.
- Experiment with `sequence` to chain multiple animations on one prop.

---

Next: [Subscriptions](10-subscriptions.md)
