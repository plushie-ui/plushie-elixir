//! Accessibility tree conversion for accesskit.
//!
//! Converts julep's `TreeNode` representation into accesskit `TreeUpdate`
//! structs for platform accessibility APIs.

use accesskit::{Live, Node, NodeId, Role, Toggled, Tree, TreeUpdate};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use crate::protocol::TreeNode;

/// Build an accesskit `TreeUpdate` from a julep tree.
///
/// Walks the tree recursively, mapping widget types to accesskit roles and
/// extracting accessible properties from widget props. If `focused_id` is
/// provided, the matching node receives keyboard focus.
pub fn build_tree_update(root: &TreeNode, focused_id: Option<&str>) -> TreeUpdate {
    let mut nodes = Vec::new();
    let root_id = node_id_from_str(&root.id);
    let focus_nid = focused_id.map(node_id_from_str).unwrap_or(root_id);

    build_node(root, &mut nodes);

    TreeUpdate {
        nodes,
        tree: Some(Tree::new(root_id)),
        focus: focus_nid,
    }
}

/// Maps a julep widget type_name to an accesskit Role.
pub fn role_for_type(type_name: &str) -> Role {
    match type_name {
        "button" => Role::Button,
        "text" => Role::Label,
        "text_input" => Role::TextInput,
        "text_editor" => Role::MultilineTextInput,
        "checkbox" => Role::CheckBox,
        "toggler" => Role::Switch,
        "radio" => Role::RadioButton,
        "slider" | "vertical_slider" => Role::Slider,
        "pick_list" | "combo_box" => Role::ComboBox,
        "progress_bar" => Role::ProgressIndicator,
        "scrollable" => Role::ScrollView,
        "container" | "column" | "row" | "stack" | "keyed_column" | "grid" | "float" | "pin"
        | "responsive" | "space" | "themer" | "mouse_area" | "sensor" | "overlay" => {
            Role::GenericContainer
        }
        "window" => Role::Window,
        "image" | "svg" | "qr_code" => Role::Image,
        "canvas" => Role::Canvas,
        "table" => Role::Table,
        "tooltip" => Role::Tooltip,
        "markdown" => Role::Document,
        "pane_grid" => Role::Group,
        "rule" => Role::Splitter,
        "rich_text" | "rich" => Role::Label,
        _ => Role::Unknown,
    }
}

/// Convert a string ID to a stable NodeId by hashing.
///
/// Uses DefaultHasher which is stable within a single process run.
/// NodeIds are never persisted, so cross-build stability is not needed.
pub fn node_id_from_str(id: &str) -> NodeId {
    let mut hasher = DefaultHasher::new();
    id.hash(&mut hasher);
    NodeId(hasher.finish())
}

fn is_a11y_hidden(props: &serde_json::Value) -> bool {
    props
        .get("a11y")
        .and_then(|a| a.get("hidden"))
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
}

fn build_node(node: &TreeNode, nodes: &mut Vec<(NodeId, Node)>) {
    let props = &node.props;
    let a11y = props.get("a11y");

    // Check if hidden via a11y override
    if is_a11y_hidden(props) {
        return;
    }

    let nid = node_id_from_str(&node.id);

    // Determine role -- a11y override takes precedence
    let role = if let Some(role_str) = a11y.and_then(|a| a.get("role")).and_then(|v| v.as_str()) {
        role_from_string(role_str)
    } else {
        role_for_type(&node.type_name)
    };

    let mut ak_node = Node::new(role);

    // Collect child IDs (excluding hidden children)
    let child_ids: Vec<NodeId> = node
        .children
        .iter()
        .filter(|c| !is_a11y_hidden(&c.props))
        .map(|c| node_id_from_str(&c.id))
        .collect();

    if !child_ids.is_empty() {
        ak_node.set_children(child_ids);
    }

    // Auto-infer label from props
    let auto_label = match node.type_name.as_str() {
        "button" | "checkbox" | "toggler" | "radio" => props.get("label").and_then(|v| v.as_str()),
        "text" | "rich_text" => props.get("content").and_then(|v| v.as_str()),
        "image" | "svg" => props.get("alt").and_then(|v| v.as_str()),
        _ => None,
    };

    // a11y label override takes precedence
    let label = a11y
        .and_then(|a| a.get("label"))
        .and_then(|v| v.as_str())
        .or(auto_label);

    if let Some(name) = label {
        ak_node.set_label(name);
    }

    // a11y description
    if let Some(desc) = a11y
        .and_then(|a| a.get("description"))
        .and_then(|v| v.as_str())
    {
        ak_node.set_description(desc);
    }

    // Text input placeholder as description (if no explicit description)
    if node.type_name == "text_input" && a11y.and_then(|a| a.get("description")).is_none() {
        if let Some(ph) = props.get("placeholder").and_then(|v| v.as_str()) {
            ak_node.set_description(ph);
        }
    }

    // Disabled state
    if props
        .get("disabled")
        .and_then(|v| v.as_bool())
        .unwrap_or(false)
    {
        ak_node.set_disabled();
    }

    // Checked / toggled state
    match node.type_name.as_str() {
        "checkbox" => {
            if let Some(checked) = props.get("checked").and_then(|v| v.as_bool()) {
                ak_node.set_toggled(if checked {
                    Toggled::True
                } else {
                    Toggled::False
                });
            }
        }
        "toggler" => {
            if let Some(toggled) = props.get("is_toggled").and_then(|v| v.as_bool()) {
                ak_node.set_toggled(if toggled {
                    Toggled::True
                } else {
                    Toggled::False
                });
            }
        }
        "radio" => {
            if let Some(selected) = props.get("selected").and_then(|v| v.as_bool()) {
                ak_node.set_toggled(if selected {
                    Toggled::True
                } else {
                    Toggled::False
                });
            }
        }
        _ => {}
    }

    // Numeric value (slider, progress_bar)
    if let Some(val) = props.get("value").and_then(|v| v.as_f64()) {
        ak_node.set_numeric_value(val);
    }

    // Range (slider) -- set min/max
    if let Some(range) = props.get("range").and_then(|v| v.as_array()) {
        if range.len() == 2 {
            if let (Some(min), Some(max)) = (range[0].as_f64(), range[1].as_f64()) {
                ak_node.set_min_numeric_value(min);
                ak_node.set_max_numeric_value(max);
            }
        }
    }

    // String value (text_input, pick_list selected)
    if let Some(val) = props.get("value").and_then(|v| v.as_str()) {
        ak_node.set_value(val);
    }
    if let Some(sel) = props.get("selected").and_then(|v| v.as_str()) {
        ak_node.set_value(sel);
    }

    // a11y expanded
    if let Some(expanded) = a11y
        .and_then(|a| a.get("expanded"))
        .and_then(|v| v.as_bool())
    {
        ak_node.set_expanded(expanded);
    }

    // a11y required
    if let Some(true) = a11y
        .and_then(|a| a.get("required"))
        .and_then(|v| v.as_bool())
    {
        ak_node.set_required();
    }

    // a11y level (heading)
    if let Some(level) = a11y.and_then(|a| a.get("level")).and_then(|v| v.as_u64()) {
        if (1..=6).contains(&level) {
            ak_node.set_level(level as usize);
        }
    }

    // a11y live region
    if let Some(live) = a11y.and_then(|a| a.get("live")).and_then(|v| v.as_str()) {
        match live {
            "polite" => ak_node.set_live(Live::Polite),
            "assertive" => ak_node.set_live(Live::Assertive),
            _ => {} // "off" or unknown -- no live region
        }
    }

    nodes.push((nid, ak_node));

    // Recurse into children
    for child in &node.children {
        build_node(child, nodes);
    }
}

/// Parse a role string from the a11y prop into an accesskit Role.
fn role_from_string(s: &str) -> Role {
    match s {
        "alert" => Role::Alert,
        "alert_dialog" | "alertdialog" => Role::AlertDialog,
        "button" => Role::Button,
        "cell" => Role::Cell,
        "checkbox" | "check_box" => Role::CheckBox,
        "column_header" => Role::ColumnHeader,
        "combo_box" | "combobox" => Role::ComboBox,
        "dialog" => Role::Dialog,
        "document" => Role::Document,
        "generic_container" | "generic" | "container" => Role::GenericContainer,
        "grid" => Role::Grid,
        "group" => Role::Group,
        "heading" => Role::Heading,
        "image" => Role::Image,
        "label" => Role::Label,
        "link" => Role::Link,
        "list" => Role::List,
        "list_item" => Role::ListItem,
        "menu" => Role::Menu,
        "menu_bar" => Role::MenuBar,
        "menu_item" => Role::MenuItem,
        "meter" => Role::Meter,
        "navigation" => Role::Navigation,
        "progress_indicator" | "progressbar" => Role::ProgressIndicator,
        "radio" | "radio_button" => Role::RadioButton,
        "region" => Role::Region,
        "row" => Role::Row,
        "row_header" => Role::RowHeader,
        "scroll_view" => Role::ScrollView,
        "search" => Role::Search,
        "separator" => Role::Splitter,
        "slider" => Role::Slider,
        "status" => Role::Status,
        "switch" => Role::Switch,
        "tab" => Role::Tab,
        "tab_list" => Role::TabList,
        "tab_panel" => Role::TabPanel,
        "table" => Role::Table,
        "text_input" => Role::TextInput,
        "multiline_text_input" | "text_editor" => Role::MultilineTextInput,
        "timer" => Role::Timer,
        "toolbar" => Role::Toolbar,
        "tooltip" => Role::Tooltip,
        "tree" => Role::Tree,
        "tree_item" => Role::TreeItem,
        "window" => Role::Window,
        _ => Role::Unknown,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn make_node(id: &str, type_name: &str, props: serde_json::Value) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props,
            children: vec![],
        }
    }

    fn make_node_with_children(
        id: &str,
        type_name: &str,
        props: serde_json::Value,
        children: Vec<TreeNode>,
    ) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props,
            children,
        }
    }

    #[test]
    fn test_empty_tree() {
        let root = make_node("root", "container", json!({}));
        let update = build_tree_update(&root, None);
        assert_eq!(update.nodes.len(), 1);
        assert!(update.tree.is_some());
    }

    #[test]
    fn test_button_auto_inference() {
        let btn = make_node("btn1", "button", json!({"label": "Click me"}));
        let update = build_tree_update(&btn, None);
        assert_eq!(update.nodes.len(), 1);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::Button);
        assert_eq!(node.label(), Some("Click me"));
    }

    #[test]
    fn test_text_auto_inference() {
        let txt = make_node("t1", "text", json!({"content": "Hello world"}));
        let update = build_tree_update(&txt, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::Label);
        assert_eq!(node.label(), Some("Hello world"));
    }

    #[test]
    fn test_slider_range_value() {
        let sl = make_node("sl", "slider", json!({"value": 42.0, "range": [0, 100]}));
        let update = build_tree_update(&sl, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::Slider);
        assert_eq!(node.numeric_value(), Some(42.0));
        assert_eq!(node.min_numeric_value(), Some(0.0));
        assert_eq!(node.max_numeric_value(), Some(100.0));
    }

    #[test]
    fn test_checkbox_toggled_state() {
        let cb = make_node(
            "cb",
            "checkbox",
            json!({"label": "Accept", "checked": true}),
        );
        let update = build_tree_update(&cb, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::CheckBox);
        assert_eq!(node.toggled(), Some(Toggled::True));
        assert_eq!(node.label(), Some("Accept"));
    }

    #[test]
    fn test_disabled_state() {
        let btn = make_node("btn", "button", json!({"label": "Go", "disabled": true}));
        let update = build_tree_update(&btn, None);
        let (_, node) = &update.nodes[0];
        assert!(node.is_disabled());
    }

    #[test]
    fn test_a11y_override_role() {
        let node = make_node(
            "h1",
            "text",
            json!({
                "content": "Title",
                "a11y": {"role": "heading", "level": 1}
            }),
        );
        let update = build_tree_update(&node, None);
        let (_, built) = &update.nodes[0];
        assert_eq!(built.role(), Role::Heading);
        assert_eq!(built.level(), Some(1));
    }

    #[test]
    fn test_a11y_override_label() {
        let node = make_node(
            "btn",
            "button",
            json!({
                "label": "X",
                "a11y": {"label": "Close dialog"}
            }),
        );
        let update = build_tree_update(&node, None);
        let (_, built) = &update.nodes[0];
        assert_eq!(built.label(), Some("Close dialog"));
    }

    #[test]
    fn test_hidden_node_excluded() {
        let root = make_node_with_children(
            "root",
            "column",
            json!({}),
            vec![
                make_node("visible", "text", json!({"content": "Hi"})),
                make_node(
                    "hidden",
                    "text",
                    json!({"content": "Secret", "a11y": {"hidden": true}}),
                ),
            ],
        );
        let update = build_tree_update(&root, None);
        // Root + visible = 2 nodes. Hidden is excluded.
        assert_eq!(update.nodes.len(), 2);
    }

    #[test]
    fn test_nested_tree_structure() {
        let root = make_node_with_children(
            "root",
            "column",
            json!({}),
            vec![
                make_node("btn", "button", json!({"label": "Go"})),
                make_node_with_children(
                    "inner",
                    "container",
                    json!({}),
                    vec![make_node("txt", "text", json!({"content": "Hello"}))],
                ),
            ],
        );
        let update = build_tree_update(&root, None);
        // root + btn + inner + txt = 4
        assert_eq!(update.nodes.len(), 4);
    }

    #[test]
    fn test_focus_tracking() {
        let root = make_node_with_children(
            "root",
            "column",
            json!({}),
            vec![make_node("btn", "button", json!({"label": "Go"}))],
        );
        let update = build_tree_update(&root, Some("btn"));
        assert_eq!(update.focus, node_id_from_str("btn"));
    }

    #[test]
    fn test_node_id_stability() {
        let id1 = node_id_from_str("my-widget");
        let id2 = node_id_from_str("my-widget");
        assert_eq!(id1, id2);

        let id3 = node_id_from_str("other-widget");
        assert_ne!(id1, id3);
    }

    #[test]
    fn test_text_input_placeholder_as_description() {
        let ti = make_node(
            "ti",
            "text_input",
            json!({"value": "", "placeholder": "Enter name"}),
        );
        let update = build_tree_update(&ti, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.description(), Some("Enter name"));
    }

    #[test]
    fn test_toggler_state() {
        let tg = make_node(
            "tg",
            "toggler",
            json!({"is_toggled": true, "label": "Dark mode"}),
        );
        let update = build_tree_update(&tg, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::Switch);
        assert_eq!(node.toggled(), Some(Toggled::True));
        assert_eq!(node.label(), Some("Dark mode"));
    }

    #[test]
    fn test_a11y_live_region() {
        let node = make_node(
            "status",
            "text",
            json!({
                "content": "Saved",
                "a11y": {"live": "polite"}
            }),
        );
        let update = build_tree_update(&node, None);
        let (_, built) = &update.nodes[0];
        assert_eq!(built.live(), Some(Live::Polite));
    }

    #[test]
    fn test_a11y_expanded() {
        let node = make_node(
            "menu",
            "container",
            json!({
                "a11y": {"expanded": true, "role": "menu"}
            }),
        );
        let update = build_tree_update(&node, None);
        let (_, built) = &update.nodes[0];
        assert_eq!(built.is_expanded(), Some(true));
    }

    #[test]
    fn test_a11y_required() {
        let node = make_node(
            "email",
            "text_input",
            json!({
                "value": "",
                "placeholder": "Email",
                "a11y": {"required": true}
            }),
        );
        let update = build_tree_update(&node, None);
        let (_, built) = &update.nodes[0];
        assert!(built.is_required());
    }

    #[test]
    fn test_pick_list_selected_value() {
        let pl = make_node(
            "pl",
            "pick_list",
            json!({"options": ["A", "B"], "selected": "B"}),
        );
        let update = build_tree_update(&pl, None);
        let (_, node) = &update.nodes[0];
        assert_eq!(node.role(), Role::ComboBox);
        assert_eq!(node.value(), Some("B"));
    }

    #[test]
    fn test_role_for_type_comprehensive() {
        assert_eq!(role_for_type("button"), Role::Button);
        assert_eq!(role_for_type("text"), Role::Label);
        assert_eq!(role_for_type("text_input"), Role::TextInput);
        assert_eq!(role_for_type("text_editor"), Role::MultilineTextInput);
        assert_eq!(role_for_type("checkbox"), Role::CheckBox);
        assert_eq!(role_for_type("toggler"), Role::Switch);
        assert_eq!(role_for_type("radio"), Role::RadioButton);
        assert_eq!(role_for_type("slider"), Role::Slider);
        assert_eq!(role_for_type("vertical_slider"), Role::Slider);
        assert_eq!(role_for_type("pick_list"), Role::ComboBox);
        assert_eq!(role_for_type("combo_box"), Role::ComboBox);
        assert_eq!(role_for_type("progress_bar"), Role::ProgressIndicator);
        assert_eq!(role_for_type("scrollable"), Role::ScrollView);
        assert_eq!(role_for_type("container"), Role::GenericContainer);
        assert_eq!(role_for_type("column"), Role::GenericContainer);
        assert_eq!(role_for_type("row"), Role::GenericContainer);
        assert_eq!(role_for_type("window"), Role::Window);
        assert_eq!(role_for_type("image"), Role::Image);
        assert_eq!(role_for_type("canvas"), Role::Canvas);
        assert_eq!(role_for_type("table"), Role::Table);
        assert_eq!(role_for_type("tooltip"), Role::Tooltip);
        assert_eq!(role_for_type("markdown"), Role::Document);
        assert_eq!(role_for_type("pane_grid"), Role::Group);
        assert_eq!(role_for_type("rule"), Role::Splitter);
        assert_eq!(role_for_type("unknown_widget"), Role::Unknown);
    }
}
