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
                log::warn!("failed to apply patch op {:?}: {}", op.op, e);
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
                log::warn!("unknown patch op: {other}");
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::protocol::{PatchOp, TreeNode};
    use serde_json::json;

    fn make_node(id: &str, type_name: &str) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props: json!({}),
            children: vec![],
        }
    }

    fn make_node_with_props(id: &str, type_name: &str, props: serde_json::Value) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props,
            children: vec![],
        }
    }

    fn make_node_with_children(id: &str, type_name: &str, children: Vec<TreeNode>) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props: json!({}),
            children,
        }
    }

    fn make_patch_op(op: &str, path: Vec<usize>, rest: serde_json::Value) -> PatchOp {
        // Deserialize from JSON to get proper PatchOp with flattened rest
        let mut obj = serde_json::Map::new();
        obj.insert("op".to_string(), json!(op));
        obj.insert("path".to_string(), json!(path));
        if let Some(map) = rest.as_object() {
            for (k, v) in map {
                obj.insert(k.clone(), v.clone());
            }
        }
        serde_json::from_value(serde_json::Value::Object(obj)).unwrap()
    }

    // -----------------------------------------------------------------------
    // Tree basics
    // -----------------------------------------------------------------------

    #[test]
    fn new_tree_is_empty() {
        let tree = Tree::new();
        assert!(tree.root().is_none());
    }

    #[test]
    fn default_tree_is_empty() {
        let tree = Tree::default();
        assert!(tree.root().is_none());
    }

    #[test]
    fn snapshot_sets_root() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        assert!(tree.root().is_some());
        assert_eq!(tree.root().unwrap().id, "root");
        assert_eq!(tree.root().unwrap().type_name, "column");
    }

    #[test]
    fn snapshot_replaces_previous_root() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("first", "column"));
        tree.snapshot(make_node("second", "row"));
        assert_eq!(tree.root().unwrap().id, "second");
        assert_eq!(tree.root().unwrap().type_name, "row");
    }

    #[test]
    fn snapshot_preserves_children() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node("a", "text"), make_node("b", "button")],
        );
        tree.snapshot(root);
        assert_eq!(tree.root().unwrap().children.len(), 2);
        assert_eq!(tree.root().unwrap().children[0].id, "a");
        assert_eq!(tree.root().unwrap().children[1].id, "b");
    }

    // -----------------------------------------------------------------------
    // find_window
    // -----------------------------------------------------------------------

    #[test]
    fn find_window_at_root() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("main", "window"));
        let found = tree.find_window("main");
        assert!(found.is_some());
        assert_eq!(found.unwrap().id, "main");
        assert_eq!(found.unwrap().type_name, "window");
    }

    #[test]
    fn find_window_root_wrong_id() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("main", "window"));
        assert!(tree.find_window("other").is_none());
    }

    #[test]
    fn find_window_in_children() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node("win1", "window"), make_node("win2", "window")],
        );
        tree.snapshot(root);
        assert!(tree.find_window("win1").is_some());
        assert!(tree.find_window("win2").is_some());
        assert_eq!(tree.find_window("win1").unwrap().id, "win1");
    }

    #[test]
    fn find_window_not_found() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        assert!(tree.find_window("nope").is_none());
    }

    #[test]
    fn find_window_on_empty_tree() {
        let tree = Tree::new();
        assert!(tree.find_window("anything").is_none());
    }

    #[test]
    fn find_window_ignores_non_window_children() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![
                make_node("btn", "button"),
                make_node("win", "window"),
                make_node("txt", "text"),
            ],
        );
        tree.snapshot(root);
        assert!(tree.find_window("btn").is_none());
        assert!(tree.find_window("txt").is_none());
        assert!(tree.find_window("win").is_some());
    }

    #[test]
    fn find_window_does_not_search_grandchildren() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node_with_children(
                "inner",
                "row",
                vec![make_node("deep_win", "window")],
            )],
        );
        tree.snapshot(root);
        // find_window only searches root and direct children
        assert!(tree.find_window("deep_win").is_none());
    }

    // -----------------------------------------------------------------------
    // window_ids
    // -----------------------------------------------------------------------

    #[test]
    fn window_ids_when_root_is_window() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("main", "window"));
        let ids = tree.window_ids();
        assert_eq!(ids, vec!["main".to_string()]);
    }

    #[test]
    fn window_ids_collects_child_windows() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![
                make_node("w1", "window"),
                make_node("w2", "window"),
                make_node("w3", "window"),
            ],
        );
        tree.snapshot(root);
        let ids = tree.window_ids();
        assert_eq!(ids.len(), 3);
        assert!(ids.contains(&"w1".to_string()));
        assert!(ids.contains(&"w2".to_string()));
        assert!(ids.contains(&"w3".to_string()));
    }

    #[test]
    fn window_ids_skips_non_windows() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![
                make_node("w1", "window"),
                make_node("btn", "button"),
                make_node("w2", "window"),
            ],
        );
        tree.snapshot(root);
        let ids = tree.window_ids();
        assert_eq!(ids.len(), 2);
        assert!(!ids.contains(&"btn".to_string()));
    }

    #[test]
    fn window_ids_empty_when_no_windows() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        assert!(tree.window_ids().is_empty());
    }

    #[test]
    fn window_ids_empty_on_empty_tree() {
        let tree = Tree::new();
        assert!(tree.window_ids().is_empty());
    }

    // -----------------------------------------------------------------------
    // apply_patch -- replace_node
    // -----------------------------------------------------------------------

    #[test]
    fn patch_replace_root() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("old", "column"));
        let op = make_patch_op(
            "replace_node",
            vec![],
            json!({
                "node": {"id": "new", "type": "row", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().id, "new");
        assert_eq!(tree.root().unwrap().type_name, "row");
    }

    #[test]
    fn patch_replace_child() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node("a", "text"), make_node("b", "button")],
        );
        tree.snapshot(root);
        let op = make_patch_op(
            "replace_node",
            vec![1],
            json!({
                "node": {"id": "c", "type": "text", "props": {"content": "replaced"}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children[1].id, "c");
        assert_eq!(
            tree.root().unwrap().children[1].props["content"],
            "replaced"
        );
    }

    #[test]
    fn patch_replace_nested_child() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node_with_children(
                "row",
                "row",
                vec![make_node("inner", "text")],
            )],
        );
        tree.snapshot(root);
        let op = make_patch_op(
            "replace_node",
            vec![0, 0],
            json!({
                "node": {"id": "replaced", "type": "button", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children[0].children[0].id, "replaced");
        assert_eq!(
            tree.root().unwrap().children[0].children[0].type_name,
            "button"
        );
    }

    #[test]
    fn patch_replace_out_of_bounds_does_not_panic() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        let op = make_patch_op(
            "replace_node",
            vec![5],
            json!({
                "node": {"id": "x", "type": "text", "props": {}, "children": []}
            }),
        );
        // Should print an error to stderr but not panic
        tree.apply_patch(vec![op]);
        // Root is unchanged
        assert_eq!(tree.root().unwrap().id, "root");
    }

    // -----------------------------------------------------------------------
    // apply_patch -- update_props
    // -----------------------------------------------------------------------

    #[test]
    fn patch_update_props_on_root() {
        let mut tree = Tree::new();
        tree.snapshot(make_node_with_props(
            "root",
            "column",
            json!({"spacing": 5}),
        ));
        let op = make_patch_op(
            "update_props",
            vec![],
            json!({
                "props": {"spacing": 10, "padding": 20}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().props["spacing"], 10);
        assert_eq!(tree.root().unwrap().props["padding"], 20);
    }

    #[test]
    fn patch_update_props_removes_null_keys() {
        let mut tree = Tree::new();
        tree.snapshot(make_node_with_props(
            "root",
            "text",
            json!({"content": "hi", "size": 14}),
        ));
        let op = make_patch_op(
            "update_props",
            vec![],
            json!({
                "props": {"size": null}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().props["content"], "hi");
        assert!(tree.root().unwrap().props.get("size").is_none());
    }

    #[test]
    fn patch_update_props_on_child() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node_with_props(
                "txt",
                "text",
                json!({"content": "old"}),
            )],
        );
        tree.snapshot(root);
        let op = make_patch_op(
            "update_props",
            vec![0],
            json!({
                "props": {"content": "new"}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children[0].props["content"], "new");
    }

    // -----------------------------------------------------------------------
    // apply_patch -- insert_child
    // -----------------------------------------------------------------------

    #[test]
    fn patch_insert_child_at_beginning() {
        let mut tree = Tree::new();
        let root = make_node_with_children("root", "column", vec![make_node("a", "text")]);
        tree.snapshot(root);
        let op = make_patch_op(
            "insert_child",
            vec![],
            json!({
                "index": 0,
                "node": {"id": "b", "type": "button", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 2);
        assert_eq!(tree.root().unwrap().children[0].id, "b");
        assert_eq!(tree.root().unwrap().children[1].id, "a");
    }

    #[test]
    fn patch_insert_child_at_end() {
        let mut tree = Tree::new();
        let root = make_node_with_children("root", "column", vec![make_node("a", "text")]);
        tree.snapshot(root);
        let op = make_patch_op(
            "insert_child",
            vec![],
            json!({
                "index": 1,
                "node": {"id": "b", "type": "button", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 2);
        assert_eq!(tree.root().unwrap().children[1].id, "b");
    }

    #[test]
    fn patch_insert_child_beyond_length_appends() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        let op = make_patch_op(
            "insert_child",
            vec![],
            json!({
                "index": 99,
                "node": {"id": "x", "type": "text", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 1);
        assert_eq!(tree.root().unwrap().children[0].id, "x");
    }

    #[test]
    fn patch_insert_child_into_nested_parent() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node_with_children(
                "row",
                "row",
                vec![make_node("existing", "text")],
            )],
        );
        tree.snapshot(root);
        let op = make_patch_op(
            "insert_child",
            vec![0],
            json!({
                "index": 0,
                "node": {"id": "new", "type": "button", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        let row = &tree.root().unwrap().children[0];
        assert_eq!(row.children.len(), 2);
        assert_eq!(row.children[0].id, "new");
        assert_eq!(row.children[1].id, "existing");
    }

    // -----------------------------------------------------------------------
    // apply_patch -- remove_child
    // -----------------------------------------------------------------------

    #[test]
    fn patch_remove_child() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![
                make_node("a", "text"),
                make_node("b", "button"),
                make_node("c", "text"),
            ],
        );
        tree.snapshot(root);
        let op = make_patch_op("remove_child", vec![], json!({"index": 1}));
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 2);
        assert_eq!(tree.root().unwrap().children[0].id, "a");
        assert_eq!(tree.root().unwrap().children[1].id, "c");
    }

    #[test]
    fn patch_remove_child_first() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node("a", "text"), make_node("b", "button")],
        );
        tree.snapshot(root);
        let op = make_patch_op("remove_child", vec![], json!({"index": 0}));
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 1);
        assert_eq!(tree.root().unwrap().children[0].id, "b");
    }

    #[test]
    fn patch_remove_child_last() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node("a", "text"), make_node("b", "button")],
        );
        tree.snapshot(root);
        let op = make_patch_op("remove_child", vec![], json!({"index": 1}));
        tree.apply_patch(vec![op]);
        assert_eq!(tree.root().unwrap().children.len(), 1);
        assert_eq!(tree.root().unwrap().children[0].id, "a");
    }

    #[test]
    fn patch_remove_child_out_of_bounds_does_not_panic() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        let op = make_patch_op("remove_child", vec![], json!({"index": 0}));
        // Should log error, not panic
        tree.apply_patch(vec![op]);
        assert!(tree.root().unwrap().children.is_empty());
    }

    // -----------------------------------------------------------------------
    // apply_patch -- unknown op
    // -----------------------------------------------------------------------

    #[test]
    fn patch_unknown_op_does_not_panic() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        let op = make_patch_op("frobnicate", vec![], json!({}));
        tree.apply_patch(vec![op]);
        // Tree should be unchanged
        assert_eq!(tree.root().unwrap().id, "root");
    }

    // -----------------------------------------------------------------------
    // apply_patch -- multiple ops in sequence
    // -----------------------------------------------------------------------

    #[test]
    fn patch_multiple_ops_applied_in_order() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));

        let ops = vec![
            make_patch_op(
                "insert_child",
                vec![],
                json!({
                    "index": 0,
                    "node": {"id": "a", "type": "text", "props": {}, "children": []}
                }),
            ),
            make_patch_op(
                "insert_child",
                vec![],
                json!({
                    "index": 1,
                    "node": {"id": "b", "type": "text", "props": {}, "children": []}
                }),
            ),
            make_patch_op(
                "insert_child",
                vec![],
                json!({
                    "index": 1,
                    "node": {"id": "c", "type": "text", "props": {}, "children": []}
                }),
            ),
        ];
        tree.apply_patch(ops);
        let children = &tree.root().unwrap().children;
        assert_eq!(children.len(), 3);
        assert_eq!(children[0].id, "a");
        assert_eq!(children[1].id, "c");
        assert_eq!(children[2].id, "b");
    }

    // -----------------------------------------------------------------------
    // apply_patch on empty tree
    // -----------------------------------------------------------------------

    #[test]
    fn patch_on_empty_tree_does_not_panic() {
        let mut tree = Tree::new();
        let op = make_patch_op(
            "replace_node",
            vec![],
            json!({
                "node": {"id": "x", "type": "text", "props": {}, "children": []}
            }),
        );
        tree.apply_patch(vec![op]);
        // Still empty -- the op should fail gracefully
        assert!(tree.root().is_none());
    }

    // -----------------------------------------------------------------------
    // navigate_mut edge cases (tested indirectly through patch ops)
    // -----------------------------------------------------------------------

    #[test]
    fn patch_deep_path_navigation() {
        let mut tree = Tree::new();
        let root = make_node_with_children(
            "root",
            "column",
            vec![make_node_with_children(
                "r0",
                "row",
                vec![make_node_with_children(
                    "r0c0",
                    "column",
                    vec![make_node("deep", "text")],
                )],
            )],
        );
        tree.snapshot(root);
        let op = make_patch_op(
            "update_props",
            vec![0, 0, 0],
            json!({
                "props": {"content": "updated deep"}
            }),
        );
        tree.apply_patch(vec![op]);
        let deep = &tree.root().unwrap().children[0].children[0].children[0];
        assert_eq!(deep.props["content"], "updated deep");
    }

    #[test]
    fn patch_invalid_path_does_not_panic() {
        let mut tree = Tree::new();
        tree.snapshot(make_node("root", "column"));
        let op = make_patch_op(
            "update_props",
            vec![0, 1, 2],
            json!({
                "props": {"x": 1}
            }),
        );
        tree.apply_patch(vec![op]);
        // Root unchanged
        assert_eq!(tree.root().unwrap().id, "root");
    }
}
