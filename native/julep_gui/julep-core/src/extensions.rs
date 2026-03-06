use std::any::Any;
use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};

use iced::{Element, Theme};
use log;
use serde_json::Value;

use crate::image_registry::ImageRegistry;
use crate::message::Message;
use crate::protocol::{OutgoingEvent, TreeNode};
use crate::widgets::WidgetCaches;

// ---------------------------------------------------------------------------
// WidgetExtension trait
// ---------------------------------------------------------------------------

/// Trait for native Rust widget extensions.
///
/// Extensions handle custom node types that the built-in renderer doesn't
/// know about. The trait scales from trivial render-only widgets (implement
/// `type_names`, `config_key`, `render`) to full custom iced Widgets with
/// autonomous state (implement all methods).
pub trait WidgetExtension: Send + Sync + 'static {
    /// Node type names this extension handles (e.g. ["sparkline", "heatmap"]).
    fn type_names(&self) -> &[&str];

    /// Key used to route configuration from the Settings wire message's
    /// `extension_config` object. Must be unique across all extensions.
    fn config_key(&self) -> &str;

    /// Receive configuration from Elixir. Called on startup and renderer
    /// restart. Receives `Value::Null` if no config provided.
    fn init(&mut self, _config: &Value) {}

    /// Initialize or synchronize state for a node. Called in the mutable
    /// phase before view(), every time the tree changes.
    fn prepare(&mut self, _node: &TreeNode, _caches: &mut ExtensionCaches, _theme: &Theme) {}

    /// Build an iced Element for a node. Called in the immutable phase (view).
    fn render<'a>(&self, node: &'a TreeNode, env: &WidgetEnv<'a>) -> Element<'a, Message>;

    /// Handle an event emitted by this extension's widgets. Called before
    /// the event reaches the wire.
    fn handle_event(
        &mut self,
        _node_id: &str,
        _family: &str,
        _data: &Value,
        _caches: &mut ExtensionCaches,
    ) -> EventResult {
        EventResult::PassThrough
    }

    /// Handle a command sent from Elixir directly to this extension.
    fn handle_command(
        &mut self,
        _node_id: &str,
        _op: &str,
        _payload: &Value,
        _caches: &mut ExtensionCaches,
    ) -> Vec<OutgoingEvent> {
        vec![]
    }

    /// Clean up when a node is removed from the tree.
    fn cleanup(&mut self, _node_id: &str, _caches: &mut ExtensionCaches) {}
}

// ---------------------------------------------------------------------------
// EventResult
// ---------------------------------------------------------------------------

/// Result of extension event handling.
pub enum EventResult {
    /// Don't handle -- forward to Elixir as-is.
    PassThrough,
    /// Handled internally. Don't forward original. Optionally emit different events.
    Consumed(Vec<OutgoingEvent>),
    /// Handled internally AND forward original. Additional events also emitted.
    Observed(Vec<OutgoingEvent>),
}

// ---------------------------------------------------------------------------
// ExtensionCaches
// ---------------------------------------------------------------------------

/// Type-erased cache storage for extensions, keyed by node ID.
pub struct ExtensionCaches {
    inner: HashMap<String, Box<dyn Any + Send + Sync>>,
}

impl ExtensionCaches {
    pub fn new() -> Self {
        Self {
            inner: HashMap::new(),
        }
    }

    pub fn get<T: 'static>(&self, key: &str) -> Option<&T> {
        self.inner.get(key)?.downcast_ref()
    }

    pub fn get_mut<T: 'static>(&mut self, key: &str) -> Option<&mut T> {
        self.inner.get_mut(key)?.downcast_mut()
    }

    pub fn get_or_insert<T: Send + Sync + 'static>(
        &mut self,
        key: &str,
        default: impl FnOnce() -> T,
    ) -> &mut T {
        self.inner
            .entry(key.to_string())
            .or_insert_with(|| Box::new(default()))
            .downcast_mut()
            .expect("ExtensionCaches type mismatch")
    }

    pub fn insert<T: Send + Sync + 'static>(&mut self, key: String, value: T) {
        self.inner.insert(key, Box::new(value));
    }

    pub fn remove(&mut self, key: &str) -> bool {
        self.inner.remove(key).is_some()
    }

    pub fn contains(&self, key: &str) -> bool {
        self.inner.contains_key(key)
    }

    pub fn clear(&mut self) {
        self.inner.clear();
    }
}

impl Default for ExtensionCaches {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// WidgetEnv and RenderContext
// ---------------------------------------------------------------------------

/// Environment passed to extension render().
pub struct WidgetEnv<'a> {
    pub caches: &'a WidgetCaches,
    pub extension_caches: &'a ExtensionCaches,
    pub images: &'a ImageRegistry,
    pub theme: &'a Theme,
    pub render_ctx: RenderContext<'a>,
}

/// Renders child nodes through the main dispatch. Copy-able (all shared refs).
#[derive(Clone, Copy)]
pub struct RenderContext<'a> {
    pub(crate) caches: &'a WidgetCaches,
    pub(crate) images: &'a ImageRegistry,
    pub(crate) theme: &'a Theme,
    pub(crate) extensions: &'a ExtensionDispatcher,
}

impl<'a> RenderContext<'a> {
    /// Render a child node through the main dispatch.
    pub fn render_child(&self, node: &'a TreeNode) -> Element<'a, Message> {
        crate::widgets::render(node, self.caches, self.images, self.theme, self.extensions)
    }
}

// ---------------------------------------------------------------------------
// ExtensionDispatcher
// ---------------------------------------------------------------------------

/// Owns extensions and routing state.
pub struct ExtensionDispatcher {
    extensions: Vec<Box<dyn WidgetExtension>>,
    type_name_index: HashMap<String, usize>,
    node_extension_map: HashMap<String, usize>,
    poisoned: Vec<bool>,
}

impl ExtensionDispatcher {
    pub fn new(extensions: Vec<Box<dyn WidgetExtension>>) -> Self {
        let n = extensions.len();
        let mut type_name_index = HashMap::new();
        for (idx, ext) in extensions.iter().enumerate() {
            for &name in ext.type_names() {
                if let Some(prev_idx) = type_name_index.insert(name.to_string(), idx) {
                    panic!(
                        "duplicate extension type name `{name}`: registered by \
                         `{}` and `{}`",
                        extensions[prev_idx].config_key(),
                        ext.config_key(),
                    );
                }
            }
        }
        Self {
            extensions,
            type_name_index,
            node_extension_map: HashMap::new(),
            poisoned: vec![false; n],
        }
    }

    /// Check if a node type is handled by an extension.
    pub fn handles_type(&self, type_name: &str) -> bool {
        self.type_name_index.contains_key(type_name)
    }

    /// Called after Core::apply() on tree changes.
    pub fn prepare_all(&mut self, root: &TreeNode, caches: &mut ExtensionCaches, theme: &Theme) {
        let mut new_map = HashMap::new();
        self.walk_prepare(root, caches, theme, &mut new_map);

        // Prune stale nodes
        for (old_id, ext_idx) in &self.node_extension_map {
            if !new_map.contains_key(old_id) {
                if self.poisoned[*ext_idx] {
                    caches.remove(old_id);
                    log::warn!(
                        "skipping cleanup for poisoned extension `{}`; \
                         cache entry removed for node `{old_id}`",
                        self.extensions[*ext_idx].config_key()
                    );
                } else {
                    let result = catch_unwind(AssertUnwindSafe(|| {
                        self.extensions[*ext_idx].cleanup(old_id, caches);
                    }));
                    if let Err(panic) = result {
                        let msg = panic_message(&panic);
                        log::error!(
                            "extension `{}` panicked in cleanup: {msg}",
                            self.extensions[*ext_idx].config_key()
                        );
                        self.poisoned[*ext_idx] = true;
                        caches.remove(old_id);
                    }
                }
            }
        }

        self.node_extension_map = new_map;
    }

    fn walk_prepare(
        &mut self,
        node: &TreeNode,
        caches: &mut ExtensionCaches,
        theme: &Theme,
        map: &mut HashMap<String, usize>,
    ) {
        if let Some(&idx) = self.type_name_index.get(node.type_name.as_str()) {
            if !self.poisoned[idx] {
                let result = catch_unwind(AssertUnwindSafe(|| {
                    self.extensions[idx].prepare(node, caches, theme);
                }));
                if let Err(panic) = result {
                    let msg = panic_message(&panic);
                    log::error!(
                        "extension `{}` panicked in prepare: {msg}",
                        self.extensions[idx].config_key()
                    );
                    self.poisoned[idx] = true;
                }
            }
            map.insert(node.id.clone(), idx);
        }
        for child in &node.children {
            self.walk_prepare(child, caches, theme, map);
        }
    }

    /// Handle a Message::Event.
    pub fn handle_event(
        &mut self,
        id: &str,
        family: &str,
        data: &Value,
        caches: &mut ExtensionCaches,
    ) -> EventResult {
        let ext_idx = match self.node_extension_map.get(id) {
            Some(&idx) => idx,
            None => return EventResult::PassThrough,
        };
        if self.poisoned[ext_idx] {
            return EventResult::PassThrough;
        }
        match catch_unwind(AssertUnwindSafe(|| {
            self.extensions[ext_idx].handle_event(id, family, data, caches)
        })) {
            Ok(result) => result,
            Err(panic) => {
                let msg = panic_message(&panic);
                log::error!(
                    "extension `{}` panicked in handle_event: {msg}",
                    self.extensions[ext_idx].config_key()
                );
                self.poisoned[ext_idx] = true;
                EventResult::PassThrough
            }
        }
    }

    /// Handle an ExtensionCommand.
    pub fn handle_command(
        &mut self,
        node_id: &str,
        op: &str,
        payload: &Value,
        caches: &mut ExtensionCaches,
    ) -> Vec<OutgoingEvent> {
        let ext_idx = match self.node_extension_map.get(node_id) {
            Some(&idx) => idx,
            None => {
                log::warn!("extension command for unknown node `{node_id}`, ignoring");
                return vec![];
            }
        };
        if self.poisoned[ext_idx] {
            return vec![];
        }
        match catch_unwind(AssertUnwindSafe(|| {
            self.extensions[ext_idx].handle_command(node_id, op, payload, caches)
        })) {
            Ok(events) => events,
            Err(panic) => {
                let msg = panic_message(&panic);
                log::error!(
                    "extension `{}` panicked in handle_command: {msg}",
                    self.extensions[ext_idx].config_key()
                );
                self.poisoned[ext_idx] = true;
                vec![]
            }
        }
    }

    /// Route configuration to extensions.
    pub fn init_all(&mut self, config: &Value) {
        let ext_config = config.get("extension_config").unwrap_or(&Value::Null);
        for (idx, ext) in self.extensions.iter_mut().enumerate() {
            if self.poisoned[idx] {
                continue;
            }
            let slice = ext_config.get(ext.config_key()).unwrap_or(&Value::Null);
            ext.init(slice);
        }
    }

    /// Render an extension node. Returns None if no extension handles this type.
    ///
    /// The caller must construct the `WidgetEnv` and pass it in. This avoids
    /// a borrow-checker issue where a locally-constructed env would be dropped
    /// before the returned Element (which borrows from the env).
    pub fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        env: &WidgetEnv<'a>,
    ) -> Option<Element<'a, Message>> {
        let &idx = self.type_name_index.get(node.type_name.as_str())?;
        if self.poisoned[idx] {
            return Some(render_poisoned_placeholder(node));
        }
        // No catch_unwind here: the returned Element borrows from env, so
        // we can't wrap this in a closure. We also can't poison (only have
        // &self). If an extension panics in render, it propagates --
        // prepare_all will re-evaluate on the next tick.
        let element = self.extensions[idx].render(node, env);
        Some(element)
    }

    /// Reset all poisoned flags. Called on Snapshot.
    pub fn clear_poisoned(&mut self) {
        self.poisoned.fill(false);
    }

    /// Check if any extensions are registered.
    pub fn is_empty(&self) -> bool {
        self.extensions.is_empty()
    }
}

impl Default for ExtensionDispatcher {
    fn default() -> Self {
        Self::new(vec![])
    }
}

fn render_poisoned_placeholder<'a>(node: &TreeNode) -> Element<'a, Message> {
    use iced::widget::text;
    use iced::Color;
    text(format!("Extension error: node `{}`", node.id))
        .color(Color::from_rgb(1.0, 0.0, 0.0))
        .into()
}

fn panic_message(panic: &Box<dyn Any + Send>) -> String {
    if let Some(s) = panic.downcast_ref::<&str>() {
        s.to_string()
    } else if let Some(s) = panic.downcast_ref::<String>() {
        s.clone()
    } else {
        "unknown panic".to_string()
    }
}
