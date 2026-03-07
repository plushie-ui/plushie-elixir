#[cfg(feature = "headless")]
pub mod headless_mode {
    use std::io::{self, BufRead, Write};

    use iced::Theme;
    use serde_json::Value;

    use julep_core::codec::Codec;
    use julep_core::engine::Core;
    use julep_core::protocol::{
        IncomingMessage, InteractResponse, QueryResponse, ResetResponse, ScreenshotResponseEmpty,
        SnapshotCaptureResponse,
    };

    /// Default screenshot width when not specified by the caller.
    const DEFAULT_SCREENSHOT_WIDTH: u32 = 1024;
    /// Default screenshot height when not specified by the caller.
    const DEFAULT_SCREENSHOT_HEIGHT: u32 = 768;

    use julep_core::extensions::{ExtensionCaches, ExtensionDispatcher};

    /// Run the headless mode event loop.
    /// No iced::daemon. Reads framed messages from stdin, processes through Core,
    /// writes responses to stdout using the negotiated wire codec.
    ///
    /// Extensions are initialized when a Settings message arrives (via
    /// `init_all`) and prepared after each tree-changing message (via
    /// `prepare_all`). Full extension interactivity (handle_event,
    /// handle_command) is supported. Note that extension rendering in
    /// headless mode goes through the same `widgets::render` path used
    /// for screenshot capture, so extensions that rely on real iced widget
    /// state (e.g. focus, scroll position) won't behave identically to the
    /// full daemon mode.
    pub fn run(forced_codec: Option<Codec>, mut dispatcher: ExtensionDispatcher) {
        let mut core = Core::new();
        let mut ext_caches = ExtensionCaches::new();
        let mut theme = Theme::Dark;
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
        Codec::set_global(codec);

        loop {
            match codec.read_message(&mut reader) {
                Ok(None) => break,
                Ok(Some(bytes)) => match codec.decode::<IncomingMessage>(&bytes) {
                    Ok(msg) => {
                        handle_message(&mut core, &mut theme, &mut dispatcher, &mut ext_caches, msg)
                    }
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

    fn handle_message(
        core: &mut Core,
        theme: &mut Theme,
        dispatcher: &mut ExtensionDispatcher,
        ext_caches: &mut ExtensionCaches,
        msg: IncomingMessage,
    ) {
        // Track whether this message might change the tree or settings so
        // we know when to call extension lifecycle hooks.
        let is_settings = matches!(msg, IncomingMessage::Settings { .. });
        let is_snapshot = matches!(msg, IncomingMessage::Snapshot { .. });
        let is_tree_change = is_snapshot || matches!(msg, IncomingMessage::Patch { .. });

        match msg {
            // Normal messages go through Core::apply()
            IncomingMessage::Snapshot { .. }
            | IncomingMessage::Patch { .. }
            | IncomingMessage::EffectRequest { .. }
            | IncomingMessage::WidgetOp { .. }
            | IncomingMessage::SubscriptionRegister { .. }
            | IncomingMessage::SubscriptionUnregister { .. }
            | IncomingMessage::WindowOp { .. }
            | IncomingMessage::Settings { .. }
            | IncomingMessage::ImageOp { .. } => {
                // Extract extension_config before apply consumes the message.
                let ext_config = if is_settings {
                    if let IncomingMessage::Settings { ref settings } = msg {
                        settings
                            .get("extension_config")
                            .cloned()
                            .unwrap_or(Value::Null)
                    } else {
                        Value::Null
                    }
                } else {
                    Value::Null
                };

                let effects = core.apply(msg);

                // Route extension config on Settings.
                if is_settings {
                    dispatcher.init_all(&ext_config);
                }

                // In headless mode, we handle effects differently:
                // - SyncWindows: no-op (no real windows)
                // - EmitEvent: write to stdout
                // - EmitEffectResponse: write to stdout
                // - WidgetOp: no-op (no real iced widgets to operate on)
                // - WindowOp: no-op (no real windows)
                // - ThemeChanged: track for screenshot rendering
                for effect in effects {
                    match effect {
                        julep_core::engine::CoreEffect::EmitEvent(event) => {
                            emit_wire(&event);
                        }
                        julep_core::engine::CoreEffect::EmitEffectResponse(response) => {
                            emit_wire(&response);
                        }
                        julep_core::engine::CoreEffect::SpawnAsyncEffect {
                            request_id,
                            effect_type,
                            ..
                        } => {
                            // Headless has no display for file dialogs --
                            // return cancelled immediately.
                            log::debug!(
                                "headless: async effect {effect_type} returning cancelled \
                                 (no display)"
                            );
                            emit_wire(&julep_core::protocol::EffectResponse::error(
                                request_id,
                                "cancelled".to_string(),
                            ));
                        }
                        julep_core::engine::CoreEffect::ThemeChanged(t) => {
                            *theme = t;
                        }
                        _ => {} // No-op for window/widget ops in headless
                    }
                }

                // Prepare extensions after tree changes (Snapshot/Patch).
                if is_tree_change {
                    // On Snapshot, give previously-poisoned extensions a
                    // fresh chance (same as Reset does).
                    if is_snapshot {
                        dispatcher.clear_poisoned();
                    }
                    if let Some(root) = core.tree.root() {
                        dispatcher.prepare_all(root, ext_caches, theme);
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
            IncomingMessage::ScreenshotCapture {
                id,
                name,
                width,
                height,
            } => {
                let w = width.unwrap_or(DEFAULT_SCREENSHOT_WIDTH).max(1);
                let h = height.unwrap_or(DEFAULT_SCREENSHOT_HEIGHT).max(1);
                handle_screenshot_capture(core, theme, dispatcher, id, name, w, h);
            }
            IncomingMessage::Reset { id } => {
                handle_reset(core, id);
                dispatcher.clear_poisoned();
            }
            IncomingMessage::ExtensionCommand {
                node_id,
                op,
                payload,
            } => {
                let events = dispatcher.handle_command(&node_id, &op, &payload, ext_caches);
                for event in events {
                    emit_wire(&event);
                }
            }
            IncomingMessage::ExtensionCommandBatch { commands } => {
                for cmd in commands {
                    let events =
                        dispatcher.handle_command(&cmd.node_id, &cmd.op, &cmd.payload, ext_caches);
                    for event in events {
                        emit_wire(&event);
                    }
                }
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
            ("press", _) => {
                let payload_map = payload.as_object();
                let (key, modifiers) = parse_key_and_modifiers(payload_map);
                vec![serde_json::json!({
                    "type": "event", "event": "key_press", "id": "", "key": key, "modifiers": modifiers
                })]
            }
            ("release", _) => {
                let payload_map = payload.as_object();
                let (key, modifiers) = parse_key_and_modifiers(payload_map);
                vec![serde_json::json!({
                    "type": "event", "event": "key_release", "id": "", "key": key, "modifiers": modifiers
                })]
            }
            ("move_to", _) => {
                let x = payload.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0);
                let y = payload.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0);
                vec![serde_json::json!({
                    "type": "event", "event": "cursor_moved", "id": "", "x": x, "y": y
                })]
            }
            ("type_key", _) => {
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
            _ => {
                log::warn!("unknown action '{action}' or widget not found");
                vec![]
            }
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

        emit_wire(&SnapshotCaptureResponse::new(id, name, hash, 0, 0));
    }

    /// Handle a ScreenshotCapture message in headless mode.
    ///
    /// Uses iced's `Headless` renderer trait (backed by tiny-skia) to produce
    /// real RGBA pixel data without a display server or GPU. Builds an iced
    /// `UserInterface` from the current tree, draws it, and captures pixels
    /// via `renderer.screenshot()`.
    fn handle_screenshot_capture(
        core: &mut Core,
        theme: &Theme,
        dispatcher: &ExtensionDispatcher,
        id: String,
        name: String,
        width: u32,
        height: u32,
    ) {
        use iced_test::core::renderer::Headless as HeadlessTrait;
        use iced_test::core::theme::Base;
        use sha2::{Digest, Sha256};

        let root = match core.tree.root() {
            Some(r) => r,
            None => {
                emit_wire(&ScreenshotResponseEmpty::new(id, name));
                return;
            }
        };

        // Prepare caches and build the iced Element from the tree.
        julep_core::widgets::ensure_caches(root, &mut core.caches);
        let images = julep_core::image_registry::ImageRegistry::new();
        let element: iced::Element<'_, julep_core::message::Message> =
            julep_core::widgets::render(root, &core.caches, &images, theme, dispatcher);

        // Create a headless tiny-skia renderer.
        let mut renderer = match iced::futures::executor::block_on(iced::Renderer::new(
            iced::Font::DEFAULT,
            iced::Pixels(16.0),
            None,
        )) {
            Some(r) => r,
            None => {
                log::error!("failed to create headless renderer");
                emit_wire(&ScreenshotResponseEmpty::new(id, name));
                return;
            }
        };

        let size = iced::Size::new(width as f32, height as f32);
        let mut ui = iced_test::runtime::UserInterface::build(
            element,
            size,
            iced_test::runtime::user_interface::Cache::default(),
            &mut renderer,
        );

        let base = theme.base();
        ui.draw(
            &mut renderer,
            theme,
            &iced_test::core::renderer::Style {
                text_color: base.text_color,
            },
            iced::mouse::Cursor::Unavailable,
        );

        let phys_size = iced::Size::new(width, height);
        let rgba = renderer.screenshot(phys_size, 1.0, base.background_color);

        let hash = {
            let mut hasher = Sha256::new();
            hasher.update(&rgba);
            format!("{:x}", hasher.finalize())
        };

        julep_core::protocol::emit_screenshot_response(&id, &name, &hash, width, height, &rgba);
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

    fn search_by_id(node: &julep_core::protocol::TreeNode, id: &str) -> Option<Value> {
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

    fn search_by_text(node: &julep_core::protocol::TreeNode, text: &str) -> Option<Value> {
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

    fn find_id_by_text(node: &julep_core::protocol::TreeNode, text: &str) -> Option<String> {
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
        let codec = Codec::get_global();
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
        use julep_core::engine::Core;
        use julep_core::protocol::TreeNode;

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
