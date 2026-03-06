//! Test helpers for widget extension authors.
//!
//! Provides convenient constructors for `TreeNode`, `WidgetCaches`, and
//! `ExtensionCaches` so extension tests don't need to import half the crate.

use serde_json::{json, Value};

use crate::extensions::ExtensionCaches;
use crate::protocol::TreeNode;
use crate::widgets::WidgetCaches;

/// Create a minimal `TreeNode` for testing.
pub fn node(id: &str, type_name: &str) -> TreeNode {
    TreeNode {
        id: id.to_string(),
        type_name: type_name.to_string(),
        props: json!({}),
        children: vec![],
    }
}

/// Create a `TreeNode` with props for testing.
pub fn node_with_props(id: &str, type_name: &str, props: Value) -> TreeNode {
    TreeNode {
        id: id.to_string(),
        type_name: type_name.to_string(),
        props,
        children: vec![],
    }
}

/// Create a `TreeNode` with children for testing.
pub fn node_with_children(id: &str, type_name: &str, children: Vec<TreeNode>) -> TreeNode {
    TreeNode {
        id: id.to_string(),
        type_name: type_name.to_string(),
        props: json!({}),
        children,
    }
}

/// Create empty `WidgetCaches` for testing.
pub fn widget_caches() -> WidgetCaches {
    WidgetCaches::new()
}

/// Create empty `ExtensionCaches` for testing.
pub fn ext_caches() -> ExtensionCaches {
    ExtensionCaches::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_node_creation() {
        let n = node("btn-1", "button");
        assert_eq!(n.id, "btn-1");
        assert_eq!(n.type_name, "button");
        assert!(n.children.is_empty());
        assert_eq!(n.props, json!({}));
    }

    #[test]
    fn test_node_with_props() {
        let n = node_with_props("txt-1", "text", json!({"content": "hello", "size": 14}));
        assert_eq!(n.id, "txt-1");
        assert_eq!(n.type_name, "text");
        assert_eq!(n.props["content"], "hello");
        assert_eq!(n.props["size"], 14);
    }

    #[test]
    fn test_node_with_children() {
        let children = vec![node("a", "text"), node("b", "button")];
        let n = node_with_children("col-1", "column", children);
        assert_eq!(n.id, "col-1");
        assert_eq!(n.children.len(), 2);
        assert_eq!(n.children[0].id, "a");
        assert_eq!(n.children[1].id, "b");
    }

    #[test]
    fn test_widget_caches_creation() {
        let c = widget_caches();
        assert!(c.editor_contents.is_empty());
        assert!(c.combo_states.is_empty());
    }

    #[test]
    fn test_ext_caches_creation() {
        let c = ext_caches();
        assert!(!c.contains("anything"));
    }

    #[test]
    fn test_ext_caches_insert_and_get() {
        let mut c = ext_caches();
        c.insert("counter".to_string(), 42u32);
        assert_eq!(c.get::<u32>("counter"), Some(&42));
        assert!(c.contains("counter"));
    }

    #[test]
    fn test_node_with_props_and_prop_helpers() {
        use crate::prop_helpers::{prop_f32, prop_str};

        let n = node_with_props("s-1", "sparkline", json!({"label": "cpu", "max": 100.0}));
        assert_eq!(prop_str(&n, "label"), Some("cpu".to_string()));
        assert!((prop_f32(&n, "max").unwrap() - 100.0).abs() < 0.001);
    }
}
