defmodule ColorPickerWidget do
  @moduledoc """
  Canvas-based HSV color picker widget.

  A hue ring surrounds a saturation/value square. Drag the ring to
  select a hue; drag the square to adjust saturation and value.
  Keyboard accessible: Tab to focus cursors, arrow keys to adjust.

      ColorPickerWidget.new("picker")

  Events:
  - `{:color_picker_widget, :change}` with `%{"hue" => h, "saturation" => s, "value" => v}`
  """

  use Plushie.Widget

  widget(:color_picker_widget)
  event(:change, data: [hue: :number, saturation: :number, value: :number])

  state(hue: 0.0, saturation: 1.0, value: 1.0, drag: :none)

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

  @fine_step 1
  @coarse_step 15
  @sv_fine_step 0.01
  @sv_coarse_step 0.1

  # -- Event transformation ----------------------------------------------------

  @impl Plushie.Widget.Handler
  def handle_event(
        %Plushie.Event.WidgetEvent{type: :canvas_press, data: %{x: x, y: y, button: :left}},
        state
      ) do
    dx = x - @cx
    dy = y - @cy
    dist = :math.sqrt(dx * dx + dy * dy)

    cond do
      dist >= @inner_r and dist <= @outer_r ->
        new_state = %{state | drag: :ring, hue: hue_from_point(dx, dy)}
        {:emit, :change, hsv_data(new_state), new_state}

      in_square?(x, y) ->
        new_state = apply_sv(%{state | drag: :square}, x, y)
        {:emit, :change, hsv_data(new_state), new_state}

      true ->
        :consumed
    end
  end

  def handle_event(%Plushie.Event.WidgetEvent{type: :canvas_move, data: %{x: x, y: y}}, state) do
    case state.drag do
      :ring ->
        new_state = %{state | hue: hue_from_point(x - @cx, y - @cy)}
        {:emit, :change, hsv_data(new_state), new_state}

      :square ->
        new_state = apply_sv(state, x, y)
        {:emit, :change, hsv_data(new_state), new_state}

      :none ->
        :consumed
    end
  end

  def handle_event(%Plushie.Event.WidgetEvent{type: :canvas_release}, state) do
    {:update_state, %{state | drag: :none}}
  end

  def handle_event(
        %Plushie.Event.WidgetEvent{
          type: :canvas_element_key_press,
          id: element_id,
          data: %{key: key, modifiers: mods}
        },
        state
      ) do
    handle_key(element_id, key, mods, state)
  end

  def handle_event(_, _state), do: :consumed

  # -- Keyboard ----------------------------------------------------------------

  defp handle_key("hue-cursor", key, mods, state) do
    shift? = Plushie.KeyModifiers.shift?(mods)
    step = if shift?, do: @coarse_step, else: @fine_step

    new_hue =
      case key do
        k when k in [:arrow_right, :arrow_up] -> fmod(state.hue + step, 360.0)
        k when k in [:arrow_left, :arrow_down] -> fmod(state.hue - step + 360.0, 360.0)
        :page_up -> fmod(state.hue + @coarse_step, 360.0)
        :page_down -> fmod(state.hue - @coarse_step + 360.0, 360.0)
        :home -> 0.0
        :end -> 359.0
        _ -> state.hue
      end

    if new_hue != state.hue do
      new_state = %{state | hue: new_hue}
      {:emit, :change, hsv_data(new_state), new_state}
    else
      :consumed
    end
  end

  defp handle_key("sv-cursor", key, mods, state) do
    shift? = Plushie.KeyModifiers.shift?(mods)
    step = if shift?, do: @sv_coarse_step, else: @sv_fine_step

    {new_s, new_v} =
      case key do
        :arrow_right ->
          {clamp(state.saturation + step, 0.0, 1.0), state.value}

        :arrow_left ->
          {clamp(state.saturation - step, 0.0, 1.0), state.value}

        :arrow_up ->
          {state.saturation, clamp(state.value + step, 0.0, 1.0)}

        :arrow_down ->
          {state.saturation, clamp(state.value - step, 0.0, 1.0)}

        :page_up when shift? ->
          {clamp(state.saturation + @sv_coarse_step, 0.0, 1.0), state.value}

        :page_down when shift? ->
          {clamp(state.saturation - @sv_coarse_step, 0.0, 1.0), state.value}

        :page_up ->
          {state.saturation, clamp(state.value + @sv_coarse_step, 0.0, 1.0)}

        :page_down ->
          {state.saturation, clamp(state.value - @sv_coarse_step, 0.0, 1.0)}

        :home when shift? ->
          {0.0, state.value}

        :end when shift? ->
          {1.0, state.value}

        :home ->
          {state.saturation, 1.0}

        :end ->
          {state.saturation, 0.0}

        _ ->
          {state.saturation, state.value}
      end

    if new_s != state.saturation or new_v != state.value do
      new_state = %{state | saturation: new_s, value: new_v}
      {:emit, :change, hsv_data(new_state), new_state}
    else
      :consumed
    end
  end

  defp handle_key(_, _, _, _state), do: :consumed

  # -- Rendering ---------------------------------------------------------------

  @impl Plushie.Widget.Handler
  def render(id, _props, state) do
    import Plushie.UI

    hue = state.hue
    saturation = state.saturation
    value = state.value

    canvas id,
      width: @canvas_size,
      height: @canvas_size,
      on_press: true,
      on_release: true,
      on_move: true,
      arrow_mode: "none",
      alt: "HSV color picker",
      description:
        "Drag the ring to select a hue, drag the square to adjust saturation and value. Tab to focus cursors, use arrow keys to adjust." do
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

  # -- Hit testing -------------------------------------------------------------

  defp in_square?(x, y) do
    x >= @sq_origin and x <= @sq_origin + @sq_size and
      y >= @sq_origin and y <= @sq_origin + @sq_size
  end

  # -- Coordinate math ---------------------------------------------------------

  defp hue_from_point(dx, dy) do
    angle = :math.atan2(dy, dx)
    hue = angle + :math.pi() / 2
    hue = if hue < 0, do: hue + 2 * :math.pi(), else: hue
    hue * 180.0 / :math.pi()
  end

  defp apply_sv(state, x, y) do
    s = clamp((x - @sq_origin) / @sq_size, 0.0, 1.0)
    v = clamp(1.0 - (y - @sq_origin) / @sq_size, 0.0, 1.0)
    %{state | saturation: s, value: v}
  end

  defp clamp(val, lo, hi), do: max(lo, min(hi, val))

  defp hsv_data(state) do
    %{hue: state.hue, saturation: state.saturation, value: state.value}
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
