#![forbid(unsafe_code)]

//! End-to-end CLI checks for nosd-theme (Rust-only; the python oracle left
//! with Scripts/python after the port reached parity).

use std::path::PathBuf;
use std::process::Command;

fn bin() -> PathBuf {
    PathBuf::from(env!("CARGO_BIN_EXE_nosd-theme"))
}

fn scratch(tag: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "nosd-theme-cli-{}-{tag}",
        std::process::id()
    ));
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// 32x16 two-tone PNG (stdlib-quality, no external encoder).
fn test_png(path: &std::path::Path) {
    let (w, h) = (32u32, 16u32);
    let mut raw = Vec::new();
    for y in 0..h {
        raw.push(0);
        let c = if y < h / 2 { [200u8, 60, 30] } else { [30u8, 120, 200] };
        for _ in 0..w {
            raw.extend_from_slice(&c);
        }
    }
    let compressed = {
        use std::io::Write;
        let mut enc =
            flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
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
    ihdr.extend_from_slice(&w.to_be_bytes());
    ihdr.extend_from_slice(&h.to_be_bytes());
    ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
    chunk(b"IHDR", &ihdr);
    chunk(b"IDAT", &compressed);
    chunk(b"IEND", &[]);
    std::fs::write(path, out).unwrap();
}

#[test]
fn cli_image_emits_both_modes() {
    let dir = scratch("img");
    let img = dir.join("w.png");
    test_png(&img);
    for scheme in ["tonal-spot", "content", "vibrant", "faithful", "muted"] {
        let out = dir.join(format!("rs-{scheme}.json"));
        let rs = Command::new(bin())
            .args([img.to_str().unwrap(), "--scheme-type", scheme, "-o"])
            .arg(&out)
            .output()
            .unwrap();
        assert!(rs.status.success(), "rs {scheme}: {rs:?}");
        let text = std::fs::read_to_string(&out).unwrap();
        for key in ["\"dark\"", "\"light\"", "\"primary\""] {
            assert!(text.contains(key), "scheme {scheme} missing {key}");
        }
    }
}

#[test]
fn cli_error_paths() {
    // Missing image.
    let rs = Command::new(bin()).args(["/nope.png"]).output().unwrap();
    assert!(!rs.status.success());
    assert!(
        String::from_utf8_lossy(&rs.stderr).contains("Error: Image not found")
    );
    // No args at all.
    let rs = Command::new(bin()).output().unwrap();
    assert!(!rs.status.success());
    assert!(
        String::from_utf8_lossy(&rs.stderr).contains("Error: Image path is required")
    );
}
