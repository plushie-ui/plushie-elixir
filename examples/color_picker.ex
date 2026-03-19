defmodule ColorPicker do
  @moduledoc """
  HSV color picker using the canvas widget as a custom interactive control.

  A hue ring surrounds a saturation/value square. Drag the ring to select
  a hue; drag the square to adjust saturation and value. The selected color
  is displayed as a swatch and hex string below the canvas.

  Demonstrates:
  - Canvas with multiple layers and per-layer invalidation
  - Path commands (ring segments) and linear gradients with alpha
  - Interactive mouse events (press/move/release) for drag tracking
  - Coordinate math for hit testing (ring vs. square regions)
  - HSV-to-hex color conversion
  """

  use Toddy.App

  import Toddy.UI

  alias Toddy.Canvas.Shape
  alias Toddy.Event.Canvas

  # -- Geometry constants ------------------------------------------------------

  @canvas_size 400
  @cx div(@canvas_size, 2)
  @cy div(@canvas_size, 2)
  @outer_r 190
  @inner_r 150
  @mid_r div(@inner_r + @outer_r, 2)
  @sq_origin 100
  @sq_size 200
  @segments 72
  @cursor_r 7

  # -- App callbacks -----------------------------------------------------------

  def init(_opts) do
    %{hue: 0.0, saturation: 1.0, value: 1.0, drag: :none}
  end

  def update(model, %Canvas{type: :press, id: "picker", x: x, y: y, button: "left"}) do
    dx = x - @cx
    dy = y - @cy
    dist = :math.sqrt(dx * dx + dy * dy)

    cond do
      dist >= @inner_r and dist <= @outer_r ->
        %{model | drag: :ring, hue: hue_from_point(dx, dy)}

      in_square?(x, y) ->
        apply_sv(%{model | drag: :square}, x, y)

      true ->
        model
    end
  end

  def update(model, %Canvas{type: :move, id: "picker", x: x, y: y}) do
    case model.drag do
      :ring -> %{model | hue: hue_from_point(x - @cx, y - @cy)}
      :square -> apply_sv(model, x, y)
      :none -> model
    end
  end

  def update(model, %Canvas{type: :release, id: "picker"}) do
    %{model | drag: :none}
  end

  def update(model, _event), do: model

  def view(model) do

    hex = hsv_to_hex(model.hue, model.saturation, model.value)
    h_int = round(model.hue)
    s_pct = round(model.saturation * 100)
    v_pct = round(model.value * 100)

    window "color_picker", title: "Color Picker" do
      column padding: 20, spacing: 16, align_x: :center do
        canvas("picker",
          width: @canvas_size,
          height: @canvas_size,
          on_press: true,
          on_release: true,
          on_move: true,
          layers: build_layers(model)
        )

        row spacing: 16, align_y: :center do
          container "swatch", width: 48, height: 48, background: hex do
          end

          column spacing: 4 do
            text("hex_display", hex, size: 18)
            text("hsv_display", "H: #{h_int}  S: #{s_pct}%  V: #{v_pct}%")
          end
        end
      end
    end
  end

  # -- Hit testing -------------------------------------------------------------

  defp in_square?(x, y) do
    x >= @sq_origin and x <= @sq_origin + @sq_size and
      y >= @sq_origin and y <= @sq_origin + @sq_size
  end

  # -- Coordinate math ---------------------------------------------------------

  defp hue_from_point(dx, dy) do
    angle = :math.atan2(dy, dx)
    # Shift so hue 0 (red) is at 12 o'clock (top, -pi/2 in screen coords)
    hue = angle + :math.pi() / 2
    hue = if hue < 0, do: hue + 2 * :math.pi(), else: hue
    hue * 180.0 / :math.pi()
  end

  defp apply_sv(model, x, y) do
    s = clamp((x - @sq_origin) / @sq_size, 0.0, 1.0)
    v = clamp(1.0 - (y - @sq_origin) / @sq_size, 0.0, 1.0)
    %{model | saturation: s, value: v}
  end

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))

  # -- Layer builders ----------------------------------------------------------

  defp build_layers(model) do
    %{
      "a_ring" => ring_layer(),
      "b_sv_hue" => sv_hue_layer(model.hue),
      "c_sv_dark" => sv_dark_layer(),
      "d_cursors" => cursors_layer(model)
    }
  end

  defp ring_layer do
    deg_per_segment = 360 / @segments

    for i <- 0..(@segments - 1) do
      hue_deg = i * deg_per_segment
      a1 = (hue_deg - 90) * :math.pi() / 180
      a2 = (hue_deg + deg_per_segment - 90) * :math.pi() / 180

      Shape.path(
        [
          Shape.move_to(@cx + @inner_r * :math.cos(a1), @cy + @inner_r * :math.sin(a1)),
          Shape.line_to(@cx + @outer_r * :math.cos(a1), @cy + @outer_r * :math.sin(a1)),
          Shape.line_to(@cx + @outer_r * :math.cos(a2), @cy + @outer_r * :math.sin(a2)),
          Shape.line_to(@cx + @inner_r * :math.cos(a2), @cy + @inner_r * :math.sin(a2)),
          Shape.close()
        ],
        fill: hsv_to_hex(hue_deg, 1.0, 1.0)
      )
    end
  end

  defp sv_hue_layer(hue) do
    hue_color = hsv_to_hex(hue, 1.0, 1.0)

    [
      Shape.rect(@sq_origin, @sq_origin, @sq_size, @sq_size,
        fill:
          Shape.linear_gradient(
            {@sq_origin, @sq_origin},
            {@sq_origin + @sq_size, @sq_origin},
            [{0.0, "#ffffff"}, {1.0, hue_color}]
          )
      )
    ]
  end

  defp sv_dark_layer do
    [
      Shape.rect(@sq_origin, @sq_origin, @sq_size, @sq_size,
        fill:
          Shape.linear_gradient(
            {@sq_origin, @sq_origin},
            {@sq_origin, @sq_origin + @sq_size},
            [{0.0, "#00000000"}, {1.0, "#000000ff"}]
          )
      )
    ]
  end

  defp cursors_layer(model) do
    angle = (model.hue - 90) * :math.pi() / 180
    ring_x = @cx + @mid_r * :math.cos(angle)
    ring_y = @cy + @mid_r * :math.sin(angle)

    sv_x = @sq_origin + model.saturation * @sq_size
    sv_y = @sq_origin + (1.0 - model.value) * @sq_size

    cursor_stroke = Shape.stroke("#333333", 2)

    [
      Shape.circle(ring_x, ring_y, @cursor_r, fill: "#ffffff", stroke: cursor_stroke),
      Shape.circle(sv_x, sv_y, @cursor_r, fill: "#ffffff", stroke: cursor_stroke)
    ]
  end

  # -- Color conversion --------------------------------------------------------

  defp hsv_to_hex(h, s, v) do
    h = fmod(h, 360.0)
    h = if h < 0, do: h + 360.0, else: h

    c = v * s
    h_sector = h / 60.0
    x = c * (1.0 - abs(fmod(h_sector, 2.0) - 1.0))
    m = v - c

    {r1, g1, b1} =
      cond do
        h_sector < 1 -> {c, x, 0.0}
        h_sector < 2 -> {x, c, 0.0}
        h_sector < 3 -> {0.0, c, x}
        h_sector < 4 -> {0.0, x, c}
        h_sector < 5 -> {x, 0.0, c}
        true -> {c, 0.0, x}
      end

    r = round((r1 + m) * 255)
    g = round((g1 + m) * 255)
    b = round((b1 + m) * 255)

    "##{hex_byte(r)}#{hex_byte(g)}#{hex_byte(b)}"
  end

  defp hex_byte(n) do
    n
    |> max(0)
    |> min(255)
    |> Integer.to_string(16)
    |> String.pad_leading(2, "0")
    |> String.downcase()
  end

  defp fmod(a, b), do: a - b * Float.floor(a / b)
end
