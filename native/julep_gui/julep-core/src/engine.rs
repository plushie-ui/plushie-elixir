use std::collections::HashMap;

use iced::Font;
use serde_json::Value;

use crate::effects;
use crate::protocol::{EffectResponse, IncomingMessage, OutgoingEvent};
use crate::theming;
use crate::tree::Tree;
use crate::widgets::{self, WidgetCaches};

/// Side effects produced by Core::apply() that the host (App or headless) must handle.
#[derive(Debug)]
#[allow(dead_code)]
pub enum CoreEffect {
    /// The window set may have changed -- re-sync with renderer.
    SyncWindows,
    /// Emit an event to stdout.
    EmitEvent(OutgoingEvent),
    /// Emit an effect response to stdout.
    EmitEffectResponse(EffectResponse),
    /// Execute a widget operation (focus, scroll, etc.)
    WidgetOp { op: String, payload: Value },
    /// Execute a window operation (open, close, resize, etc.)
    WindowOp {
        op: String,
        window_id: String,
        settings: Value,
    },
    /// Theme changed (for the global/root theme only).
    ThemeChanged(iced::Theme),
    /// App-level theme should follow the system preference.
    ThemeFollowsSystem,
    /// Image operation (create/update/delete in-memory handles).
    ImageOp {
        op: String,
        handle: String,
        data: Option<Vec<u8>>,
        pixels: Option<Vec<u8>>,
        width: Option<u32>,
        height: Option<u32>,
    },
    /// Extension configuration received from Elixir.
    ExtensionConfig(Value),
}

/// Pure state core, decoupled from iced runtime.
pub struct Core {
    pub tree: Tree,
    pub caches: WidgetCaches,
    pub active_subscriptions: HashMap<String, String>,
    pub default_text_size: Option<f32>,
    pub default_font: Option<Font>,
}

impl Default for Core {
    fn default() -> Self {
        Self::new()
    }
}

impl Core {
    pub fn new() -> Self {
        Self {
            tree: Tree::new(),
            caches: WidgetCaches::new(),
            active_subscriptions: HashMap::new(),
            default_text_size: None,
            default_font: None,
        }
    }

    /// Process an incoming message, mutate state, return effects.
    pub fn apply(&mut self, message: IncomingMessage) -> Vec<CoreEffect> {
        let mut effects = Vec::new();

        match message {
            IncomingMessage::Snapshot { tree } => {
                log::debug!("snapshot received (root id={})", tree.id);
                if let Some(theme_val) = tree.props.get("theme") {
                    match theming::resolve_theme_only(theme_val) {
                        Some(theme) => effects.push(CoreEffect::ThemeChanged(theme)),
                        None => effects.push(CoreEffect::ThemeFollowsSystem),
                    }
                }
                self.tree.snapshot(tree);
                self.caches.clear();
                if let Some(root) = self.tree.root() {
                    widgets::ensure_caches(root, &mut self.caches);
                }
                effects.push(CoreEffect::SyncWindows);
            }
            IncomingMessage::Patch { ops } => {
                log::debug!("patch received ({} ops)", ops.len());
                self.tree.apply_patch(ops);
                if let Some(root) = self.tree.root() {
                    widgets::ensure_caches(root, &mut self.caches);
                    widgets::prune_stale_canvas_caches(root, &mut self.caches);
                }
                effects.push(CoreEffect::SyncWindows);
            }
            IncomingMessage::EffectRequest { id, kind, payload } => {
                log::debug!("effect request: {kind} ({id})");
                let response = effects::handle_effect(id, &kind, &payload);
                effects.push(CoreEffect::EmitEffectResponse(response));
            }
            IncomingMessage::WidgetOp { op, payload } => {
                log::debug!("widget_op: {op}");
                effects.push(CoreEffect::WidgetOp { op, payload });
            }
            IncomingMessage::SubscriptionRegister { kind, tag } => {
                log::debug!("subscription register: {kind} -> {tag}");
                self.active_subscriptions.insert(kind, tag);
            }
            IncomingMessage::SubscriptionUnregister { kind } => {
                log::debug!("subscription unregister: {kind}");
                self.active_subscriptions.remove(&kind);
            }
            IncomingMessage::WindowOp {
                op,
                window_id,
                settings,
            } => {
                log::debug!("window_op: {op} ({window_id})");
                effects.push(CoreEffect::WindowOp {
                    op,
                    window_id,
                    settings,
                });
            }
            IncomingMessage::Settings { settings } => {
                log::debug!("settings received");
                self.default_text_size = settings
                    .get("default_text_size")
                    .and_then(|v| v.as_f64())
                    .map(|v| v as f32);
                self.default_font = settings.get("default_font").map(|v| {
                    let family = v.get("family").and_then(|f| f.as_str());
                    if family == Some("monospace") {
                        Font::MONOSPACE
                    } else {
                        Font::DEFAULT
                    }
                });
                self.caches.default_text_size = self.default_text_size;
                self.caches.default_font = self.default_font;

                if let Some(ext_config) = settings.get("extension_config") {
                    effects.push(CoreEffect::ExtensionConfig(ext_config.clone()));
                }
            }
            IncomingMessage::ImageOp {
                op,
                handle,
                data,
                pixels,
                width,
                height,
            } => {
                log::debug!("image_op: {op} ({handle})");
                effects.push(CoreEffect::ImageOp {
                    op,
                    handle,
                    data,
                    pixels,
                    width,
                    height,
                });
            }
            _ => {
                log::warn!("unhandled message type in core");
            }
        }

        effects
    }
}

#[cfg(test)]
mod tests {
    use serde_json::Value;

    use super::*;
    use crate::protocol::{IncomingMessage, TreeNode};

    fn make_node(id: &str, type_name: &str) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props: serde_json::json!({}),
            children: vec![],
        }
    }

    fn make_node_with_props(id: &str, type_name: &str, props: Value) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props,
            children: vec![],
        }
    }

    // -- Core::new() --

    #[test]
    fn new_returns_empty_tree() {
        let core = Core::new();
        assert!(core.tree.root().is_none());
    }

    #[test]
    fn new_has_empty_active_subscriptions() {
        let core = Core::new();
        assert!(core.active_subscriptions.is_empty());
    }

    #[test]
    fn new_has_no_default_text_size() {
        let core = Core::new();
        assert!(core.default_text_size.is_none());
    }

    #[test]
    fn new_has_no_default_font() {
        let core = Core::new();
        assert!(core.default_font.is_none());
    }

    // -- Snapshot --

    #[test]
    fn snapshot_sets_tree_and_returns_sync_windows() {
        let mut core = Core::new();
        let msg = IncomingMessage::Snapshot {
            tree: make_node("root", "column"),
        };
        let effects = core.apply(msg);
        // Tree should be populated
        assert!(core.tree.root().is_some());
        assert_eq!(core.tree.root().unwrap().id, "root");
        // Must include SyncWindows
        let has_sync = effects.iter().any(|e| matches!(e, CoreEffect::SyncWindows));
        assert!(has_sync);
    }

    #[test]
    fn snapshot_with_theme_prop_returns_theme_changed() {
        let mut core = Core::new();
        let msg = IncomingMessage::Snapshot {
            tree: make_node_with_props("root", "column", serde_json::json!({"theme": "dark"})),
        };
        let effects = core.apply(msg);
        let has_theme = effects
            .iter()
            .any(|e| matches!(e, CoreEffect::ThemeChanged(_)));
        assert!(has_theme);
    }

    #[test]
    fn snapshot_without_theme_prop_has_no_theme_changed() {
        let mut core = Core::new();
        let msg = IncomingMessage::Snapshot {
            tree: make_node("root", "column"),
        };
        let effects = core.apply(msg);
        let has_theme = effects
            .iter()
            .any(|e| matches!(e, CoreEffect::ThemeChanged(_)));
        assert!(!has_theme);
    }

    // -- Patch --

    #[test]
    fn patch_with_no_ops_returns_sync_windows() {
        let mut core = Core::new();
        // First put a tree in place so patch has something to work with
        let snapshot_msg = IncomingMessage::Snapshot {
            tree: make_node("root", "column"),
        };
        core.apply(snapshot_msg);

        let patch_msg = IncomingMessage::Patch { ops: vec![] };
        let effects = core.apply(patch_msg);
        let has_sync = effects.iter().any(|e| matches!(e, CoreEffect::SyncWindows));
        assert!(has_sync);
    }

    // -- Settings --

    #[test]
    fn settings_sets_default_text_size() {
        let mut core = Core::new();
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({"default_text_size": 18.0}),
        };
        core.apply(msg);
        assert_eq!(core.default_text_size, Some(18.0_f32));
    }

    #[test]
    fn settings_sets_default_font_monospace() {
        let mut core = Core::new();
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({"default_font": {"family": "monospace"}}),
        };
        core.apply(msg);
        assert_eq!(core.default_font, Some(iced::Font::MONOSPACE));
    }

    #[test]
    fn settings_sets_default_font_default_for_unknown_family() {
        let mut core = Core::new();
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({"default_font": {"family": "sans-serif"}}),
        };
        core.apply(msg);
        assert_eq!(core.default_font, Some(iced::Font::DEFAULT));
    }

    #[test]
    fn settings_without_extension_config_returns_no_effects() {
        let mut core = Core::new();
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({"default_text_size": 14.0}),
        };
        let effects = core.apply(msg);
        assert!(effects.is_empty());
    }

    #[test]
    fn settings_with_extension_config_emits_effect() {
        let mut core = Core::new();
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({
                "default_text_size": 14.0,
                "extension_config": {
                    "terminal": {"shell": "/bin/bash"}
                }
            }),
        };
        let effects = core.apply(msg);
        let has_ext_config = effects
            .iter()
            .any(|e| matches!(e, CoreEffect::ExtensionConfig(_)));
        assert!(has_ext_config);
    }

    #[test]
    fn settings_with_extension_config_contains_correct_value() {
        let mut core = Core::new();
        let config_val = serde_json::json!({"terminal": {"shell": "/bin/zsh"}});
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({
                "extension_config": config_val,
            }),
        };
        let effects = core.apply(msg);
        let ext_config = effects.iter().find_map(|e| match e {
            CoreEffect::ExtensionConfig(v) => Some(v),
            _ => None,
        });
        assert_eq!(
            ext_config.unwrap(),
            &serde_json::json!({"terminal": {"shell": "/bin/zsh"}})
        );
    }

    // -- SubscriptionRegister / SubscriptionUnregister --

    #[test]
    fn subscription_register_adds_to_active_subscriptions() {
        let mut core = Core::new();
        let msg = IncomingMessage::SubscriptionRegister {
            kind: "time".to_string(),
            tag: "tick".to_string(),
        };
        core.apply(msg);
        assert_eq!(
            core.active_subscriptions.get("time").map(|s| s.as_str()),
            Some("tick")
        );
    }

    #[test]
    fn subscription_register_returns_no_effects() {
        let mut core = Core::new();
        let msg = IncomingMessage::SubscriptionRegister {
            kind: "keyboard".to_string(),
            tag: "key".to_string(),
        };
        let effects = core.apply(msg);
        assert!(effects.is_empty());
    }

    #[test]
    fn subscription_unregister_removes_from_active_subscriptions() {
        let mut core = Core::new();
        core.active_subscriptions
            .insert("time".to_string(), "tick".to_string());
        let msg = IncomingMessage::SubscriptionUnregister {
            kind: "time".to_string(),
        };
        core.apply(msg);
        assert!(!core.active_subscriptions.contains_key("time"));
    }

    #[test]
    fn subscription_unregister_returns_no_effects() {
        let mut core = Core::new();
        let msg = IncomingMessage::SubscriptionUnregister {
            kind: "time".to_string(),
        };
        let effects = core.apply(msg);
        assert!(effects.is_empty());
    }

    // -- Unhandled message types --

    #[test]
    fn unhandled_message_returns_empty_effects() {
        let mut core = Core::new();
        // Query is handled by headless/test_mode, not Core -- hits the catch-all
        let msg = IncomingMessage::Query {
            id: "q1".to_string(),
            target: "tree".to_string(),
            selector: Value::Null,
        };
        let effects = core.apply(msg);
        assert!(effects.is_empty());
    }
}
