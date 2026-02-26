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

/// A single patch operation (Phase 0: snapshot-only; ops parsed but not applied).
// Fields are unused in Phase 0 -- patches are logged and dropped.
#[allow(dead_code)]
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
}

impl OutgoingEvent {
    pub fn click(id: String) -> Self {
        Self {
            message_type: "event",
            family: "click",
            id,
        }
    }
}
