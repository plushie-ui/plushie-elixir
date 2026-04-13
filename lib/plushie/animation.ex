defmodule Plushie.Animation do
  @moduledoc """
  Animation system for Plushie.

  Plushie provides two animation approaches:

  ## Renderer-side descriptors (preferred)

  Declare animation intent in `view/1` and the renderer handles
  interpolation at full frame rate with zero wire traffic:

  - `Plushie.Animation.Transition` - timed transitions with easing
  - `Plushie.Animation.Spring` - physics-based spring animations
  - `Plushie.Animation.Sequence` - chained animation steps

  These are the right choice for animating widget properties (opacity,
  size, position, colour). No model state, no subscriptions needed.

  ## SDK-side tween

  `Plushie.Animation.Tween` is a stateful interpolator you manage in
  your model for frame-by-frame control. Use it for canvas animations,
  physics simulations, or values that drive model logic rather than
  widget props.

  ## Easing

  `Plushie.Animation.Easing` provides 31 named curves plus cubic
  bezier support. All animation modules accept easing as an atom
  (e.g. `:ease_out`, `:ease_in_out_bounce`).
  """
end
