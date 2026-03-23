defmodule ThemeToggle do
  @moduledoc """
  Animated theme toggle with a face on the thumb.

  A toggle switch where the thumb has a drawn face. Light mode shows a
  smiley; dark mode shows the face rotated upside down. The face rotates
  during the transition.

      ThemeToggle.render("my-toggle", model.toggle_progress)

  Events: `canvas_element_click` with element_id `"switch"`.
  Drive `progress` from 0.0 (light) to 1.0 (dark) with a timer.
  """

  @track_w 64
  @track_h 32
  @thumb_r 13

  @doc "Renders the theme toggle canvas widget."
  def render(id, progress, _opts \\ []) do
    import Plushie.UI

    eased = smoothstep(progress)
    thumb_x = lerp(@track_h / 2, @track_w - @track_h / 2, eased)
    track_color = lerp_color({253, 230, 138}, {91, 33, 182}, eased)
    rotation = eased * :math.pi()
    face_color = if progress < 0.5, do: "#665500", else: "#4c1d95"

    canvas id, width: @track_w, height: @track_h do
      layer "toggle" do
        group "switch",
          on_click: true,
          cursor: "pointer",
          hit_rect: %{x: 0, y: 0, w: @track_w, h: @track_h},
          a11y: %{role: :switch, label: "Dark humor", toggled: progress >= 0.5} do
          # Track
          rect(0, 0, @track_w, @track_h, fill: track_color, radius: @track_h / 2)

          # Thumb circle
          circle(thumb_x, @track_h / 2, @thumb_r, fill: "#ffffff")

          # Face drawn inside a transform group (rotates during transition)
          group do
            translate(thumb_x, @track_h / 2)
            rotate(rotation)

            # Left eye
            circle(-3.5, -3, 2, fill: face_color)
            # Right eye
            circle(3.5, -3, 2, fill: face_color)
            # Mouth (smile drawn as a path)
            path(smile_path(), stroke: Plushie.Canvas.Shape.stroke(face_color, 2))
          end
        end
      end
    end
  end

  defp smile_path do
    alias Plushie.Canvas.Shape, as: S
    [S.move_to(-5, 1), S.line_to(-3, 5), S.line_to(3, 5), S.line_to(5, 1)]
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
end
