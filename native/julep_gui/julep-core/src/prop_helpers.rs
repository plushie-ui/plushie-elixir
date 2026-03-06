//! Public prop extraction helpers for widget extensions.
//!
//! These functions provide a convenient API for reading typed values from
//! `TreeNode.props`. Extension authors use these in their `render()` and
//! `prepare()` implementations instead of manually traversing `serde_json::Value`.

use iced::{alignment, Color, ContentFit, Length};
use serde_json::Value;

use crate::protocol::TreeNode;
use crate::theming::parse_hex_color;

// ---------------------------------------------------------------------------
// Internal props accessor
// ---------------------------------------------------------------------------

type Props<'a> = Option<&'a serde_json::Map<String, Value>>;

fn props(node: &TreeNode) -> Props<'_> {
    node.props.as_object()
}

// ---------------------------------------------------------------------------
// Core prop helpers
// ---------------------------------------------------------------------------

/// Get a string prop value.
pub fn prop_str(node: &TreeNode, key: &str) -> Option<String> {
    props(node)?.get(key)?.as_str().map(str::to_owned)
}

/// Get an f32 prop value. Accepts both JSON numbers and numeric strings.
pub fn prop_f32(node: &TreeNode, key: &str) -> Option<f32> {
    let val = props(node)?.get(key)?;
    match val {
        Value::Number(n) => n.as_f64().map(|v| v as f32),
        Value::String(s) => s.trim().parse::<f32>().ok(),
        _ => None,
    }
}

/// Get an f64 prop value. Accepts both JSON numbers and numeric strings.
pub fn prop_f64(node: &TreeNode, key: &str) -> Option<f64> {
    let val = props(node)?.get(key)?;
    match val {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.trim().parse::<f64>().ok(),
        _ => None,
    }
}

/// Get a boolean prop value.
pub fn prop_bool(node: &TreeNode, key: &str) -> Option<bool> {
    props(node)?.get(key)?.as_bool()
}

/// Get a boolean prop value with a default.
pub fn prop_bool_default(node: &TreeNode, key: &str, default: bool) -> bool {
    prop_bool(node, key).unwrap_or(default)
}

/// Get a Length prop value, returning `fallback` when absent or unparseable.
pub fn prop_length(node: &TreeNode, key: &str, fallback: Length) -> Length {
    props(node)
        .and_then(|p| p.get(key))
        .and_then(value_to_length)
        .unwrap_or(fallback)
}

/// Parse a "range" prop as `[min, max]` into an inclusive `f32` range.
pub fn prop_range_f32(node: &TreeNode) -> std::ops::RangeInclusive<f32> {
    props(node)
        .and_then(|p| p.get("range"))
        .and_then(|v| v.as_array())
        .and_then(|arr| {
            let min = arr.first()?.as_f64()? as f32;
            let max = arr.get(1)?.as_f64()? as f32;
            Some(min..=max)
        })
        .unwrap_or(0.0..=100.0)
}

/// Parse a "range" prop as `[min, max]` into an inclusive `f64` range.
pub fn prop_range_f64(node: &TreeNode) -> std::ops::RangeInclusive<f64> {
    props(node)
        .and_then(|p| p.get("range"))
        .and_then(|v| v.as_array())
        .and_then(|arr| {
            let min = arr.first()?.as_f64()?;
            let max = arr.get(1)?.as_f64()?;
            Some(min..=max)
        })
        .unwrap_or(0.0..=100.0)
}

/// Parse a hex color string prop (`#RRGGBB` or `#RRGGBBAA`) to `iced::Color`.
pub fn prop_color(node: &TreeNode, key: &str) -> Option<Color> {
    let hex = prop_str(node, key)?;
    parse_hex_color(&hex)
}

/// Get an array of f32 values from a prop.
pub fn prop_f32_array(node: &TreeNode, key: &str) -> Option<Vec<f32>> {
    props(node)?.get(key)?.as_array().map(|arr| {
        arr.iter()
            .filter_map(|v| v.as_f64().map(|f| f as f32))
            .collect()
    })
}

/// Parse a horizontal alignment prop.
pub fn prop_horizontal_alignment(node: &TreeNode, key: &str) -> alignment::Horizontal {
    props(node)
        .and_then(|p| p.get(key))
        .and_then(|v| v.as_str())
        .and_then(value_to_horizontal_alignment)
        .unwrap_or(alignment::Horizontal::Left)
}

/// Parse a vertical alignment prop.
pub fn prop_vertical_alignment(node: &TreeNode, key: &str) -> alignment::Vertical {
    props(node)
        .and_then(|p| p.get(key))
        .and_then(|v| v.as_str())
        .and_then(value_to_vertical_alignment)
        .unwrap_or(alignment::Vertical::Top)
}

/// Parse a content-fit prop.
pub fn prop_content_fit(node: &TreeNode) -> Option<ContentFit> {
    let s = prop_str(node, "content_fit")?;
    match s.to_ascii_lowercase().as_str() {
        "contain" => Some(ContentFit::Contain),
        "cover" => Some(ContentFit::Cover),
        "fill" => Some(ContentFit::Fill),
        "none" => Some(ContentFit::None),
        "scale_down" => Some(ContentFit::ScaleDown),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Value conversion helpers (also public for advanced use)
// ---------------------------------------------------------------------------

/// Convert a JSON value to an iced Length.
pub fn value_to_length(val: &Value) -> Option<Length> {
    match val {
        Value::Number(n) => n
            .as_f64()
            .map(|v| v as f32)
            .filter(|v| *v >= 0.0)
            .map(Length::Fixed),
        Value::String(s) => match s.trim().to_ascii_lowercase().as_str() {
            "fill" | "full" | "expand" | "stretch" => Some(Length::Fill),
            "shrink" | "auto" | "fit" => Some(Length::Shrink),
            other => other
                .parse::<f32>()
                .ok()
                .filter(|v| *v >= 0.0)
                .map(Length::Fixed),
        },
        Value::Object(obj) => {
            if let Some(n) = obj.get("fill_portion").and_then(|v| v.as_u64()) {
                Some(Length::FillPortion(n as u16))
            } else {
                Some(Length::Shrink)
            }
        }
        _ => None,
    }
}

fn value_to_horizontal_alignment(s: &str) -> Option<alignment::Horizontal> {
    match s.trim().to_ascii_lowercase().as_str() {
        "left" | "start" => Some(alignment::Horizontal::Left),
        "center" => Some(alignment::Horizontal::Center),
        "right" | "end" => Some(alignment::Horizontal::Right),
        _ => None,
    }
}

fn value_to_vertical_alignment(s: &str) -> Option<alignment::Vertical> {
    match s.trim().to_ascii_lowercase().as_str() {
        "top" | "start" => Some(alignment::Vertical::Top),
        "center" => Some(alignment::Vertical::Center),
        "bottom" | "end" => Some(alignment::Vertical::Bottom),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn make_node(props: Value) -> TreeNode {
        TreeNode {
            id: "test".to_string(),
            type_name: "test".to_string(),
            props,
            children: vec![],
        }
    }

    #[test]
    fn test_prop_str() {
        let node = make_node(json!({"label": "hello"}));
        assert_eq!(prop_str(&node, "label"), Some("hello".to_string()));
        assert_eq!(prop_str(&node, "missing"), None);
    }

    #[test]
    fn test_prop_str_non_string() {
        let node = make_node(json!({"num": 42}));
        assert_eq!(prop_str(&node, "num"), None);
    }

    #[test]
    fn test_prop_f32_number() {
        let node = make_node(json!({"size": 14.5}));
        let v = prop_f32(&node, "size").unwrap();
        assert!((v - 14.5).abs() < 0.001);
    }

    #[test]
    fn test_prop_f32_string() {
        let node = make_node(json!({"size": "14.5"}));
        let v = prop_f32(&node, "size").unwrap();
        assert!((v - 14.5).abs() < 0.001);
    }

    #[test]
    fn test_prop_f32_missing() {
        let node = make_node(json!({}));
        assert!(prop_f32(&node, "size").is_none());
    }

    #[test]
    fn test_prop_f64_number() {
        let node = make_node(json!({"value": 99.9}));
        let v = prop_f64(&node, "value").unwrap();
        assert!((v - 99.9).abs() < 0.0001);
    }

    #[test]
    fn test_prop_f64_string() {
        let node = make_node(json!({"value": "99.9"}));
        let v = prop_f64(&node, "value").unwrap();
        assert!((v - 99.9).abs() < 0.0001);
    }

    #[test]
    fn test_prop_bool() {
        let node = make_node(json!({"disabled": true}));
        assert_eq!(prop_bool(&node, "disabled"), Some(true));
        assert_eq!(prop_bool(&node, "missing"), None);
    }

    #[test]
    fn test_prop_bool_default() {
        let node = make_node(json!({"disabled": true}));
        assert!(prop_bool_default(&node, "disabled", false));
        assert!(!prop_bool_default(&node, "missing", false));
        assert!(prop_bool_default(&node, "missing", true));
    }

    #[test]
    fn test_prop_length_fixed() {
        let node = make_node(json!({"width": 100}));
        let len = prop_length(&node, "width", Length::Shrink);
        assert!(matches!(len, Length::Fixed(v) if (v - 100.0).abs() < 0.001));
    }

    #[test]
    fn test_prop_length_fill() {
        let node = make_node(json!({"width": "fill"}));
        let len = prop_length(&node, "width", Length::Shrink);
        assert!(matches!(len, Length::Fill));
    }

    #[test]
    fn test_prop_length_fallback() {
        let node = make_node(json!({}));
        let len = prop_length(&node, "width", Length::Shrink);
        assert!(matches!(len, Length::Shrink));
    }

    #[test]
    fn test_prop_range_f32_present() {
        let node = make_node(json!({"range": [10.0, 50.0]}));
        let r = prop_range_f32(&node);
        assert_eq!(*r.start(), 10.0);
        assert_eq!(*r.end(), 50.0);
    }

    #[test]
    fn test_prop_range_f32_default() {
        let node = make_node(json!({}));
        let r = prop_range_f32(&node);
        assert_eq!(*r.start(), 0.0);
        assert_eq!(*r.end(), 100.0);
    }

    #[test]
    fn test_prop_range_f64_present() {
        let node = make_node(json!({"range": [1.0, 2.0]}));
        let r = prop_range_f64(&node);
        assert_eq!(*r.start(), 1.0);
        assert_eq!(*r.end(), 2.0);
    }

    #[test]
    fn test_prop_color_valid() {
        let node = make_node(json!({"bg": "#ff0000"}));
        let c = prop_color(&node, "bg").unwrap();
        assert!((c.r - 1.0).abs() < 0.01);
        assert!(c.g.abs() < 0.01);
        assert!(c.b.abs() < 0.01);
    }

    #[test]
    fn test_prop_color_with_alpha() {
        let node = make_node(json!({"bg": "#ff000080"}));
        let c = prop_color(&node, "bg").unwrap();
        assert!((c.a - 0.502).abs() < 0.01);
    }

    #[test]
    fn test_prop_color_invalid() {
        let node = make_node(json!({"bg": "not-a-color"}));
        assert!(prop_color(&node, "bg").is_none());
    }

    #[test]
    fn test_prop_color_missing() {
        let node = make_node(json!({}));
        assert!(prop_color(&node, "bg").is_none());
    }

    #[test]
    fn test_prop_f32_array() {
        let node = make_node(json!({"data": [1.0, 2.5, 3.0]}));
        let arr = prop_f32_array(&node, "data").unwrap();
        assert_eq!(arr.len(), 3);
        assert!((arr[0] - 1.0).abs() < 0.001);
        assert!((arr[1] - 2.5).abs() < 0.001);
        assert!((arr[2] - 3.0).abs() < 0.001);
    }

    #[test]
    fn test_prop_f32_array_empty() {
        let node = make_node(json!({"data": []}));
        let arr = prop_f32_array(&node, "data").unwrap();
        assert!(arr.is_empty());
    }

    #[test]
    fn test_prop_f32_array_missing() {
        let node = make_node(json!({}));
        assert!(prop_f32_array(&node, "data").is_none());
    }

    #[test]
    fn test_prop_f32_array_not_array() {
        let node = make_node(json!({"data": "nope"}));
        assert!(prop_f32_array(&node, "data").is_none());
    }

    #[test]
    fn test_prop_horizontal_alignment() {
        let node = make_node(json!({"align": "center"}));
        assert!(matches!(
            prop_horizontal_alignment(&node, "align"),
            alignment::Horizontal::Center
        ));
    }

    #[test]
    fn test_prop_horizontal_alignment_default() {
        let node = make_node(json!({}));
        assert!(matches!(
            prop_horizontal_alignment(&node, "align"),
            alignment::Horizontal::Left
        ));
    }

    #[test]
    fn test_prop_vertical_alignment() {
        let node = make_node(json!({"valign": "bottom"}));
        assert!(matches!(
            prop_vertical_alignment(&node, "valign"),
            alignment::Vertical::Bottom
        ));
    }

    #[test]
    fn test_prop_content_fit() {
        let node = make_node(json!({"content_fit": "cover"}));
        assert_eq!(prop_content_fit(&node), Some(ContentFit::Cover));
    }

    #[test]
    fn test_prop_content_fit_missing() {
        let node = make_node(json!({}));
        assert_eq!(prop_content_fit(&node), None);
    }

    #[test]
    fn test_value_to_length_fill_portion() {
        let val = json!({"fill_portion": 3});
        let len = value_to_length(&val).unwrap();
        assert!(matches!(len, Length::FillPortion(3)));
    }

    #[test]
    fn test_empty_props() {
        let node = TreeNode {
            id: "x".to_string(),
            type_name: "x".to_string(),
            props: Value::Null,
            children: vec![],
        };
        assert!(prop_str(&node, "anything").is_none());
        assert!(prop_f32(&node, "anything").is_none());
        assert!(prop_bool(&node, "anything").is_none());
    }
}
