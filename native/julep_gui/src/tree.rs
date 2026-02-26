use crate::protocol::{PatchOp, TreeNode};

/// Retained tree store. Holds the current root node (if any) and supports
/// full replacement (snapshot) and incremental patch application.
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

    /// Find a window node by its julep ID.
    ///
    /// If the root itself is a window with a matching ID, return it.
    /// Otherwise, search the root's direct children for a window node
    /// with the given ID.
    pub fn find_window(&self, julep_id: &str) -> Option<&TreeNode> {
        let root = self.root.as_ref()?;
        if root.type_name == "window" && root.id == julep_id {
            return Some(root);
        }
        root.children
            .iter()
            .find(|child| child.type_name == "window" && child.id == julep_id)
    }

    /// Collect the IDs of all window nodes in the tree.
    ///
    /// If the root is a window, returns just its ID. Otherwise, returns
    /// the IDs of all direct children that are window nodes.
    pub fn window_ids(&self) -> Vec<String> {
        let Some(root) = self.root.as_ref() else {
            return Vec::new();
        };
        if root.type_name == "window" {
            return vec![root.id.clone()];
        }
        root.children
            .iter()
            .filter(|child| child.type_name == "window")
            .map(|child| child.id.clone())
            .collect()
    }

    /// Apply a list of patch operations to the current tree.
    pub fn apply_patch(&mut self, ops: Vec<PatchOp>) {
        for op in ops {
            if let Err(e) = self.apply_op(&op) {
                eprintln!("julep_gui: failed to apply patch op {:?}: {}", op.op, e);
            }
        }
    }

    fn apply_op(&mut self, op: &PatchOp) -> Result<(), String> {
        let root = self.root.as_mut().ok_or("no tree to patch")?;

        match op.op.as_str() {
            "replace_node" => {
                let node = op
                    .rest
                    .get("node")
                    .ok_or("replace_node: missing 'node' field")?;
                let new_node: TreeNode = serde_json::from_value(node.clone())
                    .map_err(|e| format!("replace_node: invalid node: {e}"))?;

                if op.path.is_empty() {
                    // Replace root
                    *root = new_node;
                } else {
                    let parent = navigate_mut(root, &op.path[..op.path.len() - 1])?;
                    let idx = *op.path.last().unwrap();
                    if idx < parent.children.len() {
                        parent.children[idx] = new_node;
                    } else {
                        return Err(format!("replace_node: index {idx} out of bounds"));
                    }
                }
                Ok(())
            }
            "update_props" => {
                let target = navigate_mut(root, &op.path)?;
                let props = op
                    .rest
                    .get("props")
                    .ok_or("update_props: missing 'props' field")?;

                if let (Some(target_map), Some(patch_map)) =
                    (target.props.as_object_mut(), props.as_object())
                {
                    for (k, v) in patch_map {
                        if v.is_null() {
                            target_map.remove(k);
                        } else {
                            target_map.insert(k.clone(), v.clone());
                        }
                    }
                }
                Ok(())
            }
            "insert_child" => {
                let parent = navigate_mut(root, &op.path)?;
                let index = op
                    .rest
                    .get("index")
                    .and_then(|v| v.as_u64())
                    .ok_or("insert_child: missing or invalid 'index'")?
                    as usize;
                let node = op
                    .rest
                    .get("node")
                    .ok_or("insert_child: missing 'node' field")?;
                let new_node: TreeNode = serde_json::from_value(node.clone())
                    .map_err(|e| format!("insert_child: invalid node: {e}"))?;

                if index <= parent.children.len() {
                    parent.children.insert(index, new_node);
                } else {
                    // Append if index is beyond current length
                    parent.children.push(new_node);
                }
                Ok(())
            }
            "remove_child" => {
                let parent = navigate_mut(root, &op.path)?;
                let index = op
                    .rest
                    .get("index")
                    .and_then(|v| v.as_u64())
                    .ok_or("remove_child: missing or invalid 'index'")?
                    as usize;

                if index < parent.children.len() {
                    parent.children.remove(index);
                    Ok(())
                } else {
                    Err(format!(
                        "remove_child: index {index} out of bounds (len={})",
                        parent.children.len()
                    ))
                }
            }
            other => {
                eprintln!("julep_gui: unknown patch op: {other}");
                Ok(())
            }
        }
    }
}

/// Navigate to a node at the given path of child indices.
fn navigate_mut<'a>(root: &'a mut TreeNode, path: &[usize]) -> Result<&'a mut TreeNode, String> {
    let mut current = root;
    for &idx in path {
        if idx < current.children.len() {
            current = &mut current.children[idx];
        } else {
            return Err(format!(
                "path navigation: index {idx} out of bounds (len={})",
                current.children.len()
            ));
        }
    }
    Ok(current)
}
