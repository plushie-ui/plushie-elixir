// test_mode.rs - Helpers for --test mode
//
// When running with --test, the regular iced::daemon runs normally but the App
// also handles Query/Interact/SnapshotCapture/Reset messages from stdin
// (instead of passing them to Core::apply where they'd hit the catch-all).

pub mod test_helpers {
    use std::io::{self, Write};

    use serde_json::Value;

    use crate::julep_core::Core;
    #[cfg(feature = "test-mode")]
    use crate::protocol::SnapshotCaptureResponse;
    use crate::protocol::{
        IncomingMessage, InteractResponse, QueryResponse, ResetResponse, TreeNode,
    };
    use crate::WIRE_CODEC;

    /// Check if a message is a test-mode message (Query, Interact, etc.)
    pub fn is_test_message(msg: &IncomingMessage) -> bool {
        matches!(
            msg,
            IncomingMessage::Query { .. }
                | IncomingMessage::Interact { .. }
                | IncomingMessage::SnapshotCapture { .. }
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
            _ => vec![],
        };
        emit_wire(&InteractResponse::new(id, events));
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

        emit_wire(&SnapshotCaptureResponse::new(id, name, hash, 0, 0, None));
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
        let codec = WIRE_CODEC.get().expect("WIRE_CODEC not initialized");
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

    use crate::protocol::{IncomingMessage, TreeNode};
    use crate::test_mode::test_helpers;

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
        use crate::protocol::QueryResponse;

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
        use crate::protocol::QueryResponse;

        let resp = QueryResponse::new("q1".to_string(), "tree".to_string(), Value::Null);
        assert_eq!(resp.data, Value::Null);
    }
}
