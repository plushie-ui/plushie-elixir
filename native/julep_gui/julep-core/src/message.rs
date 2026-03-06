// message.rs - Message enum and serialization helpers
//
// Extracted from main.rs so that julep-core modules (widgets, overlay_widget,
// protocol) can reference Message without depending on the binary crate.

#[cfg(feature = "widget-markdown")]
use iced::widget::markdown;
use iced::widget::text_editor;
use iced::{window, Point};
use serde_json::Value;

use crate::protocol::KeyModifiers;

// ---------------------------------------------------------------------------
// Keyboard event data
// ---------------------------------------------------------------------------

/// All fields from an iced keyboard event, packed for Message transport.
#[derive(Debug, Clone)]
pub struct KeyEventData {
    pub key: iced::keyboard::Key,
    pub modified_key: iced::keyboard::Key,
    pub physical_key: iced::keyboard::key::Physical,
    pub location: iced::keyboard::Location,
    pub modifiers: iced::keyboard::Modifiers,
    pub text: Option<String>,
    pub repeat: bool,
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub enum Message {
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
    #[cfg(feature = "widget-markdown")]
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
    #[cfg(feature = "widget-canvas")]
    CanvasEvent(String, String, f32, f32, String),
    /// Canvas scroll event (id, cursor_x, cursor_y, delta_x, delta_y).
    #[cfg(feature = "widget-canvas")]
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

/// What the stdin reader thread sends back.
#[derive(Debug, Clone)]
pub enum StdinEvent {
    Message(crate::protocol::IncomingMessage),
    Closed,
    Warning(String),
}

// ---------------------------------------------------------------------------
// Key serialization helpers
// ---------------------------------------------------------------------------

pub fn serialize_key(key: &iced::keyboard::Key) -> String {
    match key {
        iced::keyboard::Key::Named(named) => format!("{named:?}"),
        iced::keyboard::Key::Character(c) => c.to_string(),
        iced::keyboard::Key::Unidentified => "Unidentified".to_string(),
    }
}

pub fn serialize_modifiers(mods: iced::keyboard::Modifiers) -> KeyModifiers {
    KeyModifiers {
        shift: mods.shift(),
        ctrl: mods.control(),
        alt: mods.alt(),
        logo: mods.logo(),
        command: mods.command(),
    }
}

pub fn serialize_physical_key(physical: &iced::keyboard::key::Physical) -> String {
    match physical {
        iced::keyboard::key::Physical::Code(code) => format!("{code:?}"),
        iced::keyboard::key::Physical::Unidentified(code) => {
            format!("Unidentified({code:?})")
        }
    }
}

pub fn serialize_location(location: &iced::keyboard::Location) -> &'static str {
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

pub fn serialize_mouse_button(button: &iced::mouse::Button) -> String {
    match button {
        iced::mouse::Button::Left => "left".to_string(),
        iced::mouse::Button::Right => "right".to_string(),
        iced::mouse::Button::Middle => "middle".to_string(),
        iced::mouse::Button::Back => "back".to_string(),
        iced::mouse::Button::Forward => "forward".to_string(),
        iced::mouse::Button::Other(n) => format!("other_{n}"),
    }
}

pub fn serialize_scroll_delta(delta: &iced::mouse::ScrollDelta) -> (f32, f32, &'static str) {
    match delta {
        iced::mouse::ScrollDelta::Lines { x, y } => (*x, *y, "lines"),
        iced::mouse::ScrollDelta::Pixels { x, y } => (*x, *y, "pixels"),
    }
}
