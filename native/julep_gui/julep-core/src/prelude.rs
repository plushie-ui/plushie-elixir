//! Common re-exports for widget extension authors.
//!
//! ```ignore
//! use julep_core::prelude::*;
//! ```

// Core extension types
pub use crate::extensions::{
    EventResult, ExtensionCaches, ExtensionDispatcher, RenderContext, WidgetEnv, WidgetExtension,
};

// Wire types
pub use crate::message::Message;
pub use crate::protocol::{OutgoingEvent, TreeNode};

// Renderer internals extensions may need
pub use crate::image_registry::ImageRegistry;
pub use crate::widgets::WidgetCaches;

// Prop helpers
pub use crate::prop_helpers::*;

// Commonly needed iced types
pub use iced::widget::text;
pub use iced::Element;
pub use iced::Theme;

// JSON (extensions parse props from serde_json::Value)
pub use serde_json::Value;
