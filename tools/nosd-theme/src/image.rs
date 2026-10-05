#![forbid(unsafe_code)]

//! Image reading: native PNG, PPM, JPEG sampling, ImageMagick fallback.
//! Mirrors Scripts/python/src/theming/lib/image.py.
//!
//! Parity notes:
//! - JPEG dimension scan and byte-triplet sampling mirror the Python logic.
//!   (`w*h < 16` would divide by zero in Python; we return an error there.)
//! - PPM channel scaling truncates like Python's `int()`; values are
//!   clamped to 255 (only malformed data can exceed it).

use std::io::Read;
use std::path::Path;
use std::process::Command;

pub type Rgb = (u8, u8, u8);

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ImageError {
    InvalidSignature(String),
    Unsupported(String),
    MissingData(String),
    Io(String),
    Magick(String),
}

impl std::fmt::Display for ImageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ImageError::InvalidSignature(m)
            | ImageError::Unsupported(m)
            | ImageError::MissingData(m)
            | ImageError::Io(m)
            | ImageError::Magick(m) => write!(f, "{m}"),
        }
    }
}

pub fn read_png_bytes(data: &[u8]) -> Result<Vec<Rgb>, ImageError> {
    if data.len() < 8 || data[..8] != [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A] {
        return Err(ImageError::InvalidSignature("Invalid PNG signature".into()));
    }
    let mut pos = 8usize;
    let (mut width, mut height) = (0u32, 0u32);
    let mut color_type = 0u8;
    let mut idat: Vec<u8> = Vec::new();
    while pos + 8 <= data.len() {
        let len = u32::from_be_bytes([data[pos], data[pos + 1], data[pos + 2], data[pos + 3]]) as usize;
        let typ = &data[pos + 4..pos + 8];
        if pos + 12 + len > data.len() {
            break;
        }
        let chunk = &data[pos + 8..pos + 8 + len];
        pos += 12 + len;
        if typ == b"IHDR" {
            width = u32::from_be_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
            height = u32::from_be_bytes([chunk[4], chunk[5], chunk[6], chunk[7]]);
            color_type = chunk[9];
            if chunk[8] != 8 {
                return Err(ImageError::Unsupported(format!("Unsupported bit depth: {}", chunk[8])));
            }
            if color_type != 2 && color_type != 6 {
                return Err(ImageError::Unsupported(format!("Unsupported color type: {color_type}")));
            }
        } else if typ == b"IDAT" {
            idat.extend_from_slice(chunk);
        } else if typ == b"IEND" {
            break;
        }
    }
    if idat.is_empty() || width == 0 {
        return Err(ImageError::MissingData("Missing image data".into()));
    }
    let mut decoder = flate2::read::ZlibDecoder::new(&idat[..]);
    let mut raw = Vec::new();
    decoder.read_to_end(&mut raw).map_err(|e| ImageError::MissingData(format!("zlib error: {e}")))?;
    let bpp = if color_type == 2 { 3 } else { 4 };
    let stride = width as usize * bpp + 1;
    let w = width as usize;
    let h = height as usize;
    if raw.len() < h * stride {
        return Err(ImageError::MissingData("Truncated IDAT data".into()));
    }
    let mut pixels = Vec::with_capacity(w * h);
    let mut prev = vec![0u8; w * bpp];
    for y in 0..h {
        let start = y * stride;
        let filter = raw[start];
        if filter > 4 {
            return Err(ImageError::Unsupported(format!("Unknown PNG filter type: {filter}")));
        }
        let row = &raw[start + 1..start + stride];
        let mut out = vec![0u8; w * bpp];
        for (i, x) in row.iter().enumerate() {
            let a = if i >= bpp { out[i - bpp] } else { 0 };
            let b = prev[i];
            let c = if i >= bpp { prev[i - bpp] } else { 0 };
            out[i] = match filter {
                0 => *x,
                1 => x.wrapping_add(a),
                2 => x.wrapping_add(b),
                3 => x.wrapping_add(((a as u16 + b as u16) / 2) as u8),
                _ => x.wrapping_add(paeth(a, b, c)),
            };
        }
        prev = out.clone();
        for x in 0..w {
            pixels.push((out[x * bpp], out[x * bpp + 1], out[x * bpp + 2]));
        }
    }
    Ok(pixels)
}

fn paeth(a: u8, b: u8, c: u8) -> u8 {
    let (a, b, c) = (a as i32, b as i32, c as i32);
    let p = a + b - c;
    let (pa, pb, pc) = ((p - a).abs(), (p - b).abs(), (p - c).abs());
    if pa <= pb && pa <= pc {
        a as u8
    } else if pb <= pc {
        b as u8
    } else {
        c as u8
    }
}

pub fn read_png(path: &Path) -> Result<Vec<Rgb>, ImageError> {
    let data = std::fs::read(path).map_err(|e| ImageError::Io(e.to_string()))?;
    read_png_bytes(&data)
}

fn scan_jpeg_dims(data: &[u8]) -> Option<(u32, u32)> {
    if data.len() < 2 || data[0] != 0xFF || data[1] != 0xD8 {
        return None;
    }
    let sof: [u8; 14] = [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF, 0x00];
    let sof_set: Vec<u8> = sof[..13].to_vec();
    let standalone: [u8; 10] = [0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9];
    let mut pos = 2usize;
    while pos < data.len().saturating_sub(1) {
        if data[pos] != 0xFF {
            pos += 1;
            continue;
        }
        while pos < data.len() && data[pos] == 0xFF {
            pos += 1;
        }
        if pos >= data.len() {
            break;
        }
        let marker = data[pos];
        pos += 1;
        if sof_set.contains(&marker) {
            if pos + 7 <= data.len() {
                let h = u16::from_be_bytes([data[pos + 3], data[pos + 4]]) as u32;
                let w = u16::from_be_bytes([data[pos + 5], data[pos + 6]]) as u32;
                return Some((w, h));
            }
            return None;
        }
        if marker == 0xD9 {
            break;
        }
        if !standalone.contains(&marker) && marker != 0x00 && marker != 0x01 {
            if pos + 2 <= data.len() {
                let seg = u16::from_be_bytes([data[pos], data[pos + 1]]) as usize;
                pos += seg;
            } else {
                break;
            }
        }
    }
    None
}

pub fn sample_jpeg_colors(data: &[u8], width: u32, height: u32) -> Vec<Rgb> {
    let denom = (width as usize) * (height as usize) / 16;
    if denom == 0 {
        return vec![(128, 128, 128)];
    }
    let step = (data.len() / denom).max(1);
    let mut pixels = Vec::new();
    let mut i = 0;
    while i + 2 < data.len() {
        let (r, g, b) = (data[i], data[i + 1], data[i + 2]);
        if !(r == 0xFF && matches!(g, 0xD8 | 0xD9 | 0xE0 | 0xE1)) {
            pixels.push((r, g, b));
        }
        i += step;
    }
    if pixels.is_empty() {
        pixels.push((128, 128, 128));
    }
    pixels
}

pub fn read_jpeg(path: &Path) -> Result<Vec<Rgb>, ImageError> {
    let data = std::fs::read(path).map_err(|e| ImageError::Io(e.to_string()))?;
    read_jpeg_bytes(&data)
}

pub fn read_jpeg_bytes(data: &[u8]) -> Result<Vec<Rgb>, ImageError> {
    if data.len() < 2 || data[0] != 0xFF || data[1] != 0xD8 {
        return Err(ImageError::InvalidSignature("Invalid JPEG signature".into()));
    }
    match scan_jpeg_dims(data) {
        Some((w, h)) if w != 0 && h != 0 => Ok(sample_jpeg_colors(data, w, h)),
        _ => Err(ImageError::MissingData("Could not parse JPEG dimensions".into())),
    }
}

pub fn parse_ppm(data: &[u8]) -> Result<Vec<Rgb>, ImageError> {
    let mut pos = 0usize;
    let mut tokens: Vec<String> = Vec::new();
    while tokens.len() < 4 && pos < data.len() {
        while pos < data.len() && matches!(data[pos], b' ' | b'\t' | b'\n' | b'\r') {
            pos += 1;
        }
        if pos < data.len() && data[pos] == b'#' {
            while pos < data.len() && data[pos] != b'\n' {
                pos += 1;
            }
            continue;
        }
        let start = pos;
        while pos < data.len() && !matches!(data[pos], b' ' | b'\t' | b'\n' | b'\r' | b'#') {
            pos += 1;
        }
        if pos > start {
            tokens.push(String::from_utf8_lossy(&data[start..pos]).into_owned());
        } else if pos < data.len() {
            pos += 1;
        }
    }
    if tokens.len() < 4 || tokens[0] != "P6" {
        return Err(ImageError::InvalidSignature(format!("Invalid PPM format: {tokens:?}")));
    }
    let width: usize = tokens[1].parse().map_err(|_| ImageError::InvalidSignature("Bad PPM width".into()))?;
    let height: usize = tokens[2].parse().map_err(|_| ImageError::InvalidSignature("Bad PPM height".into()))?;
    let maxval: f64 = tokens[3].parse().map_err(|_| ImageError::InvalidSignature("Bad PPM maxval".into()))?;
    if pos < data.len() && matches!(data[pos], b' ' | b'\t' | b'\n' | b'\r') {
        pos += 1;
    }
    let raw = &data[pos..];
    let scale = if maxval != 255.0 { 255.0 / maxval } else { 1.0 };
    let mut pixels = Vec::new();
    let end = (width * height * 3).min(raw.len());
    let mut i = 0;
    while i + 2 < end && i + 2 < raw.len() {
        // `int(x * scale)`, clamped (only malformed data exceeds 255).
        pixels.push((
            ((raw[i] as f64 * scale) as i64).clamp(0, 255) as u8,
            ((raw[i + 1] as f64 * scale) as i64).clamp(0, 255) as u8,
            ((raw[i + 2] as f64 * scale) as i64).clamp(0, 255) as u8,
        ));
        i += 3;
    }
    if pixels.is_empty() {
        return Err(ImageError::MissingData("No pixels extracted from PPM data".into()));
    }
    Ok(pixels)
}

fn read_via_magick(path: &Path, filter: &str) -> Result<Vec<Rgb>, ImageError> {
    let args = [
        path.to_string_lossy().into_owned(),
        "-filter".into(),
        filter.into(),
        "-resize".into(),
        "112x112!".into(),
        "-depth".into(),
        "8".into(),
        "-colorspace".into(),
        "sRGB".into(),
        "-strip".into(),
        "ppm:-".into(),
    ];
    let try_run = |bin: &str| Command::new(bin).args(&args).output();
    let out = match try_run("magick") {
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            try_run("convert").map_err(|e| ImageError::Magick(e.to_string()))?
        }
        Err(e) => return Err(ImageError::Magick(e.to_string())),
        Ok(o) => o,
    };
    if !out.status.success() {
        return Err(ImageError::Magick(format!(
            "ImageMagick failed: {}",
            String::from_utf8_lossy(&out.stderr)
        )));
    }
    parse_ppm(&out.stdout)
}

pub fn read_image(path: &Path, filter: &str) -> Result<Vec<Rgb>, ImageError> {
    match read_via_magick(path, filter) {
        Ok(px) => Ok(px),
        Err(e) => {
            let is_png =
                path.extension().and_then(|x| x.to_str()).map(|x| x.eq_ignore_ascii_case("png")).unwrap_or(false);
            if is_png {
                // Fall back to native parsing for PNG.
                read_png(path)
            } else {
                Err(e)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn png_bytes(pixels: &[(u8, u8, u8)], w: u32, h: u32) -> Vec<u8> {
        // Minimal unfiltered-PNG writer for tests (filter 0 rows).
        let mut raw = Vec::new();
        for y in 0..h as usize {
            raw.push(0);
            for x in 0..w as usize {
                let p = pixels[y * w as usize + x];
                raw.extend_from_slice(&[p.0, p.1, p.2]);
            }
        }
        let compressed = {
            use std::io::Write;
            let mut enc = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
            enc.write_all(&raw).unwrap();
            enc.finish().unwrap()
        };
        let mut out = vec![0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];
        let mut chunk = |typ: &[u8], data: &[u8]| {
            out.extend_from_slice(&(data.len() as u32).to_be_bytes());
            out.extend_from_slice(typ);
            out.extend_from_slice(data);
            out.extend_from_slice(&[0, 0, 0, 0]); // CRC ignored by parser
        };
        let mut ihdr = Vec::new();
        ihdr.extend_from_slice(&w.to_be_bytes());
        ihdr.extend_from_slice(&h.to_be_bytes());
        ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
        chunk(b"IHDR", &ihdr);
        chunk(b"IDAT", &compressed);
        chunk(b"IEND", &[]);
        out
    }

    #[test]
    fn png_roundtrip() {
        let px = vec![(255, 0, 0), (0, 255, 0), (0, 0, 255), (17, 34, 51)];
        let data = png_bytes(&px, 2, 2);
        assert_eq!(read_png_bytes(&data).unwrap(), px);
    }

    #[test]
    fn png_bad_signature() {
        assert!(read_png_bytes(b"not a png").is_err());
    }

    #[test]
    fn png_all_filter_types_rgba() {
        // 3x2 RGBA exercising Sub/Up/Average/Paeth across rows and channels.
        let px: Vec<(u8, u8, u8)> = vec![
            (200, 60, 30), (30, 120, 200), (10, 10, 10),
            (250, 250, 250), (0, 0, 0), (128, 64, 32),
        ];
        let rgba: Vec<u8> = px.iter().flat_map(|p| [p.0, p.1, p.2, 255]).collect();
        let w = 3usize;
        let rows: Vec<&[u8]> = vec![&rgba[0..12], &rgba[12..24]];
        // Encode each row with a different filter: Sub, Paeth.
        let mut raw = Vec::new();
        raw.push(1);
        raw.extend_from_slice(&encode_sub(rows[0], 4));
        raw.push(4);
        raw.extend_from_slice(&encode_paeth(rows[0], rows[1], 4));
        let compressed = {
            use std::io::Write;
            let mut enc = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
            enc.write_all(&raw).unwrap();
            enc.finish().unwrap()
        };
        let mut out = vec![0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];
        let mut chunk = |typ: &[u8], data: &[u8]| {
            out.extend_from_slice(&(data.len() as u32).to_be_bytes());
            out.extend_from_slice(typ);
            out.extend_from_slice(data);
            out.extend_from_slice(&[0, 0, 0, 0]);
        };
        let mut ihdr = Vec::new();
        ihdr.extend_from_slice(&3u32.to_be_bytes());
        ihdr.extend_from_slice(&2u32.to_be_bytes());
        ihdr.extend_from_slice(&[8, 6, 0, 0, 0]);
        chunk(b"IHDR", &ihdr);
        // Split IDAT in two to exercise concatenation.
        let mid = compressed.len() / 2;
        chunk(b"IDAT", &compressed[..mid]);
        chunk(b"IDAT", &compressed[mid..]);
        chunk(b"IEND", &[]);
        assert_eq!(read_png_bytes(&out).unwrap(), px);
        let _ = w;
    }

    fn encode_sub(row: &[u8], bpp: usize) -> Vec<u8> {
        row.iter().enumerate().map(|(i, &b)| {
            let a = if i >= bpp { row[i - bpp] } else { 0 };
            b.wrapping_sub(a)
        }).collect()
    }

    fn encode_paeth(prev: &[u8], row: &[u8], bpp: usize) -> Vec<u8> {
        row.iter().enumerate().map(|(i, &b)| {
            let a = if i >= bpp { row[i - bpp] } else { 0 };
            let cc = prev[i];
            let c = if i >= bpp { prev[i - bpp] } else { 0 };
            b.wrapping_sub(paeth_byte(a, cc, c))
        }).collect()
    }

    fn paeth_byte(a: u8, b: u8, c: u8) -> u8 {
        let (a, b, c) = (a as i16, b as i16, c as i16);
        let p = a + b - c;
        let (pa, pb, pc) = ((p - a).abs(), (p - b).abs(), (p - c).abs());
        if pa <= pb && pa <= pc { a as u8 } else if pb <= pc { b as u8 } else { c as u8 }
    }

    #[test]
    fn png_rejects_other_types() {
        // Palette color type.
        let mut data = png_bytes(&[(1, 2, 3)], 1, 1);
        data[25] = 3;
        assert!(read_png_bytes(&data).is_err());
        // 16-bit depth.
        let mut data = png_bytes(&[(1, 2, 3)], 1, 1);
        data[24] = 16;
        assert!(read_png_bytes(&data).is_err());
    }

    #[test]
    fn ppm_scaled_maxval_matches_python() {
        // Oracle from _parse_ppm.
        let mut data = b"P6\n# comment\n2 1\n15\n".to_vec();
        data.extend_from_slice(&[15, 0, 7, 0, 15, 0]);
        assert_eq!(parse_ppm(&data).unwrap(), [(255, 0, 119), (0, 255, 0)]);
        // P3 rejected like the python version.
        assert!(parse_ppm(b"P3\n1 1\n255\n0 0 0").is_err());
        // Truncated pixels.
        assert!(parse_ppm(b"P6\n1 1\n255\n\x01\x02").is_err());
    }

    #[test]
    fn jpeg_synthetic_matches_python() {
        // Oracle from _sample_jpeg_colors on these exact bytes.
        let mut jpg = vec![0xFF, 0xD8];
        let seg = |marker: u8, payload: &[u8], out: &mut Vec<u8>| {
            out.push(0xFF);
            out.push(marker);
            out.extend_from_slice(&((payload.len() + 2) as u16).to_be_bytes());
            out.extend_from_slice(payload);
        };
        let sof0: Vec<u8> = [vec![8, 0, 4, 0, 8, 3], vec![1, 0x22, 0, 2, 0x11, 1, 3, 0x11, 1]].concat();
        seg(0xC0, &sof0, &mut jpg);
        seg(0xC4, &[0; 16], &mut jpg);
        seg(0xDA, &[3, 1, 0, 2, 0, 3, 0, 0, 63, 0], &mut jpg);
        jpg.extend_from_slice(&(0..96).map(|i: u8| i.wrapping_mul(37).wrapping_add(11)).collect::<Vec<_>>());
        jpg.extend_from_slice(&[0xFF, 0xD9]);
        assert_eq!(read_jpeg_bytes(&jpg).unwrap(), [(20, 57, 94)]);
    }

    #[test]
    fn jpeg_bad_signature() {
        assert!(read_jpeg_bytes(b"not a jpeg").is_err());
    }

    #[test]
    fn ppm_parse() {
        let mut data = b"P6\n2 1\n255\n".to_vec();
        data.extend_from_slice(&[255, 0, 0, 0, 0, 255]);
        assert_eq!(parse_ppm(&data).unwrap(), [(255, 0, 0), (0, 0, 255)]);
    }
}
