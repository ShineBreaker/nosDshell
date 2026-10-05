#![forbid(unsafe_code)]

//! End-to-end CLI parity: nosd-theme vs template-processor.py on identical inputs.

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

fn python_processor() -> Option<PathBuf> {
    // Workspace layout: <root>/Scripts/python/src/theming/template-processor.py
    // with crate at <root>/tools/nosd-theme.
    let here = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let p = here.join("../../Scripts/python/src/theming/template-processor.py");
    p.exists().then_some(p)
}

#[test]
fn cli_image_json_matches_python() {
    let Some(py) = python_processor() else { return };
    let dir = scratch("img");
    let img = dir.join("w.png");
    test_png(&img);
    for scheme in ["tonal-spot", "content", "vibrant", "faithful", "muted"] {
        let rs_out = dir.join(format!("rs-{scheme}.json"));
        let py_out = dir.join(format!("py-{scheme}.json"));
        let rs = Command::new(bin())
            .args([img.to_str().unwrap(), "--scheme-type", scheme, "-o"])
            .arg(&rs_out)
            .output()
            .unwrap();
        assert!(rs.status.success(), "rs {scheme}: {rs:?}");
        let ps = Command::new("python3")
            .args([py.to_str().unwrap(), img.to_str().unwrap(), "--scheme-type", scheme, "-o"])
            .arg(&py_out)
            .output()
            .unwrap();
        assert!(ps.status.success(), "py {scheme}: {ps:?}");
        assert_eq!(
            std::fs::read_to_string(&rs_out).unwrap(),
            std::fs::read_to_string(&py_out).unwrap(),
            "scheme {scheme}"
        );
    }
}

#[test]
fn cli_error_paths_match_python() {
    let Some(py) = python_processor() else { return };
    let dir = scratch("err");
    // Missing image.
    let rs = Command::new(bin()).args(["/nope.png"]).output().unwrap();
    let ps = Command::new("python3")
        .args([py.to_str().unwrap(), "/nope.png"])
        .output()
        .unwrap();
    assert!(!rs.status.success());
    assert!(!ps.status.success());
    assert_eq!(String::from_utf8_lossy(&rs.stderr), String::from_utf8_lossy(&ps.stderr));
    // No args at all.
    let rs = Command::new(bin()).output().unwrap();
    let ps = Command::new("python3").arg(py.to_str().unwrap()).output().unwrap();
    assert!(!rs.status.success());
    assert!(!ps.status.success());
    assert_eq!(String::from_utf8_lossy(&rs.stderr), String::from_utf8_lossy(&ps.stderr));
}
