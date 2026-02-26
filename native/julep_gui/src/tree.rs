use crate::protocol::TreeNode;

/// Retained tree store. Holds the current root node (if any) and supports
/// full replacement (snapshot) for Phase 0. Patch support is stubbed.
#[derive(Debug, Default)]
pub struct Tree {
    root: Option<TreeNode>,
}

impl Tree {
    pub fn new() -> Self {
        Self::default()
    }

    /// Replace the entire tree with a new root (snapshot).
    pub fn snapshot(&mut self, root: TreeNode) {
        self.root = Some(root);
    }

    /// Return a reference to the current root, if any.
    pub fn root(&self) -> Option<&TreeNode> {
        self.root.as_ref()
    }
}
