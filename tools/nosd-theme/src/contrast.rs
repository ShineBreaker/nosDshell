#![forbid(unsafe_code)]

//! WCAG luminance and contrast utilities.
//! Mirrors Scripts/python/src/theming/lib/contrast.py.

use crate::color::Color;

fn linearize(c: u8) -> f64 {
    let n = c as f64 / 255.0;
    if n <= 0.03928 {
        return n / 12.92;
    }
    ((n + 0.055) / 1.055).powf(2.4)
}

pub fn relative_luminance(r: u8, g: u8, b: u8) -> f64 {
    0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

pub fn contrast_ratio(c1: Color, c2: Color) -> f64 {
    let l1 = relative_luminance(c1.r, c1.g, c1.b);
    let l2 = relative_luminance(c2.r, c2.g, c2.b);
    (l1.max(l2) + 0.05) / (l1.min(l2) + 0.05)
}

pub fn is_dark(c: Color) -> bool {
    relative_luminance(c.r, c.g, c.b) < 0.179
}

pub fn ensure_contrast(fg: Color, bg: Color, min_ratio: f64, prefer_light: Option<bool>) -> Color {
    if contrast_ratio(fg, bg) >= min_ratio {
        return fg;
    }
    let (h, s, l) = fg.to_hsl();
    let prefer_light = prefer_light.unwrap_or_else(|| is_dark(bg));
    let (mut low, mut high) = if prefer_light { (l, 1.0) } else { (0.0, l) };
    let mut best = fg;
    for _ in 0..20 {
        let mid = (low + high) / 2.0;
        let test = Color::from_hsl(h, s, mid);
        if contrast_ratio(test, bg) >= min_ratio {
            best = test;
            if prefer_light {
                high = mid;
            } else {
                low = mid;
            }
        } else if prefer_light {
            low = mid;
        } else {
            high = mid;
        }
    }
    best
}

pub fn get_contrasting_color(bg: Color, min_ratio: f64) -> Color {
    let fg = if is_dark(bg) { Color::new(243, 237, 247) } else { Color::new(14, 14, 67) };
    ensure_contrast(fg, bg, min_ratio, None)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ratios() {
        let black = Color::new(0, 0, 0);
        let white = Color::new(255, 255, 255);
        assert!((contrast_ratio(black, white) - 21.0).abs() < 1e-9);
        assert_eq!(contrast_ratio(black, black), 1.0);
        assert!(is_dark(black));
        assert!(!is_dark(white));
    }

    #[test]
    fn already_passing_untouched() {
        let fg = Color::new(255, 255, 255);
        let bg = Color::new(0, 0, 0);
        assert_eq!(ensure_contrast(fg, bg, 4.5, None), fg);
    }

    #[test]
    fn adjusts_toward_contrast() {
        // Mid-gray on white fails 4.5; must darken to pass.
        let fg = Color::new(150, 150, 150);
        let bg = Color::new(255, 255, 255);
        assert!(contrast_ratio(fg, bg) < 4.5);
        let fixed = ensure_contrast(fg, bg, 4.5, None);
        assert!(contrast_ratio(fixed, bg) >= 4.5);
    }
}
