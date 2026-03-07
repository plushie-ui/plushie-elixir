use std::collections::{HashMap, HashSet};

use crate::protocol::TreeNode;
#[cfg(any(feature = "widget-canvas", feature = "widget-qr-code"))]
use iced::widget::canvas;
#[cfg(feature = "widget-image")]
use iced::widget::image::FilterMethod;
use iced::widget::keyed;
#[cfg(feature = "widget-markdown")]
use iced::widget::markdown;
use iced::widget::scrollable::Anchor;
use iced::widget::text::{LineHeight, Wrapping};
#[cfg(feature = "widget-image")]
use iced::widget::Image;
#[cfg(feature = "widget-svg")]
use iced::widget::Svg;
use iced::widget::{
    button, checkbox, column, combo_box, container, grid, mouse_area, pane_grid, pick_list, pin,
    progress_bar, rich_text, row, rule, scrollable, sensor, slider, span, text, text_editor,
    text_input, toggler, tooltip, vertical_slider, Space, Stack,
};
#[allow(unused_imports)]
use iced::{
    alignment, font, keyboard, mouse, widget, Border, Color, ContentFit, Element, Fill, Font,
    Length, Padding, Pixels, Point, Radians, Rotation, Shadow, Size, Vector,
};
use serde_json::Value;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::time::Duration;

use crate::extensions::ExtensionDispatcher;
use crate::message::Message;

// ---------------------------------------------------------------------------
// Widget caches
// ---------------------------------------------------------------------------

/// Bundles all per-widget caches into a single struct so render functions
/// don't need to thread 3+ separate HashMap parameters everywhere.
pub struct WidgetCaches {
    pub editor_contents: HashMap<String, text_editor::Content>,
    #[cfg(feature = "widget-markdown")]
    pub markdown_items: HashMap<String, (u64, Vec<markdown::Item>)>,
    pub combo_states: HashMap<String, combo_box::State<String>>,
    pub combo_options: HashMap<String, Vec<String>>,
    pub pane_grid_states: HashMap<String, pane_grid::State<String>>,
    /// Per-canvas, per-layer geometry caches. Outer key is node ID, inner key
    /// is layer name. The u64 is a content hash of the layer's shapes array --
    /// when it changes the cache is cleared so the layer re-tessellates.
    #[cfg(feature = "widget-canvas")]
    pub canvas_caches: HashMap<String, HashMap<String, (u64, canvas::Cache)>>,
    /// Per-qr_code caches. Key is node ID, value is (content hash, canvas Cache).
    #[cfg(feature = "widget-qr-code")]
    pub qr_code_caches: HashMap<String, (u64, canvas::Cache)>,
    pub default_text_size: Option<f32>,
    pub default_font: Option<Font>,
    pub extension: crate::extensions::ExtensionCaches,
}

impl Default for WidgetCaches {
    fn default() -> Self {
        Self::new()
    }
}

impl WidgetCaches {
    pub fn new() -> Self {
        Self {
            editor_contents: HashMap::new(),
            #[cfg(feature = "widget-markdown")]
            markdown_items: HashMap::new(),
            combo_states: HashMap::new(),
            combo_options: HashMap::new(),
            pane_grid_states: HashMap::new(),
            #[cfg(feature = "widget-canvas")]
            canvas_caches: HashMap::new(),
            #[cfg(feature = "widget-qr-code")]
            qr_code_caches: HashMap::new(),
            default_text_size: None,
            default_font: None,
            extension: crate::extensions::ExtensionCaches::new(),
        }
    }

    pub fn clear(&mut self) {
        self.editor_contents.clear();
        #[cfg(feature = "widget-markdown")]
        self.markdown_items.clear();
        self.combo_states.clear();
        self.combo_options.clear();
        self.pane_grid_states.clear();
        #[cfg(feature = "widget-canvas")]
        self.canvas_caches.clear();
        #[cfg(feature = "widget-qr-code")]
        self.qr_code_caches.clear();
        self.extension.clear();
    }
}

// ---------------------------------------------------------------------------
// Cache pre-population
// ---------------------------------------------------------------------------

/// Walk the tree and ensure that every `text_editor`, `markdown`, and
/// `combo_box` node has an entry in the corresponding cache. This must be
/// called *before* `render` so that `render` can work with shared (`&`)
/// references to the caches.
///
/// After populating caches, prunes stale entries for nodes no longer in the
/// tree across all cache types.
pub fn ensure_caches(node: &TreeNode, caches: &mut WidgetCaches) {
    let mut live_ids = HashSet::new();
    ensure_caches_walk(node, caches, &mut live_ids);
    prune_all_stale_caches(&live_ids, caches);
}

/// Inner recursive walk: populate caches and collect live node IDs.
fn ensure_caches_walk(node: &TreeNode, caches: &mut WidgetCaches, live_ids: &mut HashSet<String>) {
    live_ids.insert(node.id.clone());

    match node.type_name.as_str() {
        "text_editor" => {
            let props = node.props.as_object();
            let content_str = prop_str(props, "content").unwrap_or_default();
            caches
                .editor_contents
                .entry(node.id.clone())
                .or_insert_with(|| text_editor::Content::with_text(&content_str));
        }
        #[cfg(feature = "widget-markdown")]
        "markdown" => {
            let props = node.props.as_object();
            let content = prop_str(props, "content").unwrap_or_default();
            let hash = hash_str(&content);
            match caches.markdown_items.get(&node.id) {
                Some((existing_hash, _)) if *existing_hash == hash => {}
                _ => {
                    let items: Vec<_> = markdown::parse(&content).collect();
                    caches.markdown_items.insert(node.id.clone(), (hash, items));
                }
            }
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
            let child_ids: HashSet<String> = node.children.iter().map(|c| c.id.clone()).collect();

            if let Some(state) = caches.pane_grid_states.get_mut(&node.id) {
                // Prune panes whose child nodes no longer exist.
                let stale_panes: Vec<pane_grid::Pane> = state
                    .panes
                    .iter()
                    .filter(|(_pane, id)| !child_ids.contains(*id))
                    .map(|(pane, _id)| *pane)
                    .collect();
                for pane in stale_panes {
                    state.close(pane);
                }
            } else {
                let child_list: Vec<String> = node.children.iter().map(|c| c.id.clone()).collect();
                let new_state = if child_list.is_empty() {
                    let (state, _) = pane_grid::State::new("default".to_string());
                    state
                } else if child_list.len() == 1 {
                    let (state, _) = pane_grid::State::new(child_list[0].clone());
                    state
                } else {
                    let (mut state, first_pane) = pane_grid::State::new(child_list[0].clone());
                    let mut last_pane = first_pane;
                    for id in child_list.iter().skip(1) {
                        if let Some((new_pane, _)) =
                            state.split(pane_grid::Axis::Vertical, last_pane, id.clone())
                        {
                            last_pane = new_pane;
                        }
                    }
                    state
                };
                caches.pane_grid_states.insert(node.id.clone(), new_state);
            }
        }
        #[cfg(feature = "widget-canvas")]
        "canvas" => {
            let props = node.props.as_object();
            // Build layer map: either from "layers" (object) or "shapes" (array -> single layer).
            let layer_map = canvas_layer_map(props);
            let node_caches = caches.canvas_caches.entry(node.id.clone()).or_default();

            // Update or create caches for each layer.
            for (layer_name, shapes_json) in &layer_map {
                let hash = hash_str(shapes_json);
                match node_caches.get(layer_name) {
                    Some((existing_hash, _cache)) => {
                        if *existing_hash != hash {
                            node_caches.insert(layer_name.clone(), (hash, canvas::Cache::new()));
                        }
                    }
                    None => {
                        node_caches.insert(layer_name.clone(), (hash, canvas::Cache::new()));
                    }
                }
            }

            // Remove stale layers that are no longer in the tree.
            node_caches.retain(|name, _| layer_map.contains_key(name));
        }
        #[cfg(feature = "widget-qr-code")]
        "qr_code" => {
            let props = node.props.as_object();
            let data = prop_str(props, "data").unwrap_or_default();
            let cell_size = prop_f32(props, "cell_size").unwrap_or(4.0);
            let ec = prop_str(props, "error_correction").unwrap_or_default();
            // Hash data + cell_size + error_correction for cache invalidation.
            let mut hasher = DefaultHasher::new();
            data.hash(&mut hasher);
            cell_size.to_bits().hash(&mut hasher);
            ec.hash(&mut hasher);
            let hash = hasher.finish();

            match caches.qr_code_caches.get(&node.id) {
                Some((existing_hash, existing_cache)) => {
                    if *existing_hash != hash {
                        existing_cache.clear();
                        caches
                            .qr_code_caches
                            .insert(node.id.clone(), (hash, canvas::Cache::new()));
                    }
                }
                None => {
                    caches
                        .qr_code_caches
                        .insert(node.id.clone(), (hash, canvas::Cache::new()));
                }
            }
        }
        _ => {}
    }

    for child in &node.children {
        ensure_caches_walk(child, caches, live_ids);
    }
}

/// Prune all cache types, removing entries whose node IDs are no longer live.
fn prune_all_stale_caches(live_ids: &HashSet<String>, caches: &mut WidgetCaches) {
    caches.editor_contents.retain(|id, _| live_ids.contains(id));
    #[cfg(feature = "widget-markdown")]
    caches.markdown_items.retain(|id, _| live_ids.contains(id));
    caches.combo_states.retain(|id, _| live_ids.contains(id));
    caches.combo_options.retain(|id, _| live_ids.contains(id));
    caches
        .pane_grid_states
        .retain(|id, _| live_ids.contains(id));
    #[cfg(feature = "widget-canvas")]
    caches.canvas_caches.retain(|id, _| live_ids.contains(id));
    #[cfg(feature = "widget-qr-code")]
    caches.qr_code_caches.retain(|id, _| live_ids.contains(id));
}

// ---------------------------------------------------------------------------
// Main render dispatch
// ---------------------------------------------------------------------------

/// Map a TreeNode to an iced Element. Unknown types render as an empty container.
pub fn render<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    #[cfg(debug_assertions)]
    validate_props(node);

    match node.type_name.as_str() {
        "column" => render_column(node, caches, images, theme, dispatcher),
        "row" => render_row(node, caches, images, theme, dispatcher),
        "text" => render_text(node, caches),
        "button" => render_button(node, caches, images, theme, dispatcher),
        "container" => render_container(node, caches, images, theme, dispatcher),
        "space" => render_space(node),
        "text_input" => render_text_input(node, caches),
        "checkbox" => render_checkbox(node, caches),
        "rule" => render_rule(node),
        "progress_bar" => render_progress_bar(node),
        "scrollable" => render_scrollable(node, caches, images, theme, dispatcher),
        "window" => render_window(node, caches, images, theme, dispatcher),
        // Native widgets
        "toggler" => render_toggler(node, caches),
        "radio" => render_radio(node, caches),
        "slider" => render_slider(node),
        "vertical_slider" => render_vertical_slider(node),
        "pick_list" => render_pick_list(node, caches),
        "combo_box" => render_combo_box(node, caches),
        "text_editor" => render_text_editor(node, caches),
        "tooltip" => render_tooltip(node, caches, images, theme, dispatcher),
        #[cfg(feature = "widget-image")]
        "image" => render_image(node, images),
        #[cfg(not(feature = "widget-image"))]
        "image" => render_feature_disabled("image", "widget-image"),
        #[cfg(feature = "widget-svg")]
        "svg" => render_svg(node),
        #[cfg(not(feature = "widget-svg"))]
        "svg" => render_feature_disabled("svg", "widget-svg"),
        #[cfg(feature = "widget-markdown")]
        "markdown" => render_markdown(node, caches, theme),
        #[cfg(not(feature = "widget-markdown"))]
        "markdown" => render_feature_disabled("markdown", "widget-markdown"),
        "stack" => render_stack(node, caches, images, theme, dispatcher),
        #[cfg(feature = "widget-canvas")]
        "canvas" => render_canvas(node, caches, images, theme, dispatcher),
        #[cfg(not(feature = "widget-canvas"))]
        "canvas" => render_feature_disabled("canvas", "widget-canvas"),
        "table" => render_table(node),
        // New native widgets
        "grid" => render_grid(node, caches, images, theme, dispatcher),
        "pin" => render_pin(node, caches, images, theme, dispatcher),
        "mouse_area" => render_mouse_area(node, caches, images, theme, dispatcher),
        "sensor" => render_sensor(node, caches, images, theme, dispatcher),
        "rich_text" | "rich" => render_rich_text(node, caches),
        "keyed_column" => render_keyed_column(node, caches, images, theme, dispatcher),
        "float" => render_float(node, caches, images, theme, dispatcher),
        "themer" => render_themer(node, caches, images, theme, dispatcher),
        "responsive" => render_responsive(node, caches, images, theme, dispatcher),
        "pane_grid" => render_pane_grid(node, caches, images, theme, dispatcher),
        "overlay" => render_overlay(node, caches, images, theme, dispatcher),
        // Feature-gated widgets
        #[cfg(feature = "widget-qr-code")]
        "qr_code" => render_qr_code(node, caches),
        #[cfg(not(feature = "widget-qr-code"))]
        "qr_code" => render_feature_disabled("qr_code", "widget-qr-code"),
        unknown => {
            if dispatcher.handles_type(unknown) {
                let render_ctx = crate::extensions::RenderContext {
                    caches,
                    images,
                    theme,
                    extensions: dispatcher,
                };
                let env = crate::extensions::WidgetEnv {
                    caches: &caches.extension,
                    images,
                    theme,
                    render_ctx,
                };
                // catch_unwind at the render boundary: extension panics produce
                // a red placeholder instead of crashing the renderer.
                // We track consecutive render panics via an atomic counter
                // on the dispatcher; after N consecutive panics, the
                // extension is poisoned on the next prepare_all cycle.
                match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    dispatcher.render(node, &env)
                })) {
                    Ok(Some(element)) => element,
                    Ok(None) => container(Space::new()).into(),
                    Err(_) => {
                        let at_threshold = dispatcher.record_render_panic(unknown);
                        if at_threshold {
                            log::error!(
                                "[id={}] extension for type `{unknown}` hit render panic \
                                 threshold, will be poisoned on next prepare cycle",
                                node.id
                            );
                        } else {
                            log::error!("extension panicked in render for node `{}`", node.id);
                        }
                        iced::widget::text(format!("Extension error: node `{}`", node.id))
                            .color(iced::Color::from_rgb(1.0, 0.0, 0.0))
                            .into()
                    }
                }
            } else {
                log::warn!(
                    "[id={}] unknown node type `{unknown}`, rendering as empty container",
                    node.id
                );
                container(Space::new()).into()
            }
        }
    }
}

#[cfg(not(all(
    feature = "widget-image",
    feature = "widget-svg",
    feature = "widget-canvas",
    feature = "widget-markdown",
    feature = "widget-qr-code"
)))]
fn render_feature_disabled<'a>(widget_name: &str, feature_name: &str) -> Element<'a, Message> {
    iced::widget::text(format!(
        "Widget '{}' requires feature '{}'",
        widget_name, feature_name
    ))
    .into()
}

// ---------------------------------------------------------------------------
// Child rendering helper
// ---------------------------------------------------------------------------

fn render_children<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Vec<Element<'a, Message>> {
    node.children
        .iter()
        .map(|c| render(c, caches, images, theme, dispatcher))
        .collect()
}

// ---------------------------------------------------------------------------
// Column
// ---------------------------------------------------------------------------

fn render_column<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_x = prop_horizontal_alignment(props, "align_x");
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches, images, theme, dispatcher);

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

fn render_row<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let align_y = prop_vertical_alignment(props, "align_y");
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches, images, theme, dispatcher);

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

fn render_button<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let id = node.id.clone();

    // Button can have either a text label or child content
    let child: Element<'a, Message> = if !node.children.is_empty() {
        node.children
            .first()
            .map(|c| render(c, caches, images, theme, dispatcher))
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            b = match style_name {
                "primary" => b.style(button::primary),
                "secondary" => b.style(button::secondary),
                "success" => b.style(button::success),
                "warning" => b.style(button::warning),
                "danger" => b.style(button::danger),
                "text" => b.style(button::text),
                _ => b.style(button::primary),
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            b = b.style(move |theme: &iced::Theme, status| {
                let mut style = button::primary(theme, status);
                apply_button_fields(&mut style, &ov.base);
                match status {
                    button::Status::Hovered => {
                        if let Some(ref f) = ov.hovered {
                            apply_button_fields(&mut style, f);
                        } else {
                            style.background = auto_derive_hover_bg(style.background);
                        }
                    }
                    button::Status::Pressed => {
                        if let Some(ref f) = ov.pressed {
                            apply_button_fields(&mut style, f);
                        }
                    }
                    button::Status::Disabled => {
                        if let Some(ref f) = ov.disabled {
                            apply_button_fields(&mut style, f);
                        } else {
                            style.background = auto_derive_disabled_bg(style.background);
                            style.text_color = auto_derive_disabled_text(style.text_color);
                        }
                    }
                    _ => {}
                }
                style
            });
        }
    }

    container(b).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Container
// ---------------------------------------------------------------------------

fn render_container<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let center = prop_bool_default(props, "center", false);
    let clip = prop_bool_default(props, "clip", false);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
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

    // Named style or style map (overrides inline if both present)
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            c = match style_name {
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
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            c = c.style(move |_theme| container_style_from_base(&ov.base));
        }
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

fn render_scrollable<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let spacing = prop_f32(props, "spacing");

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
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

fn render_window<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let padding = parse_padding_value(props);
    let width = prop_length(props, "width", Fill);
    let height = prop_length(props, "height", Fill);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            ti = match style_name {
                "default" => ti.style(text_input::default),
                _ => ti,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            ti = ti.style(move |theme: &iced::Theme, status| {
                let mut style = text_input::default(theme, status);
                apply_text_input_fields(&mut style, &ov.base);
                match status {
                    text_input::Status::Focused { .. } => {
                        if let Some(ref f) = ov.focused {
                            apply_text_input_fields(&mut style, f);
                        }
                    }
                    text_input::Status::Hovered => {
                        if let Some(ref f) = ov.hovered {
                            apply_text_input_fields(&mut style, f);
                        } else if let iced::Background::Color(c) = style.background {
                            style.background = iced::Background::Color(darken_color(c, 0.9));
                        }
                    }
                    text_input::Status::Disabled => {
                        if let Some(ref f) = ov.disabled {
                            apply_text_input_fields(&mut style, f);
                        } else {
                            if let iced::Background::Color(c) = style.background {
                                style.background = iced::Background::Color(alpha_color(c, 0.5));
                            }
                            style.value = alpha_color(style.value, 0.5);
                        }
                    }
                    _ => {}
                }
                style
            });
        }
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
    if let Some(icon_val) = props
        .and_then(|p| p.get("icon"))
        .and_then(|v| v.as_object())
    {
        if let Some(cp_str) = icon_val.get("code_point").and_then(|v| v.as_str()) {
            if let Some(code_point) = cp_str.chars().next() {
                let icon_font = icon_val
                    .get("font")
                    .map(parse_font)
                    .unwrap_or(Font::DEFAULT);
                let icon_size = icon_val
                    .get("size")
                    .and_then(|v| v.as_f64())
                    .map(|v| Pixels(v as f32));
                let icon_line_height = icon_val
                    .get("line_height")
                    .and_then(|v| match v {
                        Value::Number(n) => n.as_f64().map(|r| LineHeight::Relative(r as f32)),
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
                    })
                    .unwrap_or(LineHeight::default());
                let icon_shaping = icon_val
                    .get("shaping")
                    .and_then(|v| v.as_str())
                    .and_then(|s| match s.to_ascii_lowercase().as_str() {
                        "basic" => Some(iced::widget::text::Shaping::Basic),
                        "advanced" => Some(iced::widget::text::Shaping::Advanced),
                        "auto" => Some(iced::widget::text::Shaping::Auto),
                        _ => None,
                    })
                    .unwrap_or(iced::widget::text::Shaping::Auto);
                let icon_struct = checkbox::Icon {
                    font: icon_font,
                    code_point,
                    size: icon_size,
                    line_height: icon_line_height,
                    shaping: icon_shaping,
                };
                cb = cb.icon(icon_struct);
            }
        }
    }
    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            cb = match style_name {
                "primary" => cb.style(checkbox::primary),
                "secondary" => cb.style(checkbox::secondary),
                "success" => cb.style(checkbox::success),
                "danger" => cb.style(checkbox::danger),
                _ => cb.style(checkbox::primary),
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            cb = cb.style(move |theme: &iced::Theme, status| {
                let mut style = checkbox::primary(theme, status);
                apply_checkbox_fields(&mut style, &ov.base);
                match status {
                    checkbox::Status::Hovered { .. } => {
                        if let Some(ref f) = ov.hovered {
                            apply_checkbox_fields(&mut style, f);
                        } else if let iced::Background::Color(c) = style.background {
                            style.background = iced::Background::Color(darken_color(c, 0.9));
                        }
                    }
                    checkbox::Status::Disabled { .. } => {
                        if let Some(ref f) = ov.disabled {
                            apply_checkbox_fields(&mut style, f);
                        } else {
                            style.background = alpha_background(style.background, 0.5);
                            if let Some(tc) = style.text_color {
                                style.text_color = Some(alpha_color(tc, 0.5));
                            }
                        }
                    }
                    _ => {}
                }
                style
            });
        }
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
        if let Some(style_val) = props.and_then(|p| p.get("style")) {
            if let Some(style_name) = style_val.as_str() {
                r = match style_name {
                    "default" => r.style(rule::default),
                    "weak" => r.style(rule::weak),
                    _ => r,
                };
            } else if let Some(obj) = style_val.as_object() {
                let ov = parse_style_overrides(obj);
                r = r.style(move |theme: &iced::Theme| {
                    apply_rule_style(&mut rule::default(theme), &ov.base)
                });
            }
        }
        r.into()
    } else {
        let mut r = rule::horizontal(thickness);
        if let Some(style_val) = props.and_then(|p| p.get("style")) {
            if let Some(style_name) = style_val.as_str() {
                r = match style_name {
                    "default" => r.style(rule::default),
                    "weak" => r.style(rule::weak),
                    _ => r,
                };
            } else if let Some(obj) = style_val.as_object() {
                let ov = parse_style_overrides(obj);
                r = r.style(move |theme: &iced::Theme| {
                    apply_rule_style(&mut rule::default(theme), &ov.base)
                });
            }
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            pb = match style_name {
                "primary" => pb.style(progress_bar::primary),
                "secondary" => pb.style(progress_bar::secondary),
                "success" => pb.style(progress_bar::success),
                "danger" => pb.style(progress_bar::danger),
                "warning" => pb.style(progress_bar::warning),
                _ => pb.style(progress_bar::primary),
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            pb = pb.style(move |theme: &iced::Theme| {
                let mut style = progress_bar::primary(theme);
                apply_progress_bar_fields(&mut style, &ov.base);
                style
            });
        }
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            t = match style_name {
                "default" => t.style(toggler::default),
                _ => t,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            t = t.style(move |theme: &iced::Theme, status| {
                let mut style = toggler::default(theme, status);
                apply_toggler_fields(&mut style, &ov.base);
                match status {
                    toggler::Status::Hovered { .. } => {
                        if let Some(ref f) = ov.hovered {
                            apply_toggler_fields(&mut style, f);
                        } else {
                            style.background = darken_background(style.background, 0.9);
                        }
                    }
                    toggler::Status::Disabled { .. } => {
                        if let Some(ref f) = ov.disabled {
                            apply_toggler_fields(&mut style, f);
                        } else {
                            style.background = alpha_background(style.background, 0.5);
                            if let Some(tc) = style.text_color {
                                style.text_color = Some(alpha_color(tc, 0.5));
                            }
                        }
                    }
                    _ => {}
                }
                style
            });
        }
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            r = match style_name {
                "default" => r.style(iced::widget::radio::default),
                _ => r,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            r = r.style(move |theme: &iced::Theme, status| {
                let mut style = iced::widget::radio::default(theme, status);
                apply_radio_fields(&mut style, &ov.base);
                if matches!(status, iced::widget::radio::Status::Hovered { .. }) {
                    if let Some(ref f) = ov.hovered {
                        apply_radio_fields(&mut style, f);
                    } else {
                        style.background = darken_background(style.background, 0.9);
                    }
                }
                style
            });
        }
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
        // Clamp step to a small positive minimum to prevent division by
        // zero or infinite loops in iced's slider internals.
        s = s.step(st.max(f64::EPSILON));
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
    } else if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            s = match style_name {
                "default" => s.style(slider::default),
                _ => s,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            s = s.style(move |theme: &iced::Theme, status| {
                let mut style = slider::default(theme, status);
                apply_slider_handle_fields(&mut style.handle, &ov.base);
                if matches!(status, slider::Status::Hovered) {
                    if let Some(ref f) = ov.hovered {
                        apply_slider_handle_fields(&mut style.handle, f);
                    } else {
                        style.handle.background = darken_background(style.handle.background, 0.9);
                    }
                }
                style
            });
        }
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
    let width = prop_f32(props, "width");
    let height = prop_length(props, "height", Length::Fill);
    let id = node.id.clone();
    let release_id = node.id.clone();
    let release_value = value;

    let mut s = vertical_slider(range, value, move |v| Message::Slide(id.clone(), v))
        .on_release(Message::SlideRelease(release_id, release_value))
        .height(height);

    if let Some(w) = width {
        s = s.width(w);
    }

    if let Some(st) = step {
        s = s.step(st.max(f64::EPSILON));
    }
    if let Some(d) = prop_f64(props, "default") {
        s = s.default(d);
    }
    if let Some(ss) = prop_f64(props, "shift_step") {
        s = s.shift_step(ss);
    }

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            s = match style_name {
                "default" => s.style(vertical_slider::default),
                _ => s,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            s = s.style(move |theme: &iced::Theme, status| {
                let mut style = vertical_slider::default(theme, status);
                apply_slider_handle_fields(&mut style.handle, &ov.base);
                if matches!(status, vertical_slider::Status::Hovered) {
                    if let Some(ref f) = ov.hovered {
                        apply_slider_handle_fields(&mut style.handle, f);
                    } else {
                        style.handle.background = darken_background(style.handle.background, 0.9);
                    }
                }
                style
            });
        }
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

    // Style: string name or style map object
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            pl = match style_name {
                "default" => pl.style(pick_list::default),
                _ => pl,
            };
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            pl = pl.style(move |theme: &iced::Theme, status| {
                let mut style = pick_list::default(theme, status);
                apply_pick_list_fields(&mut style, &ov.base);
                if matches!(status, pick_list::Status::Hovered) {
                    if let Some(ref f) = ov.hovered {
                        apply_pick_list_fields(&mut style, f);
                    } else if let iced::Background::Color(c) = style.background {
                        style.background = iced::Background::Color(darken_color(c, 0.9));
                    }
                }
                style
            });
        }
    }

    if prop_bool_default(props, "on_open", false) {
        let open_id = node.id.clone();
        pl = pl.on_open(Message::Event(open_id, Value::Null, "open".into()));
    }
    if prop_bool_default(props, "on_close", false) {
        let close_id = node.id.clone();
        pl = pl.on_close(Message::Event(close_id, Value::Null, "close".into()));
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
    if prop_bool_default(props, "on_open", false) {
        let open_id = node.id.clone();
        cb = cb.on_open(Message::Event(open_id, Value::Null, "open".into()));
    }
    if prop_bool_default(props, "on_close", false) {
        let close_id = node.id.clone();
        cb = cb.on_close(Message::Event(close_id, Value::Null, "close".into()));
    }

    container(cb).id(widget::Id::from(node.id.clone())).into()
}

// ---------------------------------------------------------------------------
// Text Editor key binding helpers
// ---------------------------------------------------------------------------

/// Parse a JSON motion string into an iced Motion.
fn parse_motion(s: &str) -> Option<text_editor::Motion> {
    use text_editor::Motion;
    match s {
        "left" => Some(Motion::Left),
        "right" => Some(Motion::Right),
        "up" => Some(Motion::Up),
        "down" => Some(Motion::Down),
        "word_left" => Some(Motion::WordLeft),
        "word_right" => Some(Motion::WordRight),
        "home" => Some(Motion::Home),
        "end" => Some(Motion::End),
        "page_up" => Some(Motion::PageUp),
        "page_down" => Some(Motion::PageDown),
        "document_start" => Some(Motion::DocumentStart),
        "document_end" => Some(Motion::DocumentEnd),
        _ => None,
    }
}

/// Parse a JSON binding value into an iced Binding.
fn parse_binding(val: &Value, id: &str) -> Option<text_editor::Binding<Message>> {
    use text_editor::Binding;
    match val {
        Value::String(s) => match s.as_str() {
            "copy" => Some(Binding::Copy),
            "cut" => Some(Binding::Cut),
            "paste" => Some(Binding::Paste),
            "select_all" => Some(Binding::SelectAll),
            "enter" => Some(Binding::Enter),
            "backspace" => Some(Binding::Backspace),
            "delete" => Some(Binding::Delete),
            "unfocus" => Some(Binding::Unfocus),
            "select_word" => Some(Binding::SelectWord),
            "select_line" => Some(Binding::SelectLine),
            // "default" is handled at the rule-matching level, not here
            _ => None,
        },
        Value::Object(obj) => {
            if let Some(m) = obj
                .get("move")
                .and_then(|v| v.as_str())
                .and_then(parse_motion)
            {
                return Some(Binding::Move(m));
            }
            if let Some(m) = obj
                .get("select")
                .and_then(|v| v.as_str())
                .and_then(parse_motion)
            {
                return Some(Binding::Select(m));
            }
            if let Some(c) = obj
                .get("insert")
                .and_then(|v| v.as_str())
                .and_then(|s| s.chars().next())
            {
                return Some(Binding::Insert(c));
            }
            if let Some(tag) = obj.get("custom").and_then(|v| v.as_str()) {
                let event_id = id.to_string();
                return Some(Binding::Custom(Message::Event(
                    event_id,
                    serde_json::json!(tag),
                    "key_binding".to_string(),
                )));
            }
            if let Some(seq) = obj.get("sequence").and_then(|v| v.as_array()) {
                let bindings: Vec<_> = seq.iter().filter_map(|v| parse_binding(v, id)).collect();
                if !bindings.is_empty() {
                    return Some(Binding::Sequence(bindings));
                }
            }
            None
        }
        _ => None,
    }
}

/// Check if a KeyPress matches the modifiers specified in a binding rule.
fn match_modifiers(mods: &keyboard::Modifiers, required: &[String]) -> bool {
    for m in required {
        let ok = match m.as_str() {
            "shift" => mods.shift(),
            "ctrl" => mods.control(),
            "alt" => mods.alt(),
            "logo" => mods.logo(),
            "command" => mods.command(),
            "jump" => mods.jump(),
            _ => false,
        };
        if !ok {
            return false;
        }
    }
    true
}

/// Match a named key string against a KeyPress key.
fn match_named_key(named_key: &str, key: &keyboard::Key) -> bool {
    use keyboard::key::Named;
    let target = match named_key {
        "Enter" => Named::Enter,
        "Backspace" => Named::Backspace,
        "Delete" => Named::Delete,
        "Escape" => Named::Escape,
        "Tab" => Named::Tab,
        "Space" => Named::Space,
        "ArrowLeft" => Named::ArrowLeft,
        "ArrowRight" => Named::ArrowRight,
        "ArrowUp" => Named::ArrowUp,
        "ArrowDown" => Named::ArrowDown,
        "Home" => Named::Home,
        "End" => Named::End,
        "PageUp" => Named::PageUp,
        "PageDown" => Named::PageDown,
        "F1" => Named::F1,
        "F2" => Named::F2,
        "F3" => Named::F3,
        "F4" => Named::F4,
        "F5" => Named::F5,
        "F6" => Named::F6,
        "F7" => Named::F7,
        "F8" => Named::F8,
        "F9" => Named::F9,
        "F10" => Named::F10,
        "F11" => Named::F11,
        "F12" => Named::F12,
        _ => return false,
    };
    matches!(key, keyboard::Key::Named(n) if *n == target)
}

/// Pre-parsed key binding rule for closure capture.
struct KeyRule {
    key: Option<String>,
    named: Option<String>,
    modifiers: Vec<String>,
    binding_val: Value,
    is_default: bool,
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

    // Key bindings -- declarative rules parsed into a closure
    if let Some(rules) = props
        .and_then(|p| p.get("key_bindings"))
        .and_then(|v| v.as_array())
    {
        let editor_id = node.id.clone();
        let parsed_rules: Vec<KeyRule> = rules
            .iter()
            .filter_map(|rule| {
                let obj = rule.as_object()?;
                let key = obj.get("key").and_then(|v| v.as_str()).map(str::to_owned);
                let named = obj.get("named").and_then(|v| v.as_str()).map(str::to_owned);
                let modifiers = obj
                    .get("modifiers")
                    .and_then(|v| v.as_array())
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|v| v.as_str().map(str::to_owned))
                            .collect()
                    })
                    .unwrap_or_default();
                let binding_val = obj.get("binding").cloned().unwrap_or(Value::Null);
                let is_default = binding_val.as_str() == Some("default");
                Some(KeyRule {
                    key,
                    named,
                    modifiers,
                    binding_val,
                    is_default,
                })
            })
            .collect();

        if !parsed_rules.is_empty() {
            te = te.key_binding(move |key_press: text_editor::KeyPress| {
                for rule in &parsed_rules {
                    // Check modifiers first
                    if !match_modifiers(&key_press.modifiers, &rule.modifiers) {
                        continue;
                    }

                    // Check key match
                    if let Some(ref key_char) = rule.key {
                        // Match via to_latin for layout-independent character matching
                        let latin = key_press.key.to_latin(key_press.physical_key);
                        match latin {
                            Some(c) if c.to_string() == *key_char => {}
                            _ => continue,
                        }
                    } else if let Some(ref named_key) = rule.named {
                        if !match_named_key(named_key, &key_press.key) {
                            continue;
                        }
                    }
                    // else: no key/named constraint -- matches any key (catch-all rule)

                    // Default binding: delegate to iced's built-in handler
                    if rule.is_default {
                        return text_editor::Binding::from_key_press(key_press);
                    }

                    // Parse the specific binding
                    return parse_binding(&rule.binding_val, &editor_id);
                }
                // No rule matched -- no binding
                None
            });
        }
    }

    // Style closure, shared between plain and highlighted paths
    #[allow(clippy::type_complexity)]
    let style_fn: Option<Box<dyn Fn(&iced::Theme, text_editor::Status) -> text_editor::Style>> =
        if let Some(style_val) = props.and_then(|p| p.get("style")) {
            if let Some(style_name) = style_val.as_str() {
                match style_name {
                    "default" => Some(Box::new(text_editor::default)),
                    _ => None,
                }
            } else if let Some(obj) = style_val.as_object() {
                let ov = parse_style_overrides(obj);
                Some(Box::new(move |theme: &iced::Theme, status| {
                    let mut style = text_editor::default(theme, status);
                    apply_text_editor_fields(&mut style, &ov.base);
                    match status {
                        text_editor::Status::Focused { .. } => {
                            if let Some(ref f) = ov.focused {
                                apply_text_editor_fields(&mut style, f);
                            }
                        }
                        text_editor::Status::Hovered => {
                            if let Some(ref f) = ov.hovered {
                                apply_text_editor_fields(&mut style, f);
                            } else if let iced::Background::Color(c) = style.background {
                                style.background = iced::Background::Color(darken_color(c, 0.9));
                            }
                        }
                        text_editor::Status::Disabled => {
                            if let Some(ref f) = ov.disabled {
                                apply_text_editor_fields(&mut style, f);
                            } else {
                                if let iced::Background::Color(c) = style.background {
                                    style.background = iced::Background::Color(alpha_color(c, 0.5));
                                }
                                style.value = alpha_color(style.value, 0.5);
                            }
                        }
                        _ => {}
                    }
                    style
                }))
            } else {
                None
            }
        } else {
            None
        };

    let wid = widget::Id::from(node.id.clone());

    // Syntax highlighting changes the generic type parameter, so we must
    // branch here and produce Element from each path separately.
    #[cfg(feature = "widget-highlighter")]
    if let Some(syntax) = prop_str(props, "highlight_syntax") {
        let theme = match prop_str(props, "highlight_theme").as_deref() {
            Some("base16_mocha") => iced::highlighter::Theme::Base16Mocha,
            Some("base16_ocean") => iced::highlighter::Theme::Base16Ocean,
            Some("base16_eighties") => iced::highlighter::Theme::Base16Eighties,
            Some("inspired_github") => iced::highlighter::Theme::InspiredGitHub,
            _ => iced::highlighter::Theme::SolarizedDark,
        };
        // Set ID before highlight() -- .id() is only available on PlainText variant
        te = te.id(wid);
        let mut hl = te.highlight(&syntax, theme);
        if let Some(sf) = style_fn {
            hl = hl.style(sf);
        }
        return hl.into();
    }

    {
        if let Some(sf) = style_fn {
            te = te.style(sf);
        }
        te = te.id(wid);
        te.into()
    }
}

// ---------------------------------------------------------------------------
// Tooltip
// ---------------------------------------------------------------------------

fn render_tooltip<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
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
        .map(|c| render(c, caches, images, theme, dispatcher))
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

    if let Some(d) = prop_f64(props, "delay") {
        tt = tt.delay(Duration::from_millis(d as u64));
    }

    // Style: string name or style map (tooltip uses container::Style)
    if let Some(style_val) = props.and_then(|p| p.get("style")) {
        if let Some(style_name) = style_val.as_str() {
            tt = match style_name {
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
        } else if let Some(obj) = style_val.as_object() {
            let ov = parse_style_overrides(obj);
            tt = tt.style(move |_theme| container_style_from_base(&ov.base));
        }
    }

    tt.into()
}

// ---------------------------------------------------------------------------
// Image
// ---------------------------------------------------------------------------

#[cfg(feature = "widget-image")]
fn render_image<'a>(
    node: &'a TreeNode,
    images: &'a crate::image_registry::ImageRegistry,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let content_fit = prop_content_fit(props);

    // source can be a string (file path) or an object with a "handle" field
    // (in-memory image from the registry).
    let source_val = props.and_then(|p| p.get("source"));
    let handle: iced::widget::image::Handle = match source_val {
        Some(Value::Object(obj)) => {
            if let Some(name) = obj.get("handle").and_then(|v| v.as_str()) {
                match images.get(name) {
                    Some(h) => h.clone(),
                    None => {
                        log::warn!("[id={}] image: unknown registry handle: {name}", node.id);
                        iced::widget::image::Handle::from_bytes(vec![])
                    }
                }
            } else {
                iced::widget::image::Handle::from_bytes(vec![])
            }
        }
        _ => {
            let path = prop_str(props, "source").unwrap_or_default();
            iced::widget::image::Handle::from_path(path)
        }
    };

    let mut img = Image::new(handle).width(width).height(height);
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

#[cfg(feature = "widget-svg")]
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
    if let Some(color_str) = prop_str(props, "color") {
        if let Some(c) = crate::theming::parse_hex_color(&color_str) {
            s = s.style(move |_theme, _status| iced::widget::svg::Style { color: Some(c) });
        }
    }

    s.into()
}

// ---------------------------------------------------------------------------
// Markdown
// ---------------------------------------------------------------------------

#[cfg(feature = "widget-markdown")]
fn render_markdown<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    theme: &'a iced::Theme,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let items = match caches.markdown_items.get(&node.id) {
        Some((_hash, items)) => items.as_slice(),
        None => {
            log::warn!("markdown cache miss for id={}", node.id);
            return text("(markdown: cache miss)").into();
        }
    };

    // Build markdown Settings from props, falling back to theme defaults.
    let settings =
        if let Some(text_size) = prop_f32(props, "text_size").or(caches.default_text_size) {
            let mut s = markdown::Settings::with_text_size(text_size, markdown::Style::from(theme));
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
            let mut s = markdown::Settings::from(theme);
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

fn render_stack<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);
    let clip = prop_bool_default(props, "clip", false);

    let children = render_children(node, caches, images, theme, dispatcher);

    Stack::with_children(children)
        .width(width)
        .height(height)
        .clip(clip)
        .into()
}

// ---------------------------------------------------------------------------
// Grid
// ---------------------------------------------------------------------------

fn render_grid<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let cols = props
        .and_then(|p| p.get("columns"))
        .and_then(|v| v.as_u64())
        .unwrap_or(1) as usize;
    let spacing = prop_f32(props, "spacing").unwrap_or(0.0);

    let column_width = prop_length(props, "column_width", Length::Shrink);
    let row_height = prop_length(props, "row_height", Length::Shrink);

    let children = render_children(node, caches, images, theme, dispatcher);

    let mut g = grid(children).columns(cols).spacing(spacing);

    // Legacy pixel-only width/height props
    if let Some(w) = prop_f32(props, "width") {
        g = g.width(w);
    }
    if let Some(h) = prop_f32(props, "height") {
        g = g.height(h);
    }

    // Length-typed column_width: only Fixed maps to Pixels for iced's Grid::width
    if props.and_then(|p| p.get("column_width")).is_some() {
        if let Length::Fixed(px) = column_width {
            g = g.width(px);
        }
    }

    // Length-typed row_height: maps to Grid::height via Sizing::EvenlyDistribute
    if props.and_then(|p| p.get("row_height")).is_some() {
        g = g.height(row_height);
    }

    g.into()
}

// ---------------------------------------------------------------------------
// Pin (absolute positioning)
// ---------------------------------------------------------------------------

fn render_pin<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let x = prop_f32(props, "x").unwrap_or(0.0);
    let y = prop_f32(props, "y").unwrap_or(0.0);
    let width = prop_length(props, "width", Length::Shrink);
    let height = prop_length(props, "height", Length::Shrink);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
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

fn render_mouse_area<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
        .unwrap_or_else(|| Space::new().into());

    let id = node.id.clone();
    let release_id = format!("{}:release", node.id);

    let mut ma = mouse_area(child)
        .on_press(Message::Click(id))
        .on_release(Message::Click(release_id));

    // Conditional event handlers (opt-in via boolean props)
    if prop_bool_default(props, "on_middle_press", false) {
        let ev_id = node.id.clone();
        ma = ma.on_middle_press(Message::MouseAreaEvent(ev_id, "middle_press".into()));
    }
    if prop_bool_default(props, "on_right_press", false) {
        let ev_id = node.id.clone();
        ma = ma.on_right_press(Message::MouseAreaEvent(ev_id, "right_press".into()));
    }
    if prop_bool_default(props, "on_right_release", false) {
        let ev_id = node.id.clone();
        ma = ma.on_right_release(Message::MouseAreaEvent(ev_id, "right_release".into()));
    }
    if prop_bool_default(props, "on_middle_release", false) {
        let ev_id = node.id.clone();
        ma = ma.on_middle_release(Message::MouseAreaEvent(ev_id, "middle_release".into()));
    }
    if prop_bool_default(props, "on_double_click", false) {
        let ev_id = node.id.clone();
        ma = ma.on_double_click(Message::MouseAreaEvent(ev_id, "double_click".into()));
    }
    if prop_bool_default(props, "on_enter", false) {
        let ev_id = node.id.clone();
        ma = ma.on_enter(Message::MouseAreaEvent(ev_id, "enter".into()));
    }
    if prop_bool_default(props, "on_exit", false) {
        let ev_id = node.id.clone();
        ma = ma.on_exit(Message::MouseAreaEvent(ev_id, "exit".into()));
    }
    if prop_bool_default(props, "on_move", false) {
        let ev_id = node.id.clone();
        ma = ma.on_move(move |p| Message::MouseAreaMove(ev_id.clone(), p.x, p.y));
    }
    if prop_bool_default(props, "on_scroll", false) {
        let ev_id = node.id.clone();
        ma = ma.on_scroll(move |delta| {
            let (dx, dy) = match delta {
                mouse::ScrollDelta::Lines { x, y } => (x, y),
                mouse::ScrollDelta::Pixels { x, y } => (x, y),
            };
            Message::MouseAreaScroll(ev_id.clone(), dx, dy)
        });
    }

    if let Some(cursor) = prop_str(props, "cursor") {
        if let Some(interaction) = parse_interaction(&cursor) {
            ma = ma.interaction(interaction);
        }
    }

    ma.into()
}

// ---------------------------------------------------------------------------
// Sensor
// ---------------------------------------------------------------------------

fn render_sensor<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
        .unwrap_or_else(|| Space::new().into());

    // Sensor needs a key. Use the node id.
    let id = node.id.clone();
    let show_id = node.id.clone();
    let resize_id = node.id.clone();
    let hide_id = format!("{}:hide", node.id);

    let props = node.props.as_object();

    let mut s = sensor(child)
        .key(id)
        .on_show(move |size| {
            Message::SensorResize(format!("{}:show", show_id), size.width, size.height)
        })
        .on_resize(move |size| Message::SensorResize(resize_id.clone(), size.width, size.height))
        .on_hide(Message::Click(hide_id));

    if let Some(d) = prop_f64(props, "delay") {
        s = s.delay(Duration::from_millis(d as u64));
    }

    s.into()
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

fn render_keyed_column<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
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
            let elem = render(c, caches, images, theme, dispatcher);
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

fn render_float<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
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

fn render_themer<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let resolved_theme: Option<iced::Theme> = props
        .and_then(|p| p.get("theme"))
        .and_then(crate::theming::resolve_theme_only);

    let child: Element<'a, Message> = node
        .children
        .first()
        .map(|c| render(c, caches, images, theme, dispatcher))
        .unwrap_or_else(|| Space::new().into());

    iced::widget::Themer::new(resolved_theme, child).into()
}

// ---------------------------------------------------------------------------
// Responsive (container that reports its size)
// ---------------------------------------------------------------------------

fn render_responsive<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
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
        .map(|c| render(c, caches, images, theme, dispatcher))
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

fn render_pane_grid<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
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
        .map(|c| (c.id.clone(), render(c, caches, images, theme, dispatcher)))
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

    let min_size = prop_f32(props, "min_size").unwrap_or(10.0);

    pg = pg.on_click(move |pane| Message::PaneClicked(node_id3.clone(), pane));
    pg = pg.on_resize(min_size, move |evt| {
        Message::PaneResized(node_id.clone(), evt)
    });
    pg = pg.on_drag(move |evt| Message::PaneDragged(node_id2.clone(), evt));

    pg.into()
}

// ---------------------------------------------------------------------------
// Canvas
// ---------------------------------------------------------------------------

#[cfg(feature = "widget-canvas")]
/// Build a sorted layer map from canvas props. Supports two prop formats:
/// - `"layers"`: a JSON object mapping layer_name -> array of shapes (preferred)
/// - `"shapes"`: a flat JSON array of shapes (legacy, wrapped as a single "default" layer)
///
/// If both are present, `"layers"` wins. Returns a BTreeMap so layer order is
/// deterministic (alphabetical by name).
fn canvas_layer_map(
    props: Option<&serde_json::Map<String, Value>>,
) -> std::collections::BTreeMap<String, String> {
    let mut map = std::collections::BTreeMap::new();

    if let Some(layers_obj) = props
        .and_then(|p| p.get("layers"))
        .and_then(|v| v.as_object())
    {
        for (name, shapes_val) in layers_obj {
            map.insert(name.clone(), shapes_val.to_string());
        }
    } else if let Some(shapes_arr) = props.and_then(|p| p.get("shapes")) {
        map.insert("default".to_string(), shapes_arr.to_string());
    }

    map
}

/// Hash a string using DefaultHasher for same-process cache invalidation.
/// NOTE: DefaultHasher output is not stable across Rust versions or builds.
/// These hashes must never be persisted or compared across process restarts.
fn hash_str(s: &str) -> u64 {
    let mut hasher = DefaultHasher::new();
    s.hash(&mut hasher);
    hasher.finish()
}

#[cfg(feature = "widget-canvas")]
/// Extract sorted layer data directly from canvas props as cloned `Value`s.
///
/// This avoids the serialize-then-deserialize round trip that
/// `canvas_layer_map` + deserialization would do. `canvas_layer_map` is
/// still used in `ensure_caches` where string hashing is needed, but
/// `render_canvas` only needs the parsed shapes.
fn canvas_layers_from_props(
    props: Option<&serde_json::Map<String, Value>>,
) -> Vec<(String, Vec<Value>)> {
    if let Some(layers_obj) = props
        .and_then(|p| p.get("layers"))
        .and_then(|v| v.as_object())
    {
        let mut layers: Vec<(String, Vec<Value>)> = layers_obj
            .iter()
            .map(|(name, shapes_val)| {
                let shapes = shapes_val.as_array().cloned().unwrap_or_default();
                (name.clone(), shapes)
            })
            .collect();
        layers.sort_by(|a, b| a.0.cmp(&b.0));
        layers
    } else if let Some(shapes_arr) = props
        .and_then(|p| p.get("shapes"))
        .and_then(|v| v.as_array())
    {
        vec![("default".to_string(), shapes_arr.clone())]
    } else {
        Vec::new()
    }
}

#[cfg(feature = "widget-canvas")]
#[derive(Default)]
struct CanvasState {
    cursor_position: Option<Point>,
}

#[cfg(feature = "widget-canvas")]
struct CanvasProgram<'a> {
    /// Sorted layer data: (layer_name, shapes array).
    layers: Vec<(String, Vec<Value>)>,
    /// Per-layer caches from WidgetCaches.
    caches: Option<&'a HashMap<String, (u64, canvas::Cache)>>,
    background: Option<Color>,
    id: String,
    on_press: bool,
    on_release: bool,
    on_move: bool,
    on_scroll: bool,
    /// Reference to the image registry for resolving in-memory image handles.
    images: &'a crate::image_registry::ImageRegistry,
}

#[cfg(feature = "widget-canvas")]
impl CanvasProgram<'_> {
    fn is_interactive(&self) -> bool {
        self.on_press || self.on_release || self.on_move || self.on_scroll
    }
}

#[cfg(feature = "widget-canvas")]
/// Parse a `fill_rule` string into a `canvas::fill::Rule`. Defaults to `NonZero`.
fn parse_fill_rule(value: Option<&Value>) -> canvas::fill::Rule {
    match value.and_then(|v| v.as_str()) {
        Some("even_odd") => canvas::fill::Rule::EvenOdd,
        _ => canvas::fill::Rule::NonZero,
    }
}

#[cfg(feature = "widget-canvas")]
/// Parse a canvas fill value. If string, hex color. If gradient object,
/// build a gradient::Linear. Falls back to white. The `shape` parameter
/// provides the parent shape object for reading the `fill_rule` key.
fn parse_canvas_fill(value: &Value, shape: &Value) -> canvas::Fill {
    let rule = parse_fill_rule(shape.get("fill_rule"));
    match value {
        Value::String(s) => {
            let color = parse_hex_color(s).unwrap_or(Color::WHITE);
            canvas::Fill {
                style: canvas::Style::Solid(color),
                rule,
            }
        }
        Value::Object(obj) => match obj.get("type").and_then(|v| v.as_str()) {
            Some("linear") => {
                // Warn on unrecognized canvas gradient keys
                let valid_keys: &[&str] = &["type", "start", "end", "stops"];
                for key in obj.keys() {
                    if !valid_keys.contains(&key.as_str()) {
                        log::warn!(
                            "unrecognized canvas gradient key '{}' (valid: {:?})",
                            key,
                            valid_keys
                        );
                    }
                }

                let start = obj
                    .get("start")
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        Point::new(
                            a.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                            a.get(1).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                        )
                    })
                    .unwrap_or(Point::ORIGIN);
                let end = obj
                    .get("end")
                    .and_then(|v| v.as_array())
                    .map(|a| {
                        Point::new(
                            a.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                            a.get(1).and_then(|v| v.as_f64()).unwrap_or(0.0) as f32,
                        )
                    })
                    .unwrap_or(Point::ORIGIN);
                let mut linear = canvas::gradient::Linear::new(start, end);
                if let Some(stops) = obj.get("stops").and_then(|v| v.as_array()) {
                    for stop in stops {
                        if let Some(arr) = stop.as_array() {
                            let offset = arr.first().and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                            let color = arr
                                .get(1)
                                .and_then(parse_color)
                                .unwrap_or(Color::TRANSPARENT);
                            linear = linear.add_stop(offset, color);
                        }
                    }
                }
                canvas::Fill {
                    style: canvas::Style::Gradient(canvas::Gradient::Linear(linear)),
                    rule,
                }
            }
            Some(other) => {
                log::warn!(
                    "unrecognized canvas gradient type '{}' (supported: \"linear\")",
                    other
                );
                let color = parse_color(value).unwrap_or(Color::WHITE);
                canvas::Fill {
                    style: canvas::Style::Solid(color),
                    rule,
                }
            }
            _ => {
                let color = parse_color(value).unwrap_or(Color::WHITE);
                canvas::Fill {
                    style: canvas::Style::Solid(color),
                    rule,
                }
            }
        },
        _ => canvas::Fill {
            style: canvas::Style::Solid(Color::WHITE),
            rule,
        },
    }
}

#[cfg(feature = "widget-canvas")]
/// Parse a canvas stroke from a JSON object.
fn parse_canvas_stroke(value: &Value) -> canvas::Stroke<'static> {
    let obj = match value.as_object() {
        Some(o) => o,
        None => return canvas::Stroke::default(),
    };
    let color = obj
        .get("color")
        .and_then(parse_color)
        .unwrap_or(Color::WHITE);
    let width = obj
        .get("width")
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(1.0);
    let cap = match obj.get("cap").and_then(|v| v.as_str()).unwrap_or("butt") {
        "round" => canvas::LineCap::Round,
        "square" => canvas::LineCap::Square,
        _ => canvas::LineCap::Butt,
    };
    let join = match obj.get("join").and_then(|v| v.as_str()).unwrap_or("miter") {
        "round" => canvas::LineJoin::Round,
        "bevel" => canvas::LineJoin::Bevel,
        _ => canvas::LineJoin::Miter,
    };
    let mut stroke = canvas::Stroke::default()
        .with_color(color)
        .with_width(width)
        .with_line_cap(cap)
        .with_line_join(join);
    if let Some(dash_obj) = obj.get("dash").and_then(|v| v.as_object()) {
        let segments_val = dash_obj
            .get("segments")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default();
        let segments: Vec<f32> = segments_val
            .iter()
            .filter_map(|v| v.as_f64().map(|n| n as f32))
            .collect();
        let offset = dash_obj
            .get("offset")
            .and_then(|v| v.as_u64())
            .map(|v| v as usize)
            .unwrap_or(0);
        // LineDash borrows segments, but we need 'static. Use a leaked Box.
        let segments: &'static [f32] = Box::leak(segments.into_boxed_slice());
        stroke.line_dash = canvas::LineDash { segments, offset };
    }
    stroke
}

#[cfg(feature = "widget-canvas")]
/// Build a Path from an array of path commands.
fn build_path_from_commands(commands: &[Value]) -> canvas::Path {
    canvas::Path::new(|builder| {
        for cmd in commands {
            if let Some(s) = cmd.as_str() {
                if s == "close" {
                    builder.close();
                }
                continue;
            }
            let arr = match cmd.as_array() {
                Some(a) if !a.is_empty() => a,
                _ => continue,
            };
            let cmd_name = arr[0].as_str().unwrap_or("");
            let f = |i: usize| -> f32 {
                arr.get(i)
                    .and_then(|v| v.as_f64())
                    .map(|v| v as f32)
                    .unwrap_or(0.0)
            };
            match cmd_name {
                "move_to" => builder.move_to(Point::new(f(1), f(2))),
                "line_to" => builder.line_to(Point::new(f(1), f(2))),
                "bezier_to" => builder.bezier_curve_to(
                    Point::new(f(1), f(2)),
                    Point::new(f(3), f(4)),
                    Point::new(f(5), f(6)),
                ),
                "quadratic_to" => {
                    builder.quadratic_curve_to(Point::new(f(1), f(2)), Point::new(f(3), f(4)))
                }
                "arc" => {
                    builder.arc(canvas::path::Arc {
                        center: Point::new(f(1), f(2)),
                        radius: f(3),
                        start_angle: Radians(f(4)),
                        end_angle: Radians(f(5)),
                    });
                }
                "arc_to" => {
                    builder.arc_to(Point::new(f(1), f(2)), Point::new(f(3), f(4)), f(5));
                }
                "ellipse" => {
                    builder.ellipse(canvas::path::arc::Elliptical {
                        center: Point::new(f(1), f(2)),
                        radii: Vector::new(f(3), f(4)),
                        rotation: Radians(f(5)),
                        start_angle: Radians(f(6)),
                        end_angle: Radians(f(7)),
                    });
                }
                "rounded_rect" => {
                    builder.rounded_rectangle(
                        Point::new(f(1), f(2)),
                        Size::new(f(3), f(4)),
                        iced::border::Radius::new(f(5)),
                    );
                }
                _ => {}
            }
        }
    })
}

#[cfg(feature = "widget-canvas")]
/// Draw a sequence of shapes, handling push_clip/pop_clip nesting.
fn draw_canvas_shapes(
    frame: &mut canvas::Frame,
    shapes: &[&Value],
    images: &crate::image_registry::ImageRegistry,
) {
    let mut i = 0;
    while i < shapes.len() {
        let shape = shapes[i];
        let shape_type = shape.get("type").and_then(|v| v.as_str()).unwrap_or("");
        match shape_type {
            "push_clip" => {
                let x = shape.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                let y = shape.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                let w = shape.get("w").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                let h = shape.get("h").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                let (end_offset, clipped) = collect_clipped_shapes(&shapes[i + 1..]);
                let clip_rect = iced::Rectangle {
                    x,
                    y,
                    width: w,
                    height: h,
                };
                frame.with_clip(clip_rect, |f| {
                    draw_canvas_shapes(f, &clipped, images);
                });
                // Skip past the matching pop_clip
                i = i + 1 + end_offset + 1;
            }
            "pop_clip" => {
                // Stray pop_clip at top level -- should not happen if properly paired.
                log::warn!("canvas: pop_clip without matching push_clip");
                i += 1;
            }
            _ => {
                draw_canvas_shape(frame, shape, images);
                i += 1;
            }
        }
    }
}

#[cfg(feature = "widget-canvas")]
/// Collect shapes between a push_clip and its matching pop_clip, respecting
/// nesting. Returns (index_of_pop_clip_in_slice, collected_shapes).
fn collect_clipped_shapes<'a>(shapes: &[&'a Value]) -> (usize, Vec<&'a Value>) {
    let mut depth: usize = 0;
    let mut result: Vec<&'a Value> = Vec::new();
    for (i, &shape) in shapes.iter().enumerate() {
        let t = shape.get("type").and_then(|v| v.as_str()).unwrap_or("");
        match t {
            "push_clip" => {
                depth += 1;
                result.push(shape);
            }
            "pop_clip" if depth == 0 => {
                return (i, result);
            }
            "pop_clip" => {
                depth -= 1;
                result.push(shape);
            }
            _ => {
                result.push(shape);
            }
        }
    }
    // No matching pop_clip found -- draw all remaining shapes anyway.
    log::warn!("canvas: push_clip without matching pop_clip");
    (shapes.len(), result)
}

#[cfg(feature = "widget-canvas")]
/// Draw a single shape (or transform command) into the frame.
fn draw_canvas_shape(
    frame: &mut canvas::Frame,
    shape: &Value,
    images: &crate::image_registry::ImageRegistry,
) {
    let shape_type = shape.get("type").and_then(|v| v.as_str()).unwrap_or("");
    match shape_type {
        // -- Transform commands --
        "push_transform" => frame.push_transform(),
        "pop_transform" => frame.pop_transform(),
        "translate" => {
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            frame.translate(Vector::new(x, y));
        }
        "rotate" => {
            let angle = json_f32(shape, "angle");
            frame.rotate(Radians(angle));
        }
        "scale" => {
            // Uniform scaling via "factor", or non-uniform via "x"/"y".
            if let Some(factor) = shape.get("factor").and_then(|v| v.as_f64()) {
                frame.scale(factor as f32);
            } else {
                let x = shape.get("x").and_then(|v| v.as_f64()).unwrap_or(1.0) as f32;
                let y = shape.get("y").and_then(|v| v.as_f64()).unwrap_or(1.0) as f32;
                frame.scale_nonuniform(Vector::new(x, y));
            }
        }
        // -- Primitive shapes --
        "rect" => {
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            let w = json_f32(shape, "w");
            let h = json_f32(shape, "h");
            let rect_path = if let Some(r) = shape.get("radius").and_then(|v| v.as_f64()) {
                canvas::Path::rounded_rectangle(
                    Point::new(x, y),
                    Size::new(w, h),
                    iced::border::Radius::from(r as f32),
                )
            } else {
                canvas::Path::rectangle(Point::new(x, y), Size::new(w, h))
            };
            if let Some(fill_val) = shape.get("fill") {
                let fill = parse_canvas_fill(fill_val, shape);
                frame.fill(&rect_path, fill);
            } else if shape.get("stroke").is_none() {
                // Legacy fallback: no fill or stroke key means solid white fill
                frame.fill_rectangle(Point::new(x, y), Size::new(w, h), Color::WHITE);
            }
            if let Some(stroke_val) = shape.get("stroke") {
                let stroke = parse_canvas_stroke(stroke_val);
                frame.stroke(&rect_path, stroke);
            }
        }
        "circle" => {
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            let r = json_f32(shape, "r");
            let circle_path = canvas::Path::circle(Point::new(x, y), r);
            if let Some(fill_val) = shape.get("fill") {
                let fill = parse_canvas_fill(fill_val, shape);
                frame.fill(&circle_path, fill);
            } else if shape.get("stroke").is_none() {
                frame.fill(&circle_path, Color::WHITE);
            }
            if let Some(stroke_val) = shape.get("stroke") {
                let stroke = parse_canvas_stroke(stroke_val);
                frame.stroke(&circle_path, stroke);
            }
        }
        "line" => {
            let x1 = json_f32(shape, "x1");
            let y1 = json_f32(shape, "y1");
            let x2 = json_f32(shape, "x2");
            let y2 = json_f32(shape, "y2");
            let line_path = canvas::Path::line(Point::new(x1, y1), Point::new(x2, y2));
            if let Some(stroke_val) = shape.get("stroke") {
                let stroke = parse_canvas_stroke(stroke_val);
                frame.stroke(&line_path, stroke);
            } else {
                // Legacy: use fill color as stroke color
                let color = json_color(shape, "fill");
                let width = shape
                    .get("width")
                    .and_then(|v| v.as_f64())
                    .map(|v| v as f32)
                    .unwrap_or(1.0);
                frame.stroke(
                    &line_path,
                    canvas::Stroke::default()
                        .with_color(color)
                        .with_width(width),
                );
            }
        }
        "text" => {
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            let content = shape.get("content").and_then(|v| v.as_str()).unwrap_or("");
            let fill_color = json_color(shape, "fill");
            let size = shape.get("size").and_then(|v| v.as_f64()).map(|v| v as f32);
            let mut canvas_text = canvas::Text {
                content: content.to_owned(),
                position: Point::new(x, y),
                color: fill_color,
                ..canvas::Text::default()
            };
            if let Some(s) = size {
                canvas_text.size = Pixels(s);
            }
            if let Some(f) = shape.get("font") {
                canvas_text.font = parse_font(f);
            }
            frame.fill_text(canvas_text);
        }
        "path" => {
            let commands = shape
                .get("commands")
                .and_then(|v| v.as_array())
                .map(|a| a.as_slice())
                .unwrap_or(&[]);
            let path = build_path_from_commands(commands);
            if let Some(fill_val) = shape.get("fill") {
                let fill = parse_canvas_fill(fill_val, shape);
                frame.fill(&path, fill);
            }
            if let Some(stroke_val) = shape.get("stroke") {
                let stroke = parse_canvas_stroke(stroke_val);
                frame.stroke(&path, stroke);
            }
        }
        #[cfg(feature = "widget-image")]
        "image" => {
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            let w = json_f32(shape, "w");
            let h = json_f32(shape, "h");
            let bounds = iced::Rectangle {
                x,
                y,
                width: w,
                height: h,
            };
            // Source can be a string (file path) or an object with "handle" key
            // (in-memory image from the registry), same as the Image widget.
            let source_val = shape.get("source");
            let handle = match source_val {
                Some(Value::Object(obj)) => {
                    if let Some(name) = obj.get("handle").and_then(|v| v.as_str()) {
                        match images.get(name) {
                            Some(h) => h.clone(),
                            None => {
                                log::warn!("canvas image: unknown registry handle: {name}");
                                return;
                            }
                        }
                    } else {
                        return;
                    }
                }
                _ => {
                    let path = source_val.and_then(|v| v.as_str()).unwrap_or("");
                    iced::widget::image::Handle::from_path(path)
                }
            };
            frame.draw_image(bounds, &handle);
        }
        "svg" => {
            let source = shape.get("source").and_then(|v| v.as_str()).unwrap_or("");
            let x = json_f32(shape, "x");
            let y = json_f32(shape, "y");
            let w = json_f32(shape, "w");
            let h = json_f32(shape, "h");
            let bounds = iced::Rectangle {
                x,
                y,
                width: w,
                height: h,
            };
            let handle = iced::widget::svg::Handle::from_path(source);
            frame.draw_svg(bounds, &handle);
        }
        _ => {}
    }
}

#[cfg(feature = "widget-canvas")]
impl canvas::Program<Message> for CanvasProgram<'_> {
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
        let mut geometries = Vec::new();

        // Background fill -- cheap single rect, not cached.
        if let Some(bg) = self.background {
            let mut frame = canvas::Frame::new(renderer, bounds.size());
            frame.fill_rectangle(Point::ORIGIN, bounds.size(), bg);
            geometries.push(frame.into_geometry());
        }

        // Draw each layer, using its cache when available.
        let images = self.images;
        for (layer_name, shapes) in &self.layers {
            let shape_refs: Vec<&Value> = shapes.iter().collect();
            let geom = if let Some((_hash, cache)) = self.caches.and_then(|c| c.get(layer_name)) {
                cache.draw(renderer, bounds.size(), |frame| {
                    draw_canvas_shapes(frame, &shape_refs, images);
                })
            } else {
                // No cache available (shouldn't happen after ensure_caches, but
                // handle gracefully by drawing uncached).
                let mut frame = canvas::Frame::new(renderer, bounds.size());
                draw_canvas_shapes(&mut frame, &shape_refs, images);
                frame.into_geometry()
            };
            geometries.push(geom);
        }

        geometries
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

#[cfg(feature = "widget-canvas")]
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

#[cfg(feature = "widget-canvas")]
fn render_canvas<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    _theme: &'a iced::Theme,
    _dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Fill);
    let height = prop_length(props, "height", Length::Fixed(200.0));

    // Build sorted layer data directly from props, avoiding the
    // serialize-then-deserialize round trip that canvas_layer_map would do.
    let layers: Vec<(String, Vec<Value>)> = canvas_layers_from_props(props);

    let node_caches = caches.canvas_caches.get(&node.id);

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
        layers,
        caches: node_caches,
        background,
        id: node.id.clone(),
        on_press: on_press || interactive,
        on_release: on_release || interactive,
        on_move: on_move || interactive,
        on_scroll: on_scroll || interactive,
        images,
    })
    .width(width)
    .height(height)
    .into()
}

#[cfg(feature = "widget-canvas")]
/// Parse an f32 from a JSON value by key, defaulting to 0.
fn json_f32(val: &Value, key: &str) -> f32 {
    val.get(key)
        .and_then(|v| v.as_f64())
        .map(|v| v as f32)
        .unwrap_or(0.0)
}

#[cfg(feature = "widget-canvas")]
/// Parse a Color from a JSON "fill" field. Accepts "#rrggbb" hex strings;
/// defaults to white if missing or unparseable.
fn json_color(val: &Value, key: &str) -> Color {
    val.get(key).and_then(parse_color).unwrap_or(Color::WHITE)
}

// ---------------------------------------------------------------------------
// QR Code
// ---------------------------------------------------------------------------

#[cfg(feature = "widget-qr-code")]
struct QrCodeProgram<'a> {
    modules: Vec<Vec<bool>>,
    cell_size: f32,
    cell_color: Color,
    background_color: Color,
    cache: Option<&'a (u64, canvas::Cache)>,
}

#[cfg(feature = "widget-qr-code")]
impl canvas::Program<Message> for QrCodeProgram<'_> {
    type State = ();

    fn draw(
        &self,
        _state: &Self::State,
        renderer: &iced::Renderer,
        _theme: &iced::Theme,
        bounds: iced::Rectangle,
        _cursor: mouse::Cursor,
    ) -> Vec<canvas::Geometry> {
        let draw_fn = |frame: &mut canvas::Frame| {
            // Fill background
            frame.fill_rectangle(Point::ORIGIN, bounds.size(), self.background_color);
            // Draw each dark module as a filled square
            for (row_idx, row) in self.modules.iter().enumerate() {
                for (col_idx, &dark) in row.iter().enumerate() {
                    if dark {
                        let x = col_idx as f32 * self.cell_size;
                        let y = row_idx as f32 * self.cell_size;
                        frame.fill_rectangle(
                            Point::new(x, y),
                            Size::new(self.cell_size, self.cell_size),
                            self.cell_color,
                        );
                    }
                }
            }
        };

        if let Some((_hash, ref cache)) = self.cache {
            vec![cache.draw(renderer, bounds.size(), draw_fn)]
        } else {
            let mut frame = canvas::Frame::new(renderer, bounds.size());
            draw_fn(&mut frame);
            vec![frame.into_geometry()]
        }
    }
}

#[cfg(feature = "widget-qr-code")]
fn render_qr_code<'a>(node: &'a TreeNode, caches: &'a WidgetCaches) -> Element<'a, Message> {
    let props = node.props.as_object();
    let data = prop_str(props, "data").unwrap_or_default();
    let cell_size = prop_f32(props, "cell_size").unwrap_or(4.0);
    let ec_str = prop_str(props, "error_correction").unwrap_or_default();
    let cell_color = prop_str(props, "cell_color")
        .and_then(|s| parse_hex_color(&s))
        .unwrap_or(Color::BLACK);
    let background_color = prop_str(props, "background_color")
        .and_then(|s| parse_hex_color(&s))
        .unwrap_or(Color::WHITE);

    let ec_level = match ec_str.as_str() {
        "low" => qrcode::EcLevel::L,
        "quartile" => qrcode::EcLevel::Q,
        "high" => qrcode::EcLevel::H,
        _ => qrcode::EcLevel::M,
    };

    let qr = match qrcode::QrCode::with_error_correction_level(data.as_bytes(), ec_level) {
        Ok(qr) => qr,
        Err(e) => {
            log::warn!("[id={}] qr_code: failed to encode data: {e}", node.id);
            return text(format!("QR code error: {e}")).into();
        }
    };

    let width = qr.width();
    let modules: Vec<Vec<bool>> = (0..width)
        .map(|y| {
            (0..width)
                .map(|x| qr[(x, y)] == qrcode::types::Color::Dark)
                .collect()
        })
        .collect();

    let pixel_size = width as f32 * cell_size;

    let cache_entry = caches.qr_code_caches.get(&node.id);

    canvas(QrCodeProgram {
        modules,
        cell_size,
        cell_color,
        background_color,
        cache: cache_entry,
    })
    .width(Length::Fixed(pixel_size))
    .height(Length::Fixed(pixel_size))
    .into()
}

// ---------------------------------------------------------------------------
// Table (composite: column/row headers + data rows)
// ---------------------------------------------------------------------------

/// Parsed column descriptor from the "columns" prop.
struct TableColumn {
    key: String,
    label: String,
    align: alignment::Horizontal,
    width: Length,
    sortable: bool,
}

fn parse_table_columns(props: Props<'_>) -> Vec<TableColumn> {
    props
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
                    let align = col
                        .get("align")
                        .and_then(|v| v.as_str())
                        .and_then(value_to_horizontal_alignment)
                        .unwrap_or(alignment::Horizontal::Left);
                    let width = col
                        .get("width")
                        .and_then(value_to_length)
                        .unwrap_or(Length::FillPortion(1));
                    let sortable = col
                        .get("sortable")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false);
                    Some(TableColumn {
                        key,
                        label,
                        align,
                        width,
                        sortable,
                    })
                })
                .collect()
        })
        .unwrap_or_default()
}

fn render_table<'a>(node: &'a TreeNode) -> Element<'a, Message> {
    let props = node.props.as_object();
    let width = prop_length(props, "width", Length::Fill);
    let show_header = prop_bool_default(props, "header", true);
    let padding_val = parse_padding_value(props);
    let table_id = node.id.clone();

    let sort_by = prop_str(props, "sort_by");
    let sort_order = prop_str(props, "sort_order");

    let columns = parse_table_columns(props);

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
            .map(|col| {
                // Build sort indicator if this column is currently sorted.
                let sort_indicator = if sort_by.as_deref() == Some(&col.key) {
                    match sort_order.as_deref() {
                        Some("asc") => " \u{25B2}",
                        Some("desc") => " \u{25BC}",
                        _ => "",
                    }
                } else {
                    ""
                };

                let label_text = format!("{}{}", col.label, sort_indicator);

                if col.sortable {
                    let click_id = table_id.clone();
                    let click_key = col.key.clone();
                    container(
                        button(text(label_text).size(14.0))
                            .on_press(Message::Event(
                                click_id,
                                serde_json::json!({"column": click_key}),
                                "sort".into(),
                            ))
                            .style(button::text),
                    )
                    .width(col.width)
                    .align_x(col.align)
                    .into()
                } else {
                    container(text(label_text).size(14.0))
                        .width(col.width)
                        .align_x(col.align)
                        .into()
                }
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
            .map(|col| {
                let cell_text = data_row
                    .get(&col.key)
                    .map(|v| match v {
                        Value::String(s) => s.clone(),
                        other => other.to_string(),
                    })
                    .unwrap_or_default();
                container(text(cell_text).size(13.0))
                    .width(col.width)
                    .align_x(col.align)
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

#[cfg(any(feature = "widget-image", feature = "widget-svg"))]
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
// Mouse interaction (cursor) parsing
// ---------------------------------------------------------------------------

fn parse_interaction(s: &str) -> Option<mouse::Interaction> {
    Some(match s {
        "pointer" => mouse::Interaction::Pointer,
        "grab" => mouse::Interaction::Grab,
        "grabbing" => mouse::Interaction::Grabbing,
        "crosshair" => mouse::Interaction::Crosshair,
        "text" => mouse::Interaction::Text,
        "move" => mouse::Interaction::Move,
        "not_allowed" => mouse::Interaction::NotAllowed,
        "progress" => mouse::Interaction::Progress,
        "wait" => mouse::Interaction::Wait,
        "help" => mouse::Interaction::Help,
        "cell" => mouse::Interaction::Cell,
        "copy" => mouse::Interaction::Copy,
        "alias" => mouse::Interaction::Alias,
        "no_drop" => mouse::Interaction::NoDrop,
        "all_scroll" => mouse::Interaction::AllScroll,
        "zoom_in" => mouse::Interaction::ZoomIn,
        "zoom_out" => mouse::Interaction::ZoomOut,
        "context_menu" => mouse::Interaction::ContextMenu,
        "resizing_horizontally" => mouse::Interaction::ResizingHorizontally,
        "resizing_vertically" => mouse::Interaction::ResizingVertically,
        "resizing_diagonally_up" => mouse::Interaction::ResizingDiagonallyUp,
        "resizing_diagonally_down" => mouse::Interaction::ResizingDiagonallyDown,
        "resizing_column" => mouse::Interaction::ResizingColumn,
        "resizing_row" => mouse::Interaction::ResizingRow,
        _ => return None,
    })
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
                    // Warn on unrecognized gradient keys
                    let valid_keys: &[&str] = &["type", "angle", "stops"];
                    for key in obj.keys() {
                        if !valid_keys.contains(&key.as_str()) {
                            log::warn!(
                                "unrecognized background gradient key '{}' (valid: {:?})",
                                key,
                                valid_keys
                            );
                        }
                    }

                    let angle_deg = obj.get("angle").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                    let angle = Radians(angle_deg.to_radians());
                    let mut linear = iced::gradient::Linear::new(angle);

                    if let Some(stops) = obj.get("stops").and_then(|v| v.as_array()) {
                        let valid_stop_keys: &[&str] = &["offset", "color"];
                        for stop in stops {
                            if let Some(stop_obj) = stop.as_object() {
                                for key in stop_obj.keys() {
                                    if !valid_stop_keys.contains(&key.as_str()) {
                                        log::warn!(
                                            "unrecognized gradient stop key '{}' (valid: {:?})",
                                            key,
                                            valid_stop_keys
                                        );
                                    }
                                }
                            }
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
                Some(other) => {
                    log::warn!(
                        "unrecognized gradient type '{}' (supported: \"linear\")",
                        other
                    );
                    parse_color(value).map(iced::Background::Color)
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
                    // Default is SansSerif; unrecognized names are passed
                    // through as custom font families (user-loaded fonts).
                    "default" | "sans_serif" | "sans-serif" | "sansserif" | "" => {}
                    other => {
                        // Leak the string to get a 'static lifetime. Font
                        // family names are a small, finite set that lives for
                        // the process lifetime, so this is acceptable.
                        let leaked: &'static str = Box::leak(other.to_owned().into_boxed_str());
                        f.family = font::Family::Name(leaked);
                    }
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
// Style map parsing
// ---------------------------------------------------------------------------

/// Parsed fields from a style map JSON object. All fields are optional;
/// only those present in the JSON get populated.
#[derive(Clone, Default)]
struct StyleMapFields {
    background: Option<iced::Background>,
    text_color: Option<Color>,
    border: Option<Border>,
    shadow: Option<Shadow>,
}

fn parse_style_map_fields(obj: &serde_json::Map<String, Value>) -> StyleMapFields {
    StyleMapFields {
        background: obj.get("background").and_then(parse_background),
        text_color: obj.get("text_color").and_then(parse_color),
        border: obj.get("border").map(parse_border),
        shadow: obj.get("shadow").map(parse_shadow),
    }
}

/// Parsed style overrides for all status variants. The base fields are always
/// present; status-specific overrides are optional.
#[derive(Clone)]
struct StyleOverrides {
    base: StyleMapFields,
    hovered: Option<StyleMapFields>,
    pressed: Option<StyleMapFields>,
    disabled: Option<StyleMapFields>,
    focused: Option<StyleMapFields>,
}

fn parse_style_overrides(obj: &serde_json::Map<String, Value>) -> StyleOverrides {
    StyleOverrides {
        base: parse_style_map_fields(obj),
        hovered: obj
            .get("hovered")
            .and_then(|v| v.as_object())
            .map(parse_style_map_fields),
        pressed: obj
            .get("pressed")
            .and_then(|v| v.as_object())
            .map(parse_style_map_fields),
        disabled: obj
            .get("disabled")
            .and_then(|v| v.as_object())
            .map(parse_style_map_fields),
        focused: obj
            .get("focused")
            .and_then(|v| v.as_object())
            .map(parse_style_map_fields),
    }
}

/// Auto-derive hover background by darkening the base background to 90%.
fn auto_derive_hover_bg(bg: Option<iced::Background>) -> Option<iced::Background> {
    bg.map(|b| darken_background(b, 0.9))
}

/// Auto-derive disabled background by reducing alpha to 50%.
fn auto_derive_disabled_bg(bg: Option<iced::Background>) -> Option<iced::Background> {
    bg.map(|b| alpha_background(b, 0.5))
}

/// Auto-derive disabled text color by reducing alpha to 50%.
fn auto_derive_disabled_text(color: Color) -> Color {
    alpha_color(color, 0.5)
}

/// Apply style map fields to a button style. Background wraps in `Some`,
/// text_color, border, and shadow map directly.
fn apply_button_fields(style: &mut button::Style, fields: &StyleMapFields) {
    if let Some(bg) = fields.background {
        style.background = Some(bg);
    }
    if let Some(tc) = fields.text_color {
        style.text_color = tc;
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
    if let Some(shd) = fields.shadow {
        style.shadow = shd;
    }
}

/// Apply style map fields to a progress_bar style. Background maps as
/// `Background::Color`, text_color maps to the bar fill, border directly.
fn apply_progress_bar_fields(style: &mut progress_bar::Style, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(tc) = fields.text_color {
        style.bar = iced::Background::Color(tc);
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
}

/// Apply style map fields to a text_input or text_editor style. Both widgets
/// map background as `Background::Color`, border directly, and text_color to
/// the `value` field (the typed text color).
fn apply_text_input_fields(style: &mut text_input::Style, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
    if let Some(tc) = fields.text_color {
        style.value = tc;
    }
}

/// Apply style map fields to a text_editor style. Same field mapping as
/// text_input (background, border, text_color -> value).
fn apply_text_editor_fields(style: &mut text_editor::Style, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
    if let Some(tc) = fields.text_color {
        style.value = tc;
    }
}

/// Apply style map fields to a pick_list style. Background is
/// `Background::Color`, text_color and border map directly.
fn apply_pick_list_fields(style: &mut pick_list::Style, fields: &StyleMapFields) {
    if let Some(tc) = fields.text_color {
        style.text_color = tc;
    }
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
}

/// Apply style map fields to a slider handle. Background maps to
/// handle.background as `Background::Color`, border maps to
/// handle.border_width/border_color. Shared by slider and vertical_slider.
fn apply_slider_handle_fields(handle: &mut slider::Handle, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        handle.background = iced::Background::Color(c);
    }
    if let Some(brd) = fields.border {
        handle.border_width = brd.width;
        handle.border_color = brd.color;
    }
}

/// Apply style map fields to a radio style. Background is `Background::Color`,
/// text_color wraps in `Some`, border maps to border_width/border_color.
fn apply_radio_fields(style: &mut iced::widget::radio::Style, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(tc) = fields.text_color {
        style.text_color = Some(tc);
    }
    if let Some(brd) = fields.border {
        style.border_width = brd.width;
        style.border_color = brd.color;
    }
}

/// Apply style map fields to a toggler style. Background maps directly,
/// text_color wraps in `Some`, border maps to border_width/border_color.
fn apply_toggler_fields(style: &mut toggler::Style, fields: &StyleMapFields) {
    if let Some(bg) = fields.background {
        style.background = bg;
    }
    if let Some(tc) = fields.text_color {
        style.text_color = Some(tc);
    }
    if let Some(brd) = fields.border {
        style.background_border_width = brd.width;
        style.background_border_color = brd.color;
    }
}

/// Apply style map fields to a rule style. Maps background -> color,
/// border -> radius.
fn apply_rule_style(style: &mut rule::Style, fields: &StyleMapFields) -> rule::Style {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.color = c;
    }
    if let Some(brd) = fields.border {
        style.radius = brd.radius;
    }
    *style
}

/// Apply style map fields to a checkbox style. Background is `Background::Color`,
/// border directly, text_color wrapped in `Some`.
fn apply_checkbox_fields(style: &mut checkbox::Style, fields: &StyleMapFields) {
    if let Some(iced::Background::Color(c)) = fields.background {
        style.background = iced::Background::Color(c);
    }
    if let Some(brd) = fields.border {
        style.border = brd;
    }
    if let Some(tc) = fields.text_color {
        style.text_color = Some(tc);
    }
}

/// Build a `container::Style` from base style map fields. Used by both
/// container and tooltip widgets which share the same style type.
fn container_style_from_base(base: &StyleMapFields) -> container::Style {
    let mut style = container::Style {
        background: base.background,
        text_color: base.text_color,
        ..Default::default()
    };
    if let Some(brd) = base.border {
        style.border = brd;
    }
    if let Some(shd) = base.shadow {
        style.shadow = shd;
    }
    style
}

fn darken_color(color: Color, factor: f32) -> Color {
    Color {
        r: color.r * factor,
        g: color.g * factor,
        b: color.b * factor,
        a: color.a,
    }
}

fn alpha_color(color: Color, alpha: f32) -> Color {
    Color {
        r: color.r,
        g: color.g,
        b: color.b,
        a: color.a * alpha,
    }
}

fn darken_background(bg: iced::Background, factor: f32) -> iced::Background {
    match bg {
        iced::Background::Color(c) => iced::Background::Color(darken_color(c, factor)),
        other => other,
    }
}

fn alpha_background(bg: iced::Background, alpha: f32) -> iced::Background {
    match bg {
        iced::Background::Color(c) => iced::Background::Color(alpha_color(c, alpha)),
        other => other,
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
// Overlay
// ---------------------------------------------------------------------------

fn render_overlay<'a>(
    node: &'a TreeNode,
    caches: &'a WidgetCaches,
    images: &'a crate::image_registry::ImageRegistry,
    theme: &'a iced::Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> Element<'a, Message> {
    use crate::overlay_widget;

    let props = node.props.as_object();
    let position = prop_str(props, "position").unwrap_or_else(|| "below".to_string());
    let gap = prop_f32(props, "gap").unwrap_or(0.0);
    let offset_x = prop_f32(props, "offset_x").unwrap_or(0.0);
    let offset_y = prop_f32(props, "offset_y").unwrap_or(0.0);

    let children = &node.children;
    if children.len() < 2 {
        return text("overlay requires 2 children").into();
    }

    let anchor = render(&children[0], caches, images, theme, dispatcher);
    let content = render(&children[1], caches, images, theme, dispatcher);

    let pos = match position.as_str() {
        "above" => overlay_widget::Position::Above,
        "left" => overlay_widget::Position::Left,
        "right" => overlay_widget::Position::Right,
        _ => overlay_widget::Position::Below,
    };

    overlay_widget::OverlayWrapper::new(anchor, content, pos, gap, offset_x, offset_y).into()
}

// ---------------------------------------------------------------------------
// Debug-mode prop validation (H-08 / M-14)
// ---------------------------------------------------------------------------

/// Prop type expectations for validation.
#[cfg(debug_assertions)]
#[derive(Debug, Clone, Copy)]
enum PropType {
    Str,
    Number,
    Bool,
    Length,
    Color,
    Array,
    Any,
}

#[cfg(debug_assertions)]
fn prop_type_matches(val: &Value, expected: PropType) -> bool {
    match expected {
        PropType::Str => val.is_string(),
        PropType::Number => val.is_number() || val.is_string(), // numeric strings accepted
        PropType::Bool => val.is_boolean(),
        PropType::Length => val.is_number() || val.is_string() || val.is_object(),
        PropType::Color => val.is_string(),
        PropType::Array => val.is_array(),
        PropType::Any => true,
    }
}

/// Validate props for known widget types. Only active in debug builds.
/// Logs warnings for unexpected prop names or mismatched types.
#[cfg(debug_assertions)]
fn validate_props(node: &TreeNode) {
    use PropType::*;

    let expected: &[(&str, PropType)] = match node.type_name.as_str() {
        "button" => &[
            ("label", Str),
            ("style", Any),
            ("width", Length),
            ("height", Length),
            ("padding", Any),
            ("clip", Bool),
            ("disabled", Bool),
        ],
        "text" => &[
            ("content", Str),
            ("size", Number),
            ("color", Color),
            ("font", Any),
            ("width", Length),
            ("height", Length),
            ("horizontal_alignment", Str),
            ("vertical_alignment", Str),
            ("line_height", Number),
            ("shaping", Str),
            ("wrapping", Str),
        ],
        "column" => &[
            ("spacing", Number),
            ("padding", Any),
            ("width", Length),
            ("height", Length),
            ("max_width", Number),
            ("align_items", Str),
            ("clip", Bool),
        ],
        "row" => &[
            ("spacing", Number),
            ("padding", Any),
            ("width", Length),
            ("height", Length),
            ("max_width", Number),
            ("align_items", Str),
            ("clip", Bool),
        ],
        "container" => &[
            ("padding", Any),
            ("width", Length),
            ("height", Length),
            ("max_width", Number),
            ("max_height", Number),
            ("center_x", Any),
            ("center_y", Any),
            ("horizontal_alignment", Str),
            ("vertical_alignment", Str),
            ("clip", Bool),
            ("style", Any),
            ("background", Any),
        ],
        "text_input" => &[
            ("value", Str),
            ("placeholder", Str),
            ("font", Any),
            ("width", Length),
            ("padding", Any),
            ("size", Number),
            ("line_height", Number),
            ("secure", Bool),
            ("style", Any),
            ("icon", Any),
            ("disabled", Bool),
        ],
        "slider" => &[
            ("value", Number),
            ("range", Array),
            ("step", Number),
            ("width", Length),
            ("height", Number),
            ("style", Any),
            ("shift_step", Number),
            ("default", Number),
        ],
        "checkbox" => &[
            ("label", Str),
            ("is_checked", Bool),
            ("size", Number),
            ("font", Any),
            ("text_size", Number),
            ("spacing", Number),
            ("width", Length),
            ("style", Any),
            ("icon", Any),
            ("disabled", Bool),
        ],
        "toggler" => &[
            ("label", Str),
            ("is_toggled", Bool),
            ("size", Number),
            ("font", Any),
            ("text_size", Number),
            ("spacing", Number),
            ("width", Length),
            ("style", Any),
            ("disabled", Bool),
        ],
        "progress_bar" => &[
            ("value", Number),
            ("range", Array),
            ("width", Length),
            ("height", Length),
            ("style", Any),
        ],
        "image" => &[
            ("source", Any),
            ("width", Length),
            ("height", Length),
            ("content_fit", Str),
            ("filter_method", Str),
            ("rotation", Any),
            ("opacity", Number),
            ("border_radius", Any),
        ],
        "svg" => &[
            ("source", Str),
            ("width", Length),
            ("height", Length),
            ("content_fit", Str),
            ("rotation", Any),
            ("opacity", Number),
            ("color", Color),
        ],
        "scrollable" => &[
            ("width", Length),
            ("height", Length),
            ("direction", Any),
            ("style", Any),
            ("anchor", Str),
            ("spacing", Number),
        ],
        "grid" => &[
            ("columns", Number),
            ("spacing", Number),
            ("width", Number),
            ("height", Number),
            ("column_width", Length),
            ("row_height", Length),
        ],
        "radio" => &[
            ("label", Str),
            ("value", Str),
            ("selected", Any),
            ("size", Number),
            ("font", Any),
            ("text_size", Number),
            ("spacing", Number),
            ("width", Length),
            ("style", Any),
            ("group", Str),
        ],
        _ => return, // Unknown widget type -- skip validation
    };

    let props = match node.props.as_object() {
        Some(p) => p,
        None => return,
    };

    let expected_names: Vec<&str> = expected.iter().map(|(name, _)| *name).collect();

    for (key, val) in props {
        match expected.iter().find(|(name, _)| name == key) {
            Some((_, expected_type)) => {
                if !prop_type_matches(val, *expected_type) {
                    log::warn!(
                        "widget '{}' ({}): prop '{}' has unexpected type {:?} (expected {:?})",
                        node.id,
                        node.type_name,
                        key,
                        val,
                        expected_type
                    );
                }
            }
            None => {
                log::warn!(
                    "widget '{}' ({}): unexpected prop '{}' (known: {:?})",
                    node.id,
                    node.type_name,
                    key,
                    expected_names
                );
            }
        }
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
        #[cfg(feature = "widget-markdown")]
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

    // -- Style map tests --

    #[test]
    fn style_map_parse_overrides_basic() {
        let obj = json!({
            "background": "#ff0000",
            "text_color": "#00ff00",
            "border": {"color": "#0000ff", "width": 2.0, "radius": 4.0},
            "hovered": {
                "background": "#880000",
                "text_color": "#008800"
            },
            "pressed": {
                "background": "#440000"
            },
            "disabled": {
                "text_color": "#999999"
            },
            "focused": {
                "border": {"color": "#ffffff", "width": 3.0, "radius": 0.0}
            }
        });
        let map = obj.as_object().unwrap();
        let overrides = parse_style_overrides(map);

        // Base fields
        assert!(overrides.base.background.is_some());
        assert!(overrides.base.text_color.is_some());
        assert!(overrides.base.border.is_some());
        assert_eq!(
            overrides.base.text_color.unwrap(),
            Color::from_rgb8(0, 255, 0)
        );

        // Hovered override present with both fields
        let hovered = overrides.hovered.unwrap();
        assert!(hovered.background.is_some());
        assert!(hovered.text_color.is_some());

        // Pressed override present with background only
        let pressed = overrides.pressed.unwrap();
        assert!(pressed.background.is_some());
        assert!(pressed.text_color.is_none());

        // Disabled override present with text_color only
        let disabled = overrides.disabled.unwrap();
        assert!(disabled.background.is_none());
        assert!(disabled.text_color.is_some());

        // Focused override present with border only
        let focused = overrides.focused.unwrap();
        assert!(focused.border.is_some());
        assert!(focused.background.is_none());
    }

    #[test]
    fn style_map_parse_overrides_missing() {
        // Only base fields, no status overrides at all.
        let obj = json!({"background": "#aabbcc"});
        let map = obj.as_object().unwrap();
        let overrides = parse_style_overrides(map);

        assert!(overrides.base.background.is_some());
        assert!(overrides.hovered.is_none());
        assert!(overrides.pressed.is_none());
        assert!(overrides.disabled.is_none());
        assert!(overrides.focused.is_none());
    }

    #[test]
    fn style_map_auto_derive_hover() {
        // darken_background multiplies RGB by factor (0.9), alpha unchanged.
        let bg = Some(iced::Background::Color(Color::from_rgba(
            1.0, 0.5, 0.0, 1.0,
        )));
        let result = auto_derive_hover_bg(bg);
        match result {
            Some(iced::Background::Color(c)) => {
                // 1.0 * 0.9 = 0.9
                assert!((c.r - 0.9).abs() < 0.001);
                // 0.5 * 0.9 = 0.45
                assert!((c.g - 0.45).abs() < 0.001);
                // 0.0 * 0.9 = 0.0
                assert!((c.b - 0.0).abs() < 0.001);
                // alpha unchanged
                assert!((c.a - 1.0).abs() < 0.001);
            }
            other => panic!("expected Background::Color, got {other:?}"),
        }
    }

    #[test]
    fn style_map_auto_derive_disabled_bg() {
        // alpha_background multiplies alpha by 0.5, RGB unchanged.
        let bg = Some(iced::Background::Color(Color::from_rgba(
            0.8, 0.6, 0.4, 1.0,
        )));
        let result = auto_derive_disabled_bg(bg);
        match result {
            Some(iced::Background::Color(c)) => {
                assert!((c.r - 0.8).abs() < 0.001);
                assert!((c.g - 0.6).abs() < 0.001);
                assert!((c.b - 0.4).abs() < 0.001);
                // 1.0 * 0.5 = 0.5
                assert!((c.a - 0.5).abs() < 0.001);
            }
            other => panic!("expected Background::Color, got {other:?}"),
        }
    }

    #[test]
    fn style_map_auto_derive_disabled_text() {
        let color = Color::from_rgba(1.0, 1.0, 1.0, 0.8);
        let result = auto_derive_disabled_text(color);
        // RGB unchanged, alpha halved: 0.8 * 0.5 = 0.4
        assert!((result.r - 1.0).abs() < 0.001);
        assert!((result.g - 1.0).abs() < 0.001);
        assert!((result.b - 1.0).abs() < 0.001);
        assert!((result.a - 0.4).abs() < 0.001);
    }

    // -- Canvas caching tests --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_layer_map_from_layers() {
        let v = json!({
            "layers": {
                "background": [{"type": "rect", "width": 100}],
                "foreground": [{"type": "circle", "radius": 50}]
            }
        });
        let props = make_props(&v);
        let result = canvas_layer_map(props);
        assert_eq!(result.len(), 2);
        assert!(result.contains_key("background"));
        assert!(result.contains_key("foreground"));
        // Values are the stringified JSON of each layer's shapes array.
        let bg: Value = serde_json::from_str(result.get("background").unwrap()).unwrap();
        assert!(bg.is_array());
        assert_eq!(bg.as_array().unwrap().len(), 1);
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_layer_map_from_shapes() {
        // Legacy "shapes" key wraps in a "default" layer.
        let v = json!({
            "shapes": [{"type": "line", "x1": 0, "y1": 0, "x2": 100, "y2": 100}]
        });
        let props = make_props(&v);
        let result = canvas_layer_map(props);
        assert_eq!(result.len(), 1);
        assert!(result.contains_key("default"));
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_hash_changes() {
        let hash_a = hash_str("[{\"type\":\"rect\"}]");
        let hash_b = hash_str("[{\"type\":\"circle\"}]");
        let hash_a2 = hash_str("[{\"type\":\"rect\"}]");

        // Same input produces same hash.
        assert_eq!(hash_a, hash_a2);
        // Different input produces different hash.
        assert_ne!(hash_a, hash_b);
    }

    // -- Canvas layer sort order --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_layer_sort_order() {
        let v = json!({
            "layers": {
                "charlie": [{"type": "rect"}],
                "alpha": [{"type": "circle"}],
                "bravo": [{"type": "line"}]
            }
        });
        let props = make_props(&v);
        let result = canvas_layer_map(props);
        let keys: Vec<&String> = result.keys().collect();
        assert_eq!(keys, vec!["alpha", "bravo", "charlie"]);
    }

    // -- Canvas path commands --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_path_commands_basic() {
        let shape = json!({
            "type": "path",
            "commands": [
                ["move_to", 10, 20],
                ["line_to", 30, 40],
                "close"
            ]
        });
        assert_eq!(shape.get("type").and_then(|v| v.as_str()), Some("path"));
        let commands = shape.get("commands").and_then(|v| v.as_array()).unwrap();
        assert_eq!(commands.len(), 3);
        // First command is an array starting with "move_to".
        let move_cmd = commands[0].as_array().unwrap();
        assert_eq!(move_cmd[0].as_str(), Some("move_to"));
        assert_eq!(move_cmd[1].as_f64(), Some(10.0));
        assert_eq!(move_cmd[2].as_f64(), Some(20.0));
        // Second command is an array starting with "line_to".
        let line_cmd = commands[1].as_array().unwrap();
        assert_eq!(line_cmd[0].as_str(), Some("line_to"));
        assert_eq!(line_cmd[1].as_f64(), Some(30.0));
        assert_eq!(line_cmd[2].as_f64(), Some(40.0));
        // Third command is the bare string "close".
        assert_eq!(commands[2].as_str(), Some("close"));
    }

    // -- Canvas stroke parsing --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_stroke_parse() {
        let stroke_val = json!({
            "color": "#ff0000",
            "width": 3.0,
            "cap": "round",
            "join": "bevel"
        });
        let stroke = parse_canvas_stroke(&stroke_val);
        assert_eq!(
            stroke.style,
            canvas::Style::Solid(Color::from_rgb8(255, 0, 0))
        );
        assert_eq!(stroke.width, 3.0);
        // LineCap and LineJoin don't impl PartialEq, so use Debug format.
        assert_eq!(format!("{:?}", stroke.line_cap), "Round");
        assert_eq!(format!("{:?}", stroke.line_join), "Bevel");
    }

    // -- Canvas gradient fill parsing --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_gradient_parse() {
        let fill_val = json!({
            "type": "linear",
            "start": [0.0, 0.0],
            "end": [100.0, 0.0],
            "stops": [
                [0.0, "#ff0000"],
                [1.0, "#0000ff"]
            ]
        });
        let shape = json!({"fill": fill_val.clone()});
        let fill = parse_canvas_fill(&fill_val, &shape);
        // The fill rule should be NonZero for gradient fills.
        assert_eq!(fill.rule, canvas::fill::Rule::NonZero);
        // The style should be a gradient, not a solid color.
        match &fill.style {
            canvas::Style::Gradient(canvas::Gradient::Linear(_)) => {}
            other => panic!("expected Gradient::Linear, got {other:?}"),
        }
    }

    // -- Canvas fill_rule parsing --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_fill_rule_defaults_to_non_zero() {
        let fill_val = json!("#ff0000");
        let shape = json!({"fill": "#ff0000"});
        let fill = parse_canvas_fill(&fill_val, &shape);
        assert_eq!(fill.rule, canvas::fill::Rule::NonZero);
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_fill_rule_even_odd() {
        let fill_val = json!("#00ff00");
        let shape = json!({"fill": "#00ff00", "fill_rule": "even_odd"});
        let fill = parse_canvas_fill(&fill_val, &shape);
        assert_eq!(fill.rule, canvas::fill::Rule::EvenOdd);
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn canvas_fill_rule_explicit_non_zero() {
        let fill_val = json!("#0000ff");
        let shape = json!({"fill": "#0000ff", "fill_rule": "non_zero"});
        let fill = parse_canvas_fill(&fill_val, &shape);
        assert_eq!(fill.rule, canvas::fill::Rule::NonZero);
    }

    // -- Image registry handle lookup --

    #[cfg(feature = "widget-image")]
    #[test]
    fn image_registry_handle_lookup() {
        use crate::image_registry::ImageRegistry;

        let mut registry = ImageRegistry::new();
        // Minimal valid 1x1 RGB PNG.
        let png_bytes: Vec<u8> = vec![
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, // 8-bit RGB
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT
            0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01, 0xE2,
            0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, // IEND
            0x44, 0xAE, 0x42, 0x60, 0x82,
        ];
        registry.create_from_bytes("test_sprite".to_string(), png_bytes);
        assert!(
            registry.get("test_sprite").is_some(),
            "registered handle should be retrievable"
        );
        assert!(
            registry.get("nonexistent").is_none(),
            "unregistered name should return None"
        );
    }

    // -- Canvas clipping tests --

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn collect_clipped_shapes_simple() {
        let shapes = vec![
            json!({"type": "rect", "x": 0, "y": 0, "w": 50, "h": 50}),
            json!({"type": "pop_clip"}),
        ];
        let refs: Vec<&Value> = shapes.iter().collect();
        let (end_idx, collected) = collect_clipped_shapes(&refs);
        assert_eq!(end_idx, 1); // pop_clip is at index 1
        assert_eq!(collected.len(), 1); // just the rect
        assert_eq!(
            collected[0].get("type").and_then(|v| v.as_str()),
            Some("rect")
        );
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn collect_clipped_shapes_nested() {
        let shapes = vec![
            json!({"type": "push_clip", "x": 10, "y": 10, "w": 50, "h": 50}),
            json!({"type": "rect", "x": 0, "y": 0, "w": 20, "h": 20}),
            json!({"type": "pop_clip"}),
            json!({"type": "circle", "x": 25, "y": 25, "r": 10}),
            json!({"type": "pop_clip"}),
        ];
        let refs: Vec<&Value> = shapes.iter().collect();
        let (end_idx, collected) = collect_clipped_shapes(&refs);
        // The outer pop_clip is at index 4
        assert_eq!(end_idx, 4);
        // Collected: push_clip, rect, pop_clip (inner), circle
        assert_eq!(collected.len(), 4);
    }

    #[cfg(feature = "widget-canvas")]
    #[test]
    fn collect_clipped_shapes_no_pop() {
        let shapes = vec![json!({"type": "rect", "x": 0, "y": 0, "w": 50, "h": 50})];
        let refs: Vec<&Value> = shapes.iter().collect();
        let (end_idx, collected) = collect_clipped_shapes(&refs);
        // No pop_clip found -- returns all shapes
        assert_eq!(end_idx, shapes.len());
        assert_eq!(collected.len(), 1);
    }
}
