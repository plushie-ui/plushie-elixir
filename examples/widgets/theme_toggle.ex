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

  # Emits built-in :toggle; no custom event declaration needed.
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
  def handle_event(%Plushie.Event.TimerEvent{tag: :animate}, state) do
    new_progress = approach(state.progress, state.target, 0.06)
    {:update_state, %{state | progress: new_progress}}
  end

  # All other events consumed. ThemeToggle only surfaces :toggle.
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
    rotation = eased * 180
    face_color = if progress < 0.5, do: "#665500", else: "#4c1d95"

    ring_pad = 4
    cos_r = :math.cos(rotation * :math.pi() / 180)
    sin_r = :math.sin(rotation * :math.pi() / 180)
    face_cx = thumb_x
    face_cy = @track_h / 2
    {lx, ly} = face_pt(-3.5, -3.0, face_cx, face_cy, cos_r, sin_r)
    {rx, ry} = face_pt(3.5, -3.0, face_cx, face_cy, cos_r, sin_r)
    rotated_smile = Enum.map(smile_path(), fn [op, x, y] ->
      [op, face_cx + x * cos_r - y * sin_r, face_cy + x * sin_r + y * cos_r]
    end)

    canvas id,
      width: @track_w + ring_pad * 2,
      height: @track_h + ring_pad * 2,
      alt: "Theme toggle" do
      layer "toggle" do
        interactive "switch",
          x: ring_pad,
          y: ring_pad,
          on_click: true,
          cursor: "pointer",
          hit_rect: %{x: 0, y: 0, w: @track_w, h: @track_h},
          focus_ring_radius: @track_h / 2 + ring_pad,
          a11y: %{role: :switch, label: "Dark humor", toggled: progress >= 0.5} do
          rect(0, 0, @track_w, @track_h, fill: track_color, radius: @track_h / 2)
          circle(thumb_x, @track_h / 2, @thumb_r, fill: "#ffffff")
          circle(lx, ly, 2, fill: face_color)
          circle(rx, ry, 2, fill: face_color)
          path(rotated_smile, stroke: Plushie.Canvas.Shape.stroke(face_color, 2))
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

  defp face_pt(px, py, cx, cy, cos_r, sin_r) do
    {cx + px * cos_r - py * sin_r, cy + px * sin_r + py * cos_r}
  end

  defp smile_path do
    alias Plushie.Canvas.Shape, as: S
    [S.move_to(-5, 1), S.line_to(-3, 5), S.line_to(3, 5), S.line_to(5, 1)]
  end
end
