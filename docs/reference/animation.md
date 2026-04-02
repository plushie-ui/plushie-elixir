# Animation

Plushie's animation system is built around a key insight: your view is a
pure function. You can't call `element.animate()` because there's no
element to call it on. Instead, animations are **declarative prop values**. You
describe what each prop should be, and the renderer interpolates from
where it is to where you want it. Zero wire traffic, zero subscriptions,
zero model state.

This reference covers the full animation system: how it works, what you
can animate, how to choose the right animation, and how to build fluid,
responsive UIs that feel alive.

For a tutorial introduction, see [guide chapter 9](../guides/09-animation.md).

## How animation works

### The declarative model

In your `view/1`, wrap a prop value in a `transition()`, `spring()`, or
`loop()` descriptor:

```elixir
container "panel", max_width: transition(300, to: 200, easing: :ease_out) do
  text("content", "Hello")
end
```

The renderer receives this descriptor and interpolates `max_width` from
its current value to 200 over 300ms. Your Elixir code does nothing
during the animation. No subscriptions, no frame events, no model
updates. The renderer runs the interpolation locally at full frame rate.

### The from/to lifecycle

This is the core concept:

- **`to:`** is always required. It's the target value, where the prop
  should end up.
- **`from:`** only applies on **first appearance**. When a widget enters
  the tree for the first time, the renderer starts at `from:` and
  animates to `to:`. On subsequent renders, `from:` is ignored.
- **When `to:` changes** between renders, the renderer starts a new
  animation from the **current interpolated value** to the new target.
  No jump, no restart from the beginning.
- **When `to:` stays the same**, nothing happens. The prop stays at its
  target. Returning the same descriptor every render is free.

This means your view function doesn't need to know about animation
state. It just describes the desired state:

```elixir
# In view/1:
container "sidebar",
  max_width: transition(300, to: if(model.sidebar_open, do: 250, else: 0)) do
  sidebar_content(model)
end

# In update/2:
def update(model, %WidgetEvent{type: :click, id: "toggle-sidebar"}) do
  %{model | sidebar_open: not model.sidebar_open}
end
```

Toggle `sidebar_open` and the sidebar animates. Toggle again mid-animation
and it smoothly reverses from wherever it currently is. The view function
is identical every time; only the model changes.

### Zero wire traffic

Renderer-side animations send nothing over the wire while running.
The descriptor crosses the wire once (in the snapshot or patch), then
the renderer handles all interpolation locally. This makes them ideal
for remote rendering over SSH or high-latency connections. Animations
run at full frame rate regardless of network conditions.

## Animation principles

### Purpose-driven animation

Every animation should communicate something:

| Purpose | Example | Recommended |
|---|---|---|
| **Enter** | Content appears | Fade in, slide in |
| **Exit** | Content disappears | Fade out, slide out, collapse |
| **Feedback** | User action acknowledged | Scale pulse, color flash |
| **Attention** | Something needs action | Gentle pulse, bounce |
| **State change** | Value updated | Smooth transition between states |
| **Progress** | Work in progress | Loading shimmer, spinner |

If an animation doesn't serve one of these purposes, consider removing
it. Gratuitous animation is worse than no animation.

### Timing guidelines

| Context | Duration | Notes |
|---|---|---|
| Micro-interactions (hover, toggle) | 100-150ms | Fast enough to feel instant |
| Standard transitions (fade, slide) | 200-300ms | The sweet spot for most UI |
| Complex transitions (page change) | 300-500ms | Slower for large movements |
| Enter animations | 200-300ms | Users wait for content to appear |
| Exit animations | 150-200ms | Slightly faster; dismissed content should leave quickly |
| Stagger delay per item | 30-50ms | Too fast looks simultaneous, too slow looks broken |

Under 100ms is effectively instant, so you might as well skip the
animation. Over 500ms feels sluggish. For direct manipulation (dragging, resizing),
use no animation at all because the response should feel 1:1 connected
to the input. Animation is for the *response* after the interaction.

## Animatable props

Not every prop supports animation descriptors; the renderer must know
how to interpolate between values. These props are animatable:

### Numeric props

| Prop | Widgets | Purpose |
|---|---|---|
| `opacity` | Most widgets | Fade effects (0.0 transparent, 1.0 opaque) |
| `max_width` | column, row, container | Expand/collapse width |
| `max_height` | container | Expand/collapse height |
| `spacing` | column, row | Animate gaps between children |
| `scale` | Most widgets | Grow/shrink effect |
| `rotation` | text, rich_text, image | Rotate in degrees |
| `border_radius` | image, text, rich_text | Animate corner rounding |
| `size` | text, rich_text | Animate text size |
| `translate_x` | floating | Horizontal slide |
| `translate_y` | floating | Vertical slide |
| `x` | pin | Horizontal position |
| `y` | pin | Vertical position |
| `width` | slider | Slider track width |
| `height` | text_editor | Editor height |
| `value` | progress_bar | Smooth progress changes |
| `text_size`, `h1_size`, `h2_size`, `h3_size`, `code_size` | markdown | Heading/code size animation |

### Color props (planned)

The renderer has Oklch colour interpolation implemented (perceptually
uniform, shortest-hue-arc), but colour prop animation is not yet wired
to specific widgets. When enabled, colour transitions will produce
smooth, vibrant interpolation without the muddy midpoints of RGB
blending.

### Props that are NOT animatable

Width/height as Length values (`:fill`, `:shrink`, `{:fill_portion, n}`)
cannot be animated because they're layout directives, not numbers. Use
`max_width`/`max_height` for size animation. Padding sides are not
individually animatable. Boolean props (visible, clip, disabled) snap
immediately.

## Transitions

`Plushie.Animation.Transition`

Timed animations with a fixed duration and easing curve. Predictable
and coordinated. You know exactly when they'll finish.

```elixir
transition(300, to: 200)
transition(300, to: 200, easing: :ease_out, delay: 100)
transition(to: 200, duration: 300)  # all keyword
```

| Option | Type | Default | Description |
|---|---|---|---|
| `to:` | number | required | Target value |
| `duration:` | pos_integer | required | Duration in milliseconds |
| `easing:` | easing atom | `:ease_in_out` | Easing curve (see [catalogue](#easing-catalogue)) |
| `delay:` | non_neg_integer | `0` | Delay before start |
| `from:` | number | nil | Explicit start value (enter animations only) |
| `repeat:` | integer / `:forever` | nil | Repeat count |
| `auto_reverse:` | boolean | `false` | Reverse direction on each repeat |
| `on_complete:` | atom | nil | Emit completion event |

### Looping

`loop()` is sugar for repeating transitions. Sets `repeat: :forever`
and `auto_reverse: true` by default. Requires `from:` since the
animation needs a cycle range.

```elixir
# Pulse forever
opacity: loop(1500, to: 1.0, from: 0.7)

# Finite cycles
opacity: loop(800, to: 1.0, from: 0.5, cycles: 3)

# One direction only (spinner rotation)
rotation: loop(1000, to: 360, from: 0, auto_reverse: false)
```

## Springs

`Plushie.Animation.Spring`

Physics-based animations with no fixed duration. A spring pulls toward
the target with a force proportional to the distance, opposed by
friction (damping). It settles naturally when the velocity and
displacement are both near zero.

```elixir
spring(to: 1.05, preset: :bouncy)
spring(to: 200, stiffness: 200, damping: 20)
```

| Option | Type | Default | Description |
|---|---|---|---|
| `to:` | number | required | Target value |
| `from:` | number | nil | Explicit start value |
| `stiffness:` | number | 100 | How hard the spring pulls (higher = faster) |
| `damping:` | number | 10 | Friction (higher = less bounce) |
| `mass:` | number | 1.0 | Inertia (higher = slower to start/stop) |
| `velocity:` | number | 0.0 | Initial velocity |
| `preset:` | atom | nil | Named parameter set |
| `on_complete:` | atom | nil | Emit completion event |

### Presets

| Preset | Stiffness | Damping | Feel |
|---|---|---|---|
| `:gentle` | 120 | 14 | Slow, smooth, no overshoot |
| `:snappy` | 200 | 20 | Quick, minimal overshoot |
| `:bouncy` | 300 | 10 | Quick with visible bounce |
| `:stiff` | 400 | 30 | Very quick, crisp stop |
| `:molasses` | 60 | 12 | Slow, heavy, deliberate |

### Tuning by feel

Think of it physically: **stiffness** is how hard the spring pulls
toward the target. **Damping** is friction that slows it down. **Mass**
is how heavy the object is.

- More stiffness = faster, snappier
- More damping = less bounce, more controlled
- More mass = slower to start and stop, more momentum
- High stiffness + low damping = bouncy (like a rubber ball)
- Low stiffness + high damping = sluggish (like moving through honey)

## Sequences

`Plushie.Animation.Sequence`

Chain animations that play one after another on the same prop:

```elixir
max_width: sequence([
  transition(200, to: 300, from: 0),
  transition(500, to: 300),           # hold at 300 for 500ms
  transition(300, to: 0)              # collapse
])
```

Each step's starting value defaults to the previous step's ending value.
You can mix transitions and springs in a sequence. Useful for multi-phase
animations: enter, hold, exit.

## Choosing your animation

### Transition vs spring

| Use case | Choose | Why |
|---|---|---|
| Choreographed timing (page transitions, stagger) | Transition | Fixed duration, predictable coordination |
| Interactive feedback (hover, toggle, drag release) | Spring | Handles interruption gracefully, velocity carries |
| Entrance/exit | Transition | Consistent timing regardless of distance |
| Bouncy/playful | Spring with `:bouncy` | Natural overshoot without manual keyframes |
| Loading/progress | Transition with linear | Predictable rate |
| Subtle polish (micro-interactions) | Spring with `:snappy` | Fast, natural, barely noticeable |

### Easing guidance

Not just what they do, but when to use them:

- **`:ease_out`** - use for **things appearing**. They decelerate into
  their resting position, like a ball rolling to a stop. The most common
  easing for enter animations.
- **`:ease_in`** - use for **things disappearing**. They accelerate
  away, like an object falling. Rarely used alone.
- **`:ease_in_out`** - use for **things moving within the UI** (panel
  slide, tab switch). Smooth start and stop. The default for a reason.
- **`:linear`** - use for **continuous motion** (progress bars, loading
  spinners, color cycling). No acceleration feels mechanical and
  deliberate.
- **`:ease_out_back`** - use for **playful entrances**. Overshoots
  slightly then settles, adding personality.
- **`:ease_out_elastic`** - use for **attention-grabbing** effects.
  Oscillates like a struck spring. Use sparingly.
- **`:ease_out_bounce`** - use for **physics-like settling**. Like
  dropping a ball. Fun but distracting if overused.
- **`:cubic_bezier`** - use when none of the 31 presets match. Control
  points match the CSS `cubic-bezier()` function.

## Easing catalogue

31 named curves plus custom cubic bezier. Pass as atoms to `easing:`.

### Standard

| Easing | Feel |
|---|---|
| `:linear` | Constant velocity, mechanical |
| `:ease_in` | Gentle acceleration (sine) |
| `:ease_out` | Gentle deceleration (sine) |
| `:ease_in_out` | Smooth both ends (sine, default) |

### Power curves

Increasing intensity from quad to quint:

| Family | In | Out | In-out |
|---|---|---|---|
| Quadratic | `:ease_in_quad` | `:ease_out_quad` | `:ease_in_out_quad` |
| Cubic | `:ease_in_cubic` | `:ease_out_cubic` | `:ease_in_out_cubic` |
| Quartic | `:ease_in_quart` | `:ease_out_quart` | `:ease_in_out_quart` |
| Quintic | `:ease_in_quint` | `:ease_out_quint` | `:ease_in_out_quint` |

### Exponential and circular

| Family | In | Out | In-out |
|---|---|---|---|
| Exponential | `:ease_in_expo` | `:ease_out_expo` | `:ease_in_out_expo` |
| Circular | `:ease_in_circ` | `:ease_out_circ` | `:ease_in_out_circ` |

### Overshoot

| Family | In | Out | In-out |
|---|---|---|---|
| Back | `:ease_in_back` | `:ease_out_back` | `:ease_in_out_back` |
| Elastic | `:ease_in_elastic` | `:ease_out_elastic` | `:ease_in_out_elastic` |
| Bounce | `:ease_in_bounce` | `:ease_out_bounce` | `:ease_in_out_bounce` |

### Custom cubic bezier

```elixir
easing: {:cubic_bezier, 0.25, 0.1, 0.25, 1.0}
```

Control points match the
[CSS `cubic-bezier()` function](https://cubic-bezier.com/). Use
[cubic-bezier.com](https://cubic-bezier.com/) to design curves
visually.

## Exit animations

The `exit:` prop defines animations that play when a widget is removed
from the tree:

```elixir
container item.id,
  opacity: transition(200, to: 1.0, from: 0.0),
  exit: [opacity: transition(200, to: 0.0)] do
  text(item.id <> "-name", item.name)
end
```

When the widget leaves the tree, the renderer keeps it visible as a
**ghost** in layout flow and plays the exit animations. Other widgets
don't collapse into the space until the exit completes. When all exit
transitions finish, the ghost is removed.

Combine enter (`from:`) and exit (`exit:`) for full lifecycle animation:
the widget fades in when it appears, fades out when it disappears.

Multiple exit props are supported:

```elixir
exit: [
  opacity: transition(200, to: 0.0),
  max_width: transition(300, to: 0, easing: :ease_in)
]
```

## Interruption

### Target changes

When `to:` changes mid-animation, the renderer starts a new animation
from the **current interpolated value**. There's no jump, no restart
from zero. The animation seamlessly redirects.

For springs, velocity is preserved. If the sidebar is moving right
at high speed and you reverse it, the spring carries the momentum into
the new direction. This is why springs feel natural for interactive
elements because they respect physics.

### Snapping

A raw value (no `transition()` or `spring()` wrapper) cancels any
active animation and snaps to the value immediately:

```elixir
# Animated:
max_width: transition(300, to: 200)

# Snap (cancels animation):
max_width: 200
```

Use this when you need instant state changes (e.g., resetting layout
on window resize).

## Coordinating animations

### Synchronised timing

Give two widgets the same duration and easing to make them move
together:

```elixir
container "sidebar", max_width: transition(300, to: sidebar_width, easing: :ease_in_out) do
  ...
end
container "content", max_width: transition(300, to: content_width, easing: :ease_in_out) do
  ...
end
```

### Stagger

Offset each item's delay by its index:

```elixir
for {item, i} <- Enum.with_index(model.items) do
  container item.id,
    opacity: transition(200, to: 1.0, from: 0.0, delay: i * 40) do
    text(item.id <> "-name", item.name)
  end
end
```

30-50ms per item produces a cascade. Faster looks simultaneous; slower
looks broken.

### Completion chaining

Use `on_complete:` to trigger the next phase from `update/2`:

```elixir
max_width: transition(300, to: 0, on_complete: :collapsed)

def update(model, %WidgetEvent{type: :transition_complete, data: %{tag: :collapsed}}) do
  %{model | show_panel: false}  # remove from tree after collapse
end
```

## Reusable animation helpers

Define functions that return descriptors for consistent animation
across your app:

```elixir
defmodule MyApp.Motion do
  def fade_in(delay \\ 0) do
    transition(200, to: 1.0, from: 0.0, easing: :ease_out, delay: delay)
  end

  def slide_down(delay \\ 0) do
    transition(250, to: 0, from: -20, easing: :ease_out, delay: delay)
  end

  def press_scale do
    spring(to: 0.95, preset: :stiff)
  end
end

# Usage in view:
container item.id,
  opacity: Motion.fade_in(i * 40),
  translate_y: Motion.slide_down(i * 40) do
  ...
end
```

This is plain Elixir, not a framework feature. Just functions returning
structs. It creates a consistent motion language for your application.

## Accessibility

When the OS reports `prefers-reduced-motion`, the renderer treats all
transition descriptors as instant. Props snap to their target values,
exit ghosts are removed immediately. This is automatic; no code changes
needed.

This matters because some users have vestibular disorders where
large-scale motion causes physical discomfort. Reduced motion doesn't
mean no visual feedback; fades and colour changes are generally fine.
The issue is large spatial movements (slides, bounces, elastic effects).

## Performance

**Renderer-side transitions** (transition, spring, loop, sequence) cost
nothing on the Elixir side. The descriptor crosses the wire once, then
the renderer handles all frame-by-frame interpolation locally. No
update cycles, no subscriptions, no model state. Animating 100 items
with staggered transitions is free from Elixir's perspective.

**SDK-side Tween** requires `on_animation_frame` subscription (~60
events/sec), an update cycle per frame, a `view/1` call, a tree diff,
and a patch. This is real work. Use Tween only when you need the
animated value in your model (canvas drawing, animation-driven logic).

## SDK-side animation (Tween)

`Plushie.Animation.Tween`

For cases where you need frame-by-frame control in Elixir (canvas
animations, physics simulations, values that drive model logic). The
animated value lives in your model and you advance it manually.

```elixir
alias Plushie.Animation.Tween

# In init:
anim = Tween.new(from: 0.0, to: 1.0, duration: 300, easing: :ease_out)
%{anim: anim, animating: true}

# Subscribe to frame events:
def subscribe(model) do
  if model.animating do
    [Plushie.Subscription.on_animation_frame(:frame)]
  else
    []
  end
end

# Advance on each frame:
def update(model, %SystemEvent{type: :animation_frame, data: ts}) do
  anim = model.anim |> Tween.start_once(ts) |> Tween.advance(ts)

  if Tween.finished?(anim) do
    %{model | anim: nil, animating: false}
  else
    %{model | anim: anim}
  end
end

# Read the value in view:
def view(model) do
  opacity = if model.anim, do: Tween.value(model.anim), else: 1.0
  ...
end
```

Key functions: `new/1`, `spring/1`, `start/2`, `start_once/2`,
`advance/2`, `redirect/2`, `value/1`, `finished?/1`, `running?/1`.

### Canvas animation

Canvas shapes are data inside prop values, not individual widgets, so
they can't use renderer-side transition descriptors. Use Tween with
`on_animation_frame` to animate canvas content:

```elixir
canvas "gauge", width: 120, height: 70 do
  layer "needle" do
    angle = Tween.value(model.gauge_anim) * :math.pi()
    path([arc(60, 60, 50, :math.pi(), :math.pi() + angle)],
      stroke: stroke("#3b82f6", 4, cap: :round)
    )
  end
end
```

## Testing

**Mock mode** resolves transition descriptors to their target value
instantly. Tests work without animation awareness; `assert_text`
and `assert_exists` see the final state.

**Headless mode** runs real interpolation. Use `advance_frame/1` to
step through frames deterministically:

```elixir
@tag backend: :headless
test "panel animates width" do
  click("#toggle")
  advance_frame(150)
  assert find!("#panel").props[:max_width] < 400
  advance_frame(300)
  assert find!("#panel").props[:max_width] == 200
end
```

**`skip_transitions/0`** fast-forwards all in-flight transitions to
completion in one call:

```elixir
click("#toggle")
skip_transitions()
assert find!("#panel").props[:max_width] == 200
```

## Examples

### Sidebar toggle

```elixir
container "sidebar",
  max_width: transition(250, to: if(model.sidebar_open, do: 250, else: 0),
    easing: :ease_in_out),
  opacity: transition(200, to: if(model.sidebar_open, do: 1.0, else: 0.0)) do
  column padding: 16, spacing: 8 do
    for item <- model.nav_items do
      button(item.id, item.label, width: :fill, style: :text)
    end
  end
end
```

### Notification slide-in

```elixir
container toast.id,
  opacity: transition(200, to: 1.0, from: 0.0),
  translate_y: spring(to: 0, from: -30, preset: :snappy),
  exit: [opacity: transition(150, to: 0.0)] do
  text(toast.id <> "-msg", toast.text)
end
```

### Skeleton loading shimmer

```elixir
container "skeleton", background: "#f0f0f0", border_radius: 4 do
  container width: :fill, height: 16,
    opacity: loop(1200, to: 0.4, from: 1.0, easing: :ease_in_out) do
  end
end
```

### Progress bar

```elixir
progress_bar("upload", {0, 100},
  value: transition(300, to: model.upload_progress, easing: :ease_out)
)
```

### Hover scale with spring

```elixir
# Track hover state via pointer_area
pointer_area "card-hover", on_enter: true, on_exit: true, cursor: :pointer do
  container "card",
    scale: spring(to: if(model.card_hovered, do: 1.02, else: 1.0), preset: :snappy),
    shadow: ... do
    card_content(model)
  end
end
```

### Delete with exit animation

```elixir
keyed_column spacing: 4 do
  for item <- model.items do
    container item.id,
      opacity: transition(200, to: 1.0, from: 0.0, delay: 50),
      max_height: transition(200, to: 40, from: 0, delay: 50),
      exit: [
        opacity: transition(150, to: 0.0),
        max_height: transition(200, to: 0, easing: :ease_in)
      ] do
      row spacing: 8 do
        text(item.id <> "-name", item.name)
        button("delete", "x")
      end
    end
  end
end
```

Items fade and slide in on appear, fade and collapse on delete. The
keyed_column ensures the correct item animates out (not a positional
sibling).

## See also

- [Guide: Animation and Transitions](../guides/09-animation.md) -
  tutorial introduction
- `Plushie.Animation.Easing` - easing function catalogue
- `Plushie.Animation.Transition` - transition descriptor module docs
- `Plushie.Animation.Spring` - spring descriptor module docs
- `Plushie.Animation.Sequence` - sequential chain module docs
- `Plushie.Animation.Tween` - SDK-side stateful interpolator
- [Accessibility reference](accessibility.md) - `prefers-reduced-motion`
  and screen reader considerations
- [Testing reference](testing.md) - `advance_frame/1` and
  `skip_transitions/0`
- [cubic-bezier.com](https://cubic-bezier.com/) - visual curve designer
