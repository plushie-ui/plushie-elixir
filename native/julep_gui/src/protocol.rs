use serde::{Deserialize, Serialize};
use serde_json::Value;

/// Messages sent from Elixir to the renderer over stdin (JSONL).
#[derive(Debug, Clone, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum IncomingMessage {
    Snapshot { tree: TreeNode },
    Patch { ops: Vec<PatchOp> },
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
}

impl OutgoingEvent {
    pub fn click(id: String) -> Self {
        Self {
            message_type: "event",
            family: "click",
            id,
            value: None,
        }
    }

    pub fn input(id: String, value: String) -> Self {
        Self {
            message_type: "event",
            family: "input",
            id,
            value: Some(Value::String(value)),
        }
    }

    pub fn submit(id: String, value: String) -> Self {
        Self {
            message_type: "event",
            family: "submit",
            id,
            value: Some(Value::String(value)),
        }
    }

    pub fn toggle(id: String, checked: bool) -> Self {
        Self {
            message_type: "event",
            family: "toggle",
            id,
            value: Some(Value::Bool(checked)),
        }
    }
}
