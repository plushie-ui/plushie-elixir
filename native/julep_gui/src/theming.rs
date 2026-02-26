use iced::{Color, Theme};
use serde_json::Value;

// ---------------------------------------------------------------------------
// Theme resolution
// ---------------------------------------------------------------------------

// Note: iced's Palette does not include a warning color. Custom warning
// colors are not supported.

/// Result of resolving a theme from JSON.
pub struct ThemeResult {
    pub theme: Theme,
}

/// Resolve a JSON value into an iced Theme.
///
/// Accepts a string name (case-insensitive, underscored) or a JSON object
/// describing a custom palette. Unknown values fall back to Dark.
pub fn resolve_theme(value: &Value) -> ThemeResult {
    match value {
        Value::String(s) => ThemeResult {
            theme: resolve_builtin(s),
        },
        Value::Object(map) => {
            let theme = custom_theme_from_object(map);
            ThemeResult { theme }
        }
        _ => ThemeResult {
            theme: Theme::Dark,
        },
    }
}

/// Convenience: resolve and return just the Theme, discarding the wrapper.
pub fn resolve_theme_only(value: &Value) -> Theme {
    resolve_theme(value).theme
}

// ---------------------------------------------------------------------------
// Built-in theme resolution
// ---------------------------------------------------------------------------

/// Map a string name to a built-in iced theme variant.
fn resolve_builtin(s: &str) -> Theme {
    match s.to_ascii_lowercase().as_str() {
        "light" => Theme::Light,
        "dark" => Theme::Dark,
        "dracula" => Theme::Dracula,
        "nord" => Theme::Nord,
        "solarized_light" => Theme::SolarizedLight,
        "solarized_dark" => Theme::SolarizedDark,
        "gruvbox_light" => Theme::GruvboxLight,
        "gruvbox_dark" => Theme::GruvboxDark,
        "catppuccin_latte" => Theme::CatppuccinLatte,
        "catppuccin_frappe" => Theme::CatppuccinFrappe,
        "catppuccin_macchiato" => Theme::CatppuccinMacchiato,
        "catppuccin_mocha" => Theme::CatppuccinMocha,
        "tokyo_night" => Theme::TokyoNight,
        "tokyo_night_storm" => Theme::TokyoNightStorm,
        "tokyo_night_light" => Theme::TokyoNightLight,
        "kanagawa_wave" => Theme::KanagawaWave,
        "kanagawa_dragon" => Theme::KanagawaDragon,
        "kanagawa_lotus" => Theme::KanagawaLotus,
        "moonfly" => Theme::Moonfly,
        "nightfly" => Theme::Nightfly,
        "oxocarbon" => Theme::Oxocarbon,
        "ferra" => Theme::Ferra,
        _ => Theme::Dark,
    }
}

// ---------------------------------------------------------------------------
// Custom theme from JSON object
// ---------------------------------------------------------------------------

/// Build a custom theme from a JSON object.
///
/// Supported fields (all optional):
/// - "name"       - display name for the theme (default: "Custom")
/// - "base"       - built-in theme name whose palette is used as the starting
///                  point (default: dark)
/// - "background" - hex color string, e.g. "#1a1b26"
/// - "text"       - hex color string
/// - "primary"    - hex color string
/// - "success"    - hex color string
/// - "danger"     - hex color string
fn custom_theme_from_object(obj: &serde_json::Map<String, Value>) -> Theme {
    let base_theme = obj
        .get("base")
        .and_then(|v| v.as_str())
        .map(resolve_builtin)
        .unwrap_or(Theme::Dark);

    let mut palette = base_theme.palette();

    if let Some(color) = get_color(obj, "background") {
        palette.background = color;
    }
    if let Some(color) = get_color(obj, "text") {
        palette.text = color;
    }
    if let Some(color) = get_color(obj, "primary") {
        palette.primary = color;
    }
    if let Some(color) = get_color(obj, "success") {
        palette.success = color;
    }
    if let Some(color) = get_color(obj, "danger") {
        palette.danger = color;
    }

    let name = obj
        .get("name")
        .and_then(|v| v.as_str())
        .unwrap_or("Custom")
        .to_owned();

    Theme::custom(name, palette)
}

// ---------------------------------------------------------------------------
// Color parsing
// ---------------------------------------------------------------------------

/// Extract a hex color value from a JSON object field.
fn get_color(obj: &serde_json::Map<String, Value>, key: &str) -> Option<Color> {
    obj.get(key)
        .and_then(|v| v.as_str())
        .and_then(parse_hex_color)
}

/// Parse a hex color string like "#rrggbb" or "#rrggbbaa" into an iced Color.
pub fn parse_hex_color(hex: &str) -> Option<Color> {
    let hex = hex.trim_start_matches('#');
    if hex.len() == 6 {
        let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
        let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
        let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
        Some(Color::from_rgb8(r, g, b))
    } else if hex.len() == 8 {
        let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
        let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
        let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
        let a = u8::from_str_radix(&hex[6..8], 16).ok()?;
        Some(Color::from_rgba8(r, g, b, a as f32 / 255.0))
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use iced::theme::Palette;
    use serde_json::json;

    #[test]
    fn resolve_builtin_themes() {
        assert!(matches!(
            resolve_theme(&json!("Dark")).theme,
            Theme::Dark
        ));
        assert!(matches!(
            resolve_theme(&json!("nord")).theme,
            Theme::Nord
        ));
        assert!(matches!(
            resolve_theme(&json!("CATPPUCCIN_MOCHA")).theme,
            Theme::CatppuccinMocha
        ));
    }

    #[test]
    fn unknown_string_falls_back_to_dark() {
        assert!(matches!(
            resolve_theme(&json!("neon_pink")).theme,
            Theme::Dark
        ));
    }

    #[test]
    fn custom_theme_minimal() {
        let val = json!({"name": "Mine"});
        let result = resolve_theme(&val);
        assert_eq!(format!("{}", result.theme), "Mine");
    }

    #[test]
    fn custom_theme_with_colors() {
        let val = json!({
            "name": "Tokyo Remix",
            "background": "#1a1b26",
            "text": "#c0caf5",
            "primary": "#7aa2f7",
            "success": "#9ece6a",
            "danger": "#f7768e"
        });
        let result = resolve_theme(&val);
        let p = result.theme.palette();
        assert_eq!(p.background, Color::from_rgb8(0x1a, 0x1b, 0x26));
        assert_eq!(p.text, Color::from_rgb8(0xc0, 0xca, 0xf5));
        assert_eq!(p.primary, Color::from_rgb8(0x7a, 0xa2, 0xf7));
        assert_eq!(p.success, Color::from_rgb8(0x9e, 0xce, 0x6a));
        assert_eq!(p.danger, Color::from_rgb8(0xf7, 0x76, 0x8e));
    }

    #[test]
    fn custom_theme_with_base() {
        let val = json!({"base": "Nord", "primary": "#88c0d0"});
        let result = resolve_theme(&val);
        let p = result.theme.palette();
        // Primary should be overridden.
        assert_eq!(p.primary, Color::from_rgb8(0x88, 0xc0, 0xd0));
        // Background should come from Nord's palette.
        let nord_bg = Theme::Nord.palette().background;
        assert_eq!(p.background, nord_bg);
    }

    #[test]
    fn custom_theme_defaults_name_to_custom() {
        let val = json!({"primary": "#ff0000"});
        let result = resolve_theme(&val);
        assert_eq!(format!("{}", result.theme), "Custom");
    }

    #[test]
    fn parse_hex_color_valid() {
        let c = parse_hex_color("#ff8800").unwrap();
        assert_eq!(c, Color::from_rgb8(0xff, 0x88, 0x00));
    }

    #[test]
    fn parse_hex_color_without_hash() {
        let c = parse_hex_color("aabbcc").unwrap();
        assert_eq!(c, Color::from_rgb8(0xaa, 0xbb, 0xcc));
    }

    #[test]
    fn parse_hex_color_with_alpha() {
        let c = parse_hex_color("#ff880080").unwrap();
        assert_eq!(c, Color::from_rgba8(0xff, 0x88, 0x00, 128.0 / 255.0));
    }

    #[test]
    fn parse_hex_color_invalid_length() {
        assert!(parse_hex_color("#fff").is_none());
        assert!(parse_hex_color("").is_none());
    }

    #[test]
    fn parse_hex_color_invalid_chars() {
        assert!(parse_hex_color("#zzzzzz").is_none());
    }

    #[test]
    fn bad_color_field_is_ignored() {
        let val = json!({"background": "not-a-color", "text": "#ffffff"});
        let result = resolve_theme(&val);
        let p = result.theme.palette();
        // text should be set, background should remain the dark default.
        assert_eq!(p.text, Color::from_rgb8(0xff, 0xff, 0xff));
        assert_eq!(p.background, Palette::DARK.background);
    }
}
