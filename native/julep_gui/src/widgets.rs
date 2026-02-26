use crate::protocol::TreeNode;
use iced::widget::{button, checkbox, column, container, progress_bar, row, rule, text, text_input, Space};
use iced::{alignment, Element, Fill, Length, Padding};
use serde_json::Value;

use crate::Message;

/// Map a TreeNode to an iced Element. Unknown types render as an empty container.
pub fn render<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    match node.type_name.as_str() {
        "column" => render_column(node),
        "row" => render_row(node),
        "text" => render_text(node),
        "button" => render_button(node),
        "container" => render_container(node),
        "space" => render_space(node),
        "text_input" => render_text_input(node),
        "checkbox" => render_checkbox(node),
        "rule" => render_rule(node),
        "progress_bar" => render_progress_bar(node),
        "window" => render_window(node),
        unknown => {
            eprintln!("julep_gui: unknown node type `{unknown}`, rendering as empty container");
            container(Space::new()).into()
        }
    }
}

// ---------------------------------------------------------------------------
// Column
// ---------------------------------------------------------------------------

fn render_column<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_x = prop_horizontal_alignment(props, "align_x");

    let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();

    column(children)
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .height(height)
        .align_x(align_x)
        .into()
}

// ---------------------------------------------------------------------------
// Row
// ---------------------------------------------------------------------------

fn render_row<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_y = prop_vertical_alignment(props, "align_y");

    let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();

    row(children)
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .height(height)
        .align_y(align_y)
        .into()
}

// ---------------------------------------------------------------------------
// Text
// ---------------------------------------------------------------------------

fn render_text<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let content = prop_str(props, "content").unwrap_or_default();
    let size = prop_f32(props, "size");

    let mut t = text(content);
    if let Some(s) = size {
        t = t.size(s);
    }
    t.into()
}

// ---------------------------------------------------------------------------
// Button
// ---------------------------------------------------------------------------

fn render_button<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let label = prop_str(props, "label")
        .or_else(|| prop_str(props, "content"))
        .unwrap_or_default();
    let id = node.id.clone();

    button(text(label))
        .on_press(Message::Click(id))
        .into()
}

// ---------------------------------------------------------------------------
// Container
// ---------------------------------------------------------------------------

fn render_container<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let center = prop_bool(props, "center").unwrap_or(false);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(render)
        .unwrap_or_else(|| Space::new().into());

    let mut c = container(child).padding(padding).width(width).height(height);

    if center {
        c = c.center(Fill);
    }

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
// Window (top-level container; multi-window is Phase 2)
// ---------------------------------------------------------------------------

fn render_window<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Fill);
    let height = prop_length(props, "height", Fill);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(render)
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

fn render_text_input<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let value = prop_str(props, "value").unwrap_or_default();
    let placeholder = prop_str(props, "placeholder").unwrap_or_default();
    let width = prop_length(props, "width", Length::Fill);
    let size = prop_f32(props, "size");
    let padding = prop_f32(props, "padding");
    let id = node.id.clone();
    let has_on_submit = props.and_then(|p| p.get("on_submit")).is_some();

    let mut ti = text_input(&placeholder, &value)
        .on_input(move |v| Message::Input(id.clone(), v))
        .width(width);

    if let Some(s) = size {
        ti = ti.size(s);
    }
    if let Some(p) = padding {
        ti = ti.padding(p);
    }

    if has_on_submit {
        let submit_id = node.id.clone();
        let submit_value = value.clone();
        ti = ti.on_submit(Message::Submit(submit_id, submit_value));
    }

    ti.into()
}

// ---------------------------------------------------------------------------
// Checkbox
// ---------------------------------------------------------------------------

fn render_checkbox<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let label = prop_str(props, "label").unwrap_or_default();
    let checked = prop_bool(props, "checked").unwrap_or(false);
    let spacing = prop_f32(props, "spacing");
    let width = prop_length(props, "width", Length::Shrink);
    let id = node.id.clone();

    let mut cb = checkbox(checked)
        .label(label)
        .on_toggle(move |v| Message::Toggle(id.clone(), v))
        .width(width);

    if let Some(s) = spacing {
        cb = cb.spacing(s);
    }

    cb.into()
}

// ---------------------------------------------------------------------------
// Rule (horizontal divider)
// ---------------------------------------------------------------------------

fn render_rule<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let height = prop_f32(props, "height").unwrap_or(1.0);
    rule::horizontal(height).into()
}

// ---------------------------------------------------------------------------
// Progress Bar
// ---------------------------------------------------------------------------

fn render_progress_bar<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let range = props
        .and_then(|p| p.get("range"))
        .and_then(|v| v.as_array())
        .and_then(|arr| {
            let min = arr.first()?.as_f64()? as f32;
            let max = arr.get(1)?.as_f64()? as f32;
            Some(min..=max)
        })
        .unwrap_or(0.0..=100.0);
    let value = prop_f32(props, "value").unwrap_or(0.0);
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Shrink);

    progress_bar(range, value)
        .length(width)
        .girth(height)
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

fn prop_bool(props: Props<'_>, key: &str) -> Option<bool> {
    props?.get(key)?.as_bool()
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
        _ => None,
    }
}

fn prop_padding(props: Props<'_>) -> Padding {
    let base = prop_f32(props, "padding").unwrap_or(0.0).max(0.0);
    let top = prop_f32(props, "padding_top").unwrap_or(base);
    let right = prop_f32(props, "padding_right").unwrap_or(base);
    let bottom = prop_f32(props, "padding_bottom").unwrap_or(base);
    let left = prop_f32(props, "padding_left").unwrap_or(base);
    Padding { top, right, bottom, left }
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
