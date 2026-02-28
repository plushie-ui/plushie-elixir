#[cfg(feature = "headless")]
pub mod headless_mode {
    use std::io::{self, BufRead, Write};

    use serde_json::Value;

    use crate::codec::Codec;
    use crate::julep_core::Core;
    use crate::protocol::{
        IncomingMessage, InteractResponse, QueryResponse, ResetResponse, SnapshotCaptureResponse,
    };
    use crate::WIRE_CODEC;

    /// Run the headless mode event loop.
    /// No iced::daemon. Reads framed messages from stdin, processes through Core,
    /// writes responses to stdout using the negotiated wire codec.
    pub fn run(forced_codec: Option<Codec>) {
        let mut core = Core::new();
        let stdin = io::stdin();
        let mut reader = io::BufReader::new(stdin.lock());

        // Determine codec: forced by CLI flag, or auto-detected from first byte.
        let codec = match forced_codec {
            Some(c) => c,
            None => {
                let buf = reader.fill_buf().unwrap_or(&[]);
                if buf.is_empty() {
                    log::error!("stdin closed before first message");
                    return;
                }
                Codec::detect_from_first_byte(buf[0])
            }
        };
        log::info!("wire codec: {codec:?}");
        WIRE_CODEC
            .set(codec)
            .expect("WIRE_CODEC already initialized");

        loop {
            match codec.read_message(&mut reader) {
                Ok(None) => break,
                Ok(Some(bytes)) => match codec.decode::<IncomingMessage>(&bytes) {
                    Ok(msg) => handle_message(&mut core, msg),
                    Err(e) => {
                        log::error!("decode error: {e}");
                    }
                },
                Err(e) => {
                    log::error!("read error: {e}");
                    break;
                }
            }
        }

        log::info!("stdin closed, exiting");
    }

    fn handle_message(core: &mut Core, msg: IncomingMessage) {
        match msg {
            // Normal messages go through Core::apply()
            IncomingMessage::Snapshot { .. }
            | IncomingMessage::Patch { .. }
            | IncomingMessage::EffectRequest { .. }
            | IncomingMessage::WidgetOp { .. }
            | IncomingMessage::SubscriptionRegister { .. }
            | IncomingMessage::SubscriptionUnregister { .. }
            | IncomingMessage::WindowOp { .. }
            | IncomingMessage::Settings { .. } => {
                let effects = core.apply(msg);
                // In headless mode, we handle effects differently:
                // - SyncWindows: no-op (no real windows)
                // - EmitEvent: write to stdout
                // - EmitEffectResponse: write to stdout
                // - WidgetOp: no-op (no real iced widgets to operate on)
                // - WindowOp: no-op (no real windows)
                // - ThemeChanged: no-op (theme stored in core for rendering)
                for effect in effects {
                    match effect {
                        crate::julep_core::CoreEffect::EmitEvent(event) => {
                            emit_wire(&event);
                        }
                        crate::julep_core::CoreEffect::EmitEffectResponse(response) => {
                            emit_wire(&response);
                        }
                        _ => {} // No-op for window/widget ops in headless
                    }
                }
            }

            // Test-specific messages
            IncomingMessage::Query {
                id,
                target,
                selector,
            } => {
                handle_query(core, id, target, selector);
            }
            IncomingMessage::Interact {
                id,
                action,
                selector,
                payload,
            } => {
                handle_interact(core, id, action, selector, payload);
            }
            IncomingMessage::SnapshotCapture { id, name, .. } => {
                handle_snapshot_capture(core, id, name);
            }
            IncomingMessage::Reset { id } => {
                handle_reset(core, id);
            }
        }
    }

    fn handle_query(core: &Core, id: String, target: String, selector: Value) {
        let data = match target.as_str() {
            "tree" => {
                // Serialize the entire tree
                match core.tree.root() {
                    Some(root) => serde_json::to_value(root).unwrap_or(Value::Null),
                    None => Value::Null,
                }
            }
            "find" => {
                // Find a widget by selector in the tree
                match parse_selector(&selector) {
                    Some(Selector::Id(widget_id)) => find_node_by_id(core, &widget_id),
                    Some(Selector::Text(text)) => find_node_by_text(core, &text),
                    None => Value::Null,
                }
            }
            _ => {
                log::warn!("unknown query target: {target}");
                Value::Null
            }
        };

        emit_wire(&QueryResponse::new(id, target, data));
    }

    fn handle_interact(
        core: &mut Core,
        id: String,
        action: String,
        selector: Value,
        payload: Value,
    ) {
        // Find the target widget ID from selector
        let widget_id = match parse_selector(&selector) {
            Some(Selector::Id(wid)) => Some(wid),
            Some(Selector::Text(text)) => {
                // Walk the tree to find a node with this text
                core.tree
                    .root()
                    .and_then(|root| find_id_by_text(root, &text))
            }
            None => None,
        };

        let events = match (action.as_str(), widget_id) {
            ("click", Some(wid)) => {
                vec![serde_json::json!({"type": "event", "event": "click", "id": wid})]
            }
            ("type_text", Some(wid)) => {
                let text = payload.get("text").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "input", "id": wid, "value": text}),
                ]
            }
            ("submit", Some(wid)) => {
                let value = payload.get("value").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "submit", "id": wid, "value": value}),
                ]
            }
            ("toggle", Some(wid)) => {
                let value = payload
                    .get("value")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false);
                vec![
                    serde_json::json!({"type": "event", "event": "toggle", "id": wid, "value": value}),
                ]
            }
            ("select", Some(wid)) => {
                let value = payload.get("value").and_then(|v| v.as_str()).unwrap_or("");
                vec![
                    serde_json::json!({"type": "event", "event": "select", "id": wid, "value": value}),
                ]
            }
            ("slide", Some(wid)) => {
                let value = payload.get("value").and_then(|v| v.as_f64()).unwrap_or(0.0);
                vec![
                    serde_json::json!({"type": "event", "event": "slide", "id": wid, "value": value}),
                ]
            }
            _ => {
                log::warn!("unknown action '{action}' or widget not found");
                vec![]
            }
        };

        emit_wire(&InteractResponse::new(id, events));
    }

    fn handle_snapshot_capture(core: &Core, id: String, name: String) {
        // In headless mode without the full iced_test Simulator rendering,
        // we return a hash of the serialized tree as a placeholder.
        // Real pixel snapshots require building iced Elements and using tiny-skia.
        let tree_json = match core.tree.root() {
            Some(root) => serde_json::to_string(root).unwrap_or_default(),
            None => "null".to_string(),
        };

        let hash = {
            use sha2::{Digest, Sha256};
            let mut hasher = Sha256::new();
            hasher.update(tree_json.as_bytes());
            format!("{:x}", hasher.finalize())
        };

        emit_wire(&SnapshotCaptureResponse::new(
            id, name, hash, 0, // no pixel dimensions for tree-hash snapshots
            0, None, // no RGBA data
        ));
    }

    fn handle_reset(core: &mut Core, id: String) {
        *core = Core::new();
        emit_wire(&ResetResponse::ok(id));
    }

    // -- Selector parsing --

    enum Selector {
        Id(String),
        Text(String),
    }

    fn parse_selector(selector: &Value) -> Option<Selector> {
        let by = selector.get("by")?.as_str()?;
        let value = selector.get("value")?.as_str()?.to_string();
        match by {
            "id" => Some(Selector::Id(value)),
            "text" => Some(Selector::Text(value)),
            _ => None,
        }
    }

    // -- Tree search helpers --

    fn find_node_by_id(core: &Core, widget_id: &str) -> Value {
        match core.tree.root() {
            Some(root) => search_by_id(root, widget_id).unwrap_or(Value::Null),
            None => Value::Null,
        }
    }

    fn search_by_id(node: &crate::protocol::TreeNode, id: &str) -> Option<Value> {
        if node.id == id {
            return serde_json::to_value(node).ok();
        }
        for child in &node.children {
            if let Some(found) = search_by_id(child, id) {
                return Some(found);
            }
        }
        None
    }

    fn find_node_by_text(core: &Core, text: &str) -> Value {
        match core.tree.root() {
            Some(root) => search_by_text(root, text).unwrap_or(Value::Null),
            None => Value::Null,
        }
    }

    fn search_by_text(node: &crate::protocol::TreeNode, text: &str) -> Option<Value> {
        // Check common text props
        for key in &["content", "label", "value", "placeholder"] {
            if let Some(val) = node.props.get(*key) {
                if val.as_str() == Some(text) {
                    return serde_json::to_value(node).ok();
                }
            }
        }
        for child in &node.children {
            if let Some(found) = search_by_text(child, text) {
                return Some(found);
            }
        }
        None
    }

    fn find_id_by_text(node: &crate::protocol::TreeNode, text: &str) -> Option<String> {
        for key in &["content", "label", "value", "placeholder"] {
            if let Some(val) = node.props.get(*key) {
                if val.as_str() == Some(text) {
                    return Some(node.id.clone());
                }
            }
        }
        for child in &node.children {
            if let Some(found) = find_id_by_text(child, text) {
                return Some(found);
            }
        }
        None
    }

    /// Write a serialized response to stdout using the negotiated wire codec.
    fn emit_wire<T: serde::Serialize>(value: &T) {
        let codec = WIRE_CODEC.get().expect("WIRE_CODEC not initialized");
        match codec.encode(value) {
            Ok(bytes) => {
                let stdout = io::stdout();
                let mut handle = stdout.lock();
                if let Err(e) = handle.write_all(&bytes) {
                    log::error!("write error: {e}");
                }
                let _ = handle.flush();
            }
            Err(e) => log::error!("encode error: {e}"),
        }
    }

    #[cfg(test)]
    mod tests {
        use serde_json::Value;

        use super::*;
        use crate::julep_core::Core;
        use crate::protocol::TreeNode;

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

        fn core_with_tree(root: TreeNode) -> Core {
            let mut core = Core::new();
            core.tree.snapshot(root);
            core
        }

        // -- find_node_by_id / search_by_id --

        #[test]
        fn find_in_tree_by_id_finds_root() {
            let core = core_with_tree(make_node("root", "column"));
            let result = find_node_by_id(&core, "root");
            assert!(!result.is_null());
            assert_eq!(result.get("id").and_then(|v| v.as_str()), Some("root"));
        }

        #[test]
        fn find_in_tree_by_id_finds_nested_child() {
            let child = make_node("btn1", "button");
            let mut root = make_node("root", "column");
            root.children.push(child);

            let core = core_with_tree(root);
            let result = find_node_by_id(&core, "btn1");
            assert!(!result.is_null());
            assert_eq!(result.get("id").and_then(|v| v.as_str()), Some("btn1"));
        }

        #[test]
        fn find_in_tree_by_id_returns_null_when_not_found() {
            let core = core_with_tree(make_node("root", "column"));
            let result = find_node_by_id(&core, "nonexistent");
            assert!(result.is_null());
        }

        #[test]
        fn find_in_tree_by_id_returns_null_when_tree_empty() {
            let core = Core::new();
            let result = find_node_by_id(&core, "any");
            assert!(result.is_null());
        }

        // -- find_node_by_text / search_by_text --

        #[test]
        fn find_in_tree_by_text_matches_content_prop() {
            let node = make_node_with_props(
                "txt1",
                "text",
                serde_json::json!({"content": "Hello world"}),
            );
            let core = core_with_tree(node);
            let result = find_node_by_text(&core, "Hello world");
            assert!(!result.is_null());
            assert_eq!(result.get("id").and_then(|v| v.as_str()), Some("txt1"));
        }

        #[test]
        fn find_in_tree_by_text_matches_label_prop() {
            let node =
                make_node_with_props("btn1", "button", serde_json::json!({"label": "Click me"}));
            let core = core_with_tree(node);
            let result = find_node_by_text(&core, "Click me");
            assert!(!result.is_null());
            assert_eq!(result.get("id").and_then(|v| v.as_str()), Some("btn1"));
        }

        #[test]
        fn find_in_tree_by_text_returns_null_when_not_found() {
            let node =
                make_node_with_props("txt1", "text", serde_json::json!({"content": "Something"}));
            let core = core_with_tree(node);
            let result = find_node_by_text(&core, "Nonexistent");
            assert!(result.is_null());
        }

        #[test]
        fn find_in_tree_by_text_returns_null_when_tree_empty() {
            let core = Core::new();
            let result = find_node_by_text(&core, "any text");
            assert!(result.is_null());
        }

        // -- parse_selector --

        #[test]
        fn parse_selector_returns_id_selector() {
            let sel = serde_json::json!({"by": "id", "value": "my-widget"});
            let result = parse_selector(&sel);
            assert!(matches!(result, Some(Selector::Id(ref s)) if s == "my-widget"));
        }

        #[test]
        fn parse_selector_returns_text_selector() {
            let sel = serde_json::json!({"by": "text", "value": "Click me"});
            let result = parse_selector(&sel);
            assert!(matches!(result, Some(Selector::Text(ref s)) if s == "Click me"));
        }

        #[test]
        fn parse_selector_returns_none_for_unknown_by() {
            let sel = serde_json::json!({"by": "point", "value": "10,20"});
            let result = parse_selector(&sel);
            assert!(result.is_none());
        }

        #[test]
        fn parse_selector_returns_none_for_missing_by() {
            let sel = serde_json::json!({"value": "my-widget"});
            let result = parse_selector(&sel);
            assert!(result.is_none());
        }

        #[test]
        fn parse_selector_returns_none_for_missing_value() {
            let sel = serde_json::json!({"by": "id"});
            let result = parse_selector(&sel);
            assert!(result.is_none());
        }
    }
}
