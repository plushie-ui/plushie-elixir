#![deny(warnings)]

mod codec;
mod effects;
#[cfg(feature = "headless")]
mod headless;
mod image_registry;
mod julep_core;
mod overlay_widget;
mod protocol;
mod test_mode;
mod theming;
mod tree;
mod widgets;

use std::collections::{HashMap, HashSet};
use std::io::{self, BufRead, Read, Write};
use std::sync::{Mutex, OnceLock};
use std::thread;

use iced::futures::SinkExt;
use iced::widget::{container, markdown, pane_grid, text, text_editor};
use iced::{event, stream, system, window, Element, Fill, Point, Size, Subscription, Task, Theme};

use base64::Engine as _;
use protocol::{IncomingMessage, KeyModifiers, OutgoingEvent};
use serde_json::Value;

/// Wire codec negotiated at startup (auto-detected or forced via CLI flag).
static WIRE_CODEC: OnceLock<codec::Codec> = OnceLock::new();

/// One-shot slot for the stdin receiver. The subscription takes it once on
/// first call. Uses a Mutex because `Subscription::run` requires `fn() -> Stream`
/// (a function pointer, not a closure), so we can't capture local state.
static STDIN_RX: Mutex<Option<tokio::sync::mpsc::Receiver<StdinEvent>>> = Mutex::new(None);

// ---------------------------------------------------------------------------
// Keyboard event data
// ---------------------------------------------------------------------------

/// All fields from an iced keyboard event, packed for Message transport.
#[derive(Debug, Clone)]
struct KeyEventData {
    key: iced::keyboard::Key,
    modified_key: iced::keyboard::Key,
    physical_key: iced::keyboard::key::Physical,
    location: iced::keyboard::Location,
    modifiers: iced::keyboard::Modifiers,
    text: Option<String>,
    repeat: bool,
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub(crate) enum Message {
    /// A user clicked a button with the given node ID.
    Click(String),
    /// A text input value changed (id, new_value).
    Input(String, String),
    /// A text input was submitted (id, current_value).
    Submit(String, String),
    /// A checkbox or toggler was toggled (id, checked).
    Toggle(String, bool),
    /// A slider value changed (id, value).
    Slide(String, f64),
    /// A slider was released (id, value).
    SlideRelease(String, f64),
    /// A pick_list/combo_box/radio selection (id, value).
    Select(String, String),
    /// A text editor action (id, action).
    TextEditorAction(String, text_editor::Action),
    /// A markdown link was clicked.
    MarkdownUrl(markdown::Uri),
    /// A message arrived from the stdin reader (or stdin closed).
    Stdin(StdinEvent),
    /// No-op: used as return value for fire-and-forget tasks (font loads, etc.)
    NoOp,
    /// A keyboard key was pressed (full event data).
    KeyPressed(KeyEventData),
    /// A keyboard key was released (full event data).
    KeyReleased(KeyEventData),
    /// Keyboard modifiers changed.
    ModifiersChanged(iced::keyboard::Modifiers),
    // -- IME events --
    /// IME session opened.
    ImeOpened,
    /// IME preedit text updated (composing text, optional cursor range).
    ImePreedit(String, Option<std::ops::Range<usize>>),
    /// IME committed final text.
    ImeCommit(String),
    /// IME session closed.
    ImeClosed,
    /// A window close was requested by the user (WM close button).
    WindowCloseRequested(window::Id),
    /// A window was actually closed by iced.
    WindowClosed(window::Id),
    /// A new window was opened (iced_id, julep_id).
    WindowOpened(window::Id, String),
    // -- Mouse events --
    /// Cursor moved to (x, y) in a window.
    CursorMoved(Point, window::Id),
    /// Cursor entered a window.
    CursorEntered(window::Id),
    /// Cursor left a window.
    CursorLeft(window::Id),
    /// Mouse button pressed.
    MouseButtonPressed(iced::mouse::Button, window::Id),
    /// Mouse button released.
    MouseButtonReleased(iced::mouse::Button, window::Id),
    /// Mouse wheel scrolled.
    WheelScrolled(iced::mouse::ScrollDelta, window::Id),
    // -- Touch events --
    /// Touch finger pressed.
    FingerPressed(iced::touch::Finger, Point, window::Id),
    /// Touch finger moved.
    FingerMoved(iced::touch::Finger, Point, window::Id),
    /// Touch finger lifted.
    FingerLifted(iced::touch::Finger, Point, window::Id),
    /// Touch finger lost.
    FingerLost(iced::touch::Finger, Point, window::Id),
    // -- Window lifecycle events --
    /// A window event from iced (window_id, event).
    WindowEvent(window::Id, window::Event),
    // -- System / animation events --
    /// Animation frame with timestamp.
    AnimationFrame(iced::time::Instant),
    /// System theme mode changed.
    ThemeChanged(iced::theme::Mode),
    /// Sensor widget resize event (id, width, height).
    SensorResize(String, f32, f32),
    /// Canvas interaction event (id, kind, x, y, extra).
    CanvasEvent(String, String, f32, f32, String),
    /// Canvas scroll event (id, cursor_x, cursor_y, delta_x, delta_y).
    CanvasScroll(String, f32, f32, f32, f32),
    /// PaneGrid pane was resized (grid_id, resize_event).
    PaneResized(String, iced::widget::pane_grid::ResizeEvent),
    /// PaneGrid pane was dragged (grid_id, drag_event).
    PaneDragged(String, iced::widget::pane_grid::DragEvent),
    /// PaneGrid pane was clicked (grid_id, pane).
    PaneClicked(String, iced::widget::pane_grid::Pane),
    /// Scrollable viewport changed (id, viewport data).
    ScrollEvent(String, f32, f32, f32, f32, f32, f32, f32, f32),
    /// Text was pasted into a text_input (id, pasted_text).
    Paste(String, String),
    /// ComboBox option was hovered (combo_id, option_value).
    OptionHovered(String, String),
    /// MouseArea simple event (id, kind). Kind is one of: right_press,
    /// right_release, middle_release, double_click, enter, exit.
    MouseAreaEvent(String, String),
    /// MouseArea cursor move event (id, x, y).
    MouseAreaMove(String, f32, f32),
    /// MouseArea scroll event (id, delta_x, delta_y).
    MouseAreaScroll(String, f32, f32),
    /// Generic widget event (id, data, family).
    /// Used for on_open, on_close, sort, and other events that carry a
    /// family string and optional JSON data payload.
    Event(String, Value, String),
}

// ---------------------------------------------------------------------------
// App state
// ---------------------------------------------------------------------------

struct App {
    core: julep_core::Core,
    theme: Theme,
    /// Tasks generated by apply() that must be returned from update().
    pending_tasks: Vec<Task<Message>>,
    /// Julep window ID -> iced window ID.
    window_map: HashMap<String, window::Id>,
    /// Iced window ID -> julep window ID.
    reverse_window_map: HashMap<window::Id, String>,
    /// When true, handle Query/Interact/SnapshotCapture/ScreenshotCapture/Reset on stdin.
    test_mode: bool,
    /// In-memory image handles for use by Image widgets and canvas draw.
    image_registry: image_registry::ImageRegistry,
    /// Current system theme, tracked via ThemeChanged subscription.
    /// Used when a window or app theme is set to "system".
    system_theme: Theme,
    /// True when the app-level theme is "system" (follow OS preference).
    theme_follows_system: bool,
    /// Global scale factor multiplier (1.0 = follow OS DPI).
    scale_factor: f32,
}

/// What the stdin reader thread sends back.
#[derive(Debug, Clone)]
enum StdinEvent {
    Message(IncomingMessage),
    Closed,
    Warning(String),
}

impl App {
    fn new(test_mode: bool) -> Self {
        if test_mode {
            log::info!("running in test mode");
        }
        Self {
            core: julep_core::Core::new(),
            theme: Theme::Dark,
            pending_tasks: Vec::new(),
            window_map: HashMap::new(),
            reverse_window_map: HashMap::new(),
            test_mode,
            image_registry: image_registry::ImageRegistry::new(),
            system_theme: Theme::Dark,
            theme_follows_system: false,
            scale_factor: 1.0,
        }
    }

    fn title_for_window(&self, window_id: window::Id) -> String {
        if let Some(julep_id) = self.reverse_window_map.get(&window_id) {
            if let Some(node) = self.core.tree.find_window(julep_id) {
                if let Some(title) = node.props.get("title").and_then(|v| v.as_str()) {
                    return title.to_string();
                }
            }
        }
        "Julep".to_string()
    }

    fn theme_for_window(&self, window_id: window::Id) -> Theme {
        if let Some(julep_id) = self.reverse_window_map.get(&window_id) {
            if let Some(node) = self.core.tree.find_window(julep_id) {
                if let Some(theme_val) = node.props.get("theme") {
                    return theming::resolve_theme_only(theme_val)
                        .unwrap_or_else(|| self.system_theme.clone());
                }
            }
        }
        if self.theme_follows_system {
            self.system_theme.clone()
        } else {
            self.theme.clone()
        }
    }

    /// Return the scale factor for a window. Per-window overrides take
    /// precedence over the global setting.
    fn scale_factor_for_window(&self, window_id: window::Id) -> f32 {
        if let Some(julep_id) = self.reverse_window_map.get(&window_id) {
            if let Some(node) = self.core.tree.find_window(julep_id) {
                if let Some(sf) = node.props.get("scale_factor").and_then(|v| v.as_f64()) {
                    return sf as f32;
                }
            }
        }
        self.scale_factor
    }

    /// Resolve a julep window ID string from an iced window::Id.
    fn julep_id_for(&self, iced_id: &window::Id) -> String {
        self.reverse_window_map
            .get(iced_id)
            .cloned()
            .unwrap_or_default()
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Stdin(event) => match event {
                StdinEvent::Message(incoming) => {
                    // In test mode, handle test-specific messages directly
                    // instead of passing them to Core::apply.
                    if self.test_mode && test_mode::test_helpers::is_test_message(&incoming) {
                        match incoming {
                            IncomingMessage::Query {
                                id,
                                target,
                                selector,
                            } => {
                                test_mode::test_helpers::handle_query(
                                    &self.core, id, target, selector,
                                );
                                return Task::none();
                            }
                            IncomingMessage::Interact {
                                id,
                                action,
                                selector,
                                payload,
                            } => {
                                test_mode::test_helpers::handle_interact(
                                    &self.core, id, action, selector, payload,
                                );
                                return Task::none();
                            }
                            IncomingMessage::Reset { id } => {
                                test_mode::test_helpers::handle_reset(&mut self.core, id);
                                return Task::none();
                            }
                            #[cfg(feature = "test-mode")]
                            IncomingMessage::SnapshotCapture { id, name, .. } => {
                                test_mode::test_helpers::handle_snapshot_capture(
                                    &self.core, id, name,
                                );
                                return Task::none();
                            }
                            #[cfg(feature = "test-mode")]
                            IncomingMessage::ScreenshotCapture { id, name, .. } => {
                                // Capture real GPU-rendered pixels via iced
                                if let Some((_, &iced_id)) = self.window_map.iter().next() {
                                    return window::screenshot(iced_id).map(move |shot| {
                                        use sha2::{Digest, Sha256};
                                        let rgba: &[u8] = &shot.rgba;
                                        let mut hasher = Sha256::new();
                                        hasher.update(rgba);
                                        let hash = format!("{:x}", hasher.finalize());
                                        let w = shot.size.width;
                                        let h = shot.size.height;
                                        emit_screenshot_response(&id, &name, &hash, w, h, rgba);
                                        Message::NoOp
                                    });
                                }
                                // No windows open -- return empty screenshot
                                emit_screenshot_response(&id, &name, "", 0, 0, &[]);
                                return Task::none();
                            }
                            _ => return Task::none(),
                        }
                    }
                    self.apply(incoming);
                    let tasks: Vec<Task<Message>> = self.pending_tasks.drain(..).collect();
                    Task::batch(tasks)
                }
                StdinEvent::Warning(msg) => {
                    log::warn!("stdin warning: {msg}");
                    Task::none()
                }
                StdinEvent::Closed => {
                    log::info!("stdin closed -- exiting");
                    iced::exit()
                }
            },
            Message::NoOp => Task::none(),
            // Simple widget events: map through message_to_event and emit.
            ref msg @ (Message::Click(_)
            | Message::Input(..)
            | Message::Submit(..)
            | Message::Toggle(..)
            | Message::Slide(..)
            | Message::SlideRelease(..)
            | Message::Select(..)
            | Message::Event(..)) => {
                if let Some(event) = message_to_event(msg) {
                    emit_event(event);
                }
                Task::none()
            }
            Message::TextEditorAction(id, action) => {
                let is_edit = action.is_edit();
                if let Some(content) = self.core.caches.editor_contents.get_mut(&id) {
                    content.perform(action);
                    if is_edit {
                        let new_text = content.text();
                        emit_event(OutgoingEvent::input(id, new_text));
                    }
                }
                Task::none()
            }
            Message::MarkdownUrl(url) => {
                log::debug!("markdown link clicked: {url}");
                Task::none()
            }

            // -- Keyboard events --
            Message::KeyPressed(data) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_key_press") {
                    emit_event(OutgoingEvent::key_press(tag.clone(), &data));
                }
                Task::none()
            }
            Message::KeyReleased(data) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_key_release") {
                    emit_event(OutgoingEvent::key_release(tag.clone(), &data));
                }
                Task::none()
            }
            Message::ModifiersChanged(mods) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_modifiers_changed") {
                    emit_event(OutgoingEvent::modifiers_changed(
                        tag.clone(),
                        serialize_modifiers(mods),
                    ));
                }
                Task::none()
            }

            // -- Mouse events --
            Message::CursorMoved(pos, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_move") {
                    emit_event(OutgoingEvent::cursor_moved(tag.clone(), pos.x, pos.y));
                }
                Task::none()
            }
            Message::CursorEntered(_win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_move") {
                    emit_event(OutgoingEvent::cursor_entered(tag.clone()));
                }
                Task::none()
            }
            Message::CursorLeft(_win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_move") {
                    emit_event(OutgoingEvent::cursor_left(tag.clone()));
                }
                Task::none()
            }
            Message::MouseButtonPressed(button, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_button") {
                    emit_event(OutgoingEvent::button_pressed(
                        tag.clone(),
                        serialize_mouse_button(&button),
                    ));
                }
                Task::none()
            }
            Message::MouseButtonReleased(button, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_button") {
                    emit_event(OutgoingEvent::button_released(
                        tag.clone(),
                        serialize_mouse_button(&button),
                    ));
                }
                Task::none()
            }
            Message::WheelScrolled(delta, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_mouse_scroll") {
                    let (dx, dy, unit) = serialize_scroll_delta(&delta);
                    emit_event(OutgoingEvent::wheel_scrolled(tag.clone(), dx, dy, unit));
                }
                Task::none()
            }

            // -- Touch events --
            Message::FingerPressed(finger, pos, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_touch") {
                    emit_event(OutgoingEvent::finger_pressed(
                        tag.clone(),
                        finger.0,
                        pos.x,
                        pos.y,
                    ));
                }
                Task::none()
            }
            Message::FingerMoved(finger, pos, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_touch") {
                    emit_event(OutgoingEvent::finger_moved(
                        tag.clone(),
                        finger.0,
                        pos.x,
                        pos.y,
                    ));
                }
                Task::none()
            }
            Message::FingerLifted(finger, pos, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_touch") {
                    emit_event(OutgoingEvent::finger_lifted(
                        tag.clone(),
                        finger.0,
                        pos.x,
                        pos.y,
                    ));
                }
                Task::none()
            }
            Message::FingerLost(finger, pos, _win) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_touch") {
                    emit_event(OutgoingEvent::finger_lost(
                        tag.clone(),
                        finger.0,
                        pos.x,
                        pos.y,
                    ));
                }
                Task::none()
            }

            // -- IME events --
            Message::ImeOpened => {
                if let Some(tag) = self.core.active_subscriptions.get("on_ime") {
                    emit_event(OutgoingEvent::ime_opened(tag.clone()));
                }
                Task::none()
            }
            Message::ImePreedit(text, cursor) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_ime") {
                    emit_event(OutgoingEvent::ime_preedit(tag.clone(), text, cursor));
                }
                Task::none()
            }
            Message::ImeCommit(text) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_ime") {
                    emit_event(OutgoingEvent::ime_commit(tag.clone(), text));
                }
                Task::none()
            }
            Message::ImeClosed => {
                if let Some(tag) = self.core.active_subscriptions.get("on_ime") {
                    emit_event(OutgoingEvent::ime_closed(tag.clone()));
                }
                Task::none()
            }

            // -- Window lifecycle events --
            Message::WindowCloseRequested(window_id) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_window_close") {
                    let julep_id = self.julep_id_for(&window_id);
                    emit_event(OutgoingEvent::window_close_requested(tag.clone(), julep_id));
                }
                // Remove from maps if this was a julep-managed window.
                if let Some(julep_id) = self.reverse_window_map.remove(&window_id) {
                    self.window_map.remove(&julep_id);
                }
                window::close(window_id)
            }
            Message::WindowClosed(window_id) => {
                // Clean up maps when iced confirms a window has closed.
                if let Some(julep_id) = self.reverse_window_map.remove(&window_id) {
                    self.window_map.remove(&julep_id);
                    if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                        emit_event(OutgoingEvent::window_closed(tag.clone(), julep_id.clone()));
                    }
                    log::info!("window closed: {julep_id}");
                }
                // All managed windows gone -- exit cleanly.
                if self.window_map.is_empty() {
                    log::info!("all windows closed -- exiting");
                    iced::exit()
                } else {
                    Task::none()
                }
            }
            Message::WindowOpened(iced_id, julep_id) => {
                log::info!("window opened: {julep_id} -> {iced_id:?}");
                self.window_map.insert(julep_id.clone(), iced_id);
                self.reverse_window_map.insert(iced_id, julep_id);
                Task::none()
            }
            Message::WindowEvent(iced_id, evt) => {
                let julep_id = self.julep_id_for(&iced_id);
                match evt {
                    window::Event::Opened { position, size } => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            let pos = position.map(|p| (p.x, p.y));
                            emit_event(OutgoingEvent::window_opened(
                                tag.clone(),
                                julep_id.clone(),
                                pos,
                                size.width,
                                size.height,
                            ));
                        }
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_open") {
                            let pos = position.map(|p| (p.x, p.y));
                            emit_event(OutgoingEvent::window_opened(
                                tag.clone(),
                                julep_id,
                                pos,
                                size.width,
                                size.height,
                            ));
                        }
                    }
                    window::Event::Closed => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_closed(tag.clone(), julep_id));
                        }
                    }
                    window::Event::Moved(point) => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_moved(
                                tag.clone(),
                                julep_id.clone(),
                                point.x,
                                point.y,
                            ));
                        }
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_move") {
                            emit_event(OutgoingEvent::window_moved(
                                tag.clone(),
                                julep_id,
                                point.x,
                                point.y,
                            ));
                        }
                    }
                    window::Event::Resized(size) => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_resized(
                                tag.clone(),
                                julep_id.clone(),
                                size.width,
                                size.height,
                            ));
                        }
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_resize") {
                            emit_event(OutgoingEvent::window_resized(
                                tag.clone(),
                                julep_id,
                                size.width,
                                size.height,
                            ));
                        }
                    }
                    window::Event::Rescaled(factor) => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_rescaled(
                                tag.clone(),
                                julep_id,
                                factor,
                            ));
                        }
                    }
                    window::Event::Focused => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_focused(
                                tag.clone(),
                                julep_id.clone(),
                            ));
                        }
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_focus") {
                            emit_event(OutgoingEvent::window_focused(tag.clone(), julep_id));
                        }
                    }
                    window::Event::Unfocused => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_event") {
                            emit_event(OutgoingEvent::window_unfocused(
                                tag.clone(),
                                julep_id.clone(),
                            ));
                        }
                        if let Some(tag) = self.core.active_subscriptions.get("on_window_unfocus") {
                            emit_event(OutgoingEvent::window_unfocused(tag.clone(), julep_id));
                        }
                    }
                    window::Event::FileHovered(path) => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_file_drop") {
                            emit_event(OutgoingEvent::file_hovered(
                                tag.clone(),
                                julep_id,
                                path.to_string_lossy().to_string(),
                            ));
                        }
                    }
                    window::Event::FileDropped(path) => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_file_drop") {
                            emit_event(OutgoingEvent::file_dropped(
                                tag.clone(),
                                julep_id,
                                path.to_string_lossy().to_string(),
                            ));
                        }
                    }
                    window::Event::FilesHoveredLeft => {
                        if let Some(tag) = self.core.active_subscriptions.get("on_file_drop") {
                            emit_event(OutgoingEvent::files_hovered_left(tag.clone(), julep_id));
                        }
                    }
                    window::Event::CloseRequested => {
                        // Handled via close_requests() subscription separately.
                    }
                    window::Event::RedrawRequested(_) => {
                        // Handled via animation_frame subscription separately.
                    }
                }
                Task::none()
            }

            // -- System / animation --
            Message::AnimationFrame(instant) => {
                if let Some(tag) = self.core.active_subscriptions.get("on_animation_frame") {
                    // Convert Instant to a duration since some epoch. We use
                    // elapsed from the process start as a monotonic timestamp.
                    let millis = instant
                        .duration_since(iced::time::Instant::now() - instant.elapsed())
                        .as_millis();
                    emit_event(OutgoingEvent::animation_frame(tag.clone(), millis));
                }
                Task::none()
            }
            Message::ThemeChanged(mode) => {
                // Track system theme so "system" theme value follows OS preference
                self.system_theme = match mode {
                    iced::theme::Mode::Light => Theme::Light,
                    iced::theme::Mode::Dark => Theme::Dark,
                    _ => Theme::Dark,
                };
                if let Some(tag) = self.core.active_subscriptions.get("on_theme_change") {
                    let mode_str = match mode {
                        iced::theme::Mode::Light => "light",
                        iced::theme::Mode::Dark => "dark",
                        _ => "system",
                    };
                    emit_event(OutgoingEvent::theme_changed(
                        tag.clone(),
                        mode_str.to_string(),
                    ));
                }
                Task::none()
            }
            Message::SensorResize(id, width, height) => {
                emit_event(OutgoingEvent::sensor_resize(id, width, height));
                Task::none()
            }
            Message::CanvasEvent(id, kind, x, y, extra) => {
                match kind.as_str() {
                    "press" => emit_event(OutgoingEvent::canvas_press(id, x, y, extra)),
                    "release" => emit_event(OutgoingEvent::canvas_release(id, x, y, extra)),
                    "move" => emit_event(OutgoingEvent::canvas_move(id, x, y)),
                    _ => {}
                }
                Task::none()
            }
            Message::CanvasScroll(id, cx, cy, dx, dy) => {
                emit_event(OutgoingEvent::canvas_scroll(id, cx, cy, dx, dy));
                Task::none()
            }
            Message::PaneResized(grid_id, evt) => {
                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&grid_id) {
                    state.resize(evt.split, evt.ratio);
                }
                emit_event(OutgoingEvent::pane_resized(
                    grid_id,
                    format!("{:?}", evt.split),
                    evt.ratio,
                ));
                Task::none()
            }
            Message::PaneDragged(grid_id, evt) => {
                if let pane_grid::DragEvent::Dropped { pane, target } = evt {
                    if let Some(state) = self.core.caches.pane_grid_states.get_mut(&grid_id) {
                        // Look up julep IDs for the panes before swapping
                        let pane_id = state.get(pane).cloned().unwrap_or_default();
                        let target_pane = match target {
                            pane_grid::Target::Edge(_) => "edge".to_string(),
                            pane_grid::Target::Pane(p, _) => {
                                state.get(p).cloned().unwrap_or_default()
                            }
                        };
                        state.drop(pane, target);
                        emit_event(OutgoingEvent::pane_dragged(grid_id, pane_id, target_pane));
                    }
                }
                Task::none()
            }
            Message::PaneClicked(grid_id, pane) => {
                if let Some(state) = self.core.caches.pane_grid_states.get(&grid_id) {
                    let pane_id = state.get(pane).cloned().unwrap_or_default();
                    emit_event(OutgoingEvent::pane_clicked(grid_id, pane_id));
                }
                Task::none()
            }
            Message::ScrollEvent(
                id,
                abs_x,
                abs_y,
                rel_x,
                rel_y,
                bounds_w,
                bounds_h,
                content_w,
                content_h,
            ) => {
                emit_event(OutgoingEvent::scroll(
                    id, abs_x, abs_y, rel_x, rel_y, bounds_w, bounds_h, content_w, content_h,
                ));
                Task::none()
            }
            Message::Paste(id, text) => {
                emit_event(OutgoingEvent::paste(id, text));
                Task::none()
            }
            Message::OptionHovered(id, value) => {
                emit_event(OutgoingEvent::option_hovered(id, value));
                Task::none()
            }
            Message::MouseAreaEvent(id, kind) => {
                let event = match kind.as_str() {
                    "right_press" => OutgoingEvent::mouse_right_press(id),
                    "right_release" => OutgoingEvent::mouse_right_release(id),
                    "middle_release" => OutgoingEvent::mouse_middle_release(id),
                    "double_click" => OutgoingEvent::mouse_double_click(id),
                    "enter" => OutgoingEvent::mouse_enter(id),
                    "exit" => OutgoingEvent::mouse_exit(id),
                    _ => return Task::none(),
                };
                emit_event(event);
                Task::none()
            }
            Message::MouseAreaMove(id, x, y) => {
                emit_event(OutgoingEvent::mouse_area_move(id, x, y));
                Task::none()
            }
            Message::MouseAreaScroll(id, dx, dy) => {
                emit_event(OutgoingEvent::mouse_area_scroll(id, dx, dy));
                Task::none()
            }
        }
    }

    fn view_window(&self, window_id: window::Id) -> Element<'_, Message> {
        let julep_id = match self.reverse_window_map.get(&window_id) {
            Some(id) => id,
            None => {
                return container(text("unknown window"))
                    .width(Fill)
                    .height(Fill)
                    .center(Fill)
                    .into();
            }
        };

        match self.core.tree.find_window(julep_id) {
            Some(window_node) => {
                widgets::render(window_node, &self.core.caches, &self.image_registry)
            }
            None => container(text("waiting for snapshot..."))
                .width(Fill)
                .height(Fill)
                .center(Fill)
                .into(),
        }
    }

    fn subscription(&self) -> Subscription<Message> {
        let mut subs = vec![
            Subscription::run(stdin_subscription).map(Message::Stdin),
            // Always listen for window close events so we can clean up maps.
            window::close_events().map(Message::WindowClosed),
        ];

        // -- Keyboard subscriptions --
        if self.core.active_subscriptions.contains_key("on_key_press") {
            subs.push(event::listen_with(|evt, _status, _window| {
                if let iced::Event::Keyboard(iced::keyboard::Event::KeyPressed {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                    text,
                    repeat,
                }) = evt
                {
                    Some(Message::KeyPressed(KeyEventData {
                        key,
                        modified_key,
                        physical_key,
                        location,
                        modifiers,
                        text: text.map(|s| s.to_string()),
                        repeat,
                    }))
                } else {
                    None
                }
            }));
        }

        if self
            .core
            .active_subscriptions
            .contains_key("on_key_release")
        {
            subs.push(event::listen_with(|evt, _status, _window| {
                if let iced::Event::Keyboard(iced::keyboard::Event::KeyReleased {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                }) = evt
                {
                    Some(Message::KeyReleased(KeyEventData {
                        key,
                        modified_key,
                        physical_key,
                        location,
                        modifiers,
                        text: None,
                        repeat: false,
                    }))
                } else {
                    None
                }
            }));
        }

        if self
            .core
            .active_subscriptions
            .contains_key("on_modifiers_changed")
        {
            subs.push(event::listen_with(|evt, _status, _window| {
                if let iced::Event::Keyboard(iced::keyboard::Event::ModifiersChanged(mods)) = evt {
                    Some(Message::ModifiersChanged(mods))
                } else {
                    None
                }
            }));
        }

        // -- Mouse subscriptions --
        if self.core.active_subscriptions.contains_key("on_mouse_move") {
            subs.push(event::listen_with(|evt, _status, window| match evt {
                iced::Event::Mouse(iced::mouse::Event::CursorMoved { position }) => {
                    Some(Message::CursorMoved(position, window))
                }
                iced::Event::Mouse(iced::mouse::Event::CursorEntered) => {
                    Some(Message::CursorEntered(window))
                }
                iced::Event::Mouse(iced::mouse::Event::CursorLeft) => {
                    Some(Message::CursorLeft(window))
                }
                _ => None,
            }));
        }

        if self
            .core
            .active_subscriptions
            .contains_key("on_mouse_button")
        {
            subs.push(event::listen_with(|evt, _status, window| match evt {
                iced::Event::Mouse(iced::mouse::Event::ButtonPressed(button)) => {
                    Some(Message::MouseButtonPressed(button, window))
                }
                iced::Event::Mouse(iced::mouse::Event::ButtonReleased(button)) => {
                    Some(Message::MouseButtonReleased(button, window))
                }
                _ => None,
            }));
        }

        if self
            .core
            .active_subscriptions
            .contains_key("on_mouse_scroll")
        {
            subs.push(event::listen_with(|evt, _status, window| {
                if let iced::Event::Mouse(iced::mouse::Event::WheelScrolled { delta }) = evt {
                    Some(Message::WheelScrolled(delta, window))
                } else {
                    None
                }
            }));
        }

        // -- Touch subscriptions --
        if self.core.active_subscriptions.contains_key("on_touch") {
            subs.push(event::listen_with(|evt, _status, window| match evt {
                iced::Event::Touch(iced::touch::Event::FingerPressed { id, position }) => {
                    Some(Message::FingerPressed(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerMoved { id, position }) => {
                    Some(Message::FingerMoved(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerLifted { id, position }) => {
                    Some(Message::FingerLifted(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerLost { id, position }) => {
                    Some(Message::FingerLost(id, position, window))
                }
                _ => None,
            }));
        }

        // -- IME subscriptions --
        if self.core.active_subscriptions.contains_key("on_ime") {
            subs.push(event::listen_with(|evt, _status, _window| match evt {
                iced::Event::InputMethod(iced::advanced::input_method::Event::Opened) => {
                    Some(Message::ImeOpened)
                }
                iced::Event::InputMethod(iced::advanced::input_method::Event::Preedit(
                    text,
                    cursor,
                )) => Some(Message::ImePreedit(text, cursor)),
                iced::Event::InputMethod(iced::advanced::input_method::Event::Commit(text)) => {
                    Some(Message::ImeCommit(text))
                }
                iced::Event::InputMethod(iced::advanced::input_method::Event::Closed) => {
                    Some(Message::ImeClosed)
                }
                _ => None,
            }));
        }

        // -- Window event subscriptions --
        if self
            .core
            .active_subscriptions
            .contains_key("on_window_event")
            || self.core.active_subscriptions.contains_key("on_file_drop")
            || self
                .core
                .active_subscriptions
                .contains_key("on_window_open")
            || self
                .core
                .active_subscriptions
                .contains_key("on_window_resize")
            || self
                .core
                .active_subscriptions
                .contains_key("on_window_focus")
            || self
                .core
                .active_subscriptions
                .contains_key("on_window_unfocus")
            || self
                .core
                .active_subscriptions
                .contains_key("on_window_move")
        {
            subs.push(window::events().map(|(id, evt)| Message::WindowEvent(id, evt)));
        }

        if self
            .core
            .active_subscriptions
            .contains_key("on_window_close")
        {
            subs.push(window::close_requests().map(Message::WindowCloseRequested));
        }

        // -- Animation frame subscription --
        if self
            .core
            .active_subscriptions
            .contains_key("on_animation_frame")
        {
            subs.push(window::frames().map(Message::AnimationFrame));
        }

        // -- System theme change subscription --
        if self
            .core
            .active_subscriptions
            .contains_key("on_theme_change")
        {
            subs.push(system::theme_changes().map(Message::ThemeChanged));
        }

        // -- Catch-all event subscription --
        // Subscribes to all keyboard, mouse, and touch events via a single
        // listener, re-using existing Message variants. Window events are
        // handled separately by on_window_event.
        if self.core.active_subscriptions.contains_key("on_event") {
            subs.push(event::listen_with(|evt, _status, window| match evt {
                // Keyboard
                iced::Event::Keyboard(iced::keyboard::Event::KeyPressed {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                    text,
                    repeat,
                }) => Some(Message::KeyPressed(KeyEventData {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                    text: text.map(|s| s.to_string()),
                    repeat,
                })),
                iced::Event::Keyboard(iced::keyboard::Event::KeyReleased {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                }) => Some(Message::KeyReleased(KeyEventData {
                    key,
                    modified_key,
                    physical_key,
                    location,
                    modifiers,
                    text: None,
                    repeat: false,
                })),
                iced::Event::Keyboard(iced::keyboard::Event::ModifiersChanged(mods)) => {
                    Some(Message::ModifiersChanged(mods))
                }
                // Mouse
                iced::Event::Mouse(iced::mouse::Event::CursorMoved { position }) => {
                    Some(Message::CursorMoved(position, window))
                }
                iced::Event::Mouse(iced::mouse::Event::CursorEntered) => {
                    Some(Message::CursorEntered(window))
                }
                iced::Event::Mouse(iced::mouse::Event::CursorLeft) => {
                    Some(Message::CursorLeft(window))
                }
                iced::Event::Mouse(iced::mouse::Event::ButtonPressed(button)) => {
                    Some(Message::MouseButtonPressed(button, window))
                }
                iced::Event::Mouse(iced::mouse::Event::ButtonReleased(button)) => {
                    Some(Message::MouseButtonReleased(button, window))
                }
                iced::Event::Mouse(iced::mouse::Event::WheelScrolled { delta }) => {
                    Some(Message::WheelScrolled(delta, window))
                }
                // Touch
                iced::Event::Touch(iced::touch::Event::FingerPressed { id, position }) => {
                    Some(Message::FingerPressed(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerMoved { id, position }) => {
                    Some(Message::FingerMoved(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerLifted { id, position }) => {
                    Some(Message::FingerLifted(id, position, window))
                }
                iced::Event::Touch(iced::touch::Event::FingerLost { id, position }) => {
                    Some(Message::FingerLost(id, position, window))
                }
                // IME
                iced::Event::InputMethod(iced::advanced::input_method::Event::Opened) => {
                    Some(Message::ImeOpened)
                }
                iced::Event::InputMethod(iced::advanced::input_method::Event::Preedit(
                    text,
                    cursor,
                )) => Some(Message::ImePreedit(text, cursor)),
                iced::Event::InputMethod(iced::advanced::input_method::Event::Commit(text)) => {
                    Some(Message::ImeCommit(text))
                }
                iced::Event::InputMethod(iced::advanced::input_method::Event::Closed) => {
                    Some(Message::ImeClosed)
                }
                // Window events handled by on_window_event
                _ => None,
            }));
        }

        Subscription::batch(subs)
    }

    fn apply(&mut self, message: IncomingMessage) {
        let effects = self.core.apply(message);
        for effect in effects {
            match effect {
                julep_core::CoreEffect::SyncWindows => {
                    let task = self.sync_windows();
                    self.pending_tasks.push(task);
                }
                julep_core::CoreEffect::EmitEvent(event) => emit_event(event),
                julep_core::CoreEffect::EmitEffectResponse(response) => {
                    emit_effect_response(response)
                }
                julep_core::CoreEffect::WidgetOp { op, payload } => {
                    let task = self.handle_widget_op(&op, &payload);
                    self.pending_tasks.push(task);
                }
                julep_core::CoreEffect::WindowOp {
                    op,
                    window_id,
                    settings,
                } => {
                    let task = self.handle_window_op(&op, &window_id, &settings);
                    self.pending_tasks.push(task);
                }
                julep_core::CoreEffect::ThemeChanged(theme) => {
                    self.theme = theme;
                    self.theme_follows_system = false;
                }
                julep_core::CoreEffect::ThemeFollowsSystem => {
                    self.theme_follows_system = true;
                }
                julep_core::CoreEffect::ImageOp {
                    op,
                    handle,
                    data,
                    pixels,
                    width,
                    height,
                } => {
                    self.handle_image_op(
                        &op,
                        &handle,
                        data.as_deref(),
                        pixels.as_deref(),
                        width,
                        height,
                    );
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Widget operations
    // -----------------------------------------------------------------------

    fn handle_widget_op(&mut self, op: &str, payload: &serde_json::Value) -> Task<Message> {
        let get_target = || {
            payload
                .get("target")
                .and_then(|v| v.as_str())
                .unwrap_or_default()
                .to_string()
        };

        match op {
            "focus" => {
                iced::widget::operation::focus::<Message>(iced::widget::Id::from(get_target()))
            }
            "focus_next" => iced::widget::operation::focus_next(),
            "focus_previous" => iced::widget::operation::focus_previous(),
            "scroll_to" => {
                let target = get_target();
                let offset_x = payload
                    .get("offset_x")
                    .and_then(|v| v.as_f64())
                    .map(|v| v as f32);
                let offset_y = payload
                    .get("offset")
                    .or_else(|| payload.get("offset_y"))
                    .and_then(|v| v.as_f64())
                    .map(|v| v as f32);
                iced::widget::operation::scroll_to(
                    iced::widget::Id::from(target),
                    iced::widget::operation::AbsoluteOffset {
                        x: offset_x.unwrap_or(0.0),
                        y: offset_y.unwrap_or(0.0),
                    },
                )
            }
            "scroll_by" => {
                let target = get_target();
                let offset_x = payload
                    .get("offset_x")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0) as f32;
                let offset_y = payload
                    .get("offset_y")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0) as f32;
                iced::widget::operation::scroll_by(
                    iced::widget::Id::from(target),
                    iced::widget::operation::AbsoluteOffset {
                        x: offset_x,
                        y: offset_y,
                    },
                )
            }
            "snap_to" => {
                let target = get_target();
                let x = payload.get("x").and_then(|v| v.as_f64()).map(|v| v as f32);
                let y = payload.get("y").and_then(|v| v.as_f64()).map(|v| v as f32);
                iced::widget::operation::snap_to(
                    iced::widget::Id::from(target),
                    iced::widget::operation::RelativeOffset { x, y },
                )
            }
            "snap_to_end" => {
                let target = get_target();
                iced::widget::operation::snap_to_end(iced::widget::Id::from(target))
            }
            "select_all" => {
                iced::widget::operation::select_all(iced::widget::Id::from(get_target()))
            }
            "select_range" => {
                let target = get_target();
                let start = payload.get("start").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
                let end = payload.get("end").and_then(|v| v.as_u64()).unwrap_or(0) as usize;
                iced::widget::operation::select_range(iced::widget::Id::from(target), start, end)
            }
            "move_cursor_to_front" => {
                iced::widget::operation::move_cursor_to_front(iced::widget::Id::from(get_target()))
            }
            "move_cursor_to_end" => {
                iced::widget::operation::move_cursor_to_end(iced::widget::Id::from(get_target()))
            }
            "move_cursor_to" => {
                let target = get_target();
                let position = payload
                    .get("position")
                    .and_then(|v| v.as_u64())
                    .unwrap_or(0) as usize;
                iced::widget::operation::move_cursor_to(iced::widget::Id::from(target), position)
            }
            "close_window" => {
                // Close the oldest (main) window, which triggers app exit.
                window::oldest().and_then(window::close)
            }
            "exit" => iced::exit(),
            // -- PaneGrid operations --
            // Elixir sends: target (grid id), pane, axis, new_pane_id, a, b
            "pane_split" => {
                let target = get_target();
                let pane_id = payload
                    .get("pane")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                let new_pane_id = payload
                    .get("new_pane_id")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                let axis = match payload
                    .get("axis")
                    .and_then(|v| v.as_str())
                    .unwrap_or("vertical")
                {
                    "horizontal" => pane_grid::Axis::Horizontal,
                    _ => pane_grid::Axis::Vertical,
                };

                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&target) {
                    if let Some(pane) = find_pane_by_julep_id(state, &pane_id) {
                        let _ = state.split(axis, pane, new_pane_id);
                    }
                }
                Task::none()
            }
            "pane_close" => {
                let target = get_target();
                let pane_id = payload
                    .get("pane")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();

                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&target) {
                    if let Some(pane) = find_pane_by_julep_id(state, &pane_id) {
                        let _ = state.close(pane);
                    }
                }
                Task::none()
            }
            "pane_swap" => {
                let target = get_target();
                let a_id = payload
                    .get("a")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                let b_id = payload
                    .get("b")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();

                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&target) {
                    if let (Some(a), Some(b)) = (
                        find_pane_by_julep_id(state, &a_id),
                        find_pane_by_julep_id(state, &b_id),
                    ) {
                        state.swap(a, b);
                    }
                }
                Task::none()
            }
            "pane_maximize" => {
                let target = get_target();
                let pane_id = payload
                    .get("pane")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();

                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&target) {
                    if let Some(pane) = find_pane_by_julep_id(state, &pane_id) {
                        state.maximize(pane);
                    }
                }
                Task::none()
            }
            "pane_restore" => {
                let target = get_target();

                if let Some(state) = self.core.caches.pane_grid_states.get_mut(&target) {
                    state.restore();
                }
                Task::none()
            }
            other => {
                log::warn!("unknown widget_op: {other}");
                Task::none()
            }
        }
    }

    // -----------------------------------------------------------------------
    // Image operations
    // -----------------------------------------------------------------------

    fn handle_image_op(
        &mut self,
        op: &str,
        handle: &str,
        data: Option<&[u8]>,
        pixels: Option<&[u8]>,
        width: Option<u32>,
        height: Option<u32>,
    ) {
        match op {
            "create_image" | "update_image" => {
                if let Some(pixel_bytes) = pixels {
                    // RGBA pixel data (raw bytes, no base64 decode needed)
                    let w = width.unwrap_or(0);
                    let h = height.unwrap_or(0);
                    self.image_registry.create_from_rgba(
                        handle.to_string(),
                        w,
                        h,
                        pixel_bytes.to_vec(),
                    );
                } else if let Some(image_bytes) = data {
                    // Encoded image bytes (PNG, JPEG, etc. -- raw bytes)
                    self.image_registry
                        .create_from_bytes(handle.to_string(), image_bytes.to_vec());
                } else {
                    log::warn!("image_op {op}: missing data or pixels field");
                }
            }
            "delete_image" => {
                self.image_registry.delete(handle);
            }
            other => {
                log::warn!("unknown image_op: {other}");
            }
        }
    }

    // -----------------------------------------------------------------------
    // Window operations
    // -----------------------------------------------------------------------

    fn handle_window_op(
        &mut self,
        op: &str,
        window_id: &str,
        settings: &serde_json::Value,
    ) -> Task<Message> {
        match op {
            "open" => {
                if self.window_map.contains_key(window_id) {
                    log::warn!("window_op open: {window_id} already open, skipping");
                    return Task::none();
                }

                let win_settings = parse_window_settings(settings);
                let (iced_id, open_task) = window::open(win_settings);

                self.window_map.insert(window_id.to_string(), iced_id);
                self.reverse_window_map
                    .insert(iced_id, window_id.to_string());

                let julep_id = window_id.to_string();
                open_task.map(move |id| Message::WindowOpened(id, julep_id.clone()))
            }
            "close" => {
                if let Some(iced_id) = self.window_map.remove(window_id) {
                    self.reverse_window_map.remove(&iced_id);
                    window::close(iced_id)
                } else {
                    log::warn!("window_op close: unknown window_id: {window_id}");
                    Task::none()
                }
            }
            "resize" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let w = settings
                        .get("width")
                        .and_then(|v| v.as_f64())
                        .unwrap_or(800.0) as f32;
                    let h = settings
                        .get("height")
                        .and_then(|v| v.as_f64())
                        .unwrap_or(600.0) as f32;
                    window::resize(iced_id, Size::new(w, h))
                } else {
                    Task::none()
                }
            }
            "move" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let x = settings.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                    let y = settings.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
                    window::move_to(iced_id, Point::new(x, y))
                } else {
                    Task::none()
                }
            }
            "maximize" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let maximized = settings
                        .get("maximized")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);
                    window::maximize(iced_id, maximized)
                } else {
                    Task::none()
                }
            }
            "minimize" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let minimized = settings
                        .get("minimized")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);
                    window::minimize(iced_id, minimized)
                } else {
                    Task::none()
                }
            }
            "set_mode" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let mode = parse_window_mode(settings);
                    window::set_mode(iced_id, mode)
                } else {
                    Task::none()
                }
            }
            "toggle_maximize" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    window::toggle_maximize(iced_id)
                } else {
                    Task::none()
                }
            }
            "toggle_decorations" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    window::toggle_decorations(iced_id)
                } else {
                    Task::none()
                }
            }
            "gain_focus" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    window::gain_focus(iced_id)
                } else {
                    Task::none()
                }
            }
            "set_level" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let level = parse_window_level(
                        settings
                            .get("level")
                            .and_then(|v| v.as_str())
                            .unwrap_or("normal"),
                    );
                    window::set_level(iced_id, level)
                } else {
                    Task::none()
                }
            }
            "drag" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    window::drag(iced_id)
                } else {
                    Task::none()
                }
            }
            "drag_resize" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let direction = parse_direction(
                        settings
                            .get("direction")
                            .and_then(|v| v.as_str())
                            .unwrap_or("south_east"),
                    );
                    window::drag_resize(iced_id, direction)
                } else {
                    Task::none()
                }
            }
            "request_attention" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let urgency =
                        settings
                            .get("urgency")
                            .and_then(|v| v.as_str())
                            .map(|s| match s {
                                "critical" => window::UserAttention::Critical,
                                _ => window::UserAttention::Informational,
                            });
                    window::request_user_attention(iced_id, urgency)
                } else {
                    Task::none()
                }
            }
            "show_system_menu" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    window::show_system_menu(iced_id)
                } else {
                    Task::none()
                }
            }
            "set_resizable" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let resizable = settings
                        .get("resizable")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);
                    window::set_resizable(iced_id, resizable)
                } else {
                    Task::none()
                }
            }
            "set_min_size" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let size = parse_optional_size(settings);
                    window::set_min_size(iced_id, size)
                } else {
                    Task::none()
                }
            }
            "set_max_size" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let size = parse_optional_size(settings);
                    window::set_max_size(iced_id, size)
                } else {
                    Task::none()
                }
            }
            "mouse_passthrough" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let enabled = settings
                        .get("enabled")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(true);
                    if enabled {
                        window::enable_mouse_passthrough(iced_id)
                    } else {
                        window::disable_mouse_passthrough(iced_id)
                    }
                } else {
                    Task::none()
                }
            }
            // -- Query operations: return results as effect_response --
            "get_size" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::size(iced_id).map(move |size| {
                        let resp = protocol::EffectResponse::ok(
                            wid.clone(),
                            serde_json::json!({"width": size.width, "height": size.height}),
                        );
                        emit_effect_response(resp);
                        Message::NoOp // dummy message to keep the type system happy
                    })
                } else {
                    Task::none()
                }
            }
            "get_position" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::position(iced_id).map(move |pos| {
                        let val = match pos {
                            Some(p) => serde_json::json!({"x": p.x, "y": p.y}),
                            None => serde_json::Value::Null,
                        };
                        let resp = protocol::EffectResponse::ok(wid.clone(), val);
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "get_mode" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::mode(iced_id).map(move |mode| {
                        let mode_str = match mode {
                            window::Mode::Windowed => "windowed",
                            window::Mode::Fullscreen => "fullscreen",
                            window::Mode::Hidden => "hidden",
                        };
                        let resp =
                            protocol::EffectResponse::ok(wid.clone(), serde_json::json!(mode_str));
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "get_scale_factor" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::scale_factor(iced_id).map(move |factor| {
                        let resp =
                            protocol::EffectResponse::ok(wid.clone(), serde_json::json!(factor));
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "is_maximized" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::is_maximized(iced_id).map(move |val| {
                        let resp =
                            protocol::EffectResponse::ok(wid.clone(), serde_json::json!(val));
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "is_minimized" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::is_minimized(iced_id).map(move |val| {
                        let resp =
                            protocol::EffectResponse::ok(wid.clone(), serde_json::json!(val));
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "screenshot" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::screenshot(iced_id).map(move |screenshot| {
                        #[cfg(feature = "test-mode")]
                        let rgba_b64 = {
                            Some(base64::engine::general_purpose::STANDARD.encode(&screenshot.rgba))
                        };
                        #[cfg(not(feature = "test-mode"))]
                        let rgba_b64: Option<String> = None;

                        let mut data = serde_json::json!({
                            "width": screenshot.size.width,
                            "height": screenshot.size.height,
                            "bytes_len": screenshot.rgba.len(),
                        });
                        if let Some(b64) = rgba_b64 {
                            data["rgba_base64"] = serde_json::json!(b64);
                        }
                        let resp = protocol::EffectResponse::ok(wid.clone(), data);
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "set_icon" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let icon_data_b64 = settings
                        .get("icon_data")
                        .and_then(|v| v.as_str())
                        .unwrap_or("");
                    let width = settings.get("width").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                    let height =
                        settings.get("height").and_then(|v| v.as_u64()).unwrap_or(0) as u32;

                    match base64::engine::general_purpose::STANDARD.decode(icon_data_b64) {
                        Ok(rgba) => {
                            let expected_len = (width as usize) * (height as usize) * 4;
                            if rgba.len() != expected_len {
                                log::error!(
                                    "set_icon: expected {} bytes ({}x{}x4), got {}",
                                    expected_len,
                                    width,
                                    height,
                                    rgba.len()
                                );
                                return Task::none();
                            }
                            match window::icon::from_rgba(rgba, width, height) {
                                Ok(icon) => window::set_icon(iced_id, icon),
                                Err(e) => {
                                    log::error!("set_icon: icon creation failed: {e}");
                                    Task::none()
                                }
                            }
                        }
                        Err(e) => {
                            log::error!("set_icon: base64 decode failed: {e}");
                            Task::none()
                        }
                    }
                } else {
                    Task::none()
                }
            }
            "raw_id" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::raw_id::<Message>(iced_id).map(move |raw| {
                        let resp =
                            protocol::EffectResponse::ok(wid.clone(), serde_json::json!(raw));
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            "monitor_size" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let wid = window_id.to_string();
                    window::monitor_size(iced_id).map(move |size_opt| {
                        let result = match size_opt {
                            Some(size) => {
                                serde_json::json!({"width": size.width, "height": size.height})
                            }
                            None => serde_json::Value::Null,
                        };
                        let resp = protocol::EffectResponse::ok(wid.clone(), result);
                        emit_effect_response(resp);
                        Message::NoOp
                    })
                } else {
                    Task::none()
                }
            }
            // -- System queries: not window-specific, use tag from settings --
            "get_system_theme" => {
                let tag = settings
                    .get("tag")
                    .and_then(|v| v.as_str())
                    .unwrap_or("system_theme")
                    .to_string();
                system::theme().map(move |mode| {
                    let mode_str = match mode {
                        iced::theme::Mode::Light => "light",
                        iced::theme::Mode::Dark => "dark",
                        iced::theme::Mode::None => "none",
                    };
                    emit_query_response("system_theme", &tag, serde_json::json!(mode_str));
                    Message::NoOp
                })
            }
            "get_system_info" => {
                let tag = settings
                    .get("tag")
                    .and_then(|v| v.as_str())
                    .unwrap_or("system_info")
                    .to_string();
                system::information().map(move |info| {
                    let data = serde_json::json!({
                        "system_name": info.system_name,
                        "system_kernel": info.system_kernel,
                        "system_version": info.system_version,
                        "system_short_version": info.system_short_version,
                        "cpu_brand": info.cpu_brand,
                        "cpu_cores": info.cpu_cores,
                        "memory_total": info.memory_total,
                        "memory_used": info.memory_used,
                        "graphics_backend": info.graphics_backend,
                        "graphics_adapter": info.graphics_adapter,
                    });
                    emit_query_response("system_info", &tag, data);
                    Message::NoOp
                })
            }
            "set_resize_increments" => {
                if let Some(&iced_id) = self.window_map.get(window_id) {
                    let w = settings
                        .get("width")
                        .and_then(|v| v.as_f64())
                        .map(|v| v as f32);
                    let h = settings
                        .get("height")
                        .and_then(|v| v.as_f64())
                        .map(|v| v as f32);
                    let increments = match (w, h) {
                        (Some(w), Some(h)) => Some(Size::new(w, h)),
                        _ => None,
                    };
                    window::set_resize_increments(iced_id, increments)
                } else {
                    Task::none()
                }
            }
            "allow_automatic_tabbing" => {
                let enabled = settings
                    .get("enabled")
                    .and_then(|v| v.as_bool())
                    .unwrap_or(true);
                window::allow_automatic_tabbing(enabled)
            }
            other => {
                log::warn!("unknown window_op: {other}");
                Task::none()
            }
        }
    }

    /// Compare the set of window nodes in the tree against the currently open
    /// windows and open/close as needed.
    fn sync_windows(&mut self) -> Task<Message> {
        let tree_windows: HashSet<String> = self.core.tree.window_ids().into_iter().collect();
        let open_windows: HashSet<String> = self.window_map.keys().cloned().collect();

        let mut tasks = Vec::new();

        // Open windows that exist in the tree but are not yet open.
        for win_id in &tree_windows {
            if !open_windows.contains(win_id) {
                let settings = self.window_settings_for(win_id);
                let (iced_id, open_task) = window::open(settings);
                self.window_map.insert(win_id.clone(), iced_id);
                self.reverse_window_map.insert(iced_id, win_id.clone());

                let julep_id = win_id.clone();
                tasks.push(open_task.map(move |id| Message::WindowOpened(id, julep_id.clone())));
            }
        }

        // Close windows that are open but no longer in the tree.
        for win_id in &open_windows {
            if !tree_windows.contains(win_id) {
                if let Some(iced_id) = self.window_map.remove(win_id) {
                    self.reverse_window_map.remove(&iced_id);
                    tasks.push(window::close(iced_id));
                }
            }
        }

        Task::batch(tasks)
    }

    /// Build window::Settings from a window node's props.
    fn window_settings_for(&self, julep_id: &str) -> window::Settings {
        if let Some(node) = self.core.tree.find_window(julep_id) {
            parse_window_settings(&node.props)
        } else {
            window::Settings {
                size: Size::new(800.0, 600.0),
                ..window::Settings::default()
            }
        }
    }
}

// ---------------------------------------------------------------------------
// PaneGrid helpers
// ---------------------------------------------------------------------------

/// Find a pane_grid::Pane by its julep ID string.
fn find_pane_by_julep_id(
    state: &pane_grid::State<String>,
    julep_id: &str,
) -> Option<pane_grid::Pane> {
    state
        .panes
        .iter()
        .find(|(_, id)| id.as_str() == julep_id)
        .map(|(pane, _)| *pane)
}

// ---------------------------------------------------------------------------
// Settings / enum parsing helpers
// ---------------------------------------------------------------------------

/// Parse a full `window::Settings` from a JSON value (node props or op settings).
fn parse_window_settings(v: &serde_json::Value) -> window::Settings {
    let width = v.get("width").and_then(|v| v.as_f64()).unwrap_or(800.0) as f32;
    let height = v.get("height").and_then(|v| v.as_f64()).unwrap_or(600.0) as f32;

    let maximized = v
        .get("maximized")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let fullscreen = v
        .get("fullscreen")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let visible = v.get("visible").and_then(|v| v.as_bool()).unwrap_or(true);
    let resizable = v.get("resizable").and_then(|v| v.as_bool()).unwrap_or(true);
    let closeable = v.get("closeable").and_then(|v| v.as_bool()).unwrap_or(true);
    let minimizable = v
        .get("minimizable")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);
    let decorations = v
        .get("decorations")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);
    let transparent = v
        .get("transparent")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let blur = v.get("blur").and_then(|v| v.as_bool()).unwrap_or(false);
    let exit_on_close_request = v
        .get("exit_on_close_request")
        .and_then(|v| v.as_bool())
        .unwrap_or(true);

    let position = match v.get("position") {
        Some(serde_json::Value::String(s)) if s == "centered" => window::Position::Centered,
        Some(obj) if obj.is_object() => {
            let x = obj.get("x").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            let y = obj.get("y").and_then(|v| v.as_f64()).unwrap_or(0.0) as f32;
            window::Position::Specific(Point::new(x, y))
        }
        _ => window::Position::default(),
    };

    let min_size = parse_optional_size(v.get("min_size").unwrap_or(&serde_json::Value::Null));
    let max_size = parse_optional_size(v.get("max_size").unwrap_or(&serde_json::Value::Null));

    let level = parse_window_level(v.get("level").and_then(|v| v.as_str()).unwrap_or("normal"));

    window::Settings {
        size: Size::new(width, height),
        maximized,
        fullscreen,
        position,
        min_size,
        max_size,
        visible,
        resizable,
        closeable,
        minimizable,
        decorations,
        transparent,
        blur,
        level,
        exit_on_close_request,
        ..window::Settings::default()
    }
}

fn parse_optional_size(v: &serde_json::Value) -> Option<Size> {
    if v.is_null() || !v.is_object() {
        // Also accept from the parent settings object directly for set_min_size/set_max_size ops
        let w = v.get("width").and_then(|v| v.as_f64());
        let h = v.get("height").and_then(|v| v.as_f64());
        match (w, h) {
            (Some(w), Some(h)) => Some(Size::new(w as f32, h as f32)),
            _ => None,
        }
    } else {
        let w = v.get("width").and_then(|v| v.as_f64());
        let h = v.get("height").and_then(|v| v.as_f64());
        match (w, h) {
            (Some(w), Some(h)) => Some(Size::new(w as f32, h as f32)),
            _ => None,
        }
    }
}

fn parse_window_level(s: &str) -> window::Level {
    match s {
        "always_on_top" => window::Level::AlwaysOnTop,
        "always_on_bottom" => window::Level::AlwaysOnBottom,
        _ => window::Level::Normal,
    }
}

fn parse_window_mode(v: &serde_json::Value) -> window::Mode {
    match v.get("mode").and_then(|v| v.as_str()).unwrap_or("windowed") {
        "fullscreen" => window::Mode::Fullscreen,
        "hidden" => window::Mode::Hidden,
        _ => window::Mode::Windowed,
    }
}

fn parse_direction(s: &str) -> window::Direction {
    match s {
        "north" => window::Direction::North,
        "south" => window::Direction::South,
        "east" => window::Direction::East,
        "west" => window::Direction::West,
        "north_east" => window::Direction::NorthEast,
        "north_west" => window::Direction::NorthWest,
        "south_east" => window::Direction::SouthEast,
        "south_west" => window::Direction::SouthWest,
        _ => window::Direction::SouthEast,
    }
}

// ---------------------------------------------------------------------------
// Key serialization helpers
// ---------------------------------------------------------------------------

fn serialize_key(key: &iced::keyboard::Key) -> String {
    match key {
        iced::keyboard::Key::Named(named) => format!("{named:?}"),
        iced::keyboard::Key::Character(c) => c.to_string(),
        iced::keyboard::Key::Unidentified => "Unidentified".to_string(),
    }
}

fn serialize_modifiers(mods: iced::keyboard::Modifiers) -> KeyModifiers {
    KeyModifiers {
        shift: mods.shift(),
        ctrl: mods.control(),
        alt: mods.alt(),
        logo: mods.logo(),
        command: mods.command(),
    }
}

fn serialize_physical_key(physical: &iced::keyboard::key::Physical) -> String {
    match physical {
        iced::keyboard::key::Physical::Code(code) => format!("{code:?}"),
        iced::keyboard::key::Physical::Unidentified(code) => {
            format!("Unidentified({code:?})")
        }
    }
}

fn serialize_location(location: &iced::keyboard::Location) -> &'static str {
    match location {
        iced::keyboard::Location::Standard => "standard",
        iced::keyboard::Location::Left => "left",
        iced::keyboard::Location::Right => "right",
        iced::keyboard::Location::Numpad => "numpad",
    }
}

// ---------------------------------------------------------------------------
// Mouse serialization helpers
// ---------------------------------------------------------------------------

fn serialize_mouse_button(button: &iced::mouse::Button) -> String {
    match button {
        iced::mouse::Button::Left => "left".to_string(),
        iced::mouse::Button::Right => "right".to_string(),
        iced::mouse::Button::Middle => "middle".to_string(),
        iced::mouse::Button::Back => "back".to_string(),
        iced::mouse::Button::Forward => "forward".to_string(),
        iced::mouse::Button::Other(n) => format!("other_{n}"),
    }
}

fn serialize_scroll_delta(delta: &iced::mouse::ScrollDelta) -> (f32, f32, &'static str) {
    match delta {
        iced::mouse::ScrollDelta::Lines { x, y } => (*x, *y, "lines"),
        iced::mouse::ScrollDelta::Pixels { x, y } => (*x, *y, "pixels"),
    }
}

// ---------------------------------------------------------------------------
// stdout event emitter
// ---------------------------------------------------------------------------

fn emit_event(event: OutgoingEvent) {
    let codec = WIRE_CODEC.get().unwrap_or(&codec::Codec::MsgPack);
    match codec.encode(&event) {
        Ok(bytes) => {
            let stdout = io::stdout();
            let mut handle = stdout.lock();
            if let Err(e) = handle.write_all(&bytes) {
                log::error!("failed to write event to stdout: {e}");
            }
            let _ = handle.flush();
        }
        Err(e) => log::error!("failed to serialize event: {e}"),
    }
}

// ---------------------------------------------------------------------------
// stdout effect response emitter
// ---------------------------------------------------------------------------

fn emit_effect_response(response: protocol::EffectResponse) {
    let codec = WIRE_CODEC.get().unwrap_or(&codec::Codec::MsgPack);
    match codec.encode(&response) {
        Ok(bytes) => {
            let stdout = io::stdout();
            let mut handle = stdout.lock();
            if let Err(e) = handle.write_all(&bytes) {
                log::error!("failed to write effect response to stdout: {e}");
            }
            let _ = handle.flush();
        }
        Err(e) => log::error!("failed to serialize effect response: {e}"),
    }
}

/// Emit a query_response message to stdout. Used for system-level queries
/// (system_info, system_theme) that are not window-specific.
fn emit_query_response(kind: &str, tag: &str, data: serde_json::Value) {
    let msg = serde_json::json!({
        "type": "query_response",
        "kind": kind,
        "tag": tag,
        "data": data,
    });
    let codec = WIRE_CODEC.get().unwrap_or(&codec::Codec::MsgPack);
    match codec.encode(&msg) {
        Ok(bytes) => {
            let stdout = io::stdout();
            let mut handle = stdout.lock();
            if let Err(e) = handle.write_all(&bytes) {
                log::error!("failed to write query response to stdout: {e}");
            }
            let _ = handle.flush();
        }
        Err(e) => log::error!("failed to serialize query response: {e}"),
    }
}

// ---------------------------------------------------------------------------
// stdout screenshot response emitter -- delegates to shared protocol function
// ---------------------------------------------------------------------------

/// Emit a screenshot_response to stdout (thin wrapper around shared function).
#[cfg(feature = "test-mode")]
fn emit_screenshot_response(
    id: &str,
    name: &str,
    hash: &str,
    width: u32,
    height: u32,
    rgba_bytes: &[u8],
) {
    protocol::emit_screenshot_response(id, name, hash, width, height, rgba_bytes);
}

// ---------------------------------------------------------------------------
// Message -> OutgoingEvent mapping
// ---------------------------------------------------------------------------

/// Convert a widget Message to an OutgoingEvent, if applicable.
/// Returns None for messages that don't map to user-initiated widget events
/// (Stdin, NoOp, keyboard, mouse, window lifecycle, etc.)
pub(crate) fn message_to_event(msg: &Message) -> Option<OutgoingEvent> {
    match msg {
        Message::Click(id) => Some(OutgoingEvent::click(id.clone())),
        Message::Input(id, value) => Some(OutgoingEvent::input(id.clone(), value.clone())),
        Message::Submit(id, value) => Some(OutgoingEvent::submit(id.clone(), value.clone())),
        Message::Toggle(id, value) => Some(OutgoingEvent::toggle(id.clone(), *value)),
        Message::Slide(id, value) => Some(OutgoingEvent::slide(id.clone(), *value)),
        Message::SlideRelease(id, value) => Some(OutgoingEvent::slide_release(id.clone(), *value)),
        Message::Select(id, value) => Some(OutgoingEvent::select(id.clone(), value.clone())),
        Message::SensorResize(id, w, h) => Some(OutgoingEvent::sensor_resize(id.clone(), *w, *h)),
        Message::MouseAreaEvent(id, kind) => match kind.as_str() {
            "right_press" => Some(OutgoingEvent::mouse_right_press(id.clone())),
            "right_release" => Some(OutgoingEvent::mouse_right_release(id.clone())),
            "middle_release" => Some(OutgoingEvent::mouse_middle_release(id.clone())),
            "double_click" => Some(OutgoingEvent::mouse_double_click(id.clone())),
            "enter" => Some(OutgoingEvent::mouse_enter(id.clone())),
            "exit" => Some(OutgoingEvent::mouse_exit(id.clone())),
            _ => None,
        },
        Message::MouseAreaMove(id, x, y) => {
            Some(OutgoingEvent::mouse_area_move(id.clone(), *x, *y))
        }
        Message::MouseAreaScroll(id, dx, dy) => {
            Some(OutgoingEvent::mouse_area_scroll(id.clone(), *dx, *dy))
        }
        Message::ScrollEvent(id, abs_x, abs_y, rel_x, rel_y, bw, bh, cw, ch) => {
            Some(OutgoingEvent::scroll(
                id.clone(),
                *abs_x,
                *abs_y,
                *rel_x,
                *rel_y,
                *bw,
                *bh,
                *cw,
                *ch,
            ))
        }
        Message::Event(id, data, family) => {
            let data_opt = if data.is_null() {
                None
            } else {
                Some(data.clone())
            };
            Some(OutgoingEvent::generic(
                family_str_to_static(family),
                id.clone(),
                data_opt,
            ))
        }
        _ => None,
    }
}

/// Maps dynamic family strings to static str references for OutgoingEvent.
/// Extends as new event families are added.
fn family_str_to_static(s: &str) -> &'static str {
    match s {
        "open" => "open",
        "close" => "close",
        "sort" => "sort",
        "key_binding" => "key_binding",
        _ => "event",
    }
}

// ---------------------------------------------------------------------------
// stdin subscription + reader thread
// ---------------------------------------------------------------------------

/// Async stream that yields StdinEvents. Bridges the background stdin reader
/// thread into iced's subscription system. Only wakes iced when data arrives
/// -- zero CPU when idle.
fn stdin_subscription() -> impl iced::futures::Stream<Item = StdinEvent> {
    stream::channel(32, async |mut sender| {
        let mut rx = STDIN_RX
            .lock()
            .expect("STDIN_RX lock poisoned")
            .take()
            .expect("stdin_subscription: no receiver (called more than once?)");

        while let Some(event) = rx.recv().await {
            if sender.send(event).await.is_err() {
                break;
            }
        }
    })
}

fn spawn_stdin_reader(
    sender: tokio::sync::mpsc::Sender<StdinEvent>,
    mut reader: io::BufReader<io::Stdin>,
) {
    thread::spawn(move || {
        let codec = WIRE_CODEC.get().expect("WIRE_CODEC not initialized");

        loop {
            match codec.read_message(&mut reader) {
                Ok(None) => {
                    let _ = sender.blocking_send(StdinEvent::Closed);
                    break;
                }
                Ok(Some(bytes)) => match codec.decode::<IncomingMessage>(&bytes) {
                    Ok(msg) => {
                        if sender.blocking_send(StdinEvent::Message(msg)).is_err() {
                            return;
                        }
                    }
                    Err(e) => {
                        let warning = format!("parse error: {e}");
                        if sender.blocking_send(StdinEvent::Warning(warning)).is_err() {
                            return;
                        }
                    }
                },
                Err(e) => {
                    let _ = sender.blocking_send(StdinEvent::Warning(format!("read error: {e}")));
                    let _ = sender.blocking_send(StdinEvent::Closed);
                    break;
                }
            }
        }
    });
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Read the first message from stdin synchronously, expecting a Settings message.
/// Determines the wire codec (from CLI flag or auto-detection) and stores it in
/// `WIRE_CODEC`. Returns the settings Value, iced Settings, font bytes, and
/// the buffered reader (to be handed off to the stdin reader thread).
fn read_initial_settings(
    forced_codec: Option<codec::Codec>,
) -> (
    Value,
    iced::Settings,
    Vec<Vec<u8>>,
    io::BufReader<io::Stdin>,
) {
    let mut reader = io::BufReader::new(io::stdin());

    // Determine codec: forced by CLI flag, or auto-detected from first byte.
    //
    // Auto-detect reads one byte to determine the format: '{' (0x7B) = JSON,
    // anything else = MsgPack length prefix. We use read_exact (blocking) rather
    // than fill_buf (non-blocking peek) because fill_buf on a pipe can return
    // empty before the writer has sent any data, causing a false EOF.
    //
    // Since the detection byte is consumed, we read the rest of the first
    // message manually (the remaining 3 bytes of the MsgPack length prefix,
    // or the rest of the JSON line).
    let (codec, first_byte) = match forced_codec {
        Some(c) => (c, None),
        None => {
            let mut first = [0u8; 1];
            match reader.read_exact(&mut first) {
                Ok(()) => {}
                Err(e) => {
                    log::error!("stdin closed before settings received: {e}");
                    let _ = WIRE_CODEC.set(codec::Codec::MsgPack);
                    return (
                        Value::Object(Default::default()),
                        iced::Settings::default(),
                        Vec::new(),
                        reader,
                    );
                }
            }
            (
                codec::Codec::detect_from_first_byte(first[0]),
                Some(first[0]),
            )
        }
    };
    log::info!("wire codec: {codec:?}");
    WIRE_CODEC
        .set(codec)
        .expect("WIRE_CODEC already initialized");

    // Read the first framed message. If we consumed a detection byte, we need
    // to account for it when reading the rest of the message.
    let payload = if let Some(byte) = first_byte {
        match codec {
            codec::Codec::MsgPack => {
                // byte is the first of the 4-byte BE length prefix. Read 3 more.
                let mut rest = [0u8; 3];
                if let Err(e) = reader.read_exact(&mut rest) {
                    log::error!("failed to read initial settings: {e}");
                    return (
                        Value::Object(Default::default()),
                        iced::Settings::default(),
                        Vec::new(),
                        reader,
                    );
                }
                let len = u32::from_be_bytes([byte, rest[0], rest[1], rest[2]]) as usize;
                let mut payload = vec![0u8; len];
                if let Err(e) = reader.read_exact(&mut payload) {
                    log::error!("failed to read initial settings payload: {e}");
                    return (
                        Value::Object(Default::default()),
                        iced::Settings::default(),
                        Vec::new(),
                        reader,
                    );
                }
                payload
            }
            codec::Codec::Json => {
                // byte is '{'. Read the rest of the line, prepend '{'.
                let mut line = String::new();
                if let Err(e) = reader.read_line(&mut line) {
                    log::error!("failed to read initial settings: {e}");
                    return (
                        Value::Object(Default::default()),
                        iced::Settings::default(),
                        Vec::new(),
                        reader,
                    );
                }
                let full = format!("{}{}", byte as char, line.trim());
                full.into_bytes()
            }
        }
    } else {
        // Forced codec -- no detection byte consumed. Use normal read_message.
        match codec.read_message(&mut reader) {
            Ok(Some(bytes)) => bytes,
            Ok(None) => {
                log::error!("stdin closed before settings received");
                return (
                    Value::Object(Default::default()),
                    iced::Settings::default(),
                    Vec::new(),
                    reader,
                );
            }
            Err(e) => {
                log::error!("failed to read initial settings: {e}");
                return (
                    Value::Object(Default::default()),
                    iced::Settings::default(),
                    Vec::new(),
                    reader,
                );
            }
        }
    };

    // Decode the payload into an IncomingMessage.
    let msg: IncomingMessage = match codec.decode(&payload) {
        Ok(m) => m,
        Err(err) => {
            log::error!("failed to decode initial settings: {err}");
            if forced_codec.is_some() {
                // Emit error in the forced codec's format so the client can decode it.
                let error = serde_json::json!({"type": "error", "message": format!("decode failed: {err}")});
                let fallback =
                    format!("{{\"type\":\"error\",\"message\":\"decode failed: {err}\"}}\n");
                let bytes = codec
                    .encode(&error)
                    .unwrap_or_else(|_| fallback.into_bytes());
                let _ = io::stdout().lock().write_all(&bytes);
                let _ = io::stdout().lock().flush();
            } else {
                // No forced codec -- emit plain JSON error for diagnostics.
                let error_msg = format!(
                    "{{\"type\":\"error\",\"message\":\"failed to decode initial settings: {err}\"}}\n"
                );
                let _ = io::stdout().lock().write_all(error_msg.as_bytes());
                let _ = io::stdout().lock().flush();
            }
            std::process::exit(1);
        }
    };

    // Extract Settings variant.
    match msg {
        IncomingMessage::Settings { settings } => {
            log::info!("initial settings received");
            let antialiasing = settings
                .get("antialiasing")
                .and_then(|v| v.as_bool())
                .unwrap_or(false);
            let vsync = settings
                .get("vsync")
                .and_then(|v| v.as_bool())
                .unwrap_or(true);
            let iced_settings = iced::Settings {
                antialiasing,
                vsync,
                ..Default::default()
            };

            let mut font_bytes: Vec<Vec<u8>> = Vec::new();
            if let Some(fonts) = settings.get("fonts").and_then(|v| v.as_array()) {
                for font_val in fonts {
                    if let Some(path) = font_val.as_str() {
                        match std::fs::read(path) {
                            Ok(bytes) => {
                                log::info!("loaded font: {path}");
                                font_bytes.push(bytes);
                            }
                            Err(e) => {
                                log::error!("failed to load font {path}: {e}");
                            }
                        }
                    }
                }
            }

            (settings, iced_settings, font_bytes, reader)
        }
        other => {
            let variant = match &other {
                IncomingMessage::Snapshot { .. } => "snapshot",
                IncomingMessage::Patch { .. } => "patch",
                IncomingMessage::EffectRequest { .. } => "effect_request",
                IncomingMessage::WidgetOp { .. } => "widget_op",
                IncomingMessage::SubscriptionRegister { .. } => "subscription_register",
                IncomingMessage::SubscriptionUnregister { .. } => "subscription_unregister",
                IncomingMessage::WindowOp { .. } => "window_op",
                IncomingMessage::Settings { .. } => "settings",
                IncomingMessage::Query { .. } => "query",
                IncomingMessage::Interact { .. } => "interact",
                IncomingMessage::SnapshotCapture { .. } => "snapshot_capture",
                IncomingMessage::ScreenshotCapture { .. } => "screenshot_capture",
                IncomingMessage::Reset { .. } => "reset",
                IncomingMessage::ImageOp { .. } => "image_op",
            };
            log::error!("expected settings as first message, got {variant}");
            (
                Value::Object(Default::default()),
                iced::Settings::default(),
                Vec::new(),
                reader,
            )
        }
    }
}

fn main() -> iced::Result {
    let args: Vec<String> = std::env::args().collect();

    // Levelled logging via RUST_LOG. Default: warn (quiet). Use
    // RUST_LOG=julep_gui=debug (or =info, =trace) for more output.
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn")).init();

    // Parse codec flags early so all modes (headless, test, normal) can use them.
    let forced_codec = if args.contains(&"--msgpack".to_string()) {
        Some(codec::Codec::MsgPack)
    } else if args.contains(&"--json".to_string()) {
        Some(codec::Codec::Json)
    } else {
        None
    };

    #[cfg(feature = "headless")]
    {
        if args.contains(&"--headless".to_string()) {
            headless::headless_mode::run(forced_codec);
            return Ok(());
        }
    }

    let test_mode = args.contains(&"--test".to_string());

    // Read the first message synchronously to get iced settings and font
    // data before the daemon starts. This must happen before the stdin
    // reader thread is spawned.
    let (initial_settings, iced_settings, font_bytes, reader) = read_initial_settings(forced_codec);

    // Spawn stdin reader thread with tokio channel. The receiver goes into
    // STDIN_RX so the subscription (which is a fn pointer, not a closure)
    // can take it once on first call.
    let (tx, rx) = tokio::sync::mpsc::channel::<StdinEvent>(64);
    spawn_stdin_reader(tx, reader);
    *STDIN_RX.lock().expect("STDIN_RX lock poisoned") = Some(rx);

    let settings_slot: Mutex<Option<(Value, Vec<Vec<u8>>)>> =
        Mutex::new(Some((initial_settings, font_bytes)));

    iced::daemon(
        move || {
            let (settings, fonts) = settings_slot
                .lock()
                .expect("settings_slot lock poisoned")
                .take()
                .unwrap_or_default();

            let mut app = App::new(test_mode);

            // Extract scale_factor before applying settings to Core
            app.scale_factor = settings
                .get("scale_factor")
                .and_then(|v| v.as_f64())
                .map(|v| v as f32)
                .unwrap_or(1.0);

            // Apply initial settings to Core (Settings doesn't produce effects)
            let _ = app.core.apply(IncomingMessage::Settings { settings });

            // Build font load tasks
            let font_tasks: Vec<Task<Message>> = fonts
                .into_iter()
                .map(|bytes| {
                    iced::font::load(bytes).map(|result| {
                        if let Err(e) = result {
                            log::error!("font load error: {e:?}");
                        }
                        Message::NoOp
                    })
                })
                .collect();

            let task = if font_tasks.is_empty() {
                Task::none()
            } else {
                Task::batch(font_tasks)
            };

            (app, task)
        },
        App::update,
        App::view_window,
    )
    .title(App::title_for_window)
    .subscription(App::subscription)
    .theme(App::theme_for_window)
    .scale_factor(App::scale_factor_for_window)
    .settings(iced_settings)
    .run()
}
