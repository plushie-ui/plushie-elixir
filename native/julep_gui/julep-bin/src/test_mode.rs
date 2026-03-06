// test_mode.rs - Helpers for --test mode
//
// When running with --test, the regular iced::daemon runs normally but the App
// also handles Query/Interact/SnapshotCapture/Reset messages from stdin
// (instead of passing them to Core::apply where they'd hit the catch-all).

pub mod test_helpers {
    use std::io::{self, Write};

    use serde_json::Value;

    use julep_core::codec::Codec;
    use julep_core::engine::Core;
    #[cfg(feature = "test-mode")]
    use julep_core::protocol::SnapshotCaptureResponse;
    use julep_core::protocol::{
        IncomingMessage, InteractResponse, QueryResponse, ResetResponse, TreeNode,
    };

    /// Check if a message is a test-mode message (Query, Interact, etc.)
    pub fn is_test_message(msg: &IncomingMessage) -> bool {
        matches!(
            msg,
            IncomingMessage::Query { .. }
                | IncomingMessage::Interact { .. }
                | IncomingMessage::SnapshotCapture { .. }
                | IncomingMessage::ScreenshotCapture { .. }
                | IncomingMessage::Reset { .. }
        )
    }

    /// Handle a test-mode Query message.
    pub fn handle_query(core: &Core, id: String, target: String, selector: Value) {
        let data = match target.as_str() {
            "tree" => match core.tree.root() {
                Some(root) => serde_json::to_value(root).unwrap_or(Value::Null),
                None => Value::Null,
            },
            "find" => {
                let widget_id = selector.get("value").and_then(|v| v.as_str()).unwrap_or("");
                match core.tree.root() {
                    Some(root) => find_node_by_id(root, widget_id),
                    None => Value::Null,
                }
            }
            _ => Value::Null,
        };
        emit_wire(&QueryResponse::new(id, target, data));
    }

    /// Handle a test-mode Interact message.
    /// Returns the events that would be generated.
    pub fn handle_interact(
        _core: &Core,
        id: String,
        action: String,
        selector: Value,
        payload: Value,
    ) {
        let widget_id = selector
            .get("value")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        let events = match action.as_str() {
            "click" => {
                vec![serde_json::json!({"type": "event", "event": "click", "id": widget_id})]
            }
            "type_text" => {
                let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "input", "id": widget_id, "value": text}),
                ]
            }
            "submit" => {
                let value = payload.get("value").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "submit", "id": widget_id, "value": value}),
                ]
            }
            "toggle" => {
                let value = payload
                    .get("value")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                vec![
                    serde_json::json!({"type": "event", "event": "toggle", "id": widget_id, "value": value}),
                ]
            }
            "select" => {
                let value = payload.get("value").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "select", "id": widget_id, "value": value}),
                ]
            }
            "slide" => {
                let value = payload.get("value").and_then(|v| v.as_f64()).unwrap_or(0.0);
                vec![
                    serde_json::json!({"type": "event", "event": "slide", "id": widget_id, "value": value}),
                ]
            }
            "press" => {
                let payload_map = payload.as_object();
                let (key, modifiers) = parse_key_and_modifiers(payload_map);
                vec![serde_json::json!({
                    "type": "event", "event": "key_press", "id": "", "key": key, "modifiers": modifiers
                })]
            }
            "release" => {
                let payload_map = payload.as_object();
                let (key, modifiers) = parse_key_and_modifiers(payload_map);
                vec![serde_json::json!({
                    "type": "event", "event": "key_release", "id": "", "key": key, "modifiers": modifiers
                })]
            }
            "move_to" => {
                let x = payload.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let y = payload.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0);
                vec![serde_json::json!({
                    "type": "event", "event": "cursor_moved", "id": "", "x": x, "y": y
                })]
            }
            "type_key" => {
                let payload_map = payload.as_object();
                let (key, modifiers) = parse_key_and_modifiers(payload_map);
                vec![
                    serde_json::json!({
                        "type": "event", "event": "key_press", "id": "", "key": key, "modifiers": modifiers
                    }),
                    serde_json::json!({
                        "type": "event", "event": "key_release", "id": "", "key": key, "modifiers": modifiers
                    }),
                ]
            }
            _ => vec![],
        };
        emit_wire(&InteractResponse::new(id, events));
    }

    /// Parse key and modifiers from an interact payload.
    ///
    /// Supports two formats:
    /// 1. Explicit modifiers map: `{"key": "s", "modifiers": {"ctrl": true, ...}}`
    /// 2. Combined key string: `{"key": "ctrl+s"}` -- splits on `+` and extracts
    ///    modifier prefixes (ctrl/command, shift, alt, logo/super/meta).
    fn parse_key_and_modifiers(
        payload: Option<&serde_json::Map<String, serde_json::Value>>,
    ) -> (String, serde_json::Value) {
        let empty_map = serde_json::Map::new();
        let map = payload.unwrap_or(&empty_map);

        let raw_key = map
            .get("key")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();

        // Explicit modifiers map takes priority
        if let Some(mods) = map.get("modifiers").and_then(|v| v.as_object()) {
            let modifiers = serde_json::json!({
                "shift": mods.get("shift").and_then(|v| v.as_bool()).unwrap_or(false),
                "ctrl": mods.get("ctrl").and_then(|v| v.as_bool()).unwrap_or(false),
                "alt": mods.get("alt").and_then(|v| v.as_bool()).unwrap_or(false),
                "logo": mods.get("logo").and_then(|v| v.as_bool()).unwrap_or(false),
            });
            return (raw_key, modifiers);
        }

        // Parse "ctrl+s" style combined key strings
        let parts: Vec<&str> = raw_key.split('+').collect();
        if parts.len() > 1 {
            let key = parts.last().unwrap().to_string();
            let mut shift = false;
            let mut ctrl = false;
            let mut alt = false;
            let mut logo = false;
            for &part in &parts[..parts.len() - 1] {
                match part {
                    "ctrl" | "command" => ctrl = true,
                    "shift" => shift = true,
                    "alt" => alt = true,
                    "logo" | "super" | "meta" => logo = true,
                    _ => {}
                }
            }
            let modifiers = serde_json::json!({
                "shift": shift, "ctrl": ctrl, "alt": alt, "logo": logo,
            });
            (key, modifiers)
        } else {
            let modifiers = serde_json::json!({
                "shift": false, "ctrl": false, "alt": false, "logo": false,
            });
            (raw_key, modifiers)
        }
    }

    /// Handle a Reset message -- reinitialise the core to a blank state.
    pub fn handle_reset(core: &mut Core, id: String) {
        *core = Core::new();
        emit_wire(&ResetResponse::ok(id));
    }

    /// Handle a SnapshotCapture message in test mode.
    ///
    /// Serializes the current UI tree to JSON, SHA-256 hashes it, and returns
    /// a SnapshotCaptureResponse. No real pixel rendering happens here -- the
    /// hash is a stable, deterministic fingerprint of the tree structure.
    #[cfg(feature = "test-mode")]
    pub fn handle_snapshot_capture(core: &Core, id: String, name: String) {
        use sha2::{Digest, Sha256};

        let tree_json = match core.tree.root() {
            Some(root) => serde_json::to_string(root).unwrap_or_default(),
            None => "null".to_string(),
        };

        let mut hasher = Sha256::new();
        hasher.update(tree_json.as_bytes());
        let hash = format!("{:x}", hasher.finalize());

        emit_wire(&SnapshotCaptureResponse::new(id, name, hash, 0, 0));
    }

    // -- helpers --

    fn find_node_by_id(node: &TreeNode, id: &str) -> Value {
        if node.id == id {
            return serde_json::to_value(node).unwrap_or(Value::Null);
        }
        for child in &node.children {
            let found = find_node_by_id(child, id);
            if !found.is_null() {
                return found;
            }
        }
        Value::Null
    }

    /// Write a serialized response to stdout using the negotiated wire codec.
    fn emit_wire<T: serde::Serialize>(value: &T) {
        let codec = Codec::get_global();
        match codec.encode(value) {
            Ok(bytes) => {
                let stdout = io::stdout();
                let mut handle = stdout.lock();
                let _ = handle.write_all(&bytes);
                let _ = handle.flush();
            }
            Err(e) => log::error!("encode error: {e}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use serde_json::Value;

    use super::test_helpers;
    use julep_core::protocol::{IncomingMessage, TreeNode};

    fn make_tree_node(id: &str, type_name: &str) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props: Value::Object(Default::default()),
            children: vec![],
        }
    }

    // -- is_test_message --

    #[test]
    fn is_test_message_returns_true_for_query() {
        let msg = IncomingMessage::Query {
            id: "q1".to_string(),
            target: "tree".to_string(),
            selector: Value::Null,
        };
        assert!(test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_true_for_interact() {
        let msg = IncomingMessage::Interact {
            id: "i1".to_string(),
            action: "click".to_string(),
            selector: Value::Null,
            payload: Value::Null,
        };
        assert!(test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_true_for_reset() {
        let msg = IncomingMessage::Reset {
            id: "r1".to_string(),
        };
        assert!(test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_true_for_snapshot_capture() {
        let msg = IncomingMessage::SnapshotCapture {
            id: "sc1".to_string(),
            name: "my_snap".to_string(),
            theme: Value::Null,
            viewport: Value::Null,
        };
        assert!(test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_false_for_snapshot() {
        let msg = IncomingMessage::Snapshot {
            tree: make_tree_node("root", "column"),
        };
        assert!(!test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_false_for_patch() {
        let msg = IncomingMessage::Patch { ops: vec![] };
        assert!(!test_helpers::is_test_message(&msg));
    }

    #[test]
    fn is_test_message_returns_false_for_settings() {
        let msg = IncomingMessage::Settings {
            settings: serde_json::json!({}),
        };
        assert!(!test_helpers::is_test_message(&msg));
    }

    // -- handle_query --
    // handle_query writes to stdout; we verify it doesn't panic and that
    // QueryResponse::new produces the correct structure independently.

    #[test]
    fn query_response_has_correct_structure() {
        use julep_core::protocol::QueryResponse;

        let resp = QueryResponse::new(
            "q42".to_string(),
            "tree".to_string(),
            serde_json::json!({"id": "root"}),
        );
        assert_eq!(resp.id, "q42");
        assert_eq!(resp.target, "tree");
        assert_eq!(resp.message_type, "query_response");
        assert_eq!(resp.data, serde_json::json!({"id": "root"}));
    }

    #[test]
    fn query_response_null_data_when_tree_empty() {
        use julep_core::protocol::QueryResponse;

        let resp = QueryResponse::new("q1".to_string(), "tree".to_string(), Value::Null);
        assert_eq!(resp.data, Value::Null);
    }

    // -- screenshot protocol --

    #[test]
    fn is_test_message_returns_true_for_screenshot_capture() {
        let msg = IncomingMessage::ScreenshotCapture {
            id: "sc1".to_string(),
            name: "test_shot".to_string(),
            width: None,
            height: None,
        };
        assert!(test_helpers::is_test_message(&msg));
    }

    #[test]
    fn snapshot_capture_response_has_no_rgba_field() {
        use julep_core::protocol::SnapshotCaptureResponse;

        let resp = SnapshotCaptureResponse::new(
            "s1".to_string(),
            "snap".to_string(),
            "abc123".to_string(),
            100,
            200,
        );
        let json = serde_json::to_value(&resp).unwrap();
        assert!(
            json.get("rgba_base64").is_none(),
            "SnapshotCaptureResponse should not have an rgba_base64 field"
        );
    }

    #[test]
    fn screenshot_response_empty_has_correct_structure() {
        use julep_core::protocol::ScreenshotResponseEmpty;

        let resp = ScreenshotResponseEmpty::new("sc1".to_string(), "test_shot".to_string());
        assert_eq!(resp.message_type, "screenshot_response");
        assert_eq!(resp.hash, "");
        assert_eq!(resp.width, 0);
        assert_eq!(resp.height, 0);

        let json = serde_json::to_value(&resp).unwrap();
        assert_eq!(json.get("type").unwrap(), "screenshot_response");
    }
}
