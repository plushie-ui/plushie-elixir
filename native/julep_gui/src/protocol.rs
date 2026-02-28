use serde::{Deserialize, Deserializer, Serialize};
use serde_json::Value;

/// Messages sent from Elixir to the renderer over stdin (JSONL).
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum IncomingMessage {
    Snapshot {
        tree: TreeNode,
    },
    Patch {
        ops: Vec<PatchOp>,
    },
    EffectRequest {
        id: String,
        kind: String,
        payload: Value,
    },
    WidgetOp {
        op: String,
        #[serde(default)]
        payload: Value,
    },
    SubscriptionRegister {
        kind: String,
        tag: String,
    },
    SubscriptionUnregister {
        kind: String,
    },
    WindowOp {
        op: String,
        window_id: String,
        #[serde(default)]
        settings: Value,
    },
    Settings {
        settings: Value,
    },
    /// Query the current tree or find a widget.
    Query {
        id: String,
        target: String,
        #[serde(default)]
        selector: Value,
    },
    /// Interact with a widget (click, type, etc.)
    Interact {
        id: String,
        action: String,
        #[serde(default)]
        selector: Value,
        #[serde(default)]
        payload: Value,
    },
    /// Capture a pixel snapshot.
    #[allow(dead_code)]
    SnapshotCapture {
        id: String,
        name: String,
        #[serde(default)]
        theme: Value,
        #[serde(default)]
        viewport: Value,
    },
    /// Reset the app state.
    Reset {
        id: String,
    },
    /// Image operation (create, update, delete in-memory image handles).
    ///
    /// Binary fields (`data`, `pixels`) accept either raw bytes (from msgpack)
    /// or base64-encoded strings (from JSON). The custom deserializer handles both.
    ImageOp {
        op: String,
        handle: String,
        #[serde(default, deserialize_with = "deserialize_binary_field")]
        data: Option<Vec<u8>>,
        #[serde(default, deserialize_with = "deserialize_binary_field")]
        pixels: Option<Vec<u8>>,
        #[serde(default)]
        width: Option<u32>,
        #[serde(default)]
        height: Option<u32>,
    },
}

/// Response to an effect request, written to stdout as JSONL.
#[derive(Debug, Serialize)]
pub struct EffectResponse {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub id: String,
    pub status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

impl EffectResponse {
    pub fn ok(id: String, result: Value) -> Self {
        Self {
            message_type: "effect_response",
            id,
            status: "ok",
            result: Some(result),
            error: None,
        }
    }

    pub fn error(id: String, reason: String) -> Self {
        Self {
            message_type: "effect_response",
            id,
            status: "error",
            result: None,
            error: Some(reason),
        }
    }

    pub fn unsupported(id: String) -> Self {
        Self::error(id, "unsupported".to_string())
    }
}

/// Response to a Query message.
#[derive(Debug, Serialize)]
pub struct QueryResponse {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub id: String,
    pub target: String,
    pub data: Value,
}

impl QueryResponse {
    pub fn new(id: String, target: String, data: Value) -> Self {
        Self {
            message_type: "query_response",
            id,
            target,
            data,
        }
    }
}

/// Response to an Interact message.
#[derive(Debug, Serialize)]
pub struct InteractResponse {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub id: String,
    pub events: Vec<Value>,
}

impl InteractResponse {
    pub fn new(id: String, events: Vec<Value>) -> Self {
        Self {
            message_type: "interact_response",
            id,
            events,
        }
    }
}

/// Response to a SnapshotCapture message.
#[derive(Debug, Serialize)]
#[allow(dead_code)]
pub struct SnapshotCaptureResponse {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub id: String,
    pub name: String,
    pub hash: String,
    pub width: u32,
    pub height: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub rgba_base64: Option<String>,
}

#[allow(dead_code)]
impl SnapshotCaptureResponse {
    pub fn new(
        id: String,
        name: String,
        hash: String,
        width: u32,
        height: u32,
        rgba_base64: Option<String>,
    ) -> Self {
        Self {
            message_type: "snapshot_response",
            id,
            name,
            hash,
            width,
            height,
            rgba_base64,
        }
    }
}

/// Response to a Reset message.
#[derive(Debug, Serialize)]
pub struct ResetResponse {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub id: String,
    pub status: &'static str,
}

impl ResetResponse {
    pub fn ok(id: String) -> Self {
        Self {
            message_type: "reset_response",
            id,
            status: "ok",
        }
    }
}

/// A single node in the UI tree.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct TreeNode {
    pub id: String,
    #[serde(rename = "type")]
    pub type_name: String,
    #[serde(default)]
    pub props: Value,
    #[serde(default)]
    pub children: Vec<TreeNode>,
}

/// A single patch operation applied incrementally to the retained tree.
#[derive(Debug, Clone, Deserialize, Serialize)]
pub struct PatchOp {
    pub op: String,
    pub path: Vec<usize>,
    #[serde(flatten)]
    pub rest: Value,
}

/// Events written to stdout by the renderer.
#[derive(Debug, Serialize)]
pub struct OutgoingEvent {
    #[serde(rename = "type")]
    pub message_type: &'static str,
    pub family: &'static str,
    pub id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub tag: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub modifiers: Option<KeyModifiers>,
    /// Flexible extra data for events that carry additional fields beyond
    /// the standard id/value/tag/modifiers shape.  Serialized as a nested
    /// `"data"` object.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub data: Option<Value>,
}

/// Serializable representation of keyboard modifiers.
#[derive(Debug, Serialize)]
pub struct KeyModifiers {
    pub shift: bool,
    pub ctrl: bool,
    pub alt: bool,
    pub logo: bool,
    pub command: bool,
}

// ---------------------------------------------------------------------------
// Widget events (click, input, toggle, slide, select, submit)
// ---------------------------------------------------------------------------

impl OutgoingEvent {
    /// Helper to build a bare event with only the common fields.
    fn bare(family: &'static str, id: String) -> Self {
        Self {
            message_type: "event",
            family,
            id,
            value: None,
            tag: None,
            modifiers: None,
            data: None,
        }
    }

    /// Helper to build a subscription-tagged event with no widget id.
    fn tagged(family: &'static str, tag: String) -> Self {
        Self {
            message_type: "event",
            family,
            id: String::new(),
            value: None,
            tag: Some(tag),
            modifiers: None,
            data: None,
        }
    }

    /// Generic widget event with a family string and optional data payload.
    /// Used for on_open, on_close, sort, and other events.
    pub fn generic(family: &'static str, id: String, data: Option<Value>) -> Self {
        Self {
            data,
            ..Self::bare(family, id)
        }
    }

    pub fn click(id: String) -> Self {
        Self::bare("click", id)
    }

    pub fn input(id: String, value: String) -> Self {
        Self {
            value: Some(Value::String(value)),
            ..Self::bare("input", id)
        }
    }

    pub fn submit(id: String, value: String) -> Self {
        Self {
            value: Some(Value::String(value)),
            ..Self::bare("submit", id)
        }
    }

    pub fn toggle(id: String, checked: bool) -> Self {
        Self {
            value: Some(Value::Bool(checked)),
            ..Self::bare("toggle", id)
        }
    }

    pub fn slide(id: String, value: f64) -> Self {
        Self {
            value: Some(serde_json::json!(value)),
            ..Self::bare("slide", id)
        }
    }

    pub fn slide_release(id: String, value: f64) -> Self {
        Self {
            value: Some(serde_json::json!(value)),
            ..Self::bare("slide_release", id)
        }
    }

    pub fn select(id: String, value: String) -> Self {
        Self {
            value: Some(Value::String(value)),
            ..Self::bare("select", id)
        }
    }

    // -----------------------------------------------------------------------
    // Keyboard events
    // -----------------------------------------------------------------------

    pub fn key_press(tag: String, data: &crate::KeyEventData) -> Self {
        Self {
            modifiers: Some(crate::serialize_modifiers(data.modifiers)),
            value: Some(Value::String(crate::serialize_key(&data.key))),
            data: Some(serde_json::json!({
                "modified_key": crate::serialize_key(&data.modified_key),
                "physical_key": crate::serialize_physical_key(&data.physical_key),
                "location": crate::serialize_location(&data.location),
                "text": data.text.as_deref(),
                "repeat": data.repeat,
            })),
            ..Self::tagged("key_press", tag)
        }
    }

    pub fn key_release(tag: String, data: &crate::KeyEventData) -> Self {
        Self {
            modifiers: Some(crate::serialize_modifiers(data.modifiers)),
            value: Some(Value::String(crate::serialize_key(&data.key))),
            data: Some(serde_json::json!({
                "modified_key": crate::serialize_key(&data.modified_key),
                "physical_key": crate::serialize_physical_key(&data.physical_key),
                "location": crate::serialize_location(&data.location),
            })),
            ..Self::tagged("key_release", tag)
        }
    }

    pub fn modifiers_changed(tag: String, modifiers: KeyModifiers) -> Self {
        Self {
            modifiers: Some(modifiers),
            ..Self::tagged("modifiers_changed", tag)
        }
    }

    // -----------------------------------------------------------------------
    // Mouse events
    // -----------------------------------------------------------------------

    pub fn cursor_moved(tag: String, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y})),
            ..Self::tagged("cursor_moved", tag)
        }
    }

    pub fn cursor_entered(tag: String) -> Self {
        Self::tagged("cursor_entered", tag)
    }

    pub fn cursor_left(tag: String) -> Self {
        Self::tagged("cursor_left", tag)
    }

    pub fn button_pressed(tag: String, button: String) -> Self {
        Self {
            value: Some(Value::String(button)),
            ..Self::tagged("button_pressed", tag)
        }
    }

    pub fn button_released(tag: String, button: String) -> Self {
        Self {
            value: Some(Value::String(button)),
            ..Self::tagged("button_released", tag)
        }
    }

    pub fn wheel_scrolled(tag: String, delta_x: f32, delta_y: f32, unit: &str) -> Self {
        Self {
            data: Some(serde_json::json!({
                "delta_x": delta_x,
                "delta_y": delta_y,
                "unit": unit,
            })),
            ..Self::tagged("wheel_scrolled", tag)
        }
    }

    // -----------------------------------------------------------------------
    // Touch events
    // -----------------------------------------------------------------------

    pub fn finger_pressed(tag: String, finger_id: u64, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "finger_id": finger_id,
                "x": x,
                "y": y,
            })),
            ..Self::tagged("finger_pressed", tag)
        }
    }

    pub fn finger_moved(tag: String, finger_id: u64, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "finger_id": finger_id,
                "x": x,
                "y": y,
            })),
            ..Self::tagged("finger_moved", tag)
        }
    }

    pub fn finger_lifted(tag: String, finger_id: u64, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "finger_id": finger_id,
                "x": x,
                "y": y,
            })),
            ..Self::tagged("finger_lifted", tag)
        }
    }

    pub fn finger_lost(tag: String, finger_id: u64, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "finger_id": finger_id,
                "x": x,
                "y": y,
            })),
            ..Self::tagged("finger_lost", tag)
        }
    }

    // -----------------------------------------------------------------------
    // Window lifecycle events
    // -----------------------------------------------------------------------

    pub fn window_opened(
        tag: String,
        window_id: String,
        position: Option<(f32, f32)>,
        width: f32,
        height: f32,
    ) -> Self {
        let pos = position.map(|(x, y)| serde_json::json!({"x": x, "y": y}));
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "position": pos,
                "width": width,
                "height": height,
            })),
            ..Self::tagged("window_opened", tag)
        }
    }

    pub fn window_closed(tag: String, window_id: String) -> Self {
        Self {
            data: Some(serde_json::json!({"window_id": window_id})),
            ..Self::tagged("window_closed", tag)
        }
    }

    pub fn window_close_requested(tag: String, window_id: String) -> Self {
        Self {
            data: Some(serde_json::json!({"window_id": window_id})),
            ..Self::tagged("window_close_requested", tag)
        }
    }

    pub fn window_moved(tag: String, window_id: String, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "x": x,
                "y": y,
            })),
            ..Self::tagged("window_moved", tag)
        }
    }

    pub fn window_resized(tag: String, window_id: String, width: f32, height: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "width": width,
                "height": height,
            })),
            ..Self::tagged("window_resized", tag)
        }
    }

    pub fn window_focused(tag: String, window_id: String) -> Self {
        Self {
            data: Some(serde_json::json!({"window_id": window_id})),
            ..Self::tagged("window_focused", tag)
        }
    }

    pub fn window_unfocused(tag: String, window_id: String) -> Self {
        Self {
            data: Some(serde_json::json!({"window_id": window_id})),
            ..Self::tagged("window_unfocused", tag)
        }
    }

    pub fn window_rescaled(tag: String, window_id: String, scale_factor: f32) -> Self {
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "scale_factor": scale_factor,
            })),
            ..Self::tagged("window_rescaled", tag)
        }
    }

    pub fn file_hovered(tag: String, window_id: String, path: String) -> Self {
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "path": path,
            })),
            ..Self::tagged("file_hovered", tag)
        }
    }

    pub fn file_dropped(tag: String, window_id: String, path: String) -> Self {
        Self {
            data: Some(serde_json::json!({
                "window_id": window_id,
                "path": path,
            })),
            ..Self::tagged("file_dropped", tag)
        }
    }

    pub fn files_hovered_left(tag: String, window_id: String) -> Self {
        Self {
            data: Some(serde_json::json!({"window_id": window_id})),
            ..Self::tagged("files_hovered_left", tag)
        }
    }

    // -----------------------------------------------------------------------
    // Animation / theme / system events
    // -----------------------------------------------------------------------

    pub fn animation_frame(tag: String, timestamp_millis: u128) -> Self {
        Self {
            data: Some(serde_json::json!({"timestamp": timestamp_millis})),
            ..Self::tagged("animation_frame", tag)
        }
    }

    pub fn theme_changed(tag: String, mode: String) -> Self {
        Self {
            value: Some(Value::String(mode)),
            ..Self::tagged("theme_changed", tag)
        }
    }

    // -----------------------------------------------------------------------
    // Sensor events
    // -----------------------------------------------------------------------

    pub fn sensor_resize(id: String, width: f32, height: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"width": width, "height": height})),
            ..Self::bare("sensor_resize", id)
        }
    }

    // -----------------------------------------------------------------------
    // Canvas events
    // -----------------------------------------------------------------------

    pub fn canvas_press(id: String, x: f32, y: f32, button: String) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y, "button": button})),
            ..Self::bare("canvas_press", id)
        }
    }

    pub fn canvas_release(id: String, x: f32, y: f32, button: String) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y, "button": button})),
            ..Self::bare("canvas_release", id)
        }
    }

    pub fn canvas_move(id: String, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y})),
            ..Self::bare("canvas_move", id)
        }
    }

    pub fn canvas_scroll(id: String, x: f32, y: f32, delta_x: f32, delta_y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y, "delta_x": delta_x, "delta_y": delta_y})),
            ..Self::bare("canvas_scroll", id)
        }
    }

    // -----------------------------------------------------------------------
    // MouseArea events
    // -----------------------------------------------------------------------

    pub fn mouse_right_press(id: String) -> Self {
        Self::bare("mouse_right_press", id)
    }

    pub fn mouse_right_release(id: String) -> Self {
        Self::bare("mouse_right_release", id)
    }

    pub fn mouse_middle_release(id: String) -> Self {
        Self::bare("mouse_middle_release", id)
    }

    pub fn mouse_double_click(id: String) -> Self {
        Self::bare("mouse_double_click", id)
    }

    pub fn mouse_enter(id: String) -> Self {
        Self::bare("mouse_enter", id)
    }

    pub fn mouse_exit(id: String) -> Self {
        Self::bare("mouse_exit", id)
    }

    pub fn mouse_area_move(id: String, x: f32, y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"x": x, "y": y})),
            ..Self::bare("mouse_move", id)
        }
    }

    pub fn mouse_area_scroll(id: String, delta_x: f32, delta_y: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"delta_x": delta_x, "delta_y": delta_y})),
            ..Self::bare("mouse_scroll", id)
        }
    }

    // -----------------------------------------------------------------------
    // PaneGrid events
    // -----------------------------------------------------------------------

    pub fn pane_resized(id: String, split: String, ratio: f32) -> Self {
        Self {
            data: Some(serde_json::json!({"split": split, "ratio": ratio})),
            ..Self::bare("pane_resized", id)
        }
    }

    pub fn pane_dragged(id: String, pane: String, target: String) -> Self {
        Self {
            data: Some(serde_json::json!({"pane": pane, "target": target})),
            ..Self::bare("pane_dragged", id)
        }
    }

    pub fn pane_clicked(id: String, pane: String) -> Self {
        Self {
            data: Some(serde_json::json!({"pane": pane})),
            ..Self::bare("pane_clicked", id)
        }
    }

    // -----------------------------------------------------------------------
    // TextInput paste event
    // -----------------------------------------------------------------------

    pub fn paste(id: String, text: String) -> Self {
        Self {
            value: Some(Value::String(text)),
            ..Self::bare("paste", id)
        }
    }

    // -----------------------------------------------------------------------
    // ComboBox option hovered event
    // -----------------------------------------------------------------------

    pub fn option_hovered(id: String, value: String) -> Self {
        Self {
            value: Some(Value::String(value)),
            ..Self::bare("option_hovered", id)
        }
    }

    // -----------------------------------------------------------------------
    // Scrollable events
    // -----------------------------------------------------------------------

    #[allow(clippy::too_many_arguments)]
    pub fn scroll(
        id: String,
        abs_x: f32,
        abs_y: f32,
        rel_x: f32,
        rel_y: f32,
        bounds_w: f32,
        bounds_h: f32,
        content_w: f32,
        content_h: f32,
    ) -> Self {
        Self {
            data: Some(serde_json::json!({
                "absolute_x": abs_x, "absolute_y": abs_y,
                "relative_x": rel_x, "relative_y": rel_y,
                "bounds_width": bounds_w, "bounds_height": bounds_h,
                "content_width": content_w, "content_height": content_h,
            })),
            ..Self::bare("scroll", id)
        }
    }
}

// ---------------------------------------------------------------------------
// Binary field deserialization (handles both raw bytes and base64 strings)
// ---------------------------------------------------------------------------

/// Deserializes a binary field that may arrive as:
/// - Raw bytes (msgpack binary type, via rmpv path)
/// - Base64-encoded string (JSON path)
/// - null / absent (returns None)
///
/// When the codec's rmpv-based decode extracts binary fields and injects them
/// as `serde_json::Value::Array` of u8 values, serde picks them up as Vec<u8>.
/// When the field arrives as a base64 string (JSON mode), we decode it here.
fn deserialize_binary_field<'de, D>(deserializer: D) -> Result<Option<Vec<u8>>, D::Error>
where
    D: Deserializer<'de>,
{
    use serde::de::Error;

    let val: Option<Value> = Option::deserialize(deserializer)?;
    match val {
        None => Ok(None),
        Some(Value::Null) => Ok(None),
        // Base64 string (JSON mode)
        Some(Value::String(s)) => {
            use base64::Engine as _;
            base64::engine::general_purpose::STANDARD
                .decode(&s)
                .map(Some)
                .map_err(|e| D::Error::custom(format!("base64 decode: {e}")))
        }
        // Array of u8 values (injected by rmpv binary extraction)
        Some(Value::Array(arr)) => {
            let bytes: Result<Vec<u8>, _> = arr
                .into_iter()
                .map(|v| {
                    v.as_u64()
                        .and_then(|n| u8::try_from(n).ok())
                        .ok_or_else(|| D::Error::custom("expected u8 in binary array"))
                })
                .collect();
            bytes.map(Some)
        }
        Some(other) => Err(D::Error::custom(format!(
            "expected string, array, or null for binary field, got {other}"
        ))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    // -----------------------------------------------------------------------
    // IncomingMessage deserialization
    // -----------------------------------------------------------------------

    #[test]
    fn deserialize_snapshot() {
        let json =
            r#"{"type":"snapshot","tree":{"id":"root","type":"column","props":{},"children":[]}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::Snapshot { tree } => {
                assert_eq!(tree.id, "root");
                assert_eq!(tree.type_name, "column");
            }
            _ => panic!("expected Snapshot"),
        }
    }

    #[test]
    fn deserialize_snapshot_nested_tree() {
        let json = r#"{"type":"snapshot","tree":{"id":"root","type":"column","props":{"spacing":10},"children":[{"id":"c1","type":"text","props":{"content":"hello"},"children":[]}]}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::Snapshot { tree } => {
                assert_eq!(tree.children.len(), 1);
                assert_eq!(tree.children[0].id, "c1");
                assert_eq!(tree.children[0].type_name, "text");
                assert_eq!(tree.props["spacing"], 10);
            }
            _ => panic!("expected Snapshot"),
        }
    }

    #[test]
    fn deserialize_patch_replace_node() {
        let json = r#"{"type":"patch","ops":[{"op":"replace_node","path":[0],"node":{"id":"x","type":"text","props":{},"children":[]}}]}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::Patch { ops } => {
                assert_eq!(ops.len(), 1);
                assert_eq!(ops[0].op, "replace_node");
                assert_eq!(ops[0].path, vec![0]);
                assert!(ops[0].rest.get("node").is_some());
            }
            _ => panic!("expected Patch"),
        }
    }

    #[test]
    fn deserialize_patch_multiple_ops() {
        let json = r#"{"type":"patch","ops":[{"op":"update_props","path":[0],"props":{"color":"red"}},{"op":"remove_child","path":[],"index":2}]}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::Patch { ops } => {
                assert_eq!(ops.len(), 2);
                assert_eq!(ops[0].op, "update_props");
                assert_eq!(ops[1].op, "remove_child");
            }
            _ => panic!("expected Patch"),
        }
    }

    #[test]
    fn deserialize_effect_request() {
        let json = r#"{"type":"effect_request","id":"e1","kind":"clipboard_read","payload":{}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::EffectRequest { id, kind, payload } => {
                assert_eq!(id, "e1");
                assert_eq!(kind, "clipboard_read");
                assert!(payload.is_object());
            }
            _ => panic!("expected EffectRequest"),
        }
    }

    #[test]
    fn deserialize_effect_request_with_payload() {
        let json = r#"{"type":"effect_request","id":"e2","kind":"clipboard_write","payload":{"text":"copied"}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::EffectRequest { id, kind, payload } => {
                assert_eq!(id, "e2");
                assert_eq!(kind, "clipboard_write");
                assert_eq!(payload["text"], "copied");
            }
            _ => panic!("expected EffectRequest"),
        }
    }

    #[test]
    fn deserialize_widget_op() {
        let json = r#"{"type":"widget_op","op":"focus","payload":{"target":"input1"}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::WidgetOp { op, payload } => {
                assert_eq!(op, "focus");
                assert_eq!(payload["target"], "input1");
            }
            _ => panic!("expected WidgetOp"),
        }
    }

    #[test]
    fn deserialize_widget_op_no_payload() {
        let json = r#"{"type":"widget_op","op":"blur"}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::WidgetOp { op, payload } => {
                assert_eq!(op, "blur");
                assert!(payload.is_null());
            }
            _ => panic!("expected WidgetOp"),
        }
    }

    #[test]
    fn deserialize_subscription_register() {
        let json = r#"{"type":"subscription_register","kind":"on_key_press","tag":"keys"}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::SubscriptionRegister { kind, tag } => {
                assert_eq!(kind, "on_key_press");
                assert_eq!(tag, "keys");
            }
            _ => panic!("expected SubscriptionRegister"),
        }
    }

    #[test]
    fn deserialize_subscription_unregister() {
        let json = r#"{"type":"subscription_unregister","kind":"on_key_press"}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::SubscriptionUnregister { kind } => {
                assert_eq!(kind, "on_key_press");
            }
            _ => panic!("expected SubscriptionUnregister"),
        }
    }

    #[test]
    fn deserialize_settings() {
        let json = r#"{"type":"settings","settings":{"default_text_size":18}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::Settings { settings } => {
                assert_eq!(settings["default_text_size"], 18);
            }
            _ => panic!("expected Settings"),
        }
    }

    #[test]
    fn deserialize_window_op() {
        let json = r#"{"type":"window_op","op":"resize","window_id":"main","settings":{"width":800,"height":600}}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::WindowOp {
                op,
                window_id,
                settings,
            } => {
                assert_eq!(op, "resize");
                assert_eq!(window_id, "main");
                assert_eq!(settings["width"], 800);
                assert_eq!(settings["height"], 600);
            }
            _ => panic!("expected WindowOp"),
        }
    }

    #[test]
    fn deserialize_window_op_no_settings() {
        let json = r#"{"type":"window_op","op":"close","window_id":"popup"}"#;
        let msg: IncomingMessage = serde_json::from_str(json).unwrap();
        match msg {
            IncomingMessage::WindowOp {
                op,
                window_id,
                settings,
            } => {
                assert_eq!(op, "close");
                assert_eq!(window_id, "popup");
                assert!(settings.is_null());
            }
            _ => panic!("expected WindowOp"),
        }
    }

    #[test]
    fn deserialize_malformed_json_missing_field() {
        let json = r#"{"type":"snapshot"}"#;
        let result = serde_json::from_str::<IncomingMessage>(json);
        assert!(result.is_err());
    }

    #[test]
    fn deserialize_unknown_type_tag() {
        let json = r#"{"type":"bogus_message","data":42}"#;
        let result = serde_json::from_str::<IncomingMessage>(json);
        assert!(result.is_err());
    }

    #[test]
    fn deserialize_invalid_json_syntax() {
        let json = r#"{"type":"snapshot",,,}"#;
        let result = serde_json::from_str::<IncomingMessage>(json);
        assert!(result.is_err());
    }

    // -----------------------------------------------------------------------
    // TreeNode deserialization
    // -----------------------------------------------------------------------

    #[test]
    fn tree_node_full() {
        let json = r#"{"id":"root","type":"column","props":{"spacing":10},"children":[{"id":"c1","type":"text","props":{"content":"hi"},"children":[]}]}"#;
        let node: TreeNode = serde_json::from_str(json).unwrap();
        assert_eq!(node.id, "root");
        assert_eq!(node.type_name, "column");
        assert_eq!(node.children.len(), 1);
        assert_eq!(node.children[0].id, "c1");
        assert_eq!(node.props["spacing"], 10);
    }

    #[test]
    fn tree_node_defaults_props_and_children() {
        let json = r#"{"id":"x","type":"text"}"#;
        let node: TreeNode = serde_json::from_str(json).unwrap();
        assert_eq!(node.id, "x");
        assert_eq!(node.type_name, "text");
        assert!(node.children.is_empty());
    }

    #[test]
    fn tree_node_deeply_nested() {
        let json = r#"{"id":"a","type":"column","children":[{"id":"b","type":"row","children":[{"id":"c","type":"text"}]}]}"#;
        let node: TreeNode = serde_json::from_str(json).unwrap();
        assert_eq!(node.children[0].children[0].id, "c");
    }

    // -----------------------------------------------------------------------
    // PatchOp deserialization
    // -----------------------------------------------------------------------

    #[test]
    fn patch_op_replace_node() {
        let json = r#"{"op":"replace_node","path":[1,2],"node":{"id":"n","type":"text"}}"#;
        let op: PatchOp = serde_json::from_str(json).unwrap();
        assert_eq!(op.op, "replace_node");
        assert_eq!(op.path, vec![1, 2]);
        assert!(op.rest.get("node").is_some());
    }

    #[test]
    fn patch_op_update_props() {
        let json = r#"{"op":"update_props","path":[0],"props":{"color":"red"}}"#;
        let op: PatchOp = serde_json::from_str(json).unwrap();
        assert_eq!(op.op, "update_props");
        assert_eq!(op.rest["props"]["color"], "red");
    }

    #[test]
    fn patch_op_insert_child() {
        let json =
            r#"{"op":"insert_child","path":[],"index":0,"node":{"id":"new","type":"button"}}"#;
        let op: PatchOp = serde_json::from_str(json).unwrap();
        assert_eq!(op.op, "insert_child");
        assert!(op.path.is_empty());
        assert_eq!(op.rest["index"], 0);
    }

    #[test]
    fn patch_op_remove_child() {
        let json = r#"{"op":"remove_child","path":[0],"index":1}"#;
        let op: PatchOp = serde_json::from_str(json).unwrap();
        assert_eq!(op.op, "remove_child");
        assert_eq!(op.rest["index"], 1);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- widget events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_click_event() {
        let evt = OutgoingEvent::click("btn1".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["type"], "event");
        assert_eq!(json["family"], "click");
        assert_eq!(json["id"], "btn1");
        assert!(json.get("value").is_none());
        assert!(json.get("tag").is_none());
        assert!(json.get("modifiers").is_none());
    }

    #[test]
    fn serialize_input_event() {
        let evt = OutgoingEvent::input("inp1".to_string(), "hello".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "input");
        assert_eq!(json["id"], "inp1");
        assert_eq!(json["value"], "hello");
    }

    #[test]
    fn serialize_submit_event() {
        let evt = OutgoingEvent::submit("form1".to_string(), "data".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "submit");
        assert_eq!(json["value"], "data");
    }

    #[test]
    fn serialize_toggle_event_true() {
        let evt = OutgoingEvent::toggle("chk1".to_string(), true);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "toggle");
        assert_eq!(json["value"], true);
    }

    #[test]
    fn serialize_toggle_event_false() {
        let evt = OutgoingEvent::toggle("chk1".to_string(), false);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["value"], false);
    }

    #[test]
    fn serialize_slide_event() {
        let evt = OutgoingEvent::slide("slider1".to_string(), 0.75);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "slide");
        assert_eq!(json["value"], 0.75);
    }

    #[test]
    fn serialize_slide_release_event() {
        let evt = OutgoingEvent::slide_release("slider1".to_string(), 0.5);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "slide_release");
        assert_eq!(json["value"], 0.5);
    }

    #[test]
    fn serialize_select_event() {
        let evt = OutgoingEvent::select("picker1".to_string(), "option_b".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "select");
        assert_eq!(json["value"], "option_b");
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- keyboard events
    // -----------------------------------------------------------------------

    fn make_key_event_data(key_str: &str, shift: bool, alt: bool) -> crate::KeyEventData {
        use iced::keyboard;
        crate::KeyEventData {
            key: if key_str.len() == 1 {
                keyboard::Key::Character(key_str.into())
            } else {
                keyboard::Key::Named(keyboard::key::Named::Escape)
            },
            modified_key: if key_str.len() == 1 {
                keyboard::Key::Character(key_str.to_uppercase().into())
            } else {
                keyboard::Key::Named(keyboard::key::Named::Escape)
            },
            physical_key: keyboard::key::Physical::Code(keyboard::key::Code::KeyA),
            location: keyboard::Location::Standard,
            modifiers: {
                let mut m = keyboard::Modifiers::empty();
                if shift {
                    m = m | keyboard::Modifiers::SHIFT;
                }
                if alt {
                    m = m | keyboard::Modifiers::ALT;
                }
                m
            },
            text: if key_str.len() == 1 {
                Some(key_str.to_string())
            } else {
                None
            },
            repeat: false,
        }
    }

    #[test]
    fn serialize_key_press_with_modifiers() {
        let data = make_key_event_data("a", true, true);
        let evt = OutgoingEvent::key_press("keys".to_string(), &data);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "key_press");
        assert_eq!(json["tag"], "keys");
        assert_eq!(json["value"], "a");
        assert!(json["id"].as_str().unwrap().is_empty());
        assert_eq!(json["modifiers"]["shift"], true);
        assert_eq!(json["modifiers"]["ctrl"], false);
        assert_eq!(json["modifiers"]["alt"], true);
        assert_eq!(json["modifiers"]["logo"], false);
        assert_eq!(json["modifiers"]["command"], false);
        // New fields (nested under "data")
        assert_eq!(json["data"]["modified_key"], "A");
        assert_eq!(json["data"]["physical_key"], "KeyA");
        assert_eq!(json["data"]["location"], "standard");
        assert_eq!(json["data"]["text"], "a");
        assert_eq!(json["data"]["repeat"], false);
    }

    #[test]
    fn serialize_key_release() {
        let data = make_key_event_data("Escape", false, false);
        let evt = OutgoingEvent::key_release("keys".to_string(), &data);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "key_release");
        assert_eq!(json["value"], "Escape");
        // key_release should not have text or repeat
        assert!(json.get("text").is_none() || json["text"].is_null());
    }

    #[test]
    fn serialize_modifiers_changed() {
        let mods = KeyModifiers {
            shift: true,
            ctrl: true,
            alt: false,
            logo: false,
            command: false,
        };
        let evt = OutgoingEvent::modifiers_changed("mods".to_string(), mods);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "modifiers_changed");
        assert!(json.get("value").is_none());
        assert_eq!(json["modifiers"]["shift"], true);
        assert_eq!(json["modifiers"]["ctrl"], true);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- mouse events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_cursor_moved() {
        let evt = OutgoingEvent::cursor_moved("mouse".to_string(), 100.0, 200.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "cursor_moved");
        assert_eq!(json["data"]["x"], 100.0);
        assert_eq!(json["data"]["y"], 200.0);
    }

    #[test]
    fn serialize_cursor_entered() {
        let evt = OutgoingEvent::cursor_entered("mouse".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "cursor_entered");
        assert_eq!(json["tag"], "mouse");
    }

    #[test]
    fn serialize_cursor_left() {
        let evt = OutgoingEvent::cursor_left("mouse".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "cursor_left");
    }

    #[test]
    fn serialize_button_pressed() {
        let evt = OutgoingEvent::button_pressed("mouse".to_string(), "Left".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "button_pressed");
        assert_eq!(json["value"], "Left");
    }

    #[test]
    fn serialize_button_released() {
        let evt = OutgoingEvent::button_released("mouse".to_string(), "Right".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "button_released");
        assert_eq!(json["value"], "Right");
    }

    #[test]
    fn serialize_wheel_scrolled() {
        let evt = OutgoingEvent::wheel_scrolled("mouse".to_string(), 0.0, -3.0, "line");
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "wheel_scrolled");
        assert_eq!(json["data"]["delta_x"], 0.0);
        assert_eq!(json["data"]["delta_y"], -3.0);
        assert_eq!(json["data"]["unit"], "line");
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- touch events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_finger_pressed() {
        let evt = OutgoingEvent::finger_pressed("touch".to_string(), 1, 50.0, 75.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "finger_pressed");
        assert_eq!(json["data"]["finger_id"], 1);
        assert_eq!(json["data"]["x"], 50.0);
        assert_eq!(json["data"]["y"], 75.0);
    }

    #[test]
    fn serialize_finger_moved() {
        let evt = OutgoingEvent::finger_moved("touch".to_string(), 2, 60.0, 80.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "finger_moved");
        assert_eq!(json["data"]["finger_id"], 2);
    }

    #[test]
    fn serialize_finger_lifted() {
        let evt = OutgoingEvent::finger_lifted("touch".to_string(), 1, 55.0, 78.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "finger_lifted");
    }

    #[test]
    fn serialize_finger_lost() {
        let evt = OutgoingEvent::finger_lost("touch".to_string(), 3, 0.0, 0.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "finger_lost");
        assert_eq!(json["data"]["finger_id"], 3);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- window lifecycle events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_window_opened_with_position() {
        let evt = OutgoingEvent::window_opened(
            "win_events".to_string(),
            "main".to_string(),
            Some((10.0, 20.0)),
            800.0,
            600.0,
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_opened");
        assert_eq!(json["data"]["window_id"], "main");
        assert_eq!(json["data"]["width"], 800.0);
        assert_eq!(json["data"]["height"], 600.0);
        assert_eq!(json["data"]["position"]["x"], 10.0);
        assert_eq!(json["data"]["position"]["y"], 20.0);
    }

    #[test]
    fn serialize_window_opened_without_position() {
        let evt = OutgoingEvent::window_opened(
            "win_events".to_string(),
            "main".to_string(),
            None,
            1024.0,
            768.0,
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_opened");
        assert!(json["data"]["position"].is_null());
    }

    #[test]
    fn serialize_window_closed() {
        let evt = OutgoingEvent::window_closed("win_events".to_string(), "popup".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_closed");
        assert_eq!(json["data"]["window_id"], "popup");
    }

    #[test]
    fn serialize_window_close_requested() {
        let evt =
            OutgoingEvent::window_close_requested("win_events".to_string(), "main".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_close_requested");
    }

    #[test]
    fn serialize_window_moved() {
        let evt =
            OutgoingEvent::window_moved("win_events".to_string(), "main".to_string(), 50.0, 100.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_moved");
        assert_eq!(json["data"]["x"], 50.0);
        assert_eq!(json["data"]["y"], 100.0);
    }

    #[test]
    fn serialize_window_resized() {
        let evt = OutgoingEvent::window_resized(
            "win_events".to_string(),
            "main".to_string(),
            1920.0,
            1080.0,
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_resized");
        assert_eq!(json["data"]["width"], 1920.0);
    }

    #[test]
    fn serialize_window_focused() {
        let evt = OutgoingEvent::window_focused("win_events".to_string(), "main".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_focused");
    }

    #[test]
    fn serialize_window_unfocused() {
        let evt = OutgoingEvent::window_unfocused("win_events".to_string(), "main".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_unfocused");
    }

    #[test]
    fn serialize_window_rescaled() {
        let evt = OutgoingEvent::window_rescaled("win_events".to_string(), "main".to_string(), 2.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "window_rescaled");
        assert_eq!(json["data"]["scale_factor"], 2.0);
    }

    #[test]
    fn serialize_file_hovered() {
        let evt = OutgoingEvent::file_hovered(
            "win_events".to_string(),
            "main".to_string(),
            "/tmp/a.txt".to_string(),
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "file_hovered");
        assert_eq!(json["data"]["path"], "/tmp/a.txt");
    }

    #[test]
    fn serialize_file_dropped() {
        let evt = OutgoingEvent::file_dropped(
            "win_events".to_string(),
            "main".to_string(),
            "/tmp/b.txt".to_string(),
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "file_dropped");
        assert_eq!(json["data"]["path"], "/tmp/b.txt");
    }

    #[test]
    fn serialize_files_hovered_left() {
        let evt = OutgoingEvent::files_hovered_left("win_events".to_string(), "main".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "files_hovered_left");
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- sensor events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_sensor_resize() {
        let evt = OutgoingEvent::sensor_resize("s1".to_string(), 100.0, 200.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "sensor_resize");
        assert_eq!(json["id"], "s1");
        assert_eq!(json["data"]["width"], 100.0);
        assert_eq!(json["data"]["height"], 200.0);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- canvas events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_canvas_press() {
        let evt = OutgoingEvent::canvas_press("c1".to_string(), 10.0, 20.0, "Left".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "canvas_press");
        assert_eq!(json["data"]["x"], 10.0);
        assert_eq!(json["data"]["button"], "Left");
    }

    #[test]
    fn serialize_canvas_release() {
        let evt = OutgoingEvent::canvas_release("c1".to_string(), 10.0, 20.0, "Left".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "canvas_release");
    }

    #[test]
    fn serialize_canvas_move() {
        let evt = OutgoingEvent::canvas_move("c1".to_string(), 30.0, 40.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "canvas_move");
        assert_eq!(json["data"]["x"], 30.0);
        assert_eq!(json["data"]["y"], 40.0);
    }

    #[test]
    fn serialize_canvas_scroll() {
        let evt = OutgoingEvent::canvas_scroll("c1".to_string(), 5.0, 5.0, 0.0, -1.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "canvas_scroll");
        assert_eq!(json["data"]["delta_y"], -1.0);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- mouse area events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_mouse_right_press() {
        let evt = OutgoingEvent::mouse_right_press("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_right_press");
        assert_eq!(json["id"], "zone");
    }

    #[test]
    fn serialize_mouse_right_release() {
        let evt = OutgoingEvent::mouse_right_release("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_right_release");
    }

    #[test]
    fn serialize_mouse_middle_release() {
        let evt = OutgoingEvent::mouse_middle_release("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_middle_release");
    }

    #[test]
    fn serialize_mouse_double_click() {
        let evt = OutgoingEvent::mouse_double_click("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_double_click");
    }

    #[test]
    fn serialize_mouse_enter() {
        let evt = OutgoingEvent::mouse_enter("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_enter");
    }

    #[test]
    fn serialize_mouse_exit() {
        let evt = OutgoingEvent::mouse_exit("zone".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_exit");
    }

    #[test]
    fn serialize_mouse_area_move() {
        let evt = OutgoingEvent::mouse_area_move("zone".to_string(), 10.5, 20.3);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_move");
        assert_eq!(json["id"], "zone");
        let data = &json["data"];
        assert!((data["x"].as_f64().unwrap() - 10.5).abs() < 0.01);
        assert!((data["y"].as_f64().unwrap() - 20.3).abs() < 0.01);
    }

    #[test]
    fn serialize_mouse_area_scroll() {
        let evt = OutgoingEvent::mouse_area_scroll("zone".to_string(), 0.0, -3.0);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "mouse_scroll");
        assert_eq!(json["id"], "zone");
        assert_eq!(json["data"]["delta_x"], 0.0);
        assert_eq!(json["data"]["delta_y"], -3.0);
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- pane grid events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_pane_resized() {
        let evt = OutgoingEvent::pane_resized("pg1".to_string(), "split_0".to_string(), 0.5);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "pane_resized");
        assert_eq!(json["data"]["split"], "split_0");
        assert_eq!(json["data"]["ratio"], json!(0.5));
    }

    #[test]
    fn serialize_pane_dragged() {
        let evt = OutgoingEvent::pane_dragged(
            "pg1".to_string(),
            "pane_a".to_string(),
            "pane_b".to_string(),
        );
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "pane_dragged");
        assert_eq!(json["data"]["pane"], "pane_a");
        assert_eq!(json["data"]["target"], "pane_b");
    }

    #[test]
    fn serialize_pane_clicked() {
        let evt = OutgoingEvent::pane_clicked("pg1".to_string(), "pane_x".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "pane_clicked");
        assert_eq!(json["data"]["pane"], "pane_x");
    }

    // -----------------------------------------------------------------------
    // OutgoingEvent serialization -- animation/theme events
    // -----------------------------------------------------------------------

    #[test]
    fn serialize_animation_frame() {
        let evt = OutgoingEvent::animation_frame("anim".to_string(), 16000);
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "animation_frame");
        assert_eq!(json["data"]["timestamp"], 16000);
    }

    #[test]
    fn serialize_theme_changed() {
        let evt = OutgoingEvent::theme_changed("theme".to_string(), "dark".to_string());
        let json = serde_json::to_value(&evt).unwrap();
        assert_eq!(json["family"], "theme_changed");
        assert_eq!(json["value"], "dark");
    }

    // -----------------------------------------------------------------------
    // EffectResponse serialization
    // -----------------------------------------------------------------------

    #[test]
    fn effect_response_ok() {
        let resp = EffectResponse::ok("e1".to_string(), json!("clipboard content"));
        let json = serde_json::to_value(&resp).unwrap();
        assert_eq!(json["type"], "effect_response");
        assert_eq!(json["id"], "e1");
        assert_eq!(json["status"], "ok");
        assert_eq!(json["result"], "clipboard content");
        assert!(json.get("error").is_none());
    }

    #[test]
    fn effect_response_error() {
        let resp = EffectResponse::error("e2".to_string(), "not found".to_string());
        let json = serde_json::to_value(&resp).unwrap();
        assert_eq!(json["type"], "effect_response");
        assert_eq!(json["id"], "e2");
        assert_eq!(json["status"], "error");
        assert_eq!(json["error"], "not found");
        assert!(json.get("result").is_none());
    }

    #[test]
    fn effect_response_unsupported() {
        let resp = EffectResponse::unsupported("e3".to_string());
        let json = serde_json::to_value(&resp).unwrap();
        assert_eq!(json["status"], "error");
        assert_eq!(json["error"], "unsupported");
    }

    #[test]
    fn effect_response_ok_with_object_result() {
        let resp = EffectResponse::ok("e4".to_string(), json!({"files": ["/a.txt", "/b.txt"]}));
        let json = serde_json::to_value(&resp).unwrap();
        assert_eq!(json["result"]["files"][0], "/a.txt");
        assert_eq!(json["result"]["files"][1], "/b.txt");
    }

    // -----------------------------------------------------------------------
    // Round-trip: serialize then deserialize OutgoingEvent as generic Value
    // -----------------------------------------------------------------------

    #[test]
    fn outgoing_event_roundtrip_all_fields_present() {
        let data = make_key_event_data("a", true, false);
        let evt = OutgoingEvent::key_press("kb".to_string(), &data);
        let serialized = serde_json::to_string(&evt).unwrap();
        let parsed: Value = serde_json::from_str(&serialized).unwrap();
        assert_eq!(parsed["type"], "event");
        assert_eq!(parsed["family"], "key_press");
        assert_eq!(parsed["value"], "a");
        assert_eq!(parsed["tag"], "kb");
        assert_eq!(parsed["modifiers"]["shift"], true);
        // Extra fields from KeyEventData (nested under "data")
        assert!(parsed["data"].get("modified_key").is_some());
        assert!(parsed["data"].get("physical_key").is_some());
        assert!(parsed["data"].get("location").is_some());
    }

    #[test]
    fn outgoing_event_bare_omits_optional_fields() {
        let evt = OutgoingEvent::click("b".to_string());
        let serialized = serde_json::to_string(&evt).unwrap();
        // value, tag, modifiers should all be absent from the JSON string
        assert!(!serialized.contains("\"value\""));
        assert!(!serialized.contains("\"tag\""));
        assert!(!serialized.contains("\"modifiers\""));
    }
}
