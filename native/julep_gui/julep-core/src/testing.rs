//! Test helpers for widget extension authors.
//!
//! Provides convenient constructors for `TreeNode`, `WidgetCaches`, and
//! `ExtensionCaches` so extension tests don't need to import half the crate.

use iced::Theme;
use serde_json::{json, Value};

use crate::extensions::{ExtensionCaches, ExtensionDispatcher, RenderContext, WidgetEnv};
use crate::image_registry::ImageRegistry;
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

/// Create an empty `ImageRegistry` for testing.
pub fn image_registry() -> ImageRegistry {
    ImageRegistry::new()
}

/// Create an empty `ExtensionDispatcher` for testing.
pub fn dispatcher() -> ExtensionDispatcher {
    ExtensionDispatcher::new(vec![])
}

/// Create a `WidgetEnv` for testing extension `render()` methods.
///
/// The caller owns all the dependencies and passes them in. Use the other
/// helpers in this module (`widget_caches()`, `ext_caches()`, etc.) to
/// create default instances.
///
/// # Example
///
/// ```ignore
/// use julep_core::testing::*;
/// use iced::Theme;
///
/// let wc = widget_caches();
/// let ec = ext_caches();
/// let images = image_registry();
/// let theme = Theme::Dark;
/// let disp = dispatcher();
///
/// let env = widget_env_with(&ec, &wc, &images, &theme, &disp);
/// let element = my_extension.render(&node("n1", "sparkline"), &env);
/// ```
pub fn widget_env_with<'a>(
    ext_caches: &'a ExtensionCaches,
    widget_caches: &'a WidgetCaches,
    images: &'a ImageRegistry,
    theme: &'a Theme,
    dispatcher: &'a ExtensionDispatcher,
) -> WidgetEnv<'a> {
    WidgetEnv {
        caches: ext_caches,
        images,
        theme,
        render_ctx: RenderContext {
            caches: widget_caches,
            images,
            theme,
            extensions: dispatcher,
        },
    }
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
        assert!(!c.contains("test", "anything"));
    }

    #[test]
    fn test_ext_caches_insert_and_get() {
        let mut c = ext_caches();
        c.insert("ns", "counter".to_string(), 42u32);
        assert_eq!(c.get::<u32>("ns", "counter"), Some(&42));
        assert!(c.contains("ns", "counter"));
    }

    #[test]
    fn test_node_with_props_and_prop_helpers() {
        use crate::prop_helpers::{prop_f32, prop_str};

        let n = node_with_props("s-1", "sparkline", json!({"label": "cpu", "max": 100.0}));
        assert_eq!(prop_str(&n, "label"), Some("cpu".to_string()));
        assert!((prop_f32(&n, "max").unwrap() - 100.0).abs() < 0.001);
    }

    #[test]
    fn test_image_registry_creation() {
        let r = image_registry();
        assert!(r.get("nonexistent").is_none());
    }

    #[test]
    fn test_dispatcher_creation() {
        let d = dispatcher();
        assert!(d.is_empty());
        assert!(!d.handles_type("anything"));
    }

    #[test]
    fn test_widget_env_with() {
        use iced::Theme;

        let wc = widget_caches();
        let ec = ext_caches();
        let images = image_registry();
        let theme = Theme::Dark;
        let disp = dispatcher();

        let env = widget_env_with(&ec, &wc, &images, &theme, &disp);

        // Verify env fields are accessible and point to our instances
        assert!(!env.caches.contains("test", "anything"));
        assert!(env.render_ctx.extensions.is_empty());
    }

    #[test]
    fn test_generation_counter_starts_at_zero() {
        use crate::extensions::GenerationCounter;

        let counter = GenerationCounter::new();
        assert_eq!(counter.get(), 0);
    }

    #[test]
    fn test_generation_counter_default() {
        use crate::extensions::GenerationCounter;

        let counter = GenerationCounter::default();
        assert_eq!(counter.get(), 0);
    }

    #[test]
    fn test_generation_counter_bump() {
        use crate::extensions::GenerationCounter;

        let mut counter = GenerationCounter::new();
        counter.bump();
        assert_eq!(counter.get(), 1);
        counter.bump();
        counter.bump();
        assert_eq!(counter.get(), 3);
    }

    #[test]
    fn test_generation_counter_in_ext_caches() {
        use crate::extensions::GenerationCounter;

        let mut caches = ext_caches();
        caches.insert("spark", "spark-1:gen".to_string(), GenerationCounter::new());

        let gen = caches
            .get_mut::<GenerationCounter>("spark", "spark-1:gen")
            .unwrap();
        assert_eq!(gen.get(), 0);
        gen.bump();
        assert_eq!(gen.get(), 1);

        // Re-borrow to verify persistence
        let gen = caches
            .get::<GenerationCounter>("spark", "spark-1:gen")
            .unwrap();
        assert_eq!(gen.get(), 1);
    }
}
