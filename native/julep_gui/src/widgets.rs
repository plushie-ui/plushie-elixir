use std::collections::HashMap;

use crate::protocol::TreeNode;
use iced::widget::image::FilterMethod;
use iced::widget::keyed;
use iced::widget::scrollable::Anchor;
use iced::widget::text::{LineHeight, Wrapping};
use iced::widget::{
    button, canvas, checkbox, column, combo_box, container, grid, markdown, mouse_area, pane_grid,
    pick_list, pin, progress_bar, rich_text, row, rule, scrollable, sensor, slider, span, text,
    text_editor, text_input, toggler, tooltip, vertical_slider, Image, Space, Stack, Svg,
};
use iced::{
    alignment, font, mouse, widget, Border, Color, ContentFit, Element, Fill, Font, Length,
    Padding, Pixels, Point, Radians, Rotation, Shadow, Size, Vector,
};
use serde_json::Value;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use crate::Message;

// ---------------------------------------------------------------------------
// Widget caches
// ---------------------------------------------------------------------------

/// Bundles all per-widget caches into a single struct so render functions
/// don't need to thread 3+ separate HashMap parameters everywhere.
pub struct WidgetCaches {
    pub editor_contents: HashMap<String, text_editor::Content>,
    pub markdown_items: HashMap<String, Vec<markdown::Item>>,
    pub combo_states: HashMap<String, combo_box::State<String>>,
    pub combo_options: HashMap<String, Vec<String>>,
    pub pane_grid_states: HashMap<String, pane_grid::State<String>>,
    pub default_text_size: Option<f32>,
    pub default_font: Option<Font>,
}

impl WidgetCaches {
    pub fn new() -> Self {
        Self {
            editor_contents: HashMap::new(),
            markdown_items: HashMap::new(),
            combo_states: HashMap::new(),
            combo_options: HashMap::new(),
            pane_grid_states: HashMap::new(),
            default_text_size: None,
            default_font: None,
        }
    }

    pub fn clear(&mut self) {
        self.editor_contents.clear();
        self.markdown_items.clear();
        self.combo_states.clear();
        self.combo_options.clear();
        self.pane_grid_states.clear();
    }
}

// ---------------------------------------------------------------------------
// Cache pre-population
// ---------------------------------------------------------------------------

/// Walk the tree and ensure that every `text_editor`, `markdown`, and
/// `combo_box` node has an entry in the corresponding cache. This must be
/// called *before* `render` so that `render` can work with shared (`&`)
/// references to the caches.
pub fn ensure_caches(node: &TreeNode, caches: &mut WidgetCaches) {
    match node.type_name.as_str() {
        "text_editor" => {
            let props = node.props.as_object();
            let content_str = prop_str(props, "content").unwrap_or_default();
            caches
                .editor_contents
                .entry(node.id.clone())
                .or_insert_with(|| text_editor::Content::with_text(&content_str));
        }
        "markdown" => {
            let props = node.props.as_object();
            let content = prop_str(props, "content").unwrap_or_default();
            caches
                .markdown_items
                .entry(node.id.clone())
                .or_insert_with(|| markdown::parse(&content).collect());
        }
        "combo_box" => {
            let props = node.props.as_object();
            let options: Vec<String> = props
                .and_then(|p| p.get("options"))
                .and_then(|v| v.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(str::to_owned))
                        .collect()
                })
                .unwrap_or_default();
            let cached_options = caches.combo_options.get(&node.id);
            let options_changed = cached_options.is_none_or(|cached| *cached != options);
            if options_changed {
                caches
                    .combo_states
                    .insert(node.id.clone(), combo_box::State::new(options.clone()));
                caches.combo_options.insert(node.id.clone(), options);
            }
        }
        "pane_grid" => {
            caches
                .pane_grid_states
                .entry(node.id.clone())
                .or_insert_with(|| {
                    let child_ids: Vec<String> =
                        node.children.iter().map(|c| c.id.clone()).collect();
                    if child_ids.is_empty() {
                        let (state, _) = pane_grid::State::new("default".to_string());
                        state
                    } else if child_ids.len() == 1 {
                        let (state, _) = pane_grid::State::new(child_ids[0].clone());
                        state
                    } else {
                        let (mut state, first_pane) = pane_grid::State::new(child_ids[0].clone());
                        let mut last_pane = first_pane;
                        for id in child_ids.iter().skip(1) {
                            if let Some((new_pane, _)) =
                                state.split(pane_grid::Axis::Vertical, last_pane, id.clone())
                            {
                                last_pane = new_pane;
                            }
                        }
                        state
                    }
                });
        }
        _ => {}
    }

    for child in &node.children {
        ensure_caches(child, caches);
    }
}

// ---------------------------------------------------------------------------
// Main render dispatch
// ---------------------------------------------------------------------------

/// Map a TreeNode to an iced Element. Unknown types render as an empty container.
pub fn render<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    match node.type_name.as_str() {
        "column" => render_column(node, caches),
        "row" => render_row(node, caches),
        "text" => render_text(node, caches),
        "button" => render_button(node, caches),
        "container" => render_container(node, caches),
        "space" => render_space(node),
        "text_input" => render_text_input(node, caches),
        "checkbox" => render_checkbox(node, caches),
        "rule" => render_rule(node),
        "progress_bar" => render_progress_bar(node),
        "scrollable" => render_scrollable(node, caches),
        "window" => render_window(node, caches),
        // Native widgets
        "toggler" => render_toggler(node, caches),
        "radio" => render_radio(node, caches),
        "slider" => render_slider(node),
        "vertical_slider" => render_vertical_slider(node),
        "pick_list" => render_pick_list(node, caches),
        "combo_box" => render_combo_box(node, caches),
        "text_editor" => render_text_editor(node, caches),
        "tooltip" => render_tooltip(node, caches),
        "image" => render_image(node),
        "svg" => render_svg(node),
        "markdown" => render_markdown(node, caches),
        "stack" => render_stack(node, caches),
        "canvas" => render_canvas(node),
        "table" => render_table(node),
        // New native widgets
        "grid" => render_grid(node, caches),
        "pin" => render_pin(node, caches),
        "mouse_area" => render_mouse_area(node, caches),
        "sensor" => render_sensor(node, caches),
        "rich_text" | "rich" => render_rich_text(node, caches),
        "keyed_column" => render_keyed_column(node, caches),
        "float" => render_float(node, caches),
        "themer" => render_themer(node, caches),
        "responsive" => render_responsive(node, caches),
        "pane_grid" => render_pane_grid(node, caches),
        unknown => {
            log::warn!("unknown node type `{unknown}`, rendering as empty container");
            container(Space::new()).into()
        }
    }
}

// ---------------------------------------------------------------------------
// Child rendering helper
// ---------------------------------------------------------------------------

fn render_children<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Vec<Element<'a, Message>> {
    node.children.iter().map(|c| render(c, caches)).collect()
}

// ---------------------------------------------------------------------------
// Column
// ---------------------------------------------------------------------------

fn render_column<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_x = prop_horizontal_alignment(props, "align_x");
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches);

    let mut col = column(children)
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .height(height)
        .align_x(align_x)
        .clip(clip);

    if let Some(mw) = prop_f32(props, "max_width") {
        col = col.max_width(mw);
    }

    let elem: Element<'a, Message> = if prop_bool_default(props, "wrap", false) {
        col.wrap().into()
    } else {
        col.into()
    };

    container(elem).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

fn render_row<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_y = prop_vertical_alignment(props, "align_y");
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches);

    let r = row(children)
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .height(height)
        .align_y(align_y)
        .clip(clip);

    let max_width = prop_f32(props, "max_width");

    let elem: Element<'a, Message> = if prop_bool_default(props, "wrap", false) {
        r.wrap().into()
    } else {
        r.into()
    };

    // Row doesn't have max_width natively; wrap in a container to constrain it.
    let row_elem = if let Some(mw) = max_width {
        container(elem).max_width(mw).into()
    } else {
        elem
    };

    container(row_elem)
        .id(widget::Id::from(node.id.clone()))
        .into()
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

fn render_text<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let content = prop_str(props, "content").unwrap_or_default();
    let size = prop_f32(props, "size").or(caches.default_text_size);

    let mut t = text(content);
    if let Some(s) = size {
        t = t.size(s);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        t = t.font(f);
    }
    if let Some(c) = props.and_then(|p| p.get("color")).and_then(parse_color) {
        t = t.color(c);
    }
    if let Some(w) = value_to_length_opt(props.and_then(|p| p.get("width"))) {
        t = t.width(w);
    }
    if let Some(h) = value_to_length_opt(props.and_then(|p| p.get("height"))) {
        t = t.height(h);
    }
    if let Some(lh) = parse_line_height(props) {
        t = t.line_height(lh);
    }
    if let Some(ax) = props
        .and_then(|p| p.get("align_x"))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
    {
        t = t.align_x(ax);
    }
    if let Some(ay) = props
        .and_then(|p| p.get("align_y"))
        .and_then(|v| v.as_str())
        .and_then(value_to_vertical_alignment)
    {
        t = t.align_y(ay);
    }
    if let Some(w) = parse_wrapping(props) {
        t = t.wrapping(w);
    }
    if let Some(shaping) = parse_shaping(props) {
        t = t.shaping(shaping);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        t = match style_name.as_str() {
            "primary" => t.style(text::primary),
            "secondary" => t.style(text::secondary),
            "success" => t.style(text::success),
            "danger" => t.style(text::danger),
            "warning" => t.style(text::warning),
            _ => t.style(text::default),
        };
    }

    t.into()
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

fn render_button<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let id = node.id.clone();

    // Button can have either a text label or child content
    let child: Element<'a, Message> = if !node.children.is_empty() {
        node.children
            .first()
            .map(|c| render(c, caches))
            .unwrap_or_else(|| Space::new().into())
    } else {
        let label = prop_str(props, "label")
            .or_else(|| prop_str(props, "content"))
            .unwrap_or_default();
        text(label).into()
    };

    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let clip = prop_bool_default(props, "clip", false);
    let disabled =
        prop_bool_default(props, "disabled", false) || !prop_bool_default(props, "enabled", true);

    let mut b = button(child)
        .padding(padding)
        .width(width)
        .height(height)
        .clip(clip);

    if !disabled {
        b = b.on_press(Message::Click(id));
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        b = match style_name.as_str() {
            "primary" => b.style(button::primary),
            "secondary" => b.style(button::secondary),
            "success" => b.style(button::success),
            "warning" => b.style(button::warning),
            "danger" => b.style(button::danger),
            "text" => b.style(button::text),
            _ => b.style(button::primary),
        };
    }

    container(b).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Container
// ---------------------------------------------------------------------------

fn render_container<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let center = prop_bool_default(props, "center", false);
    let clip = prop_bool_default(props, "clip", false);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let mut c = container(child)
        .padding(padding)
        .width(width)
        .height(height)
        .clip(clip);

    if let Some(mw) = prop_f32(props, "max_width") {
        c = c.max_width(mw);
    }
    if let Some(mh) = prop_f32(props, "max_height") {
        c = c.max_height(mh);
    }

    if center {
        c = c.center(Fill);
    }

    if let Some(ax) = props
        .and_then(|p| p.get("align_x"))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
    {
        c = c.align_x(ax);
    }
    if let Some(ay) = props
        .and_then(|p| p.get("align_y"))
        .and_then(|v| v.as_str())
        .and_then(value_to_vertical_alignment)
    {
        c = c.align_y(ay);
    }

    // Inline styling via custom style closure
    let bg = props
        .and_then(|p| p.get("background"))
        .and_then(parse_background);
    let text_color = props.and_then(|p| p.get("color")).and_then(parse_color);
    let border_val = props.and_then(|p| p.get("border")).map(parse_border);
    let shadow_val = props.and_then(|p| p.get("shadow")).map(parse_shadow);
    let has_inline_style =
        bg.is_some() || text_color.is_some() || border_val.is_some() || shadow_val.is_some();

    if has_inline_style {
        c = c.style(move |_theme| {
            let mut style = container::Style {
                background: bg,
                text_color,
                ..Default::default()
            };
            if let Some(b) = border_val {
                style.border = b;
            }
            if let Some(s) = shadow_val {
                style.shadow = s;
            }
            style
        });
    }

    // Named style (overrides inline if both present)
    if let Some(style_name) = prop_str(props, "style") {
        c = match style_name.as_str() {
            "transparent" => c.style(container::transparent),
            "rounded_box" => c.style(container::rounded_box),
            "bordered_box" => c.style(container::bordered_box),
            "dark" => c.style(container::dark),
            "primary" => c.style(container::primary),
            "secondary" => c.style(container::secondary),
            "success" => c.style(container::success),
            "danger" => c.style(container::danger),
            "warning" => c.style(container::warning),
            _ => c,
        };
    }

    // Widget ID for operations targeting
    c = c.id(widget::Id::from(node.id.clone()));

    c.into()
}

// ---------------------------------------------------------------------------
// Space
// ---------------------------------------------------------------------------

fn render_space<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    Space::new().width(width).height(height).into()
}

// ---------------------------------------------------------------------------
// Scrollable
// ---------------------------------------------------------------------------

fn render_scrollable<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let spacing = prop_f32(props, "spacing");

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let direction = prop_str(props, "direction").unwrap_or_default();

    // Build scrollbar configuration from props
    let build_scrollbar = |props: Props<'_>| -> scrollable::Scrollbar {
        let mut sb = scrollable::Scrollbar::default();
        if let Some(w) = prop_f32(props, "scrollbar_width") {
            sb = sb.width(w);
        }
        if let Some(m) = prop_f32(props, "scrollbar_margin") {
            sb = sb.margin(m);
        }
        if let Some(sw) = prop_f32(props, "scroller_width") {
            sb = sb.scroller_width(sw);
        }
        sb
    };

    let sb = build_scrollbar(props);
    let mut s = match direction.as_str() {
        "horizontal" => scrollable(child).direction(scrollable::Direction::Horizontal(sb)),
        "both" => scrollable(child).direction(scrollable::Direction::Both {
            vertical: sb,
            horizontal: build_scrollbar(props),
        }),
        _ => scrollable(child).direction(scrollable::Direction::Vertical(sb)),
    };

    s = s.width(width).height(height);

    // Widget ID -- always set from node.id like other widgets
    s = s.id(widget::Id::from(node.id.clone()));

    if let Some(sp) = spacing {
        s = s.spacing(sp);
    }

    // Anchor
    if let Some(anchor_str) = prop_str(props, "anchor") {
        match anchor_str.to_ascii_lowercase().as_str() {
            "end" | "bottom" | "right" => {
                s = s.anchor_y(Anchor::End);
            }
            _ => {}
        }
    }

    // on_scroll: emit viewport data when scroll position changes
    if prop_bool_default(props, "on_scroll", false) {
        let scroll_id = node.id.clone();
        s = s.on_scroll(move |viewport| {
            let abs = viewport.absolute_offset();
            let rel = viewport.relative_offset();
            let bounds = viewport.bounds();
            let content_bounds = viewport.content_bounds();
            Message::ScrollEvent(
                scroll_id.clone(),
                abs.x,
                abs.y,
                rel.x,
                rel.y,
                bounds.width,
                bounds.height,
                content_bounds.width,
                content_bounds.height,
            )
        });
    }

    // auto_scroll: automatically scroll to show new content
    if prop_bool_default(props, "auto_scroll", false) {
        s = s.auto_scroll(true);
    }

    s.into()
}

// ---------------------------------------------------------------------------
// Window (top-level container)
// ---------------------------------------------------------------------------

fn render_window<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Fill);
    let height = prop_length(props, "height", Fill);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    container(child)
        .padding(padding)
        .width(width)
        .height(height)
        .into()
}

// ---------------------------------------------------------------------------
// Text Input
// ---------------------------------------------------------------------------

fn render_text_input<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let value = prop_str(props, "value").unwrap_or_default();
    let placeholder = prop_str(props, "placeholder").unwrap_or_default();
    let width = prop_length(props, "width", Length::Fill);
    let size = prop_f32(props, "size").or(caches.default_text_size);
    let padding = parse_padding_value(props);
    let secure = prop_bool_default(props, "secure", false);
    let id = node.id.clone();
    let has_on_submit = props.and_then(|p| p.get("on_submit")).is_some();

    let mut ti = text_input(&placeholder, &value)
        .on_input(move |v| Message::Input(id.clone(), v))
        .width(width)
        .padding(padding)
        .secure(secure);

    if let Some(s) = size {
        ti = ti.size(s);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        ti = ti.font(f);
    }
    if let Some(lh) = parse_line_height(props) {
        ti = ti.line_height(lh);
    }
    if let Some(ax) = props
        .and_then(|p| p.get("align_x"))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
    {
        ti = ti.align_x(ax);
    }

    if has_on_submit {
        let submit_id = node.id.clone();
        let submit_value = value.clone();
        ti = ti.on_submit(Message::Submit(submit_id, submit_value));
    }

    if prop_bool_default(props, "on_paste", false) {
        let paste_id = node.id.clone();
        ti = ti.on_paste(move |text| Message::Paste(paste_id.clone(), text));
    }

    if let Some(icon) = props
        .and_then(|p| p.get("icon"))
        .and_then(parse_text_input_icon)
    {
        ti = ti.icon(icon);
    }

    // Widget ID
    if let Some(id_str) = prop_str(props, "id") {
        ti = ti.id(id_str);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        ti = match style_name.as_str() {
            "default" => ti.style(text_input::default),
            _ => ti,
        };
    }

    ti.into()
}

// ---------------------------------------------------------------------------
// Checkbox
// ---------------------------------------------------------------------------

fn render_checkbox<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let label = prop_str(props, "label").unwrap_or_default();
    let checked = prop_bool_default(props, "checked", false);
    let spacing = prop_f32(props, "spacing");
    let width = prop_length(props, "width", Length::Shrink);
    let id = node.id.clone();

    let disabled = prop_bool_default(props, "disabled", false);

    let mut cb = checkbox(checked).label(label).width(width);

    if !disabled {
        cb = cb.on_toggle(move |v| Message::Toggle(id.clone(), v));
    }

    if let Some(s) = spacing {
        cb = cb.spacing(s);
    }
    if let Some(sz) = prop_f32(props, "size") {
        cb = cb.size(sz);
    }
    if let Some(ts) = prop_f32(props, "text_size").or(caches.default_text_size) {
        cb = cb.text_size(ts);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        cb = cb.font(f);
    }
    if let Some(lh) = parse_line_height(props) {
        cb = cb.text_line_height(lh);
    }
    if let Some(shaping) = parse_shaping(props) {
        cb = cb.text_shaping(shaping);
    }
    if let Some(w) = parse_wrapping(props) {
        cb = cb.text_wrapping(w);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        cb = match style_name.as_str() {
            "primary" => cb.style(checkbox::primary),
            "secondary" => cb.style(checkbox::secondary),
            "success" => cb.style(checkbox::success),
            "danger" => cb.style(checkbox::danger),
            _ => cb.style(checkbox::primary),
        };
    }

    container(cb).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Rule (horizontal/vertical divider)
// ---------------------------------------------------------------------------

fn render_rule<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let direction = prop_str(props, "direction").unwrap_or_default();

    // Thickness is the cross-axis dimension:
    // horizontal rule -> height, vertical rule -> width.
    // "thickness" is a universal alias for either.
    let thickness = if direction == "vertical" {
        prop_f32(props, "width")
    } else {
        prop_f32(props, "height")
    }
    .or_else(|| prop_f32(props, "thickness"))
    .unwrap_or(1.0);

    if direction == "vertical" {
        let mut r = rule::vertical(thickness);
        if let Some(style_name) = prop_str(props, "style") {
            r = match style_name.as_str() {
                "default" => r.style(rule::default),
                "weak" => r.style(rule::weak),
                _ => r,
            };
        }
        r.into()
    } else {
        let mut r = rule::horizontal(thickness);
        if let Some(style_name) = prop_str(props, "style") {
            r = match style_name.as_str() {
                "default" => r.style(rule::default),
                "weak" => r.style(rule::weak),
                _ => r,
            };
        }
        r.into()
    }
}

// ---------------------------------------------------------------------------
// Progress Bar
// ---------------------------------------------------------------------------

fn render_progress_bar<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let range = prop_range_f32(props);
    let value = prop_f32(props, "value").unwrap_or(0.0);
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Shrink);

    let mut pb = progress_bar(range, value).length(width).girth(height);

    if prop_bool_default(props, "vertical", false) {
        pb = pb.vertical();
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        pb = match style_name.as_str() {
            "primary" => pb.style(progress_bar::primary),
            "secondary" => pb.style(progress_bar::secondary),
            "success" => pb.style(progress_bar::success),
            "danger" => pb.style(progress_bar::danger),
            "warning" => pb.style(progress_bar::warning),
            _ => pb.style(progress_bar::primary),
        };
    }

    pb.into()
}

// ---------------------------------------------------------------------------
// Toggler
// ---------------------------------------------------------------------------

fn render_toggler<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let is_toggled = prop_bool_default(props, "is_toggled", false);
    let label = prop_str(props, "label");
    let spacing = prop_f32(props, "spacing");
    let width = prop_length(props, "width", Length::Shrink);
    let id = node.id.clone();

    let disabled = prop_bool_default(props, "disabled", false);

    let mut t = toggler(is_toggled).width(width);

    if !disabled {
        t = t.on_toggle(move |v| Message::Toggle(id.clone(), v));
    }

    if let Some(l) = label {
        t = t.label(l);
    }
    if let Some(s) = spacing {
        t = t.spacing(s);
    }
    if let Some(sz) = prop_f32(props, "size") {
        t = t.size(sz);
    }
    if let Some(ts) = prop_f32(props, "text_size").or(caches.default_text_size) {
        t = t.text_size(ts);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        t = t.font(f);
    }
    if let Some(lh) = parse_line_height(props) {
        t = t.text_line_height(lh);
    }
    if let Some(shaping) = parse_shaping(props) {
        t = t.text_shaping(shaping);
    }
    if let Some(w) = parse_wrapping(props) {
        t = t.text_wrapping(w);
    }
    if let Some(align) = props
        .and_then(|p| p.get("text_alignment"))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
    {
        t = t.text_alignment(align);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        t = match style_name.as_str() {
            "default" => t.style(toggler::default),
            _ => t,
        };
    }

    container(t).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Radio
// ---------------------------------------------------------------------------

fn render_radio<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let value = prop_str(props, "value").unwrap_or_default();
    let selected_str = prop_str(props, "selected").unwrap_or_default();
    let label = prop_str(props, "label").unwrap_or_else(|| value.clone());
    // Use "group" prop as the event ID so all radios in a group emit the same ID.
    let event_id = prop_str(props, "group").unwrap_or_else(|| node.id.clone());

    let is_selected = if value == selected_str {
        Some(0u8)
    } else {
        None
    };
    let select_value = value;

    let mut r = iced::widget::Radio::new(label, 0u8, is_selected, move |_| {
        Message::Select(event_id.clone(), select_value.clone())
    });

    if let Some(s) = prop_f32(props, "spacing") {
        r = r.spacing(s);
    }
    if let Some(w) = value_to_length_opt(props.and_then(|p| p.get("width"))) {
        r = r.width(w);
    }
    if let Some(sz) = prop_f32(props, "size") {
        r = r.size(sz);
    }
    if let Some(ts) = prop_f32(props, "text_size").or(caches.default_text_size) {
        r = r.text_size(ts);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        r = r.font(f);
    }
    if let Some(lh) = parse_line_height(props) {
        r = r.text_line_height(lh);
    }
    if let Some(shaping) = parse_shaping(props) {
        r = r.text_shaping(shaping);
    }
    if let Some(w) = parse_wrapping(props) {
        r = r.text_wrapping(w);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        r = match style_name.as_str() {
            "default" => r.style(iced::widget::radio::default),
            _ => r,
        };
    }

    container(r).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Slider
// ---------------------------------------------------------------------------

fn render_slider<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let range = prop_range_f64(props);
    let value = prop_f64(props, "value").unwrap_or(*range.start());
    let step = prop_f64(props, "step");
    let width = prop_length(props, "width", Length::Fill);
    let id = node.id.clone();
    let release_id = node.id.clone();
    let release_value = value;

    let mut s = slider(range, value, move |v| Message::Slide(id.clone(), v))
        .on_release(Message::SlideRelease(release_id, release_value))
        .width(width);

    if let Some(st) = step {
        s = s.step(st);
    }
    if let Some(d) = prop_f64(props, "default") {
        s = s.default(d);
    }
    if let Some(h) = prop_f32(props, "height") {
        s = s.height(h);
    }
    if let Some(ss) = prop_f64(props, "shift_step") {
        s = s.shift_step(ss);
    }

    // Style with optional circular handle
    let circular = prop_bool_default(props, "circular_handle", false);
    if circular {
        let radius = prop_f32(props, "handle_radius").unwrap_or(8.0);
        s = s.style(move |theme, status| {
            slider::default(theme, status).with_circular_handle(radius)
        });
    } else if let Some(style_name) = prop_str(props, "style") {
        s = match style_name.as_str() {
            "default" => s.style(slider::default),
            _ => s,
        };
    }

    container(s).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Vertical Slider
// ---------------------------------------------------------------------------

fn render_vertical_slider<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let range = prop_range_f64(props);
    let value = prop_f64(props, "value").unwrap_or(*range.start());
    let step = prop_f64(props, "step");
    let height = prop_length(props, "height", Length::Fill);
    let id = node.id.clone();
    let release_id = node.id.clone();
    let release_value = value;

    let mut s = vertical_slider(range, value, move |v| Message::Slide(id.clone(), v))
        .on_release(Message::SlideRelease(release_id, release_value))
        .height(height);

    if let Some(st) = step {
        s = s.step(st);
    }
    if let Some(d) = prop_f64(props, "default") {
        s = s.default(d);
    }
    if let Some(ss) = prop_f64(props, "shift_step") {
        s = s.shift_step(ss);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        s = match style_name.as_str() {
            "default" => s.style(vertical_slider::default),
            _ => s,
        };
    }

    container(s).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Pick List
// ---------------------------------------------------------------------------

fn render_pick_list<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let options: Vec<String> = props
        .and_then(|p| p.get("options"))
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|v| v.as_str().map(str::to_owned))
                .collect()
        })
        .unwrap_or_default();
    let selected = prop_str(props, "selected");
    let placeholder = prop_str(props, "placeholder");
    let width = prop_length(props, "width", Length::Shrink);
    let padding = parse_padding_value(props);
    let id = node.id.clone();

    let mut pl = pick_list(options, selected, move |v: String| {
        Message::Select(id.clone(), v)
    })
    .width(width)
    .padding(padding);

    if let Some(p) = placeholder {
        pl = pl.placeholder(p);
    }
    if let Some(ts) = prop_f32(props, "text_size").or(caches.default_text_size) {
        pl = pl.text_size(ts);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        pl = pl.font(f);
    }
    if let Some(mh) = prop_f32(props, "menu_height") {
        pl = pl.menu_height(mh);
    }
    if let Some(lh) = parse_line_height(props) {
        pl = pl.text_line_height(lh);
    }
    if let Some(shaping) = parse_shaping(props) {
        pl = pl.text_shaping(shaping);
    }

    if let Some(handle) = parse_pick_list_handle(props) {
        pl = pl.handle(handle);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        pl = match style_name.as_str() {
            "default" => pl.style(pick_list::default),
            _ => pl,
        };
    }

    container(pl).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Combo Box
// ---------------------------------------------------------------------------

fn render_combo_box<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let state = match caches.combo_states.get(&node.id) {
        Some(s) => s,
        None => {
            log::warn!("combo_box cache miss for id={}", node.id);
            return text("(combo_box: cache miss)").into();
        }
    };

    let props = node.props.as_object();
    let selected: Option<String> = prop_str(props, "selected");
    let placeholder = prop_str(props, "placeholder").unwrap_or_default();
    let width = prop_length(props, "width", Length::Fill);
    let padding_val = parse_padding_value(props);
    let id = node.id.clone();
    let input_id = node.id.clone();

    let mut cb = combo_box(state, &placeholder, selected.as_ref(), move |selected| {
        Message::Select(id.clone(), selected)
    })
    .width(width)
    .padding(padding_val);

    // on_input: emit Input events so Elixir can filter
    cb = cb.on_input(move |v| Message::Input(input_id.clone(), v));

    if let Some(sz) = prop_f32(props, "size").or(caches.default_text_size) {
        cb = cb.size(sz);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        cb = cb.font(f);
    }
    if let Some(lh) = parse_line_height(props) {
        cb = cb.line_height(lh);
    }
    if let Some(mh) = prop_f32(props, "menu_height") {
        cb = cb.menu_height(mh);
    }
    if let Some(icon) = props
        .and_then(|p| p.get("icon"))
        .and_then(parse_text_input_icon)
    {
        cb = cb.icon(icon);
    }
    if prop_bool_default(props, "on_option_hovered", false) {
        let hover_id = node.id.clone();
        cb = cb.on_option_hovered(move |val| Message::OptionHovered(hover_id.clone(), val));
    }

    container(cb).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Text Editor
// ---------------------------------------------------------------------------

fn render_text_editor<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let height = prop_length(props, "height", Length::Shrink);
    let placeholder = prop_str(props, "placeholder").unwrap_or_default();
    let id = node.id.clone();

    let content = match caches.editor_contents.get(&node.id) {
        Some(c) => c,
        None => {
            log::warn!("text_editor cache miss for id={}", node.id);
            return text("(text_editor: cache miss)").into();
        }
    };

    let editor_id = id;
    let mut te = text_editor(content)
        .on_action(move |action| Message::TextEditorAction(editor_id.clone(), action))
        .height(height);

    if !placeholder.is_empty() {
        te = te.placeholder(placeholder);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        te = te.font(f);
    }
    if let Some(sz) = prop_f32(props, "size").or(caches.default_text_size) {
        te = te.size(sz);
    }
    if let Some(lh) = parse_line_height(props) {
        te = te.line_height(lh);
    }
    if let Some(p) = prop_f32(props, "padding") {
        te = te.padding(p);
    }
    if let Some(minh) = prop_f32(props, "min_height") {
        te = te.min_height(minh);
    }
    if let Some(maxh) = prop_f32(props, "max_height") {
        te = te.max_height(maxh);
    }
    if let Some(w) = parse_wrapping(props) {
        te = te.wrapping(w);
    }
    // text_editor.width() takes impl Into<Pixels>, not Length
    if let Some(w) = prop_f32(props, "width") {
        te = te.width(w);
    }

    // Named style
    if let Some(style_name) = prop_str(props, "style") {
        te = match style_name.as_str() {
            "default" => te.style(text_editor::default),
            _ => te,
        };
    }

    // Widget ID for operations targeting
    te = te.id(widget::Id::from(node.id.clone()));

    te.into()
}

// ---------------------------------------------------------------------------
// Tooltip
// ---------------------------------------------------------------------------

fn render_tooltip<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let tip = prop_str(props, "tip").unwrap_or_default();
    let gap = prop_f32(props, "gap");
    let position = prop_str(props, "position")
        .map(|s| match s.to_ascii_lowercase().as_str() {
            "bottom" => tooltip::Position::Bottom,
            "left" => tooltip::Position::Left,
            "right" => tooltip::Position::Right,
            "follow_cursor" | "follow" => tooltip::Position::FollowCursor,
            _ => tooltip::Position::Top,
        })
        .unwrap_or(tooltip::Position::Top);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let mut tt = tooltip(child, text(tip), position);
    if let Some(g) = gap {
        tt = tt.gap(g);
    }

    // Tooltip padding is a single f32 value (not per-side)
    if let Some(p) = prop_f32(props, "padding") {
        tt = tt.padding(p);
    }

    let snap = prop_bool_default(props, "snap_within_viewport", true);
    tt = tt.snap_within_viewport(snap);

    // Named style (tooltip uses container::Style)
    if let Some(style_name) = prop_str(props, "style") {
        tt = match style_name.as_str() {
            "transparent" => tt.style(container::transparent),
            "rounded_box" => tt.style(container::rounded_box),
            "bordered_box" => tt.style(container::bordered_box),
            "dark" => tt.style(container::dark),
            "primary" => tt.style(container::primary),
            "secondary" => tt.style(container::secondary),
            "success" => tt.style(container::success),
            "danger" => tt.style(container::danger),
            "warning" => tt.style(container::warning),
            _ => tt,
        };
    }

    tt.into()
}

// ---------------------------------------------------------------------------
// Image
// ---------------------------------------------------------------------------

fn render_image<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let source = prop_str(props, "source").unwrap_or_default();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let content_fit = prop_content_fit(props);

    let mut img = Image::new(source).width(width).height(height);
    if let Some(cf) = content_fit {
        img = img.content_fit(cf);
    }
    if let Some(r) = prop_f32(props, "rotation") {
        img = img.rotation(Rotation::from(Radians(r.to_radians())));
    }
    if let Some(o) = prop_f32(props, "opacity") {
        img = img.opacity(o);
    }
    if let Some(br) = prop_f32(props, "border_radius") {
        img = img.border_radius(br);
    }
    if let Some(fm_str) = prop_str(props, "filter_method") {
        let fm = match fm_str.to_ascii_lowercase().as_str() {
            "nearest" => FilterMethod::Nearest,
            _ => FilterMethod::Linear,
        };
        img = img.filter_method(fm);
    }
    if let Some(expand) = prop_bool(props, "expand") {
        img = img.expand(expand);
    }
    if let Some(scale) = prop_f32(props, "scale") {
        img = img.scale(scale);
    }
    // crop: {"x": u32, "y": u32, "width": u32, "height": u32}
    if let Some(crop_obj) = props
        .and_then(|p| p.get("crop"))
        .and_then(|v| v.as_object())
    {
        let cx = crop_obj.get("x").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        let cy = crop_obj.get("y").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        let cw = crop_obj.get("width").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        let ch = crop_obj.get("height").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        img = img.crop(iced::Rectangle {
            x: cx,
            y: cy,
            width: cw,
            height: ch,
        });
    }

    img.into()
}

// ---------------------------------------------------------------------------
// SVG
// ---------------------------------------------------------------------------

fn render_svg<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let source = prop_str(props, "source").unwrap_or_default();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let content_fit = prop_content_fit(props);

    let mut s = Svg::from_path(source).width(width).height(height);
    if let Some(cf) = content_fit {
        s = s.content_fit(cf);
    }
    if let Some(r) = prop_f32(props, "rotation") {
        s = s.rotation(Rotation::from(Radians(r.to_radians())));
    }
    if let Some(o) = prop_f32(props, "opacity") {
        s = s.opacity(o);
    }

    s.into()
}

// ---------------------------------------------------------------------------
// Markdown
// ---------------------------------------------------------------------------

fn render_markdown<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let items = match caches.markdown_items.get(&node.id) {
        Some(items) => items.as_slice(),
        None => {
            log::warn!("markdown cache miss for id={}", node.id);
            return text("(markdown: cache miss)").into();
        }
    };

    // Build markdown Settings from props, falling back to theme defaults.
    let settings =
        if let Some(text_size) = prop_f32(props, "text_size").or(caches.default_text_size) {
            let mut s = markdown::Settings::with_text_size(
                text_size,
                markdown::Style::from(&iced::Theme::Dark),
            );
            if let Some(v) = prop_f32(props, "h1_size") {
                s.h1_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "h2_size") {
                s.h2_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "h3_size") {
                s.h3_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "code_size") {
                s.code_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "spacing") {
                s.spacing = Pixels(v);
            }
            s
        } else {
            let mut s = markdown::Settings::from(&iced::Theme::Dark);
            if let Some(v) = prop_f32(props, "h1_size") {
                s.h1_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "h2_size") {
                s.h2_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "h3_size") {
                s.h3_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "code_size") {
                s.code_size = Pixels(v);
            }
            if let Some(v) = prop_f32(props, "spacing") {
                s.spacing = Pixels(v);
            }
            s
        };

    let mut md: Element<'a, Message> = markdown::view(items, settings).map(Message::MarkdownUrl);

    // Wrap in container if width is specified
    if let Some(w) = value_to_length_opt(props.and_then(|p| p.get("width"))) {
        md = container(md).width(w).into();
    }

    md
}

// ---------------------------------------------------------------------------
// Stack
// ---------------------------------------------------------------------------

fn render_stack<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches);

    Stack::with_children(children)
        .width(width)
        .height(height)
        .clip(clip)
        .into()
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

fn render_grid<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let cols = props
        .and_then(|p| p.get("columns"))
        .and_then(|v| v.as_u64())
        .unwrap_or(1) as usize;
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);

    let children = render_children(node, caches);

    let mut g = grid(children).columns(cols).spacing(spacing);

    if let Some(w) = prop_f32(props, "width") {
        g = g.width(w);
    }
    if let Some(h) = prop_f32(props, "height") {
        g = g.height(h);
    }

    g.into()
}

// ---------------------------------------------------------------------------
// Pin (absolute positioning)
// ---------------------------------------------------------------------------

fn render_pin<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let x = prop_f32(props, "x").unwrap_or(0.0);
    let y = prop_f32(props, "y").unwrap_or(0.0);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    pin(child)
        .position(Point::new(x, y))
        .width(width)
        .height(height)
        .into()
}

// ---------------------------------------------------------------------------
// MouseArea
// ---------------------------------------------------------------------------

fn render_mouse_area<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let id = node.id.clone();
    let release_id = format!("{}:release", node.id);
    let middle_id = format!("{}:middle", node.id);

    mouse_area(child)
        .on_press(Message::Click(id))
        .on_release(Message::Click(release_id))
        .on_middle_press(Message::Click(middle_id))
        .into()
}

// ---------------------------------------------------------------------------
// Sensor
// ---------------------------------------------------------------------------

fn render_sensor<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    // Sensor needs a key. Use the node id.
    let id = node.id.clone();
    let show_id = node.id.clone();
    let resize_id = node.id.clone();
    let hide_id = format!("{}:hide", node.id);

    sensor(child)
        .key(id)
        .on_show(move |size| {
            Message::SensorResize(format!("{}:show", show_id), size.width, size.height)
        })
        .on_resize(move |size| Message::SensorResize(resize_id.clone(), size.width, size.height))
        .on_hide(Message::Click(hide_id))
        .into()
}

// ---------------------------------------------------------------------------
// Rich Text
// ---------------------------------------------------------------------------

fn render_rich_text<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    // spans is an array of objects: {text, size, color, font, link}
    let spans_value = props
        .and_then(|p| p.get("spans"))
        .and_then(|v| v.as_array());

    let span_list: Vec<iced::widget::text::Span<'a, String, Font>> = spans_value
        .map(|arr| {
            arr.iter()
                .map(|sv| {
                    let content = sv
                        .get("text")
                        .and_then(|v| v.as_str())
                        .unwrap_or("")
                        .to_owned();
                    let mut s = span(content);
                    if let Some(sz) = sv.get("size").and_then(|v| v.as_f64()) {
                        s = s.size(Pixels(sz as f32));
                    }
                    if let Some(c) = sv.get("color").and_then(parse_color) {
                        s = s.color(c);
                    }
                    if let Some(f) = sv.get("font") {
                        s = s.font(parse_font(f));
                    }
                    if let Some(link) = sv.get("link").and_then(|v| v.as_str()) {
                        s = s.link(link.to_owned());
                    }
                    s
                })
                .collect()
        })
        .unwrap_or_default();

    let id = node.id.clone();
    let mut rt = rich_text(span_list).width(width).height(height);

    if let Some(sz) = prop_f32(props, "size").or(caches.default_text_size) {
        rt = rt.size(sz);
    }
    let font = props
        .and_then(|p| p.get("font"))
        .map(parse_font)
        .or(caches.default_font);
    if let Some(f) = font {
        rt = rt.font(f);
    }
    if let Some(c) = props.and_then(|p| p.get("color")).and_then(parse_color) {
        rt = rt.color(c);
    }
    if let Some(lh) = parse_line_height(props) {
        rt = rt.line_height(lh);
    }

    rt = rt.on_link_click(move |link| Message::Click(format!("{}:{}", id, link)));

    rt.into()
}

// ---------------------------------------------------------------------------
// Keyed Column
// ---------------------------------------------------------------------------

fn render_keyed_column<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    let keyed_children: Vec<(u64, Element<'a, Message>)> = node
        .children
        .iter()
        .map(|c| {
            let mut hasher = DefaultHasher::new();
            c.id.hash(&mut hasher);
            let key = hasher.finish();
            let elem = render(c, caches);
            (key, elem)
        })
        .collect();

    let mut kc = keyed::Column::with_children(keyed_children);
    kc = kc
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .height(height);

    if let Some(mw) = prop_f32(props, "max_width") {
        kc = kc.max_width(mw);
    }

    kc.into()
}

// ---------------------------------------------------------------------------
// Float (floating overlay with scale/translate)
// ---------------------------------------------------------------------------

fn render_float<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let tx = prop_f32(props, "translate_x").unwrap_or(0.0);
    let ty = prop_f32(props, "translate_y").unwrap_or(0.0);

    let mut f =
        iced::widget::float(child).translate(move |_content, _viewport| Vector::new(tx, ty));

    if let Some(s) = prop_f32(props, "scale") {
        f = f.scale(s);
    }

    f.into()
}

// ---------------------------------------------------------------------------
// Themer (applies a sub-theme to child content)
// ---------------------------------------------------------------------------

fn render_themer<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let theme: Option<iced::Theme> = props
        .and_then(|p| p.get("theme"))
        .map(crate::theming::resolve_theme_only);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    iced::widget::Themer::new(theme, child).into()
}

// ---------------------------------------------------------------------------
// Responsive (container that reports its size)
// ---------------------------------------------------------------------------

fn render_responsive<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    // iced's Responsive widget takes a closure that receives Size and returns
    // an Element. Since we can't call back to Elixir within a single frame,
    // we render the children as-is and wrap in a sensor so Elixir receives
    // resize events with the actual measured size.
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Fill);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches))
        .unwrap_or_else(|| Space::new().into());

    let resize_id = node.id.clone();

    sensor(container(child).width(width).height(height))
        .key(node.id.clone())
        .on_resize(move |size| Message::SensorResize(resize_id.clone(), size.width, size.height))
        .into()
}

// ---------------------------------------------------------------------------
// PaneGrid
// ---------------------------------------------------------------------------

fn render_pane_grid<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(2.0);
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Fill);

    let state = match caches.pane_grid_states.get(&node.id) {
        Some(s) => s,
        None => return text("(pane_grid: no state)").into(),
    };

    // Pre-render children into a map keyed by julep ID. This avoids
    // lifetime issues with the PaneGrid closure borrowing both `node`
    // and `caches` simultaneously.
    let child_map: HashMap<String, Element<'a, Message>> = node
        .children
        .iter()
        .map(|c| (c.id.clone(), render(c, caches)))
        .collect();

    // We need to move child_map into the closure but PaneGrid::new
    // requires FnMut, so use a RefCell to allow mutation.
    let child_map = std::cell::RefCell::new(child_map);

    let node_id = node.id.clone();
    let node_id2 = node.id.clone();
    let node_id3 = node.id.clone();

    let mut pg = pane_grid::PaneGrid::new(state, |_pane, pane_id, _is_maximized| {
        let child_element: Element<'a, Message> = child_map
            .borrow_mut()
            .remove(pane_id)
            .unwrap_or_else(|| text(format!("(pane: {})", pane_id)).into());
        let title_bar = pane_grid::TitleBar::new(text(pane_id.clone()).size(12.0));
        pane_grid::Content::new(child_element).title_bar(title_bar)
    })
    .width(width)
    .height(height)
    .spacing(spacing);

    pg = pg.on_click(move |pane| Message::PaneClicked(node_id3.clone(), pane));
    pg = pg.on_resize(10, move |evt| Message::PaneResized(node_id.clone(), evt));
    pg = pg.on_drag(move |evt| Message::PaneDragged(node_id2.clone(), evt));

    pg.into()
}

// ---------------------------------------------------------------------------
// Canvas
// ---------------------------------------------------------------------------

#[derive(Default)]
struct CanvasState {
    cursor_position: Option<Point>,
}

struct CanvasProgram {
    shapes: Vec<Value>,
    background: Option<Color>,
    id: String,
    on_press: bool,
    on_release: bool,
    on_move: bool,
    on_scroll: bool,
}

impl CanvasProgram {
    fn is_interactive(&self) -> bool {
        self.on_press || self.on_release || self.on_move || self.on_scroll
    }
}

impl canvas::Program<Message> for CanvasProgram {
    type State = CanvasState;

    fn update(
        &self,
        state: &mut CanvasState,
        event: &iced::Event,
        bounds: iced::Rectangle,
        cursor: mouse::Cursor,
    ) -> Option<iced::widget::Action<Message>> {
        let position = cursor.position_in(bounds)?;
        state.cursor_position = Some(position);

        match event {
            iced::Event::Mouse(mouse::Event::ButtonPressed(button)) if self.on_press => {
                let btn_str = serialize_mouse_button_for_canvas(button);
                Some(iced::widget::Action::publish(Message::CanvasEvent(
                    self.id.clone(),
                    "press".to_string(),
                    position.x,
                    position.y,
                    btn_str,
                )))
            }
            iced::Event::Mouse(mouse::Event::ButtonReleased(button)) if self.on_release => {
                let btn_str = serialize_mouse_button_for_canvas(button);
                Some(iced::widget::Action::publish(Message::CanvasEvent(
                    self.id.clone(),
                    "release".to_string(),
                    position.x,
                    position.y,
                    btn_str,
                )))
            }
            iced::Event::Mouse(mouse::Event::CursorMoved { .. }) if self.on_move => {
                Some(iced::widget::Action::publish(Message::CanvasEvent(
                    self.id.clone(),
                    "move".to_string(),
                    position.x,
                    position.y,
                    String::new(),
                )))
            }
            iced::Event::Mouse(mouse::Event::WheelScrolled { delta }) if self.on_scroll => {
                let (dx, dy) = match delta {
                    mouse::ScrollDelta::Lines { x, y } => (*x, *y),
                    mouse::ScrollDelta::Pixels { x, y } => (*x, *y),
                };
                Some(iced::widget::Action::publish(Message::CanvasScroll(
                    self.id.clone(),
                    position.x,
                    position.y,
                    dx,
                    dy,
                )))
            }
            _ => None,
        }
    }

    fn draw(
        &self,
        _state: &CanvasState,
        renderer: &iced::Renderer,
        _theme: &iced::Theme,
        bounds: iced::Rectangle,
        _cursor: mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        let mut frame = canvas::Frame::new(renderer, bounds.size());

        // Background clear/fill
        if let Some(bg) = self.background {
            frame.fill_rectangle(Point::ORIGIN, bounds.size(), bg);
        }

        for shape in &self.shapes {
            let shape_type = shape.get("type").and_then(|v| v.as_str()).unwrap_or("");
            match shape_type {
                "rect" => {
                    let x = json_f32(shape, "x");
                    let y = json_f32(shape, "y");
                    let w = json_f32(shape, "w");
                    let h = json_f32(shape, "h");
                    let fill = json_color(shape, "fill");
                    frame.fill_rectangle(Point::new(x, y), Size::new(w, h), fill);
                }
                "circle" => {
                    let x = json_f32(shape, "x");
                    let y = json_f32(shape, "y");
                    let r = json_f32(shape, "r");
                    let fill = json_color(shape, "fill");
                    let circle = canvas::Path::circle(Point::new(x, y), r);
                    frame.fill(&circle, fill);
                }
                "line" => {
                    let x1 = json_f32(shape, "x1");
                    let y1 = json_f32(shape, "y1");
                    let x2 = json_f32(shape, "x2");
                    let y2 = json_f32(shape, "y2");
                    let color = json_color(shape, "fill");
                    let width = shape
                        .get("width")
                        .and_then(|v| v.as_f64())
                        .map(|v| v as f32)
                        .unwrap_or(1.0);
                    let line = canvas::Path::line(Point::new(x1, y1), Point::new(x2, y2));
                    frame.stroke(
                        &line,
                        canvas::Stroke::default()
                            .with_color(color)
                            .with_width(width),
                    );
                }
                "text" => {
                    let x = json_f32(shape, "x");
                    let y = json_f32(shape, "y");
                    let content = shape.get("content").and_then(|v| v.as_str()).unwrap_or("");
                    let fill = json_color(shape, "fill");
                    frame.fill_text(canvas::Text {
                        content: content.to_owned(),
                        position: Point::new(x, y),
                        color: fill,
                        ..canvas::Text::default()
                    });
                }
                _ => {}
            }
        }

        vec![frame.into_geometry()]
    }

    fn mouse_interaction(
        &self,
        _state: &CanvasState,
        _bounds: iced::Rectangle,
        _cursor: mouse::Cursor,
    ) -> mouse::Interaction {
        if self.is_interactive() {
            mouse::Interaction::Crosshair
        } else {
            mouse::Interaction::default()
        }
    }
}

/// Serialize a mouse button for canvas events.
fn serialize_mouse_button_for_canvas(button: &mouse::Button) -> String {
    match button {
        mouse::Button::Left => "left".to_string(),
        mouse::Button::Right => "right".to_string(),
        mouse::Button::Middle => "middle".to_string(),
        mouse::Button::Back => "back".to_string(),
        mouse::Button::Forward => "forward".to_string(),
        mouse::Button::Other(n) => format!("other_{n}"),
    }
}

fn render_canvas<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Fixed(200.0));

    let shapes: Vec<Value> = props
        .and_then(|p| p.get("shapes"))
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();

    let background = props
        .and_then(|p| p.get("background"))
        .and_then(parse_color);

    let on_press = prop_bool_default(props, "on_press", false);
    let on_release = prop_bool_default(props, "on_release", false);
    let on_move = prop_bool_default(props, "on_move", false);
    let on_scroll = prop_bool_default(props, "on_scroll", false);
    // "interactive" is a convenience flag that enables all event handlers.
    let interactive = prop_bool_default(props, "interactive", false);

    canvas(CanvasProgram {
        shapes,
        background,
        id: node.id.clone(),
        on_press: on_press || interactive,
        on_release: on_release || interactive,
        on_move: on_move || interactive,
        on_scroll: on_scroll || interactive,
    })
    .width(width)
    .height(height)
    .into()
}

/// Parse an f32 from a JSON value by key, defaulting to 0.
fn json_f32(val: &Value, key: &str) -> f32 {
    val.get(key)
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(0.0)
}

/// Parse a Color from a JSON "fill" field. Accepts "#rrggbb" hex strings;
/// defaults to white if missing or unparseable.
fn json_color(val: &Value, key: &str) -> Color {
    val.get(key).and_then(parse_color).unwrap_or(Color::WHITE)
}

// ---------------------------------------------------------------------------
// Table (composite: column/row headers + data rows)
// ---------------------------------------------------------------------------

fn render_table<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Fill);
    let show_header = prop_bool_default(props, "header", true);
    let padding_val = parse_padding_value(props);

    // "columns" is an array of {key, label} objects.
    let columns: Vec<(String, String)> = props
        .and_then(|p| p.get("columns"))
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|col| {
                    let key = col.get("key")?.as_str()?.to_owned();
                    let label = col
                        .get("label")
                        .and_then(|v| v.as_str())
                        .unwrap_or(&key)
                        .to_owned();
                    Some((key, label))
                })
                .collect()
        })
        .unwrap_or_default();

    // "rows" is an array of objects.
    let rows: Vec<&Value> = props
        .and_then(|p| p.get("rows"))
        .and_then(|v| v.as_array())
        .map(|arr| arr.iter().collect())
        .unwrap_or_default();

    if columns.is_empty() {
        return text("(empty table)").into();
    }

    let mut table_rows: Vec<Element<'a, Message>> = Vec::new();

    // Header row (conditional)
    if show_header {
        let header_cells: Vec<Element<'a, Message>> = columns
            .iter()
            .map(|(_key, label)| {
                container(text(label.clone()).size(14.0))
                    .width(Length::FillPortion(1))
                    .into()
            })
            .collect();
        let header = row(header_cells).spacing(4.0).width(Fill);
        table_rows.push(header.into());

        // Separator
        let show_separator = prop_bool_default(props, "separator", true);
        if show_separator {
            table_rows.push(rule::horizontal(1).into());
        }
    }

    // Data rows
    for data_row in &rows {
        let cells: Vec<Element<'a, Message>> = columns
            .iter()
            .map(|(key, _label)| {
                let cell_text = data_row
                    .get(key)
                    .map(|v| match v {
                        Value::String(s) => s.clone(),
                        other => other.to_string(),
                    })
                    .unwrap_or_default();
                container(text(cell_text).size(13.0))
                    .width(Length::FillPortion(1))
                    .into()
            })
            .collect();
        table_rows.push(row(cells).spacing(4.0).width(Fill).into());
    }

    scrollable(
        column(table_rows)
            .spacing(2.0)
            .width(width)
            .padding(padding_val),
    )
    .into()
}

// ---------------------------------------------------------------------------
// Prop helpers
// ---------------------------------------------------------------------------

type Props<'a> = Option<&'a serde_json::Map<String, Value>>;

fn prop_str<'a>(props: Props<'a>, key: &str) -> Option<String> {
    props?.get(key)?.as_str().map(str::to_owned)
}

fn prop_f32(props: Props<'_>, key: &str) -> Option<f32> {
    let val = props?.get(key)?;
    match val {
        Value::Number(n) => n.as_f64().map(|v| v as f32),
        Value::String(s) => s.trim().parse::<f32>().ok(),
        _ => None,
    }
}

fn prop_f64(props: Props<'_>, key: &str) -> Option<f64> {
    let val = props?.get(key)?;
    match val {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.trim().parse::<f64>().ok(),
        _ => None,
    }
}

fn prop_bool(props: Props<'_>, key: &str) -> Option<bool> {
    props?.get(key)?.as_bool()
}

/// Read a boolean prop with a default value.
fn prop_bool_default(props: Props<'_>, key: &str, default: bool) -> bool {
    prop_bool(props, key).unwrap_or(default)
}

fn prop_length(props: Props<'_>, key: &str, fallback: Length) -> Length {
    props
        .and_then(|p| p.get(key))
        .and_then(value_to_length)
        .unwrap_or(fallback)
}

fn value_to_length(val: &Value) -> Option<Length> {
    match val {
        Value::Number(n) => n
            .as_f64()
            .map(|v| v as f32)
            .filter(|v| *v >= 0.0)
            .map(Length::Fixed),
        Value::String(s) => match s.trim().to_ascii_lowercase().as_str() {
            "fill" | "full" | "expand" | "stretch" => Some(Fill),
            "shrink" | "auto" | "fit" => Some(Length::Shrink),
            other => other
                .parse::<f32>()
                .ok()
                .filter(|v| *v >= 0.0)
                .map(Length::Fixed),
        },
        Value::Object(obj) => {
            // Handle {"fill_portion": N}
            if let Some(n) = obj.get("fill_portion").and_then(|v| v.as_u64()) {
                Some(Length::FillPortion(n as u16))
            } else {
                Some(Length::Shrink)
            }
        }
        _ => None,
    }
}

/// Try to parse a length from an optional Value. Returns None if the value
/// is absent or unparseable (unlike prop_length which returns a fallback).
fn value_to_length_opt(val: Option<&Value>) -> Option<Length> {
    val.and_then(value_to_length)
}

// ---------------------------------------------------------------------------
// Padding parsing -- handles both number and object formats
// ---------------------------------------------------------------------------

/// Parse a padding value from props. Handles:
/// - `"padding": 10` -- uniform padding
/// - `"padding": {"top": 10, "right": 5, "bottom": 10, "left": 5}` -- per-side
/// - Individual `"padding_top"` etc. keys (legacy)
fn parse_padding_value(props: Props<'_>) -> Padding {
    let padding_val = props.and_then(|p| p.get("padding"));

    match padding_val {
        Some(Value::Object(obj)) => {
            let top = obj
                .get("top")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .unwrap_or(0.0)
                .max(0.0);
            let right = obj
                .get("right")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .unwrap_or(0.0)
                .max(0.0);
            let bottom = obj
                .get("bottom")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .unwrap_or(0.0)
                .max(0.0);
            let left = obj
                .get("left")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .unwrap_or(0.0)
                .max(0.0);
            Padding {
                top,
                right,
                bottom,
                left,
            }
        }
        Some(Value::Number(n)) => {
            let base = n.as_f64().map(|v| v as f32).unwrap_or(0.0).max(0.0);
            // Check for per-side overrides (legacy format)
            let top = prop_f32(props, "padding_top").unwrap_or(base);
            let right = prop_f32(props, "padding_right").unwrap_or(base);
            let bottom = prop_f32(props, "padding_bottom").unwrap_or(base);
            let left = prop_f32(props, "padding_left").unwrap_or(base);
            Padding {
                top,
                right,
                bottom,
                left,
            }
        }
        _ => {
            // No padding prop -- check legacy individual keys
            let top = prop_f32(props, "padding_top").unwrap_or(0.0);
            let right = prop_f32(props, "padding_right").unwrap_or(0.0);
            let bottom = prop_f32(props, "padding_bottom").unwrap_or(0.0);
            let left = prop_f32(props, "padding_left").unwrap_or(0.0);
            Padding {
                top,
                right,
                bottom,
                left,
            }
        }
    }
}

fn prop_horizontal_alignment(props: Props<'_>, key: &str) -> alignment::Horizontal {
    props
        .and_then(|p| p.get(key))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
        .unwrap_or(alignment::Horizontal::Left)
}

fn prop_vertical_alignment(props: Props<'_>, key: &str) -> alignment::Vertical {
    props
        .and_then(|p| p.get(key))
        .and_then(|v| v.as_str())
        .and_then(value_to_vertical_alignment)
        .unwrap_or(alignment::Vertical::Top)
}

fn value_to_horizontal_alignment(s: &str) -> Option<alignment::Horizontal> {
    match s.trim().to_ascii_lowercase().as_str() {
        "left" | "start" => Some(alignment::Horizontal::Left),
        "center" => Some(alignment::Horizontal::Center),
        "right" | "end" => Some(alignment::Horizontal::Right),
        _ => None,
    }
}

fn value_to_vertical_alignment(s: &str) -> Option<alignment::Vertical> {
    match s.trim().to_ascii_lowercase().as_str() {
        "top" | "start" => Some(alignment::Vertical::Top),
        "center" => Some(alignment::Vertical::Center),
        "bottom" | "end" => Some(alignment::Vertical::Bottom),
        _ => None,
    }
}

/// Parse a "range" prop as [min, max] into an inclusive range of f32.
fn prop_range_f32(props: Props<'_>) -> std::ops::RangeInclusive<f32> {
    props
        .and_then(|p| p.get("range"))
        .and_then(|v| v.as_array())
        .and_then(|arr| {
            let min = arr.first()?.as_f64()? as f32;
            let max = arr.get(1)?.as_f64()? as f32;
            Some(min..=max)
        })
        .unwrap_or(0.0..=100.0)
}

/// Parse a "range" prop as [min, max] into an inclusive range of f64.
fn prop_range_f64(props: Props<'_>) -> std::ops::RangeInclusive<f64> {
    props
        .and_then(|p| p.get("range"))
        .and_then(|v| v.as_array())
        .and_then(|arr| {
            let min = arr.first()?.as_f64()?;
            let max = arr.get(1)?.as_f64()?;
            Some(min..=max)
        })
        .unwrap_or(0.0..=100.0)
}

fn prop_content_fit(props: Props<'_>) -> Option<ContentFit> {
    let s = prop_str(props, "content_fit")?;
    match s.to_ascii_lowercase().as_str() {
        "contain" => Some(ContentFit::Contain),
        "cover" => Some(ContentFit::Cover),
        "fill" => Some(ContentFit::Fill),
        "none" => Some(ContentFit::None),
        "scale_down" => Some(ContentFit::ScaleDown),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Color parsing -- hex string "#rrggbb" / "#rrggbbaa" or {r,g,b,a} object
// ---------------------------------------------------------------------------

fn parse_hex_color(s: &str) -> Option<Color> {
    let s = s.strip_prefix('#').unwrap_or(s);
    if s.len() == 6 {
        let r = u8::from_str_radix(&s[0..2], 16).ok()?;
        let g = u8::from_str_radix(&s[2..4], 16).ok()?;
        let b = u8::from_str_radix(&s[4..6], 16).ok()?;
        Some(Color::from_rgb8(r, g, b))
    } else if s.len() == 8 {
        let r = u8::from_str_radix(&s[0..2], 16).ok()?;
        let g = u8::from_str_radix(&s[2..4], 16).ok()?;
        let b = u8::from_str_radix(&s[4..6], 16).ok()?;
        let a = u8::from_str_radix(&s[6..8], 16).ok()?;
        Some(Color::from_rgba8(r, g, b, a as f32 / 255.0))
    } else {
        None
    }
}

/// Parse a color from a JSON value. Accepts:
/// - A hex string: "#rrggbb" or "#rrggbbaa"
/// - An object: {"r": 0.5, "g": 0.5, "b": 0.5, "a": 1.0} (0-1 floats)
fn parse_color(value: &Value) -> Option<Color> {
    match value {
        Value::String(s) => parse_hex_color(s),
        Value::Object(obj) => {
            let r = obj.get("r").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            let g = obj.get("g").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            let b = obj.get("b").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            let a = obj.get("a").and_then(|v| v.as_f64()).unwrap_or(1.0) as f32;
            Some(Color::from_rgba(r, g, b, a))
        }
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Background parsing (color or gradient)
// ---------------------------------------------------------------------------

/// Parse a background from a JSON value. Accepts:
/// - A color string ("#rrggbb") or object ({r,g,b,a}) -> Background::Color
/// - A gradient object: {"type": "linear", "angle": 45, "stops": [{"offset": 0.0, "color": "#ff0000"}, ...]}
fn parse_background(value: &Value) -> Option<iced::Background> {
    match value {
        Value::String(_) => parse_color(value).map(iced::Background::Color),
        Value::Object(obj) => {
            match obj.get("type").and_then(|v| v.as_str()) {
                Some("linear") => {
                    let angle_deg = obj.get("angle").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                    let angle = Radians(angle_deg.to_radians());
                    let mut linear = iced::gradient::Linear::new(angle);

                    if let Some(stops) = obj.get("stops").and_then(|v| v.as_array()) {
                        for stop in stops {
                            let offset =
                                stop.get("offset").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                            let color = stop
                                .get("color")
                                .and_then(parse_color)
                                .unwrap_or(Color::TRANSPARENT);
                            linear = linear.add_stop(offset, color);
                        }
                    }

                    Some(iced::Background::Gradient(iced::Gradient::Linear(linear)))
                }
                _ => {
                    // Fall back to color object parsing ({r, g, b, a})
                    parse_color(value).map(iced::Background::Color)
                }
            }
        }
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Font parsing
// ---------------------------------------------------------------------------

/// Parse a font from a JSON value. Accepts:
/// - "default" -> Font::DEFAULT
/// - "monospace" -> Font::MONOSPACE
/// - An object with optional family, weight, style fields
fn parse_font(value: &Value) -> Font {
    match value {
        Value::String(s) => match s.to_ascii_lowercase().as_str() {
            "monospace" => Font::MONOSPACE,
            _ => Font::DEFAULT,
        },
        Value::Object(obj) => {
            let mut f = Font::DEFAULT;

            if let Some(family) = obj.get("family").and_then(|v| v.as_str()) {
                match family.to_ascii_lowercase().as_str() {
                    "monospace" | "mono" => f = Font::MONOSPACE,
                    "serif" => {
                        f.family = font::Family::Serif;
                    }
                    "cursive" => {
                        f.family = font::Family::Cursive;
                    }
                    "fantasy" => {
                        f.family = font::Family::Fantasy;
                    }
                    // Default is SansSerif
                    _ => {}
                }
            }

            if let Some(weight) = obj.get("weight").and_then(|v| v.as_str()) {
                f.weight = match weight.to_ascii_lowercase().as_str() {
                    "thin" => font::Weight::Thin,
                    "extralight" | "extra_light" => font::Weight::ExtraLight,
                    "light" => font::Weight::Light,
                    "normal" | "regular" => font::Weight::Normal,
                    "medium" => font::Weight::Medium,
                    "semibold" | "semi_bold" => font::Weight::Semibold,
                    "bold" => font::Weight::Bold,
                    "extrabold" | "extra_bold" => font::Weight::ExtraBold,
                    "black" => font::Weight::Black,
                    _ => font::Weight::Normal,
                };
            }

            if let Some(style) = obj.get("style").and_then(|v| v.as_str()) {
                f.style = match style.to_ascii_lowercase().as_str() {
                    "italic" => font::Style::Italic,
                    "oblique" => font::Style::Oblique,
                    _ => font::Style::Normal,
                };
            }

            if let Some(stretch_val) = obj.get("stretch").and_then(|v| v.as_str()) {
                f.stretch = match stretch_val.to_ascii_lowercase().as_str() {
                    "ultra_condensed" | "ultracondensed" => font::Stretch::UltraCondensed,
                    "extra_condensed" | "extracondensed" => font::Stretch::ExtraCondensed,
                    "condensed" => font::Stretch::Condensed,
                    "semi_condensed" | "semicondensed" => font::Stretch::SemiCondensed,
                    "normal" => font::Stretch::Normal,
                    "semi_expanded" | "semiexpanded" => font::Stretch::SemiExpanded,
                    "expanded" => font::Stretch::Expanded,
                    "extra_expanded" | "extraexpanded" => font::Stretch::ExtraExpanded,
                    "ultra_expanded" | "ultraexpanded" => font::Stretch::UltraExpanded,
                    _ => font::Stretch::Normal,
                };
            }

            f
        }
        _ => Font::DEFAULT,
    }
}

// ---------------------------------------------------------------------------
// Border and Shadow parsing
// ---------------------------------------------------------------------------

/// Parse a border from a JSON value.
/// Accepts: {"color": "#rrggbb", "width": 1.0, "radius": 4.0}
/// radius can be a number or [tl, tr, br, bl]
fn parse_border(value: &Value) -> Border {
    let obj = match value.as_object() {
        Some(o) => o,
        None => return Border::default(),
    };

    let color = obj
        .get("color")
        .and_then(parse_color)
        .unwrap_or(Color::TRANSPARENT);
    let width = obj
        .get("width")
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(0.0);
    let radius = match obj.get("radius") {
        Some(Value::Number(n)) => {
            let r = n.as_f64().unwrap_or(0.0) as f32;
            r.into()
        }
        Some(Value::Array(arr)) if !arr.is_empty() => {
            // Per-corner: [top_left, top_right, bottom_right, bottom_left]
            let tl = arr.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            let tr = arr.get(1).and_then(|v| v.as_f64()).unwrap_or(tl as f64) as f32;
            let br = arr.get(2).and_then(|v| v.as_f64()).unwrap_or(tl as f64) as f32;
            let bl = arr.get(3).and_then(|v| v.as_f64()).unwrap_or(tl as f64) as f32;
            iced::border::Radius {
                top_left: tl,
                top_right: tr,
                bottom_right: br,
                bottom_left: bl,
            }
        }
        Some(Value::Object(radius_obj)) => {
            // Per-corner object: {"top_left": N, "top_right": N, "bottom_right": N, "bottom_left": N}
            let tl = radius_obj
                .get("top_left")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            let tr = radius_obj
                .get("top_right")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            let br = radius_obj
                .get("bottom_right")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            let bl = radius_obj
                .get("bottom_left")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            iced::border::Radius {
                top_left: tl,
                top_right: tr,
                bottom_right: br,
                bottom_left: bl,
            }
        }
        _ => (0.0_f32).into(),
    };

    Border {
        color,
        width,
        radius,
    }
}

/// Parse a shadow from a JSON value.
/// Accepts: {"color": "#rrggbb", "offset": [x, y], "blur_radius": 5.0}
fn parse_shadow(value: &Value) -> Shadow {
    let obj = match value.as_object() {
        Some(o) => o,
        None => return Shadow::default(),
    };

    let color = obj
        .get("color")
        .and_then(parse_color)
        .unwrap_or(Color::BLACK);
    let offset = match obj.get("offset").and_then(|v| v.as_array()) {
        Some(arr) if arr.len() >= 2 => Vector::new(
            arr[0].as_f64().unwrap_or(0.0) as f32,
            arr[1].as_f64().unwrap_or(0.0) as f32,
        ),
        _ => Vector::new(0.0, 0.0),
    };
    let blur_radius = obj
        .get("blur_radius")
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(0.0);

    Shadow {
        color,
        offset,
        blur_radius,
    }
}

// ---------------------------------------------------------------------------
// Line height and wrapping parsing
// ---------------------------------------------------------------------------

/// Parse line_height prop. Accepts:
/// - A number (interpreted as relative multiplier)
/// - An object {"relative": 1.5} or {"absolute": 20}
fn parse_line_height(props: Props<'_>) -> Option<LineHeight> {
    let val = props?.get("line_height")?;
    match val {
        Value::Number(n) => {
            let v = n.as_f64()? as f32;
            Some(LineHeight::Relative(v))
        }
        Value::Object(obj) => {
            if let Some(r) = obj.get("relative").and_then(|v| v.as_f64()) {
                Some(LineHeight::Relative(r as f32))
            } else {
                obj.get("absolute")
                    .and_then(|v| v.as_f64())
                    .map(|a| LineHeight::Absolute(Pixels(a as f32)))
            }
        }
        _ => None,
    }
}

/// Parse text_shaping prop from a string.
fn parse_shaping(props: Props<'_>) -> Option<iced::widget::text::Shaping> {
    use iced::widget::text::Shaping;
    let s = prop_str(props, "text_shaping")?;
    match s.to_ascii_lowercase().as_str() {
        "basic" => Some(Shaping::Basic),
        "advanced" => Some(Shaping::Advanced),
        "auto" => Some(Shaping::Auto),
        _ => None,
    }
}

/// Parse wrapping prop from a string.
fn parse_wrapping(props: Props<'_>) -> Option<Wrapping> {
    let s = prop_str(props, "wrapping")?;
    match s.to_ascii_lowercase().as_str() {
        "none" => Some(Wrapping::None),
        "word" => Some(Wrapping::Word),
        "glyph" => Some(Wrapping::Glyph),
        "word_or_glyph" => Some(Wrapping::WordOrGlyph),
        _ => None,
    }
}

/// Parse a text_input::Icon from a JSON value.
fn parse_text_input_icon(value: &Value) -> Option<text_input::Icon<Font>> {
    let obj = value.as_object()?;

    let code_point = obj
        .get("code_point")
        .and_then(|v| v.as_str())
        .and_then(|s| s.chars().next())?;

    let font = obj.get("font").map(parse_font).unwrap_or(Font::DEFAULT);

    let size = obj
        .get("size")
        .and_then(|v| v.as_f64())
        .map(|v| Pixels(v as f32));

    let spacing = obj
        .get("spacing")
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(4.0);

    let side = match obj.get("side").and_then(|v| v.as_str()).unwrap_or("left") {
        "right" | "trailing" => text_input::Side::Right,
        _ => text_input::Side::Left,
    };

    Some(text_input::Icon {
        font,
        code_point,
        size,
        spacing,
        side,
    })
}

/// Parse a pick_list::Icon from a JSON value.
fn parse_pick_list_icon(value: &Value) -> Option<pick_list::Icon<Font>> {
    let obj = value.as_object()?;

    let code_point = obj
        .get("code_point")
        .and_then(|v| v.as_str())
        .and_then(|s| s.chars().next())?;

    let font = obj.get("font").map(parse_font).unwrap_or(Font::DEFAULT);

    let size = obj
        .get("size")
        .and_then(|v| v.as_f64())
        .map(|v| Pixels(v as f32));

    let line_height = parse_line_height(Some(obj)).unwrap_or(LineHeight::Relative(1.2));

    let shaping = parse_shaping(Some(obj)).unwrap_or(iced::widget::text::Shaping::Basic);

    Some(pick_list::Icon {
        font,
        code_point,
        size,
        line_height,
        shaping,
    })
}

/// Parse a PickList Handle from props.
fn parse_pick_list_handle(props: Props<'_>) -> Option<pick_list::Handle<Font>> {
    let handle_obj = props?.get("handle")?.as_object()?;
    let handle_type = handle_obj.get("type")?.as_str()?;

    match handle_type {
        "arrow" => {
            let size = handle_obj
                .get("size")
                .and_then(|v| v.as_f64())
                .map(|v| Pixels(v as f32));
            Some(pick_list::Handle::Arrow { size })
        }
        "static" => {
            let icon = parse_pick_list_icon(handle_obj.get("icon")?)?;
            Some(pick_list::Handle::Static(icon))
        }
        "dynamic" => {
            let closed = parse_pick_list_icon(handle_obj.get("closed")?)?;
            let open = parse_pick_list_icon(handle_obj.get("open")?)?;
            Some(pick_list::Handle::Dynamic { closed, open })
        }
        "none" => Some(pick_list::Handle::None),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// Helper: build a Props from a json! value. The value must be an object.
    fn make_props(v: &Value) -> Props<'_> {
        v.as_object()
    }

    // -- prop_f32 --

    #[test]
    fn prop_f32_returns_number() {
        let v = json!({"size": 16.0});
        assert_eq!(prop_f32(make_props(&v), "size"), Some(16.0));
    }

    #[test]
    fn prop_f32_parses_string() {
        let v = json!({"size": "24.5"});
        assert_eq!(prop_f32(make_props(&v), "size"), Some(24.5));
    }

    #[test]
    fn prop_f32_returns_none_for_missing_key() {
        let v = json!({"other": 10});
        assert_eq!(prop_f32(make_props(&v), "size"), None);
    }

    #[test]
    fn prop_f32_returns_none_for_bool() {
        let v = json!({"size": true});
        assert_eq!(prop_f32(make_props(&v), "size"), None);
    }

    // -- prop_bool --

    #[test]
    fn prop_bool_returns_true() {
        let v = json!({"visible": true});
        assert_eq!(prop_bool(make_props(&v), "visible"), Some(true));
    }

    #[test]
    fn prop_bool_returns_false() {
        let v = json!({"visible": false});
        assert_eq!(prop_bool(make_props(&v), "visible"), Some(false));
    }

    #[test]
    fn prop_bool_returns_none_for_missing() {
        let v = json!({"other": 1});
        assert_eq!(prop_bool(make_props(&v), "visible"), None);
    }

    #[test]
    fn prop_bool_default_uses_fallback() {
        let v = json!({});
        assert_eq!(prop_bool_default(make_props(&v), "clip", true), true);
        assert_eq!(prop_bool_default(make_props(&v), "clip", false), false);
    }

    // -- prop_str --

    #[test]
    fn prop_str_returns_string() {
        let v = json!({"label": "hello"});
        assert_eq!(prop_str(make_props(&v), "label"), Some("hello".to_string()));
    }

    // -- prop_length --

    #[test]
    fn prop_length_fill_string() {
        let v = json!({"width": "fill"});
        assert_eq!(prop_length(make_props(&v), "width", Length::Shrink), Fill);
    }

    #[test]
    fn prop_length_shrink_string() {
        let v = json!({"width": "shrink"});
        assert_eq!(prop_length(make_props(&v), "width", Fill), Length::Shrink);
    }

    #[test]
    fn prop_length_fixed_number() {
        let v = json!({"width": 200.0});
        assert_eq!(
            prop_length(make_props(&v), "width", Length::Shrink),
            Length::Fixed(200.0)
        );
    }

    #[test]
    fn prop_length_fill_portion_object() {
        let v = json!({"width": {"fill_portion": 3}});
        assert_eq!(
            prop_length(make_props(&v), "width", Length::Shrink),
            Length::FillPortion(3)
        );
    }

    #[test]
    fn prop_length_returns_fallback_for_missing() {
        let v = json!({});
        assert_eq!(prop_length(make_props(&v), "width", Fill), Fill);
    }

    #[test]
    fn prop_length_numeric_string() {
        let v = json!({"width": "150"});
        assert_eq!(
            prop_length(make_props(&v), "width", Length::Shrink),
            Length::Fixed(150.0)
        );
    }

    // -- parse_color --

    #[test]
    fn parse_color_hex_rrggbb() {
        let v = json!("#ff0000");
        let c = parse_color(&v).unwrap();
        assert_eq!(c, Color::from_rgb8(255, 0, 0));
    }

    #[test]
    fn parse_color_hex_rrggbbaa() {
        let v = json!("#00ff0080");
        let c = parse_color(&v).unwrap();
        assert_eq!(c, Color::from_rgba8(0, 255, 0, 128.0 / 255.0));
    }

    #[test]
    fn parse_color_object_rgba() {
        let v = json!({"r": 0.5, "g": 0.25, "b": 0.75, "a": 0.8});
        let c = parse_color(&v).unwrap();
        assert_eq!(c, Color::from_rgba(0.5, 0.25, 0.75, 0.8));
    }

    #[test]
    fn parse_color_object_defaults_alpha_to_one() {
        let v = json!({"r": 1.0, "g": 0.0, "b": 0.0});
        let c = parse_color(&v).unwrap();
        assert_eq!(c, Color::from_rgba(1.0, 0.0, 0.0, 1.0));
    }

    #[test]
    fn parse_color_returns_none_for_bad_hex() {
        let v = json!("#xyz");
        assert!(parse_color(&v).is_none());
    }

    #[test]
    fn parse_color_returns_none_for_number() {
        let v = json!(42);
        assert!(parse_color(&v).is_none());
    }

    // -- parse_font --

    #[test]
    fn parse_font_monospace_string() {
        let v = json!("monospace");
        let f = parse_font(&v);
        assert_eq!(f, Font::MONOSPACE);
    }

    #[test]
    fn parse_font_default_string() {
        let v = json!("default");
        let f = parse_font(&v);
        assert_eq!(f, Font::DEFAULT);
    }

    #[test]
    fn parse_font_object_with_weight_and_style() {
        let v = json!({"weight": "bold", "style": "italic"});
        let f = parse_font(&v);
        assert_eq!(f.weight, font::Weight::Bold);
        assert_eq!(f.style, font::Style::Italic);
    }

    #[test]
    fn parse_font_object_serif_family() {
        let v = json!({"family": "serif"});
        let f = parse_font(&v);
        assert_eq!(f.family, font::Family::Serif);
    }

    // -- parse_padding_value --

    #[test]
    fn parse_padding_uniform_number() {
        let v = json!({"padding": 10});
        let p = parse_padding_value(make_props(&v));
        assert_eq!(p.top, 10.0);
        assert_eq!(p.right, 10.0);
        assert_eq!(p.bottom, 10.0);
        assert_eq!(p.left, 10.0);
    }

    #[test]
    fn parse_padding_per_side_object() {
        let v = json!({"padding": {"top": 1, "right": 2, "bottom": 3, "left": 4}});
        let p = parse_padding_value(make_props(&v));
        assert_eq!(p.top, 1.0);
        assert_eq!(p.right, 2.0);
        assert_eq!(p.bottom, 3.0);
        assert_eq!(p.left, 4.0);
    }

    #[test]
    fn parse_padding_defaults_to_zero() {
        let v = json!({});
        let p = parse_padding_value(make_props(&v));
        assert_eq!(p.top, 0.0);
        assert_eq!(p.right, 0.0);
        assert_eq!(p.bottom, 0.0);
        assert_eq!(p.left, 0.0);
    }

    // -- parse_border --

    #[test]
    fn parse_border_with_all_fields() {
        let v = json!({"color": "#ff0000", "width": 2.0, "radius": 8.0});
        let b = parse_border(&v);
        assert_eq!(b.color, Color::from_rgb8(255, 0, 0));
        assert_eq!(b.width, 2.0);
    }

    #[test]
    fn parse_border_defaults_for_non_object() {
        let v = json!("not an object");
        let b = parse_border(&v);
        assert_eq!(b, Border::default());
    }

    // -- parse_shadow --

    #[test]
    fn parse_shadow_with_all_fields() {
        let v = json!({"color": "#000000", "offset": [3.0, 4.0], "blur_radius": 5.0});
        let s = parse_shadow(&v);
        assert_eq!(s.color, Color::from_rgb8(0, 0, 0));
        assert_eq!(s.offset, Vector::new(3.0, 4.0));
        assert_eq!(s.blur_radius, 5.0);
    }

    #[test]
    fn parse_shadow_defaults_for_non_object() {
        let v = json!(42);
        let s = parse_shadow(&v);
        assert_eq!(s, Shadow::default());
    }

    // -- WidgetCaches --

    #[test]
    fn widget_caches_new_is_empty() {
        let c = WidgetCaches::new();
        assert!(c.editor_contents.is_empty());
        assert!(c.markdown_items.is_empty());
        assert!(c.combo_states.is_empty());
        assert!(c.combo_options.is_empty());
        assert!(c.pane_grid_states.is_empty());
        assert!(c.default_text_size.is_none());
        assert!(c.default_font.is_none());
    }

    #[test]
    fn widget_caches_clear_empties_maps_but_preserves_defaults() {
        let mut c = WidgetCaches::new();
        c.default_text_size = Some(14.0);
        c.default_font = Some(Font::MONOSPACE);
        c.combo_options.insert("x".into(), vec!["a".into()]);
        c.clear();
        assert!(c.combo_options.is_empty());
        assert_eq!(c.default_text_size, Some(14.0));
        assert_eq!(c.default_font, Some(Font::MONOSPACE));
    }
}
