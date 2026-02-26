use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Messages sent from Elixir to the renderer over stdin (JSONL).
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum IncomingMessage {
    Snapshot { tree: TreeNode },
    Patch { ops: Vec<PatchOp> },
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

/// A single node in the UI tree.
#[derive(Debug, Clone, Deserialize)]
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
#[derive(Debug, Clone, Deserialize)]
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
    /// the standard id/value/tag/modifiers shape.  Serialized as a flat
    /// JSON object merged into the event.
    #[serde(flatten, skip_serializing_if = "Option::is_none")]
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

    pub fn key_press(tag: String, key: String, modifiers: KeyModifiers) -> Self {
        Self {
            modifiers: Some(modifiers),
            value: Some(Value::String(key)),
            ..Self::tagged("key_press", tag)
        }
    }

    pub fn key_release(tag: String, key: String, modifiers: KeyModifiers) -> Self {
        Self {
            modifiers: Some(modifiers),
            value: Some(Value::String(key)),
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
}
