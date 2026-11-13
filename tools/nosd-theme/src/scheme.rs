#![forbid(unsafe_code)]

//! Predefined 14-color scheme expansion to the full 48-color palette.
//! Ported from the removed Scripts/python/src/theming/lib/scheme.py.
//!
//! The expanded dict keeps Python's insertion order (ordered `Vec`).

use crate::color::Color;
use crate::contrast::ensure_contrast;
use crate::material::Scheme;

fn hex_to_color(s: &str) -> Option<Color> {
    Color::from_hex(s)
}

fn make_container_dark(base: Color) -> Color {
    let (h, s, l) = base.to_hsl();
    Color::from_hsl(h, (s + 0.15).min(1.0), (l - 0.35).max(0.15))
}

fn make_container_light(base: Color) -> Color {
    let (h, s, l) = base.to_hsl();
    Color::from_hsl(h, (s - 0.20).max(0.30), (l + 0.35).min(0.85))
}

fn make_fixed_dark(base: Color) -> (Color, Color) {
    let (h, s, _) = base.to_hsl();
    (Color::from_hsl(h, s.max(0.70), 0.85), Color::from_hsl(h, s.max(0.65), 0.75))
}

fn make_fixed_light(base: Color) -> (Color, Color) {
    let (h, s, _) = base.to_hsl();
    (Color::from_hsl(h, s.max(0.70), 0.40), Color::from_hsl(h, s.max(0.65), 0.30))
}

fn interpolate(c1: Color, c2: Color, t: f64) -> Color {
    let r = (c1.r as f64 + (c2.r as f64 - c1.r as f64) * t) as i64;
    let g = (c1.g as f64 + (c2.g as f64 - c1.g as f64) * t) as i64;
    let b = (c1.b as f64 + (c2.b as f64 - c1.b as f64) * t) as i64;
    Color::new(r.clamp(0, 255) as u8, g.clamp(0, 255) as u8, b.clamp(0, 255) as u8)
}

pub fn expand_predefined_scheme(data: &serde_json::Map<String, serde_json::Value>, mode: &str) -> Option<Scheme> {
    let get = |k: &str| data.get(k)?.as_str().and_then(hex_to_color);
    let is_dark = mode == "dark";
    let primary = get("mPrimary")?;
    let on_primary = get("mOnPrimary")?;
    let secondary = get("mSecondary")?;
    let on_secondary = get("mOnSecondary")?;
    let tertiary = get("mTertiary")?;
    let on_tertiary = get("mOnTertiary")?;
    let error = get("mError")?;
    let on_error = get("mOnError")?;
    let surface = get("mSurface")?;
    let on_surface = get("mOnSurface")?;
    let surface_variant = get("mSurfaceVariant")?;
    let on_surface_variant = get("mOnSurfaceVariant")?;
    let outline_raw = get("mOutline")?;
    let shadow = data
        .get("mShadow")
        .and_then(|v| v.as_str())
        .and_then(hex_to_color)
        .unwrap_or(surface);

    let (primary_container, secondary_container, tertiary_container, error_container) = if is_dark {
        (make_container_dark(primary), make_container_dark(secondary), make_container_dark(tertiary), make_container_dark(error))
    } else {
        (make_container_light(primary), make_container_light(secondary), make_container_light(tertiary), make_container_light(error))
    };

    let (ph, ps, _) = primary.to_hsl();
    let (sh, ss, _) = secondary.to_hsl();
    let (th, ts, _) = tertiary.to_hsl();
    let (eh, es, _) = error.to_hsl();

    let on_l = if is_dark { 0.90 } else { 0.15 };
    let on_primary_container = ensure_contrast(Color::from_hsl(ph, ps, on_l), primary_container, 4.5, None);
    let on_secondary_container = ensure_contrast(Color::from_hsl(sh, ss, on_l), secondary_container, 4.5, None);
    let on_tertiary_container = ensure_contrast(Color::from_hsl(th, ts, on_l), tertiary_container, 4.5, None);
    let on_error_container = ensure_contrast(Color::from_hsl(eh, es, on_l), error_container, 4.5, None);

    let (primary_fixed, primary_fixed_dim) = if is_dark { make_fixed_dark(primary) } else { make_fixed_light(primary) };
    let (secondary_fixed, secondary_fixed_dim) = if is_dark { make_fixed_dark(secondary) } else { make_fixed_light(secondary) };
    let (tertiary_fixed, tertiary_fixed_dim) = if is_dark { make_fixed_dark(tertiary) } else { make_fixed_light(tertiary) };

    let (fix_l, fix_var_l) = if is_dark { (0.15, 0.20) } else { (0.90, 0.85) };
    let on_primary_fixed = ensure_contrast(Color::from_hsl(ph, 0.15, fix_l), primary_fixed, 4.5, None);
    let on_primary_fixed_variant = ensure_contrast(Color::from_hsl(ph, 0.15, fix_var_l), primary_fixed_dim, 4.5, None);
    let on_secondary_fixed = ensure_contrast(Color::from_hsl(sh, 0.15, fix_l), secondary_fixed, 4.5, None);
    let on_secondary_fixed_variant = ensure_contrast(Color::from_hsl(sh, 0.15, fix_var_l), secondary_fixed_dim, 4.5, None);
    let on_tertiary_fixed = ensure_contrast(Color::from_hsl(th, 0.15, fix_l), tertiary_fixed, 4.5, None);
    let on_tertiary_fixed_variant = ensure_contrast(Color::from_hsl(th, 0.15, fix_var_l), tertiary_fixed_dim, 4.5, None);

    let (surface_h, surface_s, surface_l) = surface.to_hsl();
    let (sv_h, sv_s, sv_l) = surface_variant.to_hsl();
    let surface_container = surface_variant;
    let (lowest, low, high, highest, dim, bright) = if is_dark {
        (
            interpolate(surface, surface_variant, 0.2),
            interpolate(surface, surface_variant, 0.5),
            Color::from_hsl(sv_h, sv_s, (sv_l + 0.04).min(0.40)),
            Color::from_hsl(sv_h, sv_s, (sv_l + 0.08).min(0.45)),
            Color::from_hsl(surface_h, surface_s, (surface_l - 0.04).max(0.02)),
            Color::from_hsl(sv_h, sv_s, (sv_l + 0.12).min(0.50)),
        )
    } else {
        (
            interpolate(surface, surface_variant, 0.2),
            interpolate(surface, surface_variant, 0.5),
            Color::from_hsl(sv_h, sv_s, (sv_l - 0.04).max(0.60)),
            Color::from_hsl(sv_h, sv_s, (sv_l - 0.08).max(0.55)),
            Color::from_hsl(sv_h, sv_s, (sv_l - 0.12).max(0.50)),
            Color::from_hsl(surface_h, surface_s, (surface_l + 0.03).min(0.98)),
        )
    };

    let outline = ensure_contrast(outline_raw, surface, 3.0, None);
    let (oh, os, ol) = outline.to_hsl();
    let outline_variant = if is_dark {
        Color::from_hsl(oh, os, (ol - 0.15).max(0.1))
    } else {
        Color::from_hsl(oh, os, (ol + 0.15).min(0.9))
    };
    let scrim = Color::new(0, 0, 0);

    let (inverse_surface, inverse_on_surface, inverse_primary) = if is_dark {
        (
            Color::from_hsl(surface_h, 0.08, 0.90),
            Color::from_hsl(surface_h, 0.05, 0.15),
            Color::from_hsl(ph, (ps * 0.8).max(0.5), 0.40),
        )
    } else {
        (
            Color::from_hsl(surface_h, 0.08, 0.15),
            Color::from_hsl(surface_h, 0.05, 0.90),
            Color::from_hsl(ph, (ps * 0.8).max(0.5), 0.70),
        )
    };

    let hex = |c: Color| c.to_hex();
    Some(vec![
        ("primary", hex(primary)), ("on_primary", hex(on_primary)),
        ("primary_container", hex(primary_container)), ("on_primary_container", hex(on_primary_container)),
        ("primary_fixed", hex(primary_fixed)), ("primary_fixed_dim", hex(primary_fixed_dim)),
        ("on_primary_fixed", hex(on_primary_fixed)), ("on_primary_fixed_variant", hex(on_primary_fixed_variant)),
        ("secondary", hex(secondary)), ("on_secondary", hex(on_secondary)),
        ("secondary_container", hex(secondary_container)), ("on_secondary_container", hex(on_secondary_container)),
        ("secondary_fixed", hex(secondary_fixed)), ("secondary_fixed_dim", hex(secondary_fixed_dim)),
        ("on_secondary_fixed", hex(on_secondary_fixed)), ("on_secondary_fixed_variant", hex(on_secondary_fixed_variant)),
        ("tertiary", hex(tertiary)), ("on_tertiary", hex(on_tertiary)),
        ("tertiary_container", hex(tertiary_container)), ("on_tertiary_container", hex(on_tertiary_container)),
        ("tertiary_fixed", hex(tertiary_fixed)), ("tertiary_fixed_dim", hex(tertiary_fixed_dim)),
        ("on_tertiary_fixed", hex(on_tertiary_fixed)), ("on_tertiary_fixed_variant", hex(on_tertiary_fixed_variant)),
        ("error", hex(error)), ("on_error", hex(on_error)),
        ("error_container", hex(error_container)), ("on_error_container", hex(on_error_container)),
        ("surface", hex(surface)), ("on_surface", hex(on_surface)),
        ("surface_variant", hex(surface_variant)), ("on_surface_variant", hex(on_surface_variant)),
        ("surface_dim", hex(dim)), ("surface_bright", hex(bright)),
        ("surface_container_lowest", hex(lowest)), ("surface_container_low", hex(low)),
        ("surface_container", hex(surface_container)),
        ("surface_container_high", hex(high)), ("surface_container_highest", hex(highest)),
        ("outline", hex(outline)), ("outline_variant", hex(outline_variant)),
        ("shadow", hex(shadow)), ("scrim", hex(scrim)),
        ("inverse_surface", hex(inverse_surface)), ("inverse_on_surface", hex(inverse_on_surface)),
        ("inverse_primary", hex(inverse_primary)),
        ("background", hex(surface)), ("on_background", hex(on_surface)),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_string(), v))
    .collect())
}

/// Flatten a scheme's terminal section into template-ready keys.
/// Mirrors `inject_terminal_colors`.
pub fn inject_terminal_colors(result: &mut Scheme, mode_data: &serde_json::Map<String, serde_json::Value>) {
    let Some(term) = mode_data.get("terminal").and_then(|v| v.as_object()) else { return };
    for (json_key, flat) in [
        ("foreground", "terminal_foreground"),
        ("background", "terminal_background"),
        ("cursor", "terminal_cursor"),
        ("cursorText", "terminal_cursor_text"),
        ("selectionFg", "terminal_selection_fg"),
        ("selectionBg", "terminal_selection_bg"),
    ] {
        if let Some(v) = term.get(json_key).and_then(|v| v.as_str()) {
            result.push((flat.to_string(), v.to_string()));
        }
    }
    for group in ["normal", "bright"] {
        if let Some(g) = term.get(group).and_then(|v| v.as_object()) {
            for (name, hex) in g {
                if let Some(hex) = hex.as_str() {
                    result.push((format!("terminal_{group}_{name}"), hex.to_string()));
                }
            }
        }
    }
}

/// 深色主题独有的 accent 阴影族 9 条（`deepin-dark` 的 GTK css 引用它们）。
///
/// 这些值不是从 accent 按固定比率派生的——它们是 2016 年移植 Adwaita 3.20 时
/// 带进来的字面值，分属 197.3° / 212.5° / 213.0° 三个色相族。下表是原始值；
/// 派生时按「相对参考 accent 的 ΔH / S 比率 / L 余量」搬到当前 accent 上，
/// 在参考值 `#106daa` 下必须逐位复现原值（见 `accent_family_matches_reference`）。
const REF_ACCENT: &str = "#106daa";

pub const ACCENT_FAMILY: &[(&str, &str)] = &[
    ("accent_standalone_color", "#4dadd4"),
    ("accent_hover_color", "#76c0de"),
    ("accent_active_color", "#2e96c0"),
    ("accent_light_color", "#a9caf1"),
    ("accent_light_hover_color", "#e5effb"),
    ("accent_light_active_color", "#7eafe9"),
    ("accent_disabled_color", "#b1cff2"),
    ("accent_border_color", "#577ba7"),
    ("accent_on_bg_dim_color", "#cbdff6"),
];

/// 把参考色族的明暗关系搬到 `primary` 上。
///
/// - 色相：`H' = H + ΔH`
/// - 饱和：`S' = S · (S_target / S_ref)`，比率而非加性
/// - 亮度：变亮走余量 `L' = L + (1 − L) · t`，变暗走比率 `L' = L · (L_target / L_ref)`
///
/// 亮度必须用余量模型：加性 `L + ΔL` 在浅 accent（L ≥ 50%）下会让
/// `light_hover` / `on_bg_dim` / `disabled` 一起塌成纯白。
pub fn derive_accent_family(primary: Color) -> Vec<(String, String)> {
    let Some(reference) = hex_to_color(REF_ACCENT) else { return Vec::new() };
    let (h0, s0, l0) = reference.to_hsl();
    let (h, s, l) = primary.to_hsl();
    ACCENT_FAMILY
        .iter()
        .map(|(name, hex)| {
            let (ht, st, lt) = hex_to_color(hex).expect("accent family literal").to_hsl();
            let new_l = if lt >= l0 {
                let t = (lt - l0) / (1.0 - l0);
                l + (1.0 - l) * t
            } else {
                l * (lt / l0)
            };
            let color = Color::from_hsl(
                (h + (ht - h0)).rem_euclid(360.0),
                (s * if s0 > 0.0 { st / s0 } else { 1.0 }).clamp(0.0, 1.0),
                new_l.clamp(0.0, 1.0),
            );
            (name.to_string(), color.to_hex())
        })
        .collect()
}

/// 把派生出的 9 条并入 scheme；同名键已存在时不覆盖。
pub fn inject_accent_family(scheme: &mut Scheme) {
    let Some(primary) = scheme
        .iter()
        .find(|(k, _)| k == "primary")
        .and_then(|(_, v)| hex_to_color(v))
    else {
        return;
    };
    for (name, hex) in derive_accent_family(primary) {
        if !scheme.iter().any(|(k, _)| k == &name) {
            scheme.push((name, hex));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn tokyo_night() -> serde_json::Map<String, serde_json::Value> {
        serde_json::from_str(
            r##"{"mPrimary": "#7aa2f7", "mOnPrimary": "#1a1b26", "mSecondary": "#bb9af7",
            "mOnSecondary": "#1a1b26", "mTertiary": "#7dcfff", "mOnTertiary": "#1a1b26",
            "mError": "#f7768e", "mOnError": "#1a1b26", "mSurface": "#1a1b26",
            "mOnSurface": "#c0caf5", "mSurfaceVariant": "#24283b", "mOnSurfaceVariant": "#a9b1d6",
            "mOutline": "#565f89"}"##,
        )
        .unwrap()
    }

    fn scheme_json(s: &Scheme) -> String {
        s.iter().map(|(k, v)| format!("\"{k}\": \"{v}\"")).collect::<Vec<_>>().join(", ")
    }

    #[test]
    fn expands_to_48_keys_in_order() {
        let data = tokyo_night();
        let dark = expand_predefined_scheme(&data, "dark").unwrap();
        assert_eq!(dark.len(), 48);
        assert_eq!(dark[0].0, "primary");
        assert_eq!(dark[47].0, "on_background");
        assert_eq!(dark.iter().find(|(k, _)| k == "surface").unwrap().1, "#1a1b26");
        let light = expand_predefined_scheme(&data, "light").unwrap();
        assert_eq!(light.len(), 48);
        assert!(light.iter().map(|(k, _)| k).eq(dark.iter().map(|(k, _)| k)));
    }

    #[test]
    fn expand_matches_python_oracle() {
        // Oracle: expand_predefined_scheme(tokyo-night 14 colors, ...).
        let data = tokyo_night();
        assert_eq!(
            scheme_json(&expand_predefined_scheme(&data, "dark").unwrap()),
            "\"primary\": \"#7aa2f7\", \"on_primary\": \"#1a1b26\", \"primary_container\": \"#003dbe\", \"on_primary_container\": \"#cfddfc\", \"primary_fixed\": \"#b7cdfb\", \"primary_fixed_dim\": \"#87abf8\", \"on_primary_fixed\": \"#21242c\", \"on_primary_fixed_variant\": \"#2b303b\", \"secondary\": \"#bb9af7\", \"on_secondary\": \"#1a1b26\", \"secondary_container\": \"#4f00de\", \"on_secondary_container\": \"#dfd0fb\", \"secondary_fixed\": \"#cfb8f9\", \"secondary_fixed_dim\": \"#af89f6\", \"on_secondary_fixed\": \"#25212c\", \"on_secondary_fixed_variant\": \"#312b3b\", \"tertiary\": \"#7dcfff\", \"on_tertiary\": \"#1a1b26\", \"tertiary_container\": \"#007fca\", \"on_tertiary_container\": \"#000f19\", \"tertiary_fixed\": \"#b2e3ff\", \"tertiary_fixed_dim\": \"#80d0ff\", \"on_tertiary_fixed\": \"#21282c\", \"on_tertiary_fixed_variant\": \"#2b353b\", \"error\": \"#f7768e\", \"on_error\": \"#1a1b26\", \"error_container\": \"#bb0023\", \"on_error_container\": \"#fccfd7\", \"surface\": \"#1a1b26\", \"on_surface\": \"#c0caf5\", \"surface_variant\": \"#24283b\", \"on_surface_variant\": \"#a9b1d6\", \"surface_dim\": \"#12121a\", \"surface_bright\": \"#3b4261\", \"surface_container_lowest\": \"#1c1d2a\", \"surface_container_low\": \"#1f2130\", \"surface_container\": \"#24283b\", \"surface_container_high\": \"#2c3148\", \"surface_container_highest\": \"#333954\", \"outline\": \"#5b6591\", \"outline_variant\": \"#3e4462\", \"shadow\": \"#1a1b26\", \"scrim\": \"#000000\", \"inverse_surface\": \"#e3e4e8\", \"inverse_on_surface\": \"#242528\", \"inverse_primary\": \"#1e4cae\", \"background\": \"#1a1b26\", \"on_background\": \"#c0caf5\""
        );
        assert_eq!(
            scheme_json(&expand_predefined_scheme(&data, "light").unwrap()),
            "\"primary\": \"#7aa2f7\", \"on_primary\": \"#1a1b26\", \"primary_container\": \"#becff3\", \"on_primary_container\": \"#041a48\", \"primary_fixed\": \"#0c45c0\", \"primary_fixed_dim\": \"#093490\", \"on_primary_fixed\": \"#e2e4e9\", \"on_primary_fixed_variant\": \"#d3d7de\", \"secondary\": \"#bb9af7\", \"on_secondary\": \"#1a1b26\", \"secondary_container\": \"#d1c0f2\", \"on_secondary_container\": \"#1d0647\", \"secondary_fixed\": \"#4d0fbd\", \"secondary_fixed_dim\": \"#3a0b8e\", \"on_secondary_fixed\": \"#e4e2e9\", \"on_secondary_fixed_variant\": \"#d7d3de\", \"tertiary\": \"#7dcfff\", \"on_tertiary\": \"#1a1b26\", \"tertiary_container\": \"#bae1f7\", \"on_tertiary_container\": \"#00304c\", \"tertiary_fixed\": \"#0081cc\", \"tertiary_fixed_dim\": \"#006199\", \"on_tertiary_fixed\": \"#0e1113\", \"on_tertiary_fixed_variant\": \"#d3dade\", \"error\": \"#f7768e\", \"on_error\": \"#1a1b26\", \"error_container\": \"#f3bec8\", \"on_error_container\": \"#480411\", \"surface\": \"#1a1b26\", \"on_surface\": \"#c0caf5\", \"surface_variant\": \"#24283b\", \"on_surface_variant\": \"#a9b1d6\", \"surface_dim\": \"#616b9e\", \"surface_bright\": \"#20212f\", \"surface_container_lowest\": \"#1c1d2a\", \"surface_container_low\": \"#1f2130\", \"surface_container\": \"#24283b\", \"surface_container_high\": \"#8089b2\", \"surface_container_highest\": \"#707aa8\", \"outline\": \"#5b6591\", \"outline_variant\": \"#868eb3\", \"shadow\": \"#1a1b26\", \"scrim\": \"#000000\", \"inverse_surface\": \"#232429\", \"inverse_on_surface\": \"#e4e4e7\", \"inverse_primary\": \"#7c9fe9\", \"background\": \"#1a1b26\", \"on_background\": \"#c0caf5\""
        );
    }

    #[test]
    fn accent_family_matches_reference() {
        // 回归：参考 accent 下 9 条必须逐位等于 2016 年带进来的原值。
        let derived = derive_accent_family(Color::from_hex(REF_ACCENT).unwrap());
        assert_eq!(derived.len(), 9);
        for ((name, expected), (got_name, got)) in ACCENT_FAMILY.iter().zip(derived.iter()) {
            assert_eq!(name, got_name);
            assert_eq!(*expected, got.as_str(), "{name} 与参考值不一致");
        }
    }

    #[test]
    fn accent_family_does_not_collapse_to_white() {
        // 浅 accent 下 light_hover / on_bg_dim / disabled 不能塌成纯白。
        for accent in ["#ff00ff", "#2ca7f8", "#7fb069"] {
            let derived = derive_accent_family(Color::from_hex(accent).unwrap());
            for (name, hex) in derived {
                assert_ne!(hex, "#ffffff", "{accent} 的 {name} 塌成纯白");
            }
        }
    }

    #[test]
    fn inject_accent_family_appends_nine() {
        let mut scheme: Scheme = vec![("primary".into(), REF_ACCENT.into())];
        inject_accent_family(&mut scheme);
        assert_eq!(scheme.len(), 10);
        assert_eq!(
            scheme.iter().find(|(k, _)| k == "accent_hover_color").unwrap().1,
            "#76c0de"
        );
        // 已有同名键不覆盖
        inject_accent_family(&mut scheme);
        assert_eq!(scheme.len(), 10);
    }

    #[test]
    fn terminal_keys_flattened() {
        let mut scheme: Scheme = vec![("primary".into(), "#000000".into())];
        let mode: serde_json::Map<String, serde_json::Value> = serde_json::from_str(
            r##"{"terminal": {"foreground": "#ffffff", "normal": {"black": "#000000"}, "bright": {"red": "#ff0000"}}}"##,
        )
        .unwrap();
        inject_terminal_colors(&mut scheme, &mode);
        assert!(scheme.iter().any(|(k, v)| k == "terminal_foreground" && v == "#ffffff"));
        assert!(scheme.iter().any(|(k, v)| k == "terminal_normal_black" && v == "#000000"));
        assert!(scheme.iter().any(|(k, v)| k == "terminal_bright_red" && v == "#ff0000"));
    }
}
