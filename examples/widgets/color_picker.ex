defmodule ColorPickerWidget do
  @moduledoc """
  Canvas-based HSV color picker widget.

  Renders a hue ring surrounding a saturation/value square. The ring is built
  from path segments covering the hue spectrum. The SV square uses overlapping
  linear gradients (hue-to-white horizontal, transparent-to-black vertical).
  Focusable cursor groups mark the current hue position on the ring and the
  current SV position in the square.

      ColorPickerWidget.render("picker", model.hue, model.saturation, model.value)

  Mouse events: `Plushie.Event.Canvas` with `type: :press`, `:move`, `:release`.
  The canvas reports absolute x/y coordinates so the consuming app can compute
  hue angles and SV positions from the geometry constants.

  Keyboard events: the cursor groups are focusable interactive elements. The
  canvas uses `arrow_mode: "none"` so arrow keys propagate to the app via
  `Subscription.on_key_press/1`. The app tracks focus via
  `canvas_element_focused`/`canvas_element_blurred` widget events and adjusts
  hue/saturation/value in response to arrow keys.
  """

  import Plushie.Canvas.Shape, only: [move_to: 2, line_to: 2, close: 0]

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

  @doc """
  Renders the color picker canvas.

  Returns a canvas node with interactive hue ring and SV square.
  """
  def render(id, hue, saturation, value, _opts \\ []) do
    import Plushie.UI

    canvas id,
      width: @canvas_size,
      height: @canvas_size,
      on_press: true,
      on_release: true,
      on_move: true,
      arrow_mode: "none",
      alt: "HSV color picker",
      description: "Drag the ring to select a hue, drag the square to adjust saturation and value. Tab to focus cursors, use arrow keys to adjust." do
      layer "a_ring" do
        ring_shapes()
      end

      layer "b_sv_hue" do
        sv_hue_shapes(hue)
      end

      layer "c_sv_dark" do
        sv_dark_shapes()
      end

      layer "d_cursors" do
        cursor_groups(hue, saturation, value)
      end
    end
  end

  # -- Geometry accessors (for consumers doing hit testing) --------------------

  @doc "Canvas size in pixels (square)."
  def canvas_size, do: @canvas_size

  @doc "Centre x coordinate."
  def cx, do: @cx

  @doc "Centre y coordinate."
  def cy, do: @cy

  @doc "Inner radius of the hue ring."
  def inner_r, do: @inner_r

  @doc "Outer radius of the hue ring."
  def outer_r, do: @outer_r

  @doc "Origin (top-left x and y) of the SV square."
  def sq_origin, do: @sq_origin

  @doc "Side length of the SV square."
  def sq_size, do: @sq_size

  # -- Ring layer --------------------------------------------------------------

  defp ring_shapes do
    alias Plushie.Canvas.Shape

    deg_per_segment = 360 / @segments

    for i <- 0..(@segments - 1) do
      hue_deg = i * deg_per_segment
      a1 = (hue_deg - 90) * :math.pi() / 180
      a2 = (hue_deg + deg_per_segment - 90) * :math.pi() / 180

      Shape.path(
        [
          move_to(@cx + @inner_r * :math.cos(a1), @cy + @inner_r * :math.sin(a1)),
          line_to(@cx + @outer_r * :math.cos(a1), @cy + @outer_r * :math.sin(a1)),
          line_to(@cx + @outer_r * :math.cos(a2), @cy + @outer_r * :math.sin(a2)),
          line_to(@cx + @inner_r * :math.cos(a2), @cy + @inner_r * :math.sin(a2)),
          close()
        ],
        fill: hsv_to_hex(hue_deg, 1.0, 1.0)
      )
    end
  end

  # -- SV layers ---------------------------------------------------------------

  defp sv_hue_shapes(hue) do
    alias Plushie.Canvas.Shape

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

  defp sv_dark_shapes do
    alias Plushie.Canvas.Shape

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

  # -- Cursors -----------------------------------------------------------------

  defp cursor_groups(hue, saturation, value) do
    import Plushie.UI

    angle = (hue - 90) * :math.pi() / 180
    ring_x = @cx + @mid_r * :math.cos(angle)
    ring_y = @cy + @mid_r * :math.sin(angle)

    sv_x = @sq_origin + saturation * @sq_size
    sv_y = @sq_origin + (1.0 - value) * @sq_size

    cursor_stroke = Plushie.Canvas.Shape.stroke("#333333", 2)
    focus_stroke = %{stroke: %{color: "#3b82f6", width: 3}}

    [
      group "hue-cursor",
        x: ring_x,
        y: ring_y,
        focusable: true,
        on_click: true,
        focus_style: focus_stroke,
        show_focus_ring: false,
        a11y: %{
          role: :slider,
          label: "Hue",
          value: "#{round(hue)} degrees",
          orientation: :horizontal
        } do
        circle(0, 0, @cursor_r, fill: "#ffffff", stroke: cursor_stroke)
      end,
      group "sv-cursor",
        x: sv_x,
        y: sv_y,
        focusable: true,
        on_click: true,
        focus_style: focus_stroke,
        show_focus_ring: false,
        a11y: %{
          role: :slider,
          label: "Saturation and brightness",
          value: "#{round(saturation * 100)}% saturation, #{round(value * 100)}% brightness",
          orientation: :horizontal
        } do
        circle(0, 0, @cursor_r, fill: "#ffffff", stroke: cursor_stroke)
      end
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
