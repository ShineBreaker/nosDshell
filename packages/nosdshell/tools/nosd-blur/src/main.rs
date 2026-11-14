//! nosd-blur — pre-blur wallpapers for nosDshell.
//!
//! Usage: nosd-blur <src> <dst> --width W --height H [--sigma S]
//!
//! Pipeline: decode -> cover-resize + center-crop to W x H -> approximate
//! gaussian blur (3 successive separable box blurs) -> encode to dst
//! (png/jpg by extension). Writes are atomic via tmp file + rename.

use image::imageops::FilterType;
use image::{DynamicImage, GenericImageView, ImageFormat};
use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("nosd-blur: {e}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let (src, dst, w, h, sigma) = parse_args(&args)?;

    let img = image::open(&src).map_err(|e| format!("cannot decode {src}: {e}"))?;

    let mut work = cover_crop(&img, w, h);

    // For strong blurs, blur at quarter resolution then upscale back —
    // far fewer pixels touched, visually equivalent for a background.
    let (eff_img, eff_sigma) = if sigma >= 8.0 {
        let dw = (w / 4).max(1);
        let dh = (h / 4).max(1);
        (
            work.resize(dw, dh, FilterType::Triangle),
            sigma / 4.0,
        )
    } else {
        (work.clone(), sigma)
    };

    if eff_sigma > 0.0 {
        work = gaussian_blur(&eff_img.to_rgba8(), eff_sigma);
    } else {
        work = eff_img;
    }
    if work.width() != w || work.height() != h {
        work = work.resize_exact(w, h, FilterType::Triangle);
    }

    write_atomic(&dst, &work)
}

fn parse_args(args: &[String]) -> Result<(String, String, u32, u32, f32), String> {
    if args.len() < 4 {
        return Err(format!(
            "usage: nosd-blur <src> <dst> --width W --height H [--sigma S] (got {} args)",
            args.len()
        ));
    }
    let src = args[0].clone();
    let dst = args[1].clone();
    let mut w = None;
    let mut h = None;
    let mut sigma = None;
    let mut i = 2;
    while i < args.len() {
        match args[i].as_str() {
            "--width" => {
                i += 1;
                w = args
                    .get(i)
                    .and_then(|s| s.parse::<u32>().ok())
                    .filter(|v| *v > 0);
                w.ok_or("bad --width value")?;
            }
            "--height" => {
                i += 1;
                h = args
                    .get(i)
                    .and_then(|s| s.parse::<u32>().ok())
                    .filter(|v| *v > 0);
                h.ok_or("bad --height value")?;
            }
            "--sigma" => {
                i += 1;
                sigma = args
                    .get(i)
                    .and_then(|s| s.parse::<f32>().ok())
                    .filter(|v| *v >= 0.0);
                sigma.ok_or("bad --sigma value")?;
            }
            other => return Err(format!("unknown argument: {other}")),
        }
        i += 1;
    }
    let w = w.ok_or("missing --width")?;
    let h = h.ok_or("missing --height")?;
    // Default sigma: 3% of the short edge of the target (DESIGN.md §4)
    let sigma = sigma.unwrap_or_else(|| 0.03 * (w.min(h) as f32));
    Ok((src, dst, w, h, sigma))
}

/// Cover-resize geometry: scale factor + crop rect needed to fill WxH.
/// Returns (scaled_w, scaled_h, crop_x, crop_y) where the crop is centered.
fn cover_geometry(sw: u32, sh: u32, w: u32, h: u32) -> (u32, u32, u32, u32) {
    let scale = f64::max(w as f64 / sw as f64, h as f64 / sh as f64);
    let nw = ((sw as f64) * scale).round().max(w as f64) as u32;
    let nh = ((sh as f64) * scale).round().max(h as f64) as u32;
    (nw, nh, (nw - w) / 2, (nh - h) / 2)
}

fn cover_crop(img: &DynamicImage, w: u32, h: u32) -> DynamicImage {
    let (sw, sh) = img.dimensions();
    let (nw, nh, _, _) = cover_geometry(sw, sh, w, h);
    let resized = img.resize(nw, nh, FilterType::Triangle);
    let x = (resized.width().saturating_sub(w)) / 2;
    let y = (resized.height().saturating_sub(h)) / 2;
    resized.crop_imm(x, y, w, h)
}

/// Box sizes for `n` successive box blurs approximating a gaussian
/// (standard "boxes for gauss" computation, as used by StackBlur).
fn boxes_for_gauss(sigma: f32, n: usize) -> Vec<u32> {
    let s2 = sigma * sigma;
    let n_f = n as f32;
    let w_ideal = ((12.0 * s2 / n_f) + 1.0).sqrt();
    let mut wl = w_ideal.floor() as i32;
    if wl % 2 == 0 {
        wl -= 1;
    }
    wl = wl.max(1);
    let wu = wl + 2;
    let m_ideal = (12.0 * s2 - n_f * (wl * wl) as f32 - 4.0 * n_f * wl as f32 - 3.0 * n_f)
        / (-4.0 * wl as f32 - 4.0);
    let m = m_ideal.round().max(0.0) as usize;
    (0..n).map(|i| if i < m { wl as u32 } else { wu as u32 }).collect()
}

/// Approximate gaussian blur: 3 separable box blur passes on RGBA8.
fn gaussian_blur(img: &image::RgbaImage, sigma: f32) -> DynamicImage {
    let mut work = img.clone();
    for &r in &boxes_for_gauss(sigma, 3) {
        if r <= 1 {
            continue;
        }
        let radius = (r / 2) as i32;
        work = box_blur_pass(&work, radius);
    }
    DynamicImage::ImageRgba8(work)
}

/// One separable box blur pass (horizontal then vertical), edge-clamped,
/// running-sum — O(w*h) per pass regardless of radius.
fn box_blur_pass(src: &image::RgbaImage, radius: i32) -> image::RgbaImage {
    let w = src.width() as i32;
    let h = src.height() as i32;
    let mut tmp = image::RgbaImage::new(src.width(), src.height());
    let mut dst = image::RgbaImage::new(src.width(), src.height());
    let div = (radius * 2 + 1) as f32;

    // horizontal: tmp[y][x] = mean of src[y][x-r..=x+r]
    for y in 0..h {
        let mut acc = [0f32; 4];
        // init window at x = -radius (clamped)
        for i in -radius..=radius {
            let xi = i.clamp(0, w - 1);
            let p = src.get_pixel(xi as u32, y as u32);
            for c in 0..4 {
                acc[c] += p[c] as f32;
            }
        }
        for x in 0..w {
            let px = tmp.get_pixel_mut(x as u32, y as u32);
            for c in 0..4 {
                px[c] = (acc[c] / div).round().clamp(0.0, 255.0) as u8;
            }
            // slide window: remove x-radius, add x+radius+1
            let xa = (x + radius + 1).clamp(0, w - 1);
            let xr = (x - radius).clamp(0, w - 1);
            let pa = src.get_pixel(xa as u32, y as u32);
            let pr = src.get_pixel(xr as u32, y as u32);
            for c in 0..4 {
                acc[c] += pa[c] as f32 - pr[c] as f32;
            }
        }
    }

    // vertical: dst[x][y] = mean of tmp[x][y-r..=y+r]
    for x in 0..w {
        let mut acc = [0f32; 4];
        for i in -radius..=radius {
            let yi = i.clamp(0, h - 1);
            let p = tmp.get_pixel(x as u32, yi as u32);
            for c in 0..4 {
                acc[c] += p[c] as f32;
            }
        }
        for y in 0..h {
            let px = dst.get_pixel_mut(x as u32, y as u32);
            for c in 0..4 {
                px[c] = (acc[c] / div).round().clamp(0.0, 255.0) as u8;
            }
            let ya = (y + radius + 1).clamp(0, h - 1);
            let yr = (y - radius).clamp(0, h - 1);
            let pa = tmp.get_pixel(x as u32, ya as u32);
            let pr = tmp.get_pixel(x as u32, yr as u32);
            for c in 0..4 {
                acc[c] += pa[c] as f32 - pr[c] as f32;
            }
        }
    }
    dst
}

/// Write `img` to `dst` atomically: `<dst>.tmp-<pid>` then rename.
/// Format from dst extension (png/jpg/jpeg; default png).
fn write_atomic(dst: &str, img: &DynamicImage) -> Result<(), String> {
    let dst_path = Path::new(dst);
    let tmp = dst_path
        .with_file_name(format!(
            "{}.tmp-{}",
            dst_path
                .file_name()
                .and_then(|n| n.to_str())
                .unwrap_or("out"),
            std::process::id()
        ));
    let res = (|| -> Result<(), String> {
        let fmt = match dst_path
            .extension()
            .and_then(|e| e.to_str())
            .map(|e| e.to_ascii_lowercase())
            .as_deref()
        {
            Some("jpg") | Some("jpeg") => ImageFormat::Jpeg,
            Some("png") => ImageFormat::Png,
            Some(other) => return Err(format!("unsupported output extension: {other}")),
            None => ImageFormat::Png,
        };
        img.save_with_format(&tmp, fmt)
            .map_err(|e| format!("encode {tmp:?}: {e}"))?;
        std::fs::rename(&tmp, dst_path).map_err(|e| format!("rename to {dst}: {e}"))?;
        Ok(())
    })();
    if res.is_err() {
        let _ = std::fs::remove_file(&tmp);
    }
    res
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{Rgba, RgbaImage};

    #[test]
    fn gauss_box_sizes() {
        // sigma large enough for odd sizes > 1
        let b = boxes_for_gauss(10.0, 3);
        assert_eq!(b.len(), 3);
        for &v in &b {
            assert!(v % 2 == 1, "box size must be odd: {v}");
            assert!(v >= 3, "box size too small: {v}");
        }
        // sizes are non-decreasing (wl repeated then wu)
        assert!(b[0] <= b[1] && b[1] <= b[2]);
        // tiny sigma collapses to 1s (skipped)
        let b2 = boxes_for_gauss(0.5, 3);
        assert!(b2.iter().all(|&v| v <= 3));
        // standard reference: sigma=3, n=3 -> [3,5,5] or [5,3,3]-style split
        let b3 = boxes_for_gauss(3.0, 3);
        assert_eq!(b3.iter().sum::<u32>() % 2, 1);
    }

    #[test]
    fn cover_wider_source() {
        // 4000x1000 src -> 100x100 dst: scale = 0.1 -> 400x100, crop x=150
        let img = DynamicImage::ImageRgba8(RgbaImage::new(4000, 1000));
        let out = cover_crop(&img, 100, 100);
        assert_eq!((out.width(), out.height()), (100, 100));
        let (nw, nh, x, y) = cover_geometry(4000, 1000, 100, 100);
        assert_eq!((nw, nh), (400, 100));
        assert_eq!((x, y), (150, 0));
    }

    #[test]
    fn cover_taller_source() {
        // 1000x4000 -> 100x100: scale 0.1 -> 100x400, crop y=150
        let (nw, nh, x, y) = cover_geometry(1000, 4000, 100, 100);
        assert_eq!((nw, nh), (100, 400));
        assert_eq!((x, y), (0, 150));
        let img = DynamicImage::ImageRgba8(RgbaImage::new(1000, 4000));
        let out = cover_crop(&img, 200, 50);
        assert_eq!((out.width(), out.height()), (200, 50));
    }

    #[test]
    fn cover_smaller_source_upscales() {
        // 50x50 -> 100x100: scale 2 -> 100x100, crop 0
        let img = DynamicImage::ImageRgba8(RgbaImage::new(50, 50));
        let out = cover_crop(&img, 100, 100);
        assert_eq!((out.width(), out.height()), (100, 100));
    }

    #[test]
    fn e2e_blurs_and_dims() {
        // two-tone image: blur should soften the edge
        let mut src = RgbaImage::new(64, 64);
        for y in 0..64 {
            for x in 0..64 {
                let v = if x < 32 { 0u8 } else { 255u8 };
                src.put_pixel(x, y, Rgba([v, v, v, 255]));
            }
        }
        let blurred = gaussian_blur(&src, 4.0);
        assert_eq!((blurred.width(), blurred.height()), (64, 64));
        let edge_px = blurred.get_pixel(32, 32);
        assert!(edge_px[0] > 0 && edge_px[0] < 255, "edge not blurred");
    }

    #[test]
    fn flat_image_stays_flat() {
        let src = RgbaImage::from_pixel(48, 48, Rgba([120, 80, 40, 255]));
        let blurred = gaussian_blur(&src, 6.0);
        for (_x, _y, p) in blurred.pixels() {
            assert_eq!(p, Rgba([120, 80, 40, 255]));
        }
    }

    #[test]
    fn cli_parsing() {
        let args = vec![
            "a.png".into(),
            "b.png".into(),
            "--width".into(),
            "1920".into(),
            "--height".into(),
            "1080".into(),
        ];
        let (_, _, w, h, s) = parse_args(&args).unwrap();
        assert_eq!((w, h), (1920, 1080));
        assert!((s - 0.03 * 1080.0).abs() < 0.001);
        let args2 = vec![
            "a".into(),
            "b".into(),
            "--width".into(),
            "10".into(),
            "--height".into(),
            "10".into(),
            "--sigma".into(),
            "5".into(),
        ];
        assert_eq!(parse_args(&args2).unwrap().4, 5.0);
        assert!(parse_args(&vec!["a".into()]).is_err());
    }
}
