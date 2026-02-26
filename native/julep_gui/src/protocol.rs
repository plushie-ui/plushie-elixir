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
}

/// Serializable representation of keyboard modifiers.
#[derive(Debug, Serialize)]
pub struct KeyModifiers {
    pub shift: bool,
    pub ctrl: bool,
    pub alt: bool,
    pub logo: bool,
}

impl OutgoingEvent {
    pub fn click(id: String) -> Self {
        Self {
            message_type: "event",
            family: "click",
            id,
            value: None,
            tag: None,
            modifiers: None,
        }
    }

    pub fn input(id: String, value: String) -> Self {
        Self {
            message_type: "event",
            family: "input",
            id,
            value: Some(Value::String(value)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn submit(id: String, value: String) -> Self {
        Self {
            message_type: "event",
            family: "submit",
            id,
            value: Some(Value::String(value)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn toggle(id: String, checked: bool) -> Self {
        Self {
            message_type: "event",
            family: "toggle",
            id,
            value: Some(Value::Bool(checked)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn slide(id: String, value: f64) -> Self {
        Self {
            message_type: "event",
            family: "slide",
            id,
            value: Some(serde_json::json!(value)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn slide_release(id: String, value: f64) -> Self {
        Self {
            message_type: "event",
            family: "slide_release",
            id,
            value: Some(serde_json::json!(value)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn select(id: String, value: String) -> Self {
        Self {
            message_type: "event",
            family: "select",
            id,
            value: Some(Value::String(value)),
            tag: None,
            modifiers: None,
        }
    }

    pub fn key_press(tag: String, key: String, modifiers: KeyModifiers) -> Self {
        Self {
            message_type: "event",
            family: "key_press",
            id: String::new(),
            value: Some(Value::String(key)),
            tag: Some(tag),
            modifiers: Some(modifiers),
        }
    }

    pub fn key_release(tag: String, key: String, modifiers: KeyModifiers) -> Self {
        Self {
            message_type: "event",
            family: "key_release",
            id: String::new(),
            value: Some(Value::String(key)),
            tag: Some(tag),
            modifiers: Some(modifiers),
        }
    }

    pub fn window_close(tag: String) -> Self {
        Self {
            message_type: "event",
            family: "window_close",
            id: String::new(),
            value: None,
            tag: Some(tag),
            modifiers: None,
        }
    }
}
