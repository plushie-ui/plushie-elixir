use crate::protocol::TreeNode;
use iced::widget::{
    button, checkbox, column, container, pick_list, progress_bar, row, rule, scrollable, slider,
    text, text_input, toggler, tooltip, vertical_slider, Image, Space, Stack, Svg,
};
use iced::{alignment, ContentFit, Element, Fill, Length, Padding};
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
        "scrollable" => render_scrollable(node),
        "window" => render_window(node),
        // New native widgets
        "toggler" => render_toggler(node),
        "radio" => render_radio(node),
        "slider" => render_slider(node),
        "vertical_slider" => render_vertical_slider(node),
        "pick_list" => render_pick_list(node),
        "combo_box" => render_pick_list(node), // delegate to pick_list for now
        "text_editor" => render_text_editor(node),
        "tooltip" => render_tooltip(node),
        "image" => render_image(node),
        "svg" => render_svg(node),
        "markdown" => render_markdown(node),
        "stack" => render_stack(node),
        // Composite widgets
        "tabs" => render_tabs(node),
        "nav" => render_nav(node),
        "modal" => render_modal(node),
        "card" => render_card(node),
        "panel" => render_panel(node),
        "form" => render_form(node),
        "split_pane" => render_split_pane(node),
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
// Scrollable
// ---------------------------------------------------------------------------

fn render_scrollable<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(render)
        .unwrap_or_else(|| Space::new().into());

    scrollable(child)
        .width(width)
        .height(height)
        .into()
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
    let range = prop_range_f32(props);
    let value = prop_f32(props, "value").unwrap_or(0.0);
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Shrink);

    progress_bar(range, value)
        .length(width)
        .girth(height)
        .into()
}

// ---------------------------------------------------------------------------
// Toggler
// ---------------------------------------------------------------------------

fn render_toggler<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let is_toggled = prop_bool(props, "is_toggled").unwrap_or(false);
    let label = prop_str(props, "label");
    let spacing = prop_f32(props, "spacing");
    let width = prop_length(props, "width", Length::Shrink);
    let id = node.id.clone();

    let mut t = toggler(is_toggled)
        .on_toggle(move |v| Message::Toggle(id.clone(), v))
        .width(width);

    if let Some(l) = label {
        t = t.label(l);
    }
    if let Some(s) = spacing {
        t = t.spacing(s);
    }

    t.into()
}

// ---------------------------------------------------------------------------
// Radio
// ---------------------------------------------------------------------------

fn render_radio<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let value = prop_str(props, "value").unwrap_or_default();
    let selected_str = prop_str(props, "selected").unwrap_or_default();
    let label = prop_str(props, "label").unwrap_or_else(|| value.clone());
    // Use "group" prop as the event ID so all radios in a group emit the same ID.
    // Falls back to the node's own ID if no group is set.
    let event_id = prop_str(props, "group").unwrap_or_else(|| node.id.clone());

    let is_selected = if value == selected_str { Some(0u8) } else { None };
    let select_value = value;

    iced::widget::Radio::new(label, 0u8, is_selected, move |_| {
        Message::Select(event_id.clone(), select_value.clone())
    })
    .into()
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

    let mut s = slider(range, value, move |v| {
        Message::Slide(id.clone(), v)
    })
    .on_release(Message::SlideRelease(release_id, release_value))
    .width(width);

    if let Some(st) = step {
        s = s.step(st);
    }

    s.into()
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

    let mut s = vertical_slider(range, value, move |v| {
        Message::Slide(id.clone(), v)
    })
    .on_release(Message::SlideRelease(release_id, release_value))
    .height(height);

    if let Some(st) = step {
        s = s.step(st);
    }

    s.into()
}

// ---------------------------------------------------------------------------
// Pick List
// ---------------------------------------------------------------------------

fn render_pick_list<'a>(node: &'a TreeNode) -> Element<'a, Message> {
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
    let id = node.id.clone();

    let mut pl = pick_list(options, selected, move |v: String| {
        Message::Select(id.clone(), v)
    })
    .width(width);

    if let Some(p) = placeholder {
        pl = pl.placeholder(p);
    }

    pl.into()
}

// ---------------------------------------------------------------------------
// Text Editor (stub: render as scrollable text for now)
// ---------------------------------------------------------------------------

fn render_text_editor<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let content = prop_str(props, "content").unwrap_or_default();
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Shrink);

    // Full text_editor requires persistent Content state. For now, render as
    // a text_input so the user can at least see the content.
    let id = node.id.clone();
    let placeholder = prop_str(props, "placeholder").unwrap_or_default();

    container(
        text_input(&placeholder, &content)
            .on_input(move |v| Message::Input(id.clone(), v))
            .width(width),
    )
    .height(height)
    .into()
}

// ---------------------------------------------------------------------------
// Tooltip
// ---------------------------------------------------------------------------

fn render_tooltip<'a>(node: &'a TreeNode) -> Element<'a, Message> {
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
        .map(render)
        .unwrap_or_else(|| Space::new().into());

    let mut tt = tooltip(child, text(tip), position);
    if let Some(g) = gap {
        tt = tt.gap(g);
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

    s.into()
}

// ---------------------------------------------------------------------------
// Markdown (stub: render as text)
// ---------------------------------------------------------------------------

fn render_markdown<'a>(node: &'a TreeNode) -> Element<'a, Message> {
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
// Stack
// ---------------------------------------------------------------------------

fn render_stack<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();

    Stack::with_children(children)
        .width(width)
        .height(height)
        .into()
}

// ---------------------------------------------------------------------------
// Tabs (composite: row of buttons + active child)
// ---------------------------------------------------------------------------

fn render_tabs<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let active = prop_str(props, "active").unwrap_or_default();
    let spacing = prop_f32(props, "spacing").unwrap_or(4.0);

    // Build tab header buttons from children. Each child should have an "id"
    // that acts as its tab key, and optionally a "title" prop for the label.
    let mut headers: Vec<Element<'a, Message>> = Vec::new();
    let mut active_child: Option<Element<'a, Message>> = None;

    for child in &node.children {
        let tab_id = child.id.clone();
        let label = child
            .props
            .as_object()
            .and_then(|p| p.get("title"))
            .and_then(|v| v.as_str())
            .unwrap_or(&child.id);
        let is_active = tab_id == active;

        let btn = button(text(label.to_owned()))
            .on_press(Message::Click(tab_id.clone()));

        headers.push(btn.into());

        if is_active {
            active_child = Some(render(child));
        }
    }

    let body = active_child.unwrap_or_else(|| Space::new().into());

    column![
        row(headers).spacing(spacing),
        body,
    ]
    .into()
}

// ---------------------------------------------------------------------------
// Nav (composite: column of buttons)
// ---------------------------------------------------------------------------

fn render_nav<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let _active = prop_str(props, "active").unwrap_or_default();
    let spacing = prop_f32(props, "spacing").unwrap_or(2.0);

    let items: Vec<Element<'a, Message>> = node
        .children
        .iter()
        .map(|child| {
            let label = child
                .props
                .as_object()
                .and_then(|p| p.get("label").or_else(|| p.get("title")))
                .and_then(|v| v.as_str())
                .unwrap_or(&child.id);
            let id = child.id.clone();

            button(text(label.to_owned()))
                .on_press(Message::Click(id))
                .into()
        })
        .collect();

    column(items).spacing(spacing).into()
}

// ---------------------------------------------------------------------------
// Modal (composite: stack with overlay)
// ---------------------------------------------------------------------------

fn render_modal<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let visible = prop_bool(props, "visible").unwrap_or(false);

    if !visible || node.children.is_empty() {
        return Space::new().into();
    }

    // Render all children into a column, then center it as an overlay.
    let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();
    let body: Element<'a, Message> = if children.len() == 1 {
        children.into_iter().next().unwrap()
    } else {
        column(children).spacing(8.0).into()
    };

    container(body)
        .width(Fill)
        .height(Fill)
        .center(Fill)
        .into()
}

// ---------------------------------------------------------------------------
// Card (composite: container with title + body)
// ---------------------------------------------------------------------------

fn render_card<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let title = prop_str(props, "title").unwrap_or_default();
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Length::Shrink);

    let body: Element<'a, Message> = node
        .children
        .first()
        .map(render)
        .unwrap_or_else(|| Space::new().into());

    container(
        column![text(title).size(18.0), body].spacing(8.0),
    )
    .padding(padding)
    .width(width)
    .into()
}

// ---------------------------------------------------------------------------
// Panel (composite: collapsible section)
// ---------------------------------------------------------------------------

fn render_panel<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let title = prop_str(props, "title").unwrap_or_default();
    let collapsed = prop_bool(props, "collapsed").unwrap_or(false);
    let id = node.id.clone();

    let indicator = if collapsed { "> " } else { "v " };
    let header: Element<'a, Message> = button(text(format!("{indicator}{title}")))
        .on_press(Message::Click(id))
        .into();

    if collapsed {
        column![header].into()
    } else {
        let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();
        let mut items = vec![header];
        items.extend(children);
        column(items).spacing(4.0).into()
    }
}

// ---------------------------------------------------------------------------
// Form (composite: column with spacing)
// ---------------------------------------------------------------------------

fn render_form<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(8.0);
    let padding = prop_padding(props);
    let width = prop_length(props, "width", Length::Shrink);

    let children: Vec<Element<'a, Message>> = node.children.iter().map(render).collect();

    column(children)
        .spacing(spacing)
        .padding(padding)
        .width(width)
        .into()
}

// ---------------------------------------------------------------------------
// Split Pane (composite: row with two children at a ratio)
// ---------------------------------------------------------------------------

fn render_split_pane<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let ratio = prop_f32(props, "ratio").unwrap_or(0.5).clamp(0.0, 1.0);
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);

    let left: Element<'a, Message> = node
        .children
        .first()
        .map(render)
        .unwrap_or_else(|| Space::new().into());
    let right: Element<'a, Message> = node
        .children
        .get(1)
        .map(render)
        .unwrap_or_else(|| Space::new().into());

    // Approximate ratio using FillPortion. Scale to integer parts out of 1000.
    let left_portion = (ratio * 1000.0) as u16;
    let right_portion = 1000 - left_portion;

    row![
        container(left).width(Length::FillPortion(left_portion)),
        container(right).width(Length::FillPortion(right_portion)),
    ]
    .spacing(spacing)
    .width(Fill)
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
