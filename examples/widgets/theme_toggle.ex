defmodule ThemeToggle do
  @moduledoc """
  Animated theme toggle with a face on the thumb.

  A toggle switch where the thumb has a drawn face. Light mode shows a
  smiley; dark mode shows the face rotated upside down. The face rotates
  during the transition. Animation is managed internally.

      ThemeToggle.new("my-toggle")

  Events:
  - `:toggle` when the user clicks the switch
  """

  use Plushie.Widget

  widget :theme_toggle

  # Emits built-in :toggle -- no custom event declaration needed.
  # The BuiltinSpecs registry provides the spec (value: :boolean).

  state progress: 0.0, target: 0.0

  @track_w 64
  @track_h 32
  @thumb_r 13

  # -- Event transformation ----------------------------------------------------

  # Click on the switch group -> emit :toggle with the new boolean state
  # and flip the animation target so the thumb starts moving.
  @impl Plushie.Widget.Handler
  def handle_event(%Plushie.Event.WidgetEvent{type: :click, id: "switch"}, state) do
    new_target = if state.target == 0.0, do: 1.0, else: 0.0
    {:emit, :toggle, new_target >= 0.5, %{state | target: new_target}}
  end

  # Animation tick -> step progress toward the target value.
  def handle_event(%Plushie.Event.Timer{tag: :animate}, state) do
    new_progress = approach(state.progress, state.target, 0.06)
    {:update_state, %{state | progress: new_progress}}
  end

  # All other events consumed -- ThemeToggle only surfaces :toggle.
  def handle_event(_, _state), do: :consumed

  # -- Widget-scoped subscriptions ---------------------------------------------

  @impl Plushie.Widget.Handler
  def subscribe(_props, state) do
    if state.progress != state.target do
      [Plushie.Subscription.every(16, :animate)]
    else
      []
    end
  end

  # -- Rendering ---------------------------------------------------------------

  @impl Plushie.Widget.Handler
  def view(id, _props, state) do
    import Plushie.UI

    progress = state.progress
    eased = smoothstep(progress)
    thumb_x = lerp(@track_h / 2, @track_w - @track_h / 2, eased)
    track_color = lerp_color({253, 230, 138}, {91, 33, 182}, eased)
    rotation = eased * :math.pi()
    face_color = if progress < 0.5, do: "#665500", else: "#4c1d95"

    ring_pad = 4

    canvas id,
      width: @track_w + ring_pad * 2,
      height: @track_h + ring_pad * 2,
      alt: "Theme toggle" do
      layer "toggle" do
        group "switch",
          x: ring_pad,
          y: ring_pad,
          on_click: true,
          cursor: "pointer",
          hit_rect: %{x: 0, y: 0, w: @track_w, h: @track_h},
          focus_ring_radius: @track_h / 2 + ring_pad,
          a11y: %{role: :switch, label: "Dark humor", toggled: progress >= 0.5} do
          rect(0, 0, @track_w, @track_h, fill: track_color, radius: @track_h / 2)
          circle(thumb_x, @track_h / 2, @thumb_r, fill: "#ffffff")

          group do
            translate(thumb_x, @track_h / 2)
            rotate(rotation)
            circle(-3.5, -3, 2, fill: face_color)
            circle(3.5, -3, 2, fill: face_color)
            path(smile_path(), stroke: Plushie.Canvas.Shape.stroke(face_color, 2))
          end
        end
      end
    end
  end

  # -- Animation helpers -------------------------------------------------------

  defp approach(current, target, step) do
    cond do
      current < target -> min(current + step, target)
      current > target -> max(current - step, target)
      true -> current
    end
  end

  defp smoothstep(t) when t <= 0.0, do: 0.0
  defp smoothstep(t) when t >= 1.0, do: 1.0
  defp smoothstep(t), do: t * t * (3 - 2 * t)

  defp lerp(a, b, t), do: a + (b - a) * t

  defp lerp_color({r1, g1, b1}, {r2, g2, b2}, t) do
    r = round(lerp(r1, r2, t))
    g = round(lerp(g1, g2, t))
    b = round(lerp(b1, b2, t))
    "#" <> hex(r) <> hex(g) <> hex(b)
  end

  defp hex(n), do: n |> Integer.to_string(16) |> String.pad_leading(2, "0")

  defp smile_path do
    alias Plushie.Canvas.Shape, as: S
    [S.move_to(-5, 1), S.line_to(-3, 5), S.line_to(3, 5), S.line_to(5, 1)]
  end
end
