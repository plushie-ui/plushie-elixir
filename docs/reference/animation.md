# Animation Reference

Plushie provides two animation systems: renderer-side transitions
(the primary approach) and SDK-side animation (for complex cases).

See [guide chapter 9](../guides/09-animation.md) for a tutorial
introduction.

## Renderer-side transitions

Declared in `view/1` as prop values. The renderer handles
interpolation locally -- zero wire traffic during animation.

### `Plushie.Animation.Transition`

Timed transition with easing. See `Plushie.Animation.Transition`.

```elixir
transition(300, to: 0.0)
transition(300, to: 0.0, easing: :ease_out, delay: 100)
transition(to: 0.0, duration: 300)  # all keyword
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `to:` | term | required | Target value |
| `duration:` | pos_integer | required | Milliseconds |
| `easing:` | easing | `:ease_in_out` | Easing curve |
| `delay:` | non_neg_integer | 0 | Delay before start (ms) |
| `from:` | term | nil | Explicit start value (enter animations) |
| `repeat:` | integer \| `:forever` | nil | Repeat count |
| `auto_reverse:` | boolean | false | Reverse on each cycle |
| `on_complete:` | atom | nil | Completion event tag |

### `loop/1` and `loop/2`

Sugar for repeating transitions. Sets `repeat: :forever` and
`auto_reverse: true` by default. Requires `from:`.

```elixir
loop(800, to: 0.4, from: 1.0)
loop(800, to: 0.4, from: 1.0, cycles: 3)
```

### `Plushie.Animation.Spring`

Physics-based spring. See `Plushie.Animation.Spring`.

```elixir
spring(to: 1.05, preset: :bouncy)
spring(to: 1.05, stiffness: 200, damping: 20)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `to:` | term | required | Target value |
| `from:` | term | nil | Explicit start value |
| `stiffness:` | number | 100 | Spring constant |
| `damping:` | number | 10 | Friction |
| `mass:` | number | 1.0 | Mass |
| `velocity:` | number | 0.0 | Initial velocity |
| `preset:` | atom | nil | Named preset |
| `on_complete:` | atom | nil | Completion event tag |

Presets: `:gentle`, `:snappy`, `:bouncy`, `:stiff`, `:molasses`.

### `Plushie.Animation.Sequence`

Sequential chain. See `Plushie.Animation.Sequence`.

```elixir
sequence([
  transition(200, to: 1.0, from: 0.0),
  transition(300, to: 0.0)
])
```

Each step's `from` defaults to the previous step's final value.

## Easing catalogue

See `Plushie.Animation.Easing` for all functions. Available as
atoms for transitions or as functions for SDK-side animation.

### Standard curves

| Easing | Description |
|--------|-------------|
| `:linear` | Constant velocity |
| `:ease_in` | Sine, gentle acceleration |
| `:ease_out` | Sine, gentle deceleration |
| `:ease_in_out` | Sine, both (default) |

### Power curves

| Easing | Description |
|--------|-------------|
| `:ease_in_quad` | Quadratic acceleration |
| `:ease_out_quad` | Quadratic deceleration |
| `:ease_in_out_quad` | Quadratic both |
| `:ease_in_cubic` | Cubic |
| `:ease_out_cubic` | |
| `:ease_in_out_cubic` | |
| `:ease_in_quart` | Quartic |
| `:ease_out_quart` | |
| `:ease_in_out_quart` | |
| `:ease_in_quint` | Quintic |
| `:ease_out_quint` | |
| `:ease_in_out_quint` | |

### Exponential and circular

| Easing | Description |
|--------|-------------|
| `:ease_in_expo` | Very sharp acceleration |
| `:ease_out_expo` | Very sharp deceleration |
| `:ease_in_out_expo` | |
| `:ease_in_circ` | Circular arc |
| `:ease_out_circ` | |
| `:ease_in_out_circ` | |

### Overshoot curves

| Easing | Description |
|--------|-------------|
| `:ease_in_back` | Pulls back before accelerating |
| `:ease_out_back` | Overshoots then settles |
| `:ease_in_out_back` | Both |
| `:ease_in_elastic` | Oscillating with exponential decay |
| `:ease_out_elastic` | |
| `:ease_in_out_elastic` | |
| `:ease_in_bounce` | Bouncing ball effect |
| `:ease_out_bounce` | |
| `:ease_in_out_bounce` | |

### Custom cubic bezier

```elixir
easing: {:cubic_bezier, 0.25, 0.1, 0.25, 1.0}
```

Control points match the CSS `cubic-bezier()` function.

## Exit animations

The `exit:` prop defines transition descriptors applied when a
widget is removed from the tree:

```elixir
container item.id,
  exit: [max_width: transition(200, to: 0)] do
  text(item.id <> "-name", item.name)
end
```

The renderer keeps the widget visible during the exit animation
(as a "ghost" in layout flow), then removes it when all exit
transitions complete.

## Interruption

When a transition target changes mid-animation, the renderer
smoothly redirects from the current interpolated value to the
new target. For springs, velocity is preserved for natural
momentum.

A raw value (no `transition()` wrapper) cancels any active
animation and snaps to the value immediately.

## Accessibility

When the OS reports `prefers-reduced-motion`, the renderer
treats all transition descriptors as instant. Animations skip
to their target values. Exit ghosts are removed immediately.

## Completion events

Transitions with `on_complete:` emit a `%WidgetEvent{}`:

```elixir
max_width: transition(300, to: 0, on_complete: :collapsed)
```

```elixir
def update(model, %WidgetEvent{type: :transition_complete, data: %{tag: :collapsed}}) do
  # animation finished
end
```

## SDK-side animation

`Plushie.Animation` provides model-level animation for cases
that need frame-by-frame control. See `Plushie.Animation`.

```elixir
Animation.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
Animation.spring(from: 0.0, to: 1.0, stiffness: 200, damping: 20)
```

Key functions: `start/2`, `start_once/2`, `advance/2`,
`redirect/2`, `value/1`, `finished?/1`, `running?/1`.

Requires `Subscription.on_animation_frame(:frame)` and manual
advancement in `update/2`.

## Testing

In mock mode, transition descriptors resolve to their target
value instantly. Tests work without animation awareness.

For animation-specific tests, use headless mode with
`advance_frame/1`:

```elixir
@tag backend: :headless
test "panel animates width" do
  click("#toggle")
  advance_frame(150)
  panel = find!("#panel")
  assert panel.props[:max_width] < 400
  advance_frame(300)
  assert find!("#panel").props[:max_width] == 200
end
```

`skip_transitions/0` advances the clock far enough to complete
any animation:

```elixir
click("#toggle")
skip_transitions()
assert find!("#panel").props[:max_width] == 200
```

## Canvas animation

Canvas shapes are not animatable via transition descriptors
(shapes are data inside canvas prop values, not individual
widgets). Use SDK-side `Plushie.Animation` with
`on_animation_frame` for canvas animation.

## See also

- [Guide: Animation and Transitions](../guides/09-animation.md)
- `Plushie.Animation.Easing` -- easing function catalogue
- `Plushie.Animation.Transition` -- transition descriptor
- `Plushie.Animation.Spring` -- spring descriptor
- `Plushie.Animation.Sequence` -- sequential chain
- `Plushie.Animation` -- SDK-side animation
