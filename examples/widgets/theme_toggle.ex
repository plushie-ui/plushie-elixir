defmodule ThemeToggle do
  @moduledoc """
  Animated emoji theme toggle.

  A toggle switch where the thumb is an emoji face. Light mode shows a
  smiley; dark mode shows an upside-down imp. The emoji rotates during
  the transition.

      ThemeToggle.render("my-toggle", model.toggle_progress)

  Events: `canvas_shape_click` with shape_id `"switch"`.
  Drive `progress` from 0.0 (light) to 1.0 (dark) with a timer.
  """

  @track_w 56
  @track_h 28
  @thumb_r 11

  @doc "Renders the theme toggle canvas widget."
  def render(id, progress, _opts \\ []) do
    import Plushie.UI

    eased = smoothstep(progress)
    thumb_x = lerp(14, 42, eased)
    track_color = lerp_color({253, 230, 138}, {91, 33, 182}, eased)
    emoji = if progress < 0.5, do: "\u{1F60A}", else: "\u{1F608}"
    rotation = eased * :math.pi()

    canvas id, width: @track_w, height: @track_h do
      layer "toggle" do
        group do
          interactive "switch" do
            on_click
            cursor("pointer")
          end

          rect(0, 0, @track_w, @track_h, fill: track_color, radius: @track_h / 2)
          circle(thumb_x, @track_h / 2, @thumb_r, fill: "#ffffff")

          push_transform()
          translate(thumb_x, @track_h / 2)
          rotate(rotation)
          text(0, -1, emoji, size: 14, align_x: "center", align_y: "center")
          pop_transform()
        end
      end
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
end
