#![forbid(unsafe_code)]

//! Color representation and conversion utilities.
//! Mirrors Scripts/python/src/theming/lib/color.py.
//!
//! Parity notes (float semantics differ between the languages):
//! - Python's `%` on floats always returns a non-negative result; Rust's
//!   `%` keeps the sign. Hue wrapping uses a float Euclidean remainder.
//! - Python's `round()` is banker's rounding (half to even); Rust's
//!   `f64::round` rounds half away from zero. `py_round` mirrors Python.

pub type Rgb = (u8, u8, u8);
pub type Hsl = (f64, f64, f64);
pub type Lab = (f64, f64, f64);

/// Python `round(float)`: round half to even on the exact binary value.
pub fn py_round(f: f64) -> f64 {
    let fl = f.floor();
    let d = f - fl;
    if d < 0.5 {
        fl
    } else if d > 0.5 {
        fl + 1.0
    } else if (fl as i64) % 2 == 0 {
        fl
    } else {
        fl + 1.0
    }
}

/// Python float `%`: fmod plus a single conditional add (NOT add-then-mod,
/// which would round twice). Mirrors CPython's float_mod exactly.
pub fn py_mod(a: f64, b: f64) -> f64 {
    let m = a % b;
    if m != 0.0 && (b < 0.0) != (m < 0.0) { m + b } else { m }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    /// Optional alpha set only by the template renderer's set_alpha filter
    /// (mirrors the dynamic attribute in color.py).
    pub alpha: Option<f64>,
}

impl Color {
    pub fn new(r: u8, g: u8, b: u8) -> Self {
        Color { r, g, b, alpha: None }
    }

    pub fn from_hex(s: &str) -> Option<Color> {
        let h = s.strip_prefix('#').unwrap_or(s);
        if h.len() < 6 {
            return None;
        }
        let r = u8::from_str_radix(&h[0..2], 16).ok()?;
        let g = u8::from_str_radix(&h[2..4], 16).ok()?;
        let b = u8::from_str_radix(&h[4..6], 16).ok()?;
        Some(Color { r, g, b, alpha: None })
    }

    pub fn to_hex(self) -> String {
        format!("#{:02x}{:02x}{:02x}", self.r, self.g, self.b)
    }

    pub fn to_rgb(self) -> (u8, u8, u8) {
        (self.r, self.g, self.b)
    }

    pub fn to_hsl(self) -> Hsl {
        rgb_to_hsl(self.r, self.g, self.b)
    }

    pub fn from_hsl(h: f64, s: f64, l: f64) -> Color {
        let (r, g, b) = hsl_to_rgb(h, s, l);
        Color { r, g, b, alpha: None }
    }

    pub fn from_tuple(t: (u8, u8, u8)) -> Color {
        Color { r: t.0, g: t.1, b: t.2, alpha: None }
    }

    /// Alpha for template output; defaults to 1.0 like getattr(color, 'alpha', 1.0).
    pub fn alpha_value(&self) -> f64 {
        self.alpha.unwrap_or(1.0)
    }

    pub fn to_hct(self) -> crate::hct::Hct {
        crate::hct::Hct::from_rgb(self.r, self.g, self.b)
    }

    pub fn from_hct(h: crate::hct::Hct) -> Color {
        let (r, g, b) = h.to_rgb();
        Color { r, g, b, alpha: None }
    }
}

pub fn rgb_to_hsl(r: u8, g: u8, b: u8) -> Hsl {
    let rn = r as f64 / 255.0;
    let gn = g as f64 / 255.0;
    let bn = b as f64 / 255.0;
    let max_c = rn.max(gn).max(bn);
    let min_c = rn.min(gn).min(bn);
    let delta = max_c - min_c;
    let l = (max_c + min_c) / 2.0;
    if delta == 0.0 {
        return (0.0, 0.0, l);
    }
    let s = if l != 0.0 && l != 1.0 { delta / (1.0 - (2.0 * l - 1.0).abs()) } else { 0.0 };
    let h = if max_c == rn {
        60.0 * py_mod((gn - bn) / delta, 6.0)
    } else if max_c == gn {
        60.0 * ((bn - rn) / delta + 2.0)
    } else {
        60.0 * ((rn - gn) / delta + 4.0)
    };
    (h, s, l)
}

pub fn hsl_to_rgb(h: f64, s: f64, l: f64) -> (u8, u8, u8) {
    if s == 0.0 {
        let v = py_round(l * 255.0) as u8;
        return (v, v, v);
    }
    fn hue_to_rgb(p: f64, q: f64, mut t: f64) -> f64 {
        if t < 0.0 {
            t += 1.0;
        }
        if t > 1.0 {
            t -= 1.0;
        }
        if t < 1.0 / 6.0 {
            return p + (q - p) * 6.0 * t;
        }
        if t < 1.0 / 2.0 {
            return q;
        }
        if t < 2.0 / 3.0 {
            return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
        }
        p
    }
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s };
    let p = 2.0 * l - q;
    let hn = h / 360.0;
    (
        py_round(hue_to_rgb(p, q, hn + 1.0 / 3.0) * 255.0) as u8,
        py_round(hue_to_rgb(p, q, hn) * 255.0) as u8,
        py_round(hue_to_rgb(p, q, hn - 1.0 / 3.0) * 255.0) as u8,
    )
}

pub fn adjust_lightness(c: Color, target_l: f64) -> Color {
    let (h, s, _) = c.to_hsl();
    Color::from_hsl(h, s, target_l)
}

pub fn shift_hue(c: Color, degrees: f64) -> Color {
    let (h, s, l) = c.to_hsl();
    Color::from_hsl(py_mod(h + degrees, 360.0), s, l)
}

pub fn hue_distance(h1: f64, h2: f64) -> f64 {
    let diff = (h1 - h2).abs();
    diff.min(360.0 - diff)
}

pub fn adjust_surface(c: Color, s_max: f64, l_target: f64) -> Color {
    let (h, s, _) = c.to_hsl();
    Color::from_hsl(h, s.min(s_max), l_target)
}

pub fn saturate(c: Color, amount: f64) -> Color {
    let (h, s, l) = c.to_hsl();
    Color::from_hsl(h, (s + amount).clamp(0.0, 1.0), l)
}

// D65 white point
const WHITE_X: f64 = 95.047;
const WHITE_Y: f64 = 100.0;
const WHITE_Z: f64 = 108.883;

fn linearize(channel: u8) -> f64 {
    let n = channel as f64 / 255.0;
    if n <= 0.04045 {
        return n / 12.92;
    }
    ((n + 0.055) / 1.055).powf(2.4)
}

fn delinearize(linear: f64) -> u8 {
    let n = if linear <= 0.0031308 { linear * 12.92 } else { 1.055 * linear.powf(1.0 / 2.4) - 0.055 };
    (py_round(n * 255.0) as i64).clamp(0, 255) as u8
}

fn lab_f(t: f64) -> f64 {
    if t > 0.008856 {
        return t.powf(1.0 / 3.0);
    }
    (903.3 * t + 16.0) / 116.0
}

fn lab_f_inv(t: f64) -> f64 {
    if t > 0.206893 {
        return t * t * t;
    }
    (116.0 * t - 16.0) / 903.3
}

pub fn rgb_to_lab(r: u8, g: u8, b: u8) -> Lab {
    let lr = linearize(r);
    let lg = linearize(g);
    let lb = linearize(b);
    let x = (0.4124564 * lr + 0.3575761 * lg + 0.1804375 * lb) * 100.0;
    let y = (0.2126729 * lr + 0.7151522 * lg + 0.0721750 * lb) * 100.0;
    let z = (0.0193339 * lr + 0.1191920 * lg + 0.9503041 * lb) * 100.0;
    let fx = lab_f(x / WHITE_X);
    let fy = lab_f(y / WHITE_Y);
    let fz = lab_f(z / WHITE_Z);
    (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))
}

pub fn lab_to_rgb(l: f64, a: f64, b: f64) -> (u8, u8, u8) {
    let fy = (l + 16.0) / 116.0;
    let fx = a / 500.0 + fy;
    let fz = fy - b / 200.0;
    let x = WHITE_X * lab_f_inv(fx) / 100.0;
    let y = WHITE_Y * lab_f_inv(fy) / 100.0;
    let z = WHITE_Z * lab_f_inv(fz) / 100.0;
    let lr = 3.2404542 * x - 1.5371385 * y - 0.4985314 * z;
    let lg = -0.9692660 * x + 1.8760108 * y + 0.0415560 * z;
    let lb = 0.0556434 * x - 0.2040259 * y + 1.0572252 * z;
    (delinearize(lr.clamp(0.0, 1.0)), delinearize(lg.clamp(0.0, 1.0)), delinearize(lb.clamp(0.0, 1.0)))
}

pub fn lab_distance(a: Lab, b: Lab) -> f64 {
    let (dl, da, db) = (a.0 - b.0, a.1 - b.1, a.2 - b.2);
    (dl * dl + da * da + db * db).sqrt()
}

/// Closest named color by Lab distance (matugen-compatible).
/// Entries with missing/invalid colors are skipped like the python version.
pub fn find_closest_color(compare_to: &str, colors: &[(&str, &str)]) -> String {
    if colors.is_empty() {
        return String::new();
    }
    let Some(t) = Color::from_hex(compare_to) else { return String::new() };
    let target = rgb_to_lab(t.r, t.g, t.b);
    let mut best = String::new();
    let mut best_dist = f64::INFINITY;
    for (name, hex) in colors {
        let Some(c) = Color::from_hex(hex) else { continue };
        let d = lab_distance(target, rgb_to_lab(c.r, c.g, c.b));
        if d < best_dist {
            best_dist = d;
            best = name.to_string();
        }
    }
    best
}

#[cfg(test)]
mod tests {
    use super::*;

    fn approx(a: f64, b: f64) -> bool {
        (a - b).abs() < 1e-9
    }

    #[test]
    fn py_round_halves_to_even() {
        assert_eq!(py_round(0.5), 0.0);
        assert_eq!(py_round(1.5), 2.0);
        assert_eq!(py_round(2.5), 2.0);
        assert_eq!(py_round(3.5), 4.0);
        assert_eq!(py_round(2.4), 2.0);
        assert_eq!(py_round(2.6), 3.0);
    }

    #[test]
    fn py_mod_negative() {
        assert!(approx(py_mod(-0.5, 6.0), 5.5));
        assert!(approx(py_mod(-50.0, 360.0), 310.0));
        assert!(approx(py_mod(370.0, 360.0), 10.0));
    }

    #[test]
    fn hex_roundtrip() {
        let c = Color::from_hex("#ff5500").unwrap();
        assert_eq!((c.r, c.g, c.b), (255, 85, 0));
        assert_eq!(c.to_hex(), "#ff5500");
        assert_eq!(Color::from_hex("00ff00").unwrap().to_hex(), "#00ff00");
        assert!(Color::from_hex("#xyz").is_none());
    }

    #[test]
    fn gray_hsl() {
        let (h, s, l) = Color::new(128, 128, 128).to_hsl();
        assert_eq!(h, 0.0);
        assert_eq!(s, 0.0);
        assert!(approx(l, 128.0 / 255.0));
        assert_eq!(hsl_to_rgb(0.0, 0.0, 0.5), (128, 128, 128));
    }

    #[test]
    fn lab_roundtrip_close() {
        for (r, g, b) in [(255, 85, 0), (10, 200, 90), (0, 0, 0), (255, 255, 255)] {
            let (l, a, bb) = rgb_to_lab(r, g, b);
            let (r2, g2, b2) = lab_to_rgb(l, a, bb);
            assert!((r as i32 - r2 as i32).abs() <= 1, "{r},{g},{b} -> {r2},{g2},{b2}");
            assert!((g as i32 - g2 as i32).abs() <= 1);
            assert!((b as i32 - b2 as i32).abs() <= 1);
        }
    }

    #[test]
    fn closest_color() {
        let names = [("red", "#ff0000"), ("green", "#00ff00"), ("blue", "#0000ff")];
        assert_eq!(find_closest_color("#fe0101", &names), "red");
        assert_eq!(find_closest_color("#000000", &[]), "");
    }

    #[test]
    fn matches_python_oracle_bitexact() {
        // Values produced by Scripts/python/src/theming/lib/color.py.
        assert_eq!(rgb_to_hsl(255, 85, 0), (20.0, 1.0, 0.5));
        assert_eq!(rgb_to_hsl(10, 200, 90), (145.26315789473685, 0.9047619047619049, 0.4117647058823529));
        assert_eq!(rgb_to_hsl(0, 0, 0), (0.0, 0.0, 0.0));
        assert_eq!(rgb_to_hsl(1, 2, 3), (210.0, 0.5000000000000018, 0.00784313725490196));
        assert_eq!(rgb_to_lab(255, 85, 0), (59.674793560312324, 62.0470400788824, 69.95906962348015));
        assert_eq!(hsl_to_rgb(20.0, 1.0, 0.5), (255, 85, 0));
        assert_eq!(hsl_to_rgb(123.0, 0.45, 0.6), (107, 199, 112));
        assert_eq!(lab_to_rgb(59.674793560312324, 62.0470400788824, 69.95906962348015), (255, 85, 0));
    }
}
