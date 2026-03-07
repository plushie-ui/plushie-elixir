use std::any::Any;
use std::collections::HashMap;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::atomic::{AtomicU32, Ordering};

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

/// Type-erased cache storage for extensions.
///
/// Keys are namespaced by extension `config_key()` to prevent collisions
/// between extensions that happen to use the same cache key string. All
/// public methods accept a `namespace` parameter (the extension's
/// `config_key()`) which is prefixed onto the raw key internally.
pub struct ExtensionCaches {
    inner: HashMap<String, Box<dyn Any + Send + Sync>>,
}

impl ExtensionCaches {
    pub fn new() -> Self {
        Self {
            inner: HashMap::new(),
        }
    }

    /// Build the internal namespaced key: `"config_key:raw_key"`.
    fn namespaced_key(namespace: &str, key: &str) -> String {
        format!("{namespace}:{key}")
    }

    pub fn get<T: 'static>(&self, namespace: &str, key: &str) -> Option<&T> {
        self.inner
            .get(&Self::namespaced_key(namespace, key))?
            .downcast_ref()
    }

    pub fn get_mut<T: 'static>(&mut self, namespace: &str, key: &str) -> Option<&mut T> {
        self.inner
            .get_mut(&Self::namespaced_key(namespace, key))?
            .downcast_mut()
    }

    pub fn get_or_insert<T: Send + Sync + 'static>(
        &mut self,
        namespace: &str,
        key: &str,
        default: impl FnOnce() -> T,
    ) -> &mut T {
        let ns_key = Self::namespaced_key(namespace, key);

        // Check for type mismatch on an existing entry *before* consuming
        // the default closure, so we can replace the stale value with a
        // fresh default of the correct type.
        let needs_replace = self
            .inner
            .get(&ns_key)
            .is_some_and(|v| v.downcast_ref::<T>().is_none());

        if needs_replace {
            log::warn!(
                "extension cache type mismatch for key `{ns_key}`: \
                 replacing existing entry with new default"
            );
            self.inner.remove(&ns_key);
        }

        self.inner
            .entry(ns_key)
            .or_insert_with(|| Box::new(default()))
            .downcast_mut()
            .expect("downcast must succeed: entry was just inserted with correct type")
    }

    pub fn insert<T: Send + Sync + 'static>(&mut self, namespace: &str, key: String, value: T) {
        self.inner
            .insert(Self::namespaced_key(namespace, &key), Box::new(value));
    }

    pub fn remove(&mut self, namespace: &str, key: &str) -> bool {
        self.inner
            .remove(&Self::namespaced_key(namespace, key))
            .is_some()
    }

    pub fn contains(&self, namespace: &str, key: &str) -> bool {
        self.inner
            .contains_key(&Self::namespaced_key(namespace, key))
    }

    /// Remove all entries for a given namespace prefix.
    pub fn remove_namespace(&mut self, namespace: &str) {
        let prefix = format!("{namespace}:");
        self.inner.retain(|k, _| !k.starts_with(&prefix));
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
    pub caches: &'a ExtensionCaches,
    pub images: &'a ImageRegistry,
    pub theme: &'a Theme,
    pub render_ctx: RenderContext<'a>,
}

/// Renders child nodes through the main dispatch. Copy-able (all shared refs).
#[derive(Clone, Copy)]
pub struct RenderContext<'a> {
    pub caches: &'a WidgetCaches,
    pub images: &'a ImageRegistry,
    pub theme: &'a Theme,
    pub extensions: &'a ExtensionDispatcher,
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

/// Number of consecutive render panics before an extension is poisoned.
const RENDER_PANIC_THRESHOLD: u32 = 3;

/// Owns extensions and routing state.
pub struct ExtensionDispatcher {
    extensions: Vec<Box<dyn WidgetExtension>>,
    type_name_index: HashMap<String, usize>,
    node_extension_map: HashMap<String, usize>,
    poisoned: Vec<bool>,
    /// Per-extension consecutive render panic counter. Stored as AtomicU32
    /// so `record_render_panic` can be called with `&self` (the dispatcher
    /// is borrowed immutably during view/render).
    render_panic_counts: Vec<AtomicU32>,
}

impl ExtensionDispatcher {
    pub fn new(extensions: Vec<Box<dyn WidgetExtension>>) -> Self {
        let n = extensions.len();

        // Validate extension metadata before building the index.
        for ext in &extensions {
            if ext.config_key().is_empty() {
                panic!(
                    "extension registered with empty config_key() \
                     (type_names: {:?})",
                    ext.type_names()
                );
            }
            if ext.type_names().is_empty() {
                log::warn!(
                    "extension `{}` registered with empty type_names(); \
                     it will never match any node type",
                    ext.config_key()
                );
            }
        }

        // Check for duplicate config_key values.
        let mut seen_config_keys: HashMap<&str, usize> = HashMap::new();
        for (idx, ext) in extensions.iter().enumerate() {
            let key = ext.config_key();
            if let Some(prev_idx) = seen_config_keys.insert(key, idx) {
                panic!(
                    "duplicate extension config_key `{key}`: \
                     extension at index {prev_idx} (type_names: {:?}) and \
                     extension at index {idx} (type_names: {:?}) both use it",
                    extensions[prev_idx].type_names(),
                    ext.type_names(),
                );
            }
        }

        let mut type_name_index = HashMap::new();
        for (idx, ext) in extensions.iter().enumerate() {
            for &name in ext.type_names() {
                if let Some(prev_idx) = type_name_index.insert(name.to_string(), idx) {
                    panic!(
                        "duplicate extension type name `{name}`: \
                         extension `{}` (index {prev_idx}) and \
                         extension `{}` (index {idx}) both claim it",
                        extensions[prev_idx].config_key(),
                        ext.config_key(),
                    );
                }
            }
        }

        let render_panic_counts = (0..n).map(|_| AtomicU32::new(0)).collect();

        Self {
            extensions,
            type_name_index,
            node_extension_map: HashMap::new(),
            poisoned: vec![false; n],
            render_panic_counts,
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
                let ns = self.extensions[*ext_idx].config_key().to_string();
                if self.poisoned[*ext_idx] {
                    caches.remove(&ns, old_id);
                    log::warn!(
                        "skipping cleanup for poisoned extension `{ns}`; \
                         cache entry removed for node `{old_id}`",
                    );
                } else {
                    let result = catch_unwind(AssertUnwindSafe(|| {
                        self.extensions[*ext_idx].cleanup(old_id, caches);
                    }));
                    if let Err(panic) = result {
                        let msg = panic_message(&panic);
                        log::error!("extension `{ns}` panicked in cleanup: {msg}",);
                        self.poisoned[*ext_idx] = true;
                        caches.remove(&ns, old_id);
                    }
                }
            }
        }

        self.node_extension_map = new_map;

        // Check render panic counters -- poison extensions that exceeded
        // the threshold. Also reset counters for non-poisoned extensions
        // (a successful prepare cycle implies the tree was rebuilt, so
        // we give extensions a fresh chance).
        for idx in 0..self.extensions.len() {
            let count = self.render_panic_counts[idx].load(Ordering::Relaxed);
            if count >= RENDER_PANIC_THRESHOLD && !self.poisoned[idx] {
                log::error!(
                    "extension `{}` hit {} consecutive render panics, poisoning",
                    self.extensions[idx].config_key(),
                    count,
                );
                self.poisoned[idx] = true;
            }
            if !self.poisoned[idx] {
                self.render_panic_counts[idx].store(0, Ordering::Relaxed);
            }
        }
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
                // Report the panic back to Elixir so update/2 can handle it.
                let error_data = serde_json::json!({
                    "error": msg,
                    "op": op,
                });
                vec![OutgoingEvent::generic(
                    "extension_error",
                    node_id.to_string(),
                    Some(error_data),
                )]
            }
        }
    }

    /// Route configuration to extensions. `config` is the value of the
    /// `extension_config` key from Settings -- a JSON object keyed by
    /// each extension's `config_key()`.
    pub fn init_all(&mut self, config: &Value) {
        for (idx, ext) in self.extensions.iter_mut().enumerate() {
            if self.poisoned[idx] {
                continue;
            }
            let key = ext.config_key().to_string();
            let slice = config.get(&key).unwrap_or(&Value::Null);
            let result = catch_unwind(AssertUnwindSafe(|| {
                ext.init(slice);
            }));
            if let Err(panic) = result {
                let msg = panic_message(&panic);
                log::error!("extension `{key}` panicked in init: {msg}");
                self.poisoned[idx] = true;
            }
        }
    }

    /// Render an extension node. Returns None if no extension handles this type.
    ///
    /// The caller must construct the `WidgetEnv` and pass it in. This avoids
    /// a borrow-checker issue where a locally-constructed env would be dropped
    /// before the returned Element (which borrows from the env).
    ///
    /// Note: catch_unwind happens in the caller (`widgets::render`) because
    /// the returned Element borrows from env and can't be wrapped in a
    /// closure. When a render panic is caught, the caller should call
    /// `record_render_panic` to track consecutive failures.
    pub fn render<'a>(
        &'a self,
        node: &'a TreeNode,
        env: &WidgetEnv<'a>,
    ) -> Option<Element<'a, Message>> {
        let &idx = self.type_name_index.get(node.type_name.as_str())?;
        if self.poisoned[idx] {
            return Some(render_poisoned_placeholder(node));
        }
        let element = self.extensions[idx].render(node, env);
        // Successful render -- reset consecutive panic counter.
        self.render_panic_counts[idx].store(0, Ordering::Relaxed);
        Some(element)
    }

    /// Record a render panic for the extension that handles `type_name`.
    /// Called by the catch_unwind wrapper in `widgets::render` (which has
    /// only `&self`). Uses AtomicU32 so no `&mut self` is required.
    /// Returns `true` if the extension has reached the poison threshold.
    pub fn record_render_panic(&self, type_name: &str) -> bool {
        if let Some(&idx) = self.type_name_index.get(type_name) {
            let prev = self.render_panic_counts[idx].fetch_add(1, Ordering::Relaxed);
            prev + 1 >= RENDER_PANIC_THRESHOLD
        } else {
            false
        }
    }

    /// Reset all poisoned flags and render panic counters. Called on Snapshot.
    pub fn clear_poisoned(&mut self) {
        self.poisoned.fill(false);
        for counter in &self.render_panic_counts {
            counter.store(0, Ordering::Relaxed);
        }
    }

    /// Check if any extensions are registered.
    pub fn is_empty(&self) -> bool {
        self.extensions.is_empty()
    }

    /// Check if a specific extension (by index) is poisoned.
    #[cfg(test)]
    pub fn is_poisoned(&self, idx: usize) -> bool {
        self.poisoned.get(idx).copied().unwrap_or(false)
    }

    /// Number of registered extensions.
    pub fn len(&self) -> usize {
        self.extensions.len()
    }
}

impl Default for ExtensionDispatcher {
    fn default() -> Self {
        Self::new(vec![])
    }
}

// ---------------------------------------------------------------------------
// GenerationCounter
// ---------------------------------------------------------------------------

/// A monotonically increasing counter for tracking data changes.
///
/// Store in `ExtensionCaches` alongside your data. Call `bump()` when data
/// changes (in `handle_command` or `prepare`). In your `canvas::Program`
/// implementation, compare the generation against a saved value in your
/// `Program::State` to decide whether to clear and redraw the cache.
///
/// # Example
///
/// ```ignore
/// struct MyState {
///     generation: u64,
///     cache: canvas::Cache,
/// }
///
/// impl canvas::Program<Message> for MyProgram {
///     type State = MyState;
///
///     fn draw(&self, state: &MyState, ...) -> Vec<Geometry> {
///         if state.generation != self.current_generation {
///             state.cache.clear();
///             // update state.generation after draw
///         }
///         vec![state.cache.draw(renderer, bounds.size(), |frame| { ... })]
///     }
/// }
/// ```
#[derive(Debug, Clone)]
pub struct GenerationCounter {
    value: u64,
}

impl GenerationCounter {
    /// Create a new counter starting at zero.
    pub fn new() -> Self {
        Self { value: 0 }
    }

    /// Return the current generation value.
    pub fn get(&self) -> u64 {
        self.value
    }

    /// Increment the generation. Wraps on overflow (u64 -- effectively never).
    pub fn bump(&mut self) {
        self.value = self.value.wrapping_add(1);
    }
}

impl Default for GenerationCounter {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    // -- Test extension implementations --------------------------------------

    /// Minimal test extension that renders a text widget.
    struct TestExtension {
        type_names: Vec<&'static str>,
        config_key: &'static str,
        init_called: bool,
    }

    impl TestExtension {
        fn new(type_names: Vec<&'static str>, config_key: &'static str) -> Self {
            Self {
                type_names,
                config_key,
                init_called: false,
            }
        }
    }

    impl WidgetExtension for TestExtension {
        fn type_names(&self) -> &[&str] {
            &self.type_names
        }

        fn config_key(&self) -> &str {
            self.config_key
        }

        fn init(&mut self, _config: &Value) {
            self.init_called = true;
        }

        fn render<'a>(&self, node: &'a TreeNode, _env: &WidgetEnv<'a>) -> Element<'a, Message> {
            use iced::widget::text;
            text(format!("test:{}", node.id)).into()
        }
    }

    /// Extension with empty type_names (valid but useless -- should warn).
    struct EmptyTypesExtension;

    impl WidgetExtension for EmptyTypesExtension {
        fn type_names(&self) -> &[&str] {
            &[]
        }
        fn config_key(&self) -> &str {
            "empty_types"
        }
        fn render<'a>(&self, _node: &'a TreeNode, _env: &WidgetEnv<'a>) -> Element<'a, Message> {
            use iced::widget::text;
            text("empty").into()
        }
    }

    fn make_node(id: &str, type_name: &str) -> TreeNode {
        TreeNode {
            id: id.to_string(),
            type_name: type_name.to_string(),
            props: serde_json::json!({}),
            children: vec![],
        }
    }

    // -- Registration and type_name_index ------------------------------------

    #[test]
    fn registration_builds_type_name_index() {
        let ext = TestExtension::new(vec!["sparkline", "heatmap"], "charts");
        let dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);

        assert!(dispatcher.handles_type("sparkline"));
        assert!(dispatcher.handles_type("heatmap"));
        assert!(!dispatcher.handles_type("unknown"));
    }

    #[test]
    fn registration_with_multiple_extensions() {
        let ext_a = TestExtension::new(vec!["sparkline"], "charts");
        let ext_b = TestExtension::new(vec!["gauge"], "instruments");
        let dispatcher = ExtensionDispatcher::new(vec![Box::new(ext_a), Box::new(ext_b)]);

        assert!(dispatcher.handles_type("sparkline"));
        assert!(dispatcher.handles_type("gauge"));
        assert_eq!(dispatcher.len(), 2);
    }

    #[test]
    fn empty_dispatcher_handles_nothing() {
        let dispatcher = ExtensionDispatcher::default();
        assert!(dispatcher.is_empty());
        assert!(!dispatcher.handles_type("anything"));
    }

    // -- Duplicate type name detection ---------------------------------------

    #[test]
    #[should_panic(expected = "duplicate extension type name `sparkline`")]
    fn duplicate_type_name_panics() {
        let ext_a = TestExtension::new(vec!["sparkline"], "charts_a");
        let ext_b = TestExtension::new(vec!["sparkline"], "charts_b");
        ExtensionDispatcher::new(vec![Box::new(ext_a), Box::new(ext_b)]);
    }

    #[test]
    #[should_panic(expected = "both claim it")]
    fn duplicate_type_name_error_identifies_conflicting_extensions() {
        let ext_a = TestExtension::new(vec!["widget_x"], "ext_alpha");
        let ext_b = TestExtension::new(vec!["widget_x"], "ext_beta");
        ExtensionDispatcher::new(vec![Box::new(ext_a), Box::new(ext_b)]);
    }

    // -- Empty config_key validation -----------------------------------------

    #[test]
    #[should_panic(expected = "empty config_key()")]
    fn empty_config_key_panics() {
        let ext = TestExtension::new(vec!["widget"], "");
        ExtensionDispatcher::new(vec![Box::new(ext)]);
    }

    // -- Duplicate config_key validation ---------------------------------------

    #[test]
    #[should_panic(expected = "duplicate extension config_key `charts`")]
    fn duplicate_config_key_panics() {
        let ext_a = TestExtension::new(vec!["sparkline"], "charts");
        let ext_b = TestExtension::new(vec!["heatmap"], "charts");
        ExtensionDispatcher::new(vec![Box::new(ext_a), Box::new(ext_b)]);
    }

    // -- Empty type_names validation (warn, don't panic) ---------------------

    #[test]
    fn empty_type_names_does_not_panic() {
        // Should log a warning but not panic.
        let ext = EmptyTypesExtension;
        let dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);
        assert_eq!(dispatcher.len(), 1);
        assert!(!dispatcher.handles_type("anything"));
    }

    // -- ExtensionCaches: get/insert/get_or_insert ---------------------------

    #[test]
    fn cache_insert_and_get() {
        let mut caches = ExtensionCaches::new();
        caches.insert("charts", "node1".to_string(), 42u32);

        assert_eq!(caches.get::<u32>("charts", "node1"), Some(&42));
        assert_eq!(caches.get::<u32>("charts", "node2"), None);
    }

    #[test]
    fn cache_get_mut() {
        let mut caches = ExtensionCaches::new();
        caches.insert("ns", "key".to_string(), vec![1, 2, 3]);

        if let Some(v) = caches.get_mut::<Vec<i32>>("ns", "key") {
            v.push(4);
        }
        assert_eq!(caches.get::<Vec<i32>>("ns", "key"), Some(&vec![1, 2, 3, 4]));
    }

    #[test]
    fn cache_get_or_insert_creates_default() {
        let mut caches = ExtensionCaches::new();
        let val = caches.get_or_insert::<String>("ns", "key", || "hello".to_string());
        assert_eq!(val, "hello");

        // Second call returns existing value, doesn't overwrite.
        let val = caches.get_or_insert::<String>("ns", "key", || "world".to_string());
        assert_eq!(val, "hello");
    }

    #[test]
    fn cache_get_or_insert_type_mismatch_replaces_with_default() {
        let mut caches = ExtensionCaches::new();
        caches.insert("ns", "key".to_string(), 42u32);
        // Previously this panicked. Now it logs a warning, replaces the
        // stale entry, and returns a fresh default of the requested type.
        let val = caches.get_or_insert::<String>("ns", "key", || "replaced".to_string());
        assert_eq!(val, "replaced");
    }

    #[test]
    fn cache_wrong_type_returns_none() {
        let mut caches = ExtensionCaches::new();
        caches.insert("ns", "key".to_string(), 42u32);

        // Asking for a different type returns None (not a panic for get).
        assert_eq!(caches.get::<String>("ns", "key"), None);
    }

    #[test]
    fn cache_remove_and_contains() {
        let mut caches = ExtensionCaches::new();
        caches.insert("ns", "key".to_string(), 1u8);

        assert!(caches.contains("ns", "key"));
        assert!(caches.remove("ns", "key"));
        assert!(!caches.contains("ns", "key"));
        assert!(!caches.remove("ns", "key"));
    }

    #[test]
    fn cache_clear_removes_everything() {
        let mut caches = ExtensionCaches::new();
        caches.insert("a", "k1".to_string(), 1u32);
        caches.insert("b", "k2".to_string(), 2u32);

        caches.clear();
        assert!(!caches.contains("a", "k1"));
        assert!(!caches.contains("b", "k2"));
    }

    // -- Cache namespace isolation -------------------------------------------

    #[test]
    fn cache_namespace_isolation() {
        let mut caches = ExtensionCaches::new();

        // Two extensions use the same raw key "data" -- they shouldn't collide.
        caches.insert("charts", "data".to_string(), vec![1.0f64, 2.0, 3.0]);
        caches.insert("gauges", "data".to_string(), 42u32);

        assert_eq!(
            caches.get::<Vec<f64>>("charts", "data"),
            Some(&vec![1.0, 2.0, 3.0])
        );
        assert_eq!(caches.get::<u32>("gauges", "data"), Some(&42));
    }

    #[test]
    fn cache_remove_namespace() {
        let mut caches = ExtensionCaches::new();
        caches.insert("charts", "a".to_string(), 1u32);
        caches.insert("charts", "b".to_string(), 2u32);
        caches.insert("gauges", "a".to_string(), 3u32);

        caches.remove_namespace("charts");

        assert!(!caches.contains("charts", "a"));
        assert!(!caches.contains("charts", "b"));
        assert!(caches.contains("gauges", "a"));
    }

    // -- Poison flag management ----------------------------------------------

    #[test]
    fn poison_flag_set_and_clear() {
        let ext = TestExtension::new(vec!["sparkline"], "charts");
        let mut dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);

        assert!(!dispatcher.is_poisoned(0));

        // Simulate poisoning via render panic counter.
        for _ in 0..RENDER_PANIC_THRESHOLD {
            dispatcher.record_render_panic("sparkline");
        }

        // Poisoning happens on next prepare_all call.
        let root = make_node("root", "column");
        let mut caches = ExtensionCaches::new();
        dispatcher.prepare_all(&root, &mut caches, &Theme::Dark);

        assert!(dispatcher.is_poisoned(0));

        // clear_poisoned resets everything.
        dispatcher.clear_poisoned();
        assert!(!dispatcher.is_poisoned(0));
    }

    // -- Render panic tracking -----------------------------------------------

    #[test]
    fn record_render_panic_increments_counter() {
        let ext = TestExtension::new(vec!["sparkline"], "charts");
        let dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);

        // Below threshold -- returns false.
        assert!(!dispatcher.record_render_panic("sparkline"));
        assert!(!dispatcher.record_render_panic("sparkline"));

        // At threshold -- returns true.
        assert!(dispatcher.record_render_panic("sparkline"));
    }

    #[test]
    fn record_render_panic_unknown_type_returns_false() {
        let dispatcher = ExtensionDispatcher::default();
        assert!(!dispatcher.record_render_panic("nonexistent"));
    }

    // -- EventResult variants ------------------------------------------------

    #[test]
    fn event_result_pass_through() {
        let result = EventResult::PassThrough;
        assert!(matches!(result, EventResult::PassThrough));
    }

    #[test]
    fn event_result_consumed_with_events() {
        let events = vec![OutgoingEvent::generic("test", "n1".to_string(), None)];
        let result = EventResult::Consumed(events);
        match result {
            EventResult::Consumed(e) => assert_eq!(e.len(), 1),
            _ => panic!("expected Consumed"),
        }
    }

    #[test]
    fn event_result_observed_with_events() {
        let events = vec![OutgoingEvent::generic("test", "n1".to_string(), None)];
        let result = EventResult::Observed(events);
        match result {
            EventResult::Observed(e) => assert_eq!(e.len(), 1),
            _ => panic!("expected Observed"),
        }
    }

    // -- GenerationCounter ---------------------------------------------------

    #[test]
    fn generation_counter_starts_at_zero() {
        let counter = GenerationCounter::new();
        assert_eq!(counter.get(), 0);
    }

    #[test]
    fn generation_counter_bumps() {
        let mut counter = GenerationCounter::new();
        counter.bump();
        assert_eq!(counter.get(), 1);
        counter.bump();
        assert_eq!(counter.get(), 2);
    }

    #[test]
    fn generation_counter_default() {
        let counter = GenerationCounter::default();
        assert_eq!(counter.get(), 0);
    }

    // -- init_all ------------------------------------------------------------

    #[test]
    fn init_all_routes_config_by_key() {
        let ext = TestExtension::new(vec!["sparkline"], "charts");
        let mut dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);

        let config = serde_json::json!({"charts": {"color": "red"}});
        dispatcher.init_all(&config);

        // Can't easily inspect init_called through the trait object, but
        // at least verify no panic occurred.
        assert!(!dispatcher.is_poisoned(0));
    }

    // -- panic_message helper ------------------------------------------------

    #[test]
    fn panic_message_extracts_str() {
        let p: Box<dyn Any + Send> = Box::new("boom");
        assert_eq!(panic_message(&p), "boom");
    }

    #[test]
    fn panic_message_extracts_string() {
        let p: Box<dyn Any + Send> = Box::new("kaboom".to_string());
        assert_eq!(panic_message(&p), "kaboom");
    }

    #[test]
    fn panic_message_unknown_type() {
        let p: Box<dyn Any + Send> = Box::new(42u32);
        assert_eq!(panic_message(&p), "unknown panic");
    }

    // -- handle_command panic emits error event ------------------------------

    /// Extension that panics on handle_command.
    struct PanickingCommandExtension;

    impl WidgetExtension for PanickingCommandExtension {
        fn type_names(&self) -> &[&str] {
            &["panicker"]
        }
        fn config_key(&self) -> &str {
            "panicker"
        }
        fn render<'a>(&self, _node: &'a TreeNode, _env: &WidgetEnv<'a>) -> Element<'a, Message> {
            use iced::widget::text;
            text("panicker").into()
        }
        fn handle_command(
            &mut self,
            _node_id: &str,
            _op: &str,
            _payload: &Value,
            _caches: &mut ExtensionCaches,
        ) -> Vec<OutgoingEvent> {
            panic!("command went boom");
        }
    }

    #[test]
    fn handle_command_panic_emits_error_event() {
        let ext = PanickingCommandExtension;
        let mut dispatcher = ExtensionDispatcher::new(vec![Box::new(ext)]);
        let mut caches = ExtensionCaches::new();

        // Register the node in the extension map via prepare_all.
        let mut root = make_node("root", "column");
        root.children.push(make_node("p1", "panicker"));
        dispatcher.prepare_all(&root, &mut caches, &Theme::Dark);

        let events = dispatcher.handle_command("p1", "do_thing", &Value::Null, &mut caches);

        assert_eq!(events.len(), 1);
        let event = &events[0];
        assert_eq!(event.family, "extension_error");
        assert_eq!(event.id, "p1");
        let data = event.data.as_ref().expect("should have data");
        assert_eq!(
            data.get("error").and_then(|v| v.as_str()),
            Some("command went boom")
        );
        assert_eq!(data.get("op").and_then(|v| v.as_str()), Some("do_thing"));

        // Extension should also be poisoned.
        assert!(dispatcher.is_poisoned(0));
    }
}
