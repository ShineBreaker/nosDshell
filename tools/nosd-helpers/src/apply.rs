#![forbid(unsafe_code)]

//! apply: theme post-hook ported from Scripts/bash/template-apply.sh.
//! Usage: nosd-helpers apply <app> [dark|light]
//!
//! Behavior mirrors the bash case-by-case, including its quirks:
//! - sed `a`ppend inserts after EVERY matching line, not just the first.
//! - Address ranges are inclusive of the closing `[...]` line.
//! - starship's top-level `return`s only print bash's own error line and fall
//!   through (verified: executed scripts continue past `return`). The port
//!   keeps the fall-through file bytes and exit code; bash's locale-specific
//!   `return: can only ...` stderr line is the one known divergence.
//! - `sed -i` bumps mtime even without changes; the port only writes files on
//!   paths where bash would invoke sed/append.
//! - Theme-id strings (nosdshell, NosDshell) stay as-is: they are config
//!   contracts with generated theme files, not command names.
//!
//! HOME comes from the environment so tests can sandbox it. External tools
//! (kitty, pkill, dbus-send, ...) run as subprocesses with status ignored,
//! mirroring `|| true` / unchecked invocations.

use std::env;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

fn home() -> String {
    env::var("HOME").unwrap_or_default()
}

fn cfg(rel: &str) -> PathBuf {
    PathBuf::from(format!("{}/{rel}", home()))
}

/// ASCII whitespace for GNU grep/sed `\s` on single lines.
fn ws(b: u8) -> bool {
    matches!(b, b' ' | b'\t' | b'\n' | b'\r' | 0x0b | 0x0c)
}

fn ws_star(s: &str, mut i: usize) -> usize {
    while i < s.len() && ws(s.as_bytes()[i]) {
        i += 1;
    }
    i
}

/// `^PREFIX\s*=` line matcher (BRE `^prefix\s*=`).
fn line_assign(line: &str, prefix: &str) -> bool {
    line.strip_prefix(prefix).map(|r| ws_star(r, 0) < r.len() && r[ws_star(r, 0)..].starts_with('=')).unwrap_or(false)
}

fn read(p: &Path) -> Option<String> {
    fs::read_to_string(p).ok()
}

fn write(p: &Path, content: &str) {
    if let Some(parent) = p.parent() {
        if !parent.as_os_str().is_empty() {
            let _ = fs::create_dir_all(parent);
        }
    }
    let _ = fs::write(p, content);
}

/// Mirror `sed -i`: write temp + rename, preserving the original mode.
/// Needs only directory write permission, unlike fs::write.
fn write_in_place(p: &Path, content: &str) {
    let parent = p.parent().filter(|d| !d.as_os_str().is_empty());
    if let Some(d) = parent {
        let _ = fs::create_dir_all(d);
        let tmp = d.join(format!(".nosd-apply-{}.tmp", std::process::id()));
        if fs::write(&tmp, content).is_ok() {
            if let Ok(m) = fs::metadata(p) {
                let _ = fs::set_permissions(&tmp, m.permissions());
            }
            let _ = fs::rename(&tmp, p);
        }
    } else {
        write(p, content);
    }
}

/// Mirror `awk ... > tmp && mv tmp target`: fresh default mode, not preserved.
fn write_mv(p: &Path, content: &str) {
    let parent = p.parent().filter(|d| !d.as_os_str().is_empty());
    if let Some(d) = parent {
        let _ = fs::create_dir_all(d);
        let tmp = d.join(format!(".nosd-apply-{}.tmp", std::process::id()));
        if fs::write(&tmp, content).is_ok() {
            let _ = fs::rename(&tmp, p);
        }
    } else {
        write(p, content);
    }
}

fn run_quiet(prog: &str, args: &[&str]) {
    let _ = std::process::Command::new(prog).args(args).status();
}

fn run_capture(prog: &str, args: &[&str]) -> Option<String> {
    std::process::Command::new(prog)
        .args(args)
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
}

fn pgrep_f(pat: &str) -> bool {
    std::process::Command::new("pgrep").arg("-f").arg(pat).status().map(|s| s.success()).unwrap_or(false)
}

fn pkill(args: &[&str]) {
    run_quiet("pkill", args);
}

fn is_symlink(p: &Path) -> bool {
    fs::symlink_metadata(p).map(|m| m.file_type().is_symlink()).unwrap_or(false)
}

fn writable(p: &Path) -> bool {
    fs::metadata(p).map(|m| !m.permissions().readonly()).unwrap_or(false)
}

/// `cp --remove-destination $(readlink -f src) dst && chmod +w dst`.
fn convert_readonly_symlink(p: &Path) {
    if !is_symlink(p) || writable(p) {
        return;
    }
    if let Ok(target) = fs::canonicalize(p) {
        let _ = fs::remove_file(p);
        if fs::copy(&target, p).is_ok() {
            if let Ok(m) = fs::metadata(p) {
                let mut perm = m.permissions();
                perm.set_mode(perm.mode() | 0o222);
                let _ = fs::set_permissions(p, perm);
            }
        }
    }
}

/// Edit lines inside `/^HEADER/,/^\[/` (both endpoints processed, sed semantics:
/// the opening header never self-closes; any later `[...]` line closes).
fn edit_section(content: &str, header: &str, mut f: impl FnMut(&str) -> Option<String>) -> String {
    let mut out = Vec::new();
    let mut in_range = false;
    for line in content.split('\n') {
        let mut cur = line.to_string();
        if in_range {
            if let Some(n) = f(&cur) {
                cur = n;
            }
            if line.starts_with('[') {
                in_range = false;
            }
        } else if line == header {
            in_range = true;
            if let Some(n) = f(&cur) {
                cur = n;
            }
        }
        out.push(cur);
    }
    out.join("\n")
}

/// Section lines inclusive (for `sed -n '/hdr/,/^\[/p'` probes).
fn section_lines<'a>(lines: &'a [String], header: &str) -> Vec<&'a str> {
    let mut out = Vec::new();
    let mut in_range = false;
    for l in lines {
        if in_range {
            out.push(l.as_str());
            if l.starts_with('[') {
                in_range = false;
            }
        } else if l.as_str() == header {
            in_range = true;
            out.push(l.as_str());
        }
    }
    out
}

fn lines_of(content: &str) -> Vec<String> {
    content.split('\n').map(|s| s.to_string()).collect()
}

/// Insert `text` after EVERY line matching `pred` (sed `/re/a`).
fn insert_after_all(content: &str, pred: impl Fn(&str) -> bool, text: &str) -> String {
    let mut out = Vec::new();
    for line in content.split('\n') {
        out.push(line.to_string());
        if pred(line) {
            out.push(text.to_string());
        }
    }
    out.join("\n")
}

/// Fixed `^a\s*=\s*b$`-style matcher for ghostty's `theme = nosdshell`.
fn ghostty_theme_set(line: &str, value: &str) -> bool {
    let t = &line[ws_star(line, 0)..];
    let Some(r) = t.strip_prefix("theme") else { return false };
    let i = ws_star(r, 0);
    let Some(r2) = r[i..].strip_prefix('=') else { return false };
    let j = ws_star(r2, 0);
    r2[j..] == *value
}

fn ghostty_has_theme(line: &str) -> bool {
    let t = &line[ws_star(line, 0)..];
    let Some(r) = t.strip_prefix("theme") else { return false };
    let i = ws_star(r, 0);
    match r[i..].strip_prefix('=') {
        Some(_) => true,
        None => false,
    }
}

fn apply_ghostty() -> i32 {
    let files = [cfg(".config/ghostty/config"), cfg(".config/ghostty/config.ghostty")];
    let mut found = false;
    for f in &files {
        if !f.is_file() {
            continue;
        }
        found = true;
        let content = read(f).unwrap_or_default();
        if lines_of(&content).iter().any(|l| ghostty_theme_set(l, "nosdshell")) {
            // Already correct.
        } else if lines_of(&content).iter().any(|l| ghostty_has_theme(l)) {
            let new = lines_of(&content)
                .iter()
                .map(|l| {
                    if ghostty_has_theme(l) {
                        "theme = nosdshell".to_string()
                    } else {
                        l.clone()
                    }
                })
                .collect::<Vec<_>>()
                .join("\n");
            write_in_place(f, &new);
        } else {
            let mut new = content.clone();
            new.push_str("theme = nosdshell\n");
            write(f, &new);
        }
    }
    if found {
        if pgrep_f("ghostty") {
            pkill(&["-SIGUSR2", "ghostty"]);
        }
        0
    } else {
        eprintln!(
            "Error: No ghostty config file found at {}",
            files.iter().map(|p| p.display().to_string()).collect::<Vec<_>>().join(" ")
        );
        1
    }
}

fn apply_foot() -> i32 {
    let f = cfg(".config/foot/foot.ini");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "[main]\ninclude=~/.config/foot/themes/nosdshell\n");
        return 0;
    }
    let content = read(&f).unwrap_or_default();
    let has = content.split('\n').any(|l| l.contains("include") && l.contains("nosdshell"));
    if has {
        return 0;
    }
    let mut ls: Vec<String> = lines_of(&content);
    ls.retain(|l| !(l.contains("include=") && l.contains("themes")));
    let new = ls.join("\n");
    let new = if new.split('\n').any(|l| l == "[main]") {
        insert_after_all(&new, |l| l == "[main]", "include=~/.config/foot/themes/nosdshell")
    } else {
        // sed '1i [main]\ninclude=...\n' (trailing \n inserts a blank line)
        format!("[main]\ninclude=~/.config/foot/themes/nosdshell\n\n{new}")
    };
    write_in_place(&f, &new);
    0
}

fn apply_alacritty() -> i32 {
    const NEW: &str = "~/.config/alacritty/themes/nosdshell.toml";
    let f = cfg(".config/alacritty/alacritty.toml");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "[general]\nimport = [\n    \"~/.config/alacritty/themes/nosdshell.toml\"\n]\n");
        return 0;
    }
    let content = read(&f).unwrap_or_default();
    if content.split('\n').any(|l| l.contains("nosdshell.toml")) {
        if content.contains("\"themes/nosdshell.toml\"") {
            write_in_place(&f, &content.replace("\"themes/nosdshell.toml\"", &format!("\"{NEW}\"")));
        }
        return 0;
    }
    let ls = lines_of(&content);
    let new = if ls.iter().any(|l| l == "[general]") {
        if ls.iter().any(|l| line_assign(l, "import")) {
            // Range /import\s*=\s*\[/,/\]/: on the ] line, replace first ].
            let mut in_range = false;
            let mut out = Vec::new();
            for l in &ls {
                if !in_range && line_assign(l, "import") && l.contains('[') {
                    in_range = true;
                }
                let mut cur = l.clone();
                if in_range {
                    if let Some(i) = cur.find(']') {
                        cur = format!("{}    \"{NEW}\",\n]", &cur[..i]);
                        in_range = false;
                    }
                }
                out.push(cur);
            }
            out.join("\n")
        } else {
            insert_after_all(&ls.join("\n"), |l| l == "[general]", &format!("import = [\"{NEW}\"]"))
        }
    } else {
        // sed '1i [general]\nimport = [...]\n' (trailing \n inserts a blank line)
        format!("[general]\nimport = [\"{NEW}\"]\n\n{content}")
    };
    write_in_place(&f, &new);
    0
}

/// `^\s*config\.color_scheme\s*=` prefix length, else None.
fn wezterm_scheme_prefix(line: &str) -> Option<usize> {
    let t = &line[ws_star(line, 0)..];
    let r = t.strip_prefix("config.color_scheme")?;
    let i = ws_star(r, 0);
    let r2 = r[i..].strip_prefix('=')?;
    Some(line.len() - r2.len() + ws_star(r2, 0))
}

fn wezterm_is_nosdshell(line: &str) -> bool {
    // ^\s*config\.color_scheme\s*=\s*['"]NosDshell['"] (no end anchor)
    let Some(n) = wezterm_scheme_prefix(line) else { return false };
    let r = &line[n..];
    if !r.starts_with('\'') && !r.starts_with('"') {
        return false;
    }
    r[1..].strip_prefix("NosDshell").map(|a| matches!(a.as_bytes().first(), Some(b'\'') | Some(b'"'))).unwrap_or(false)
}

fn apply_wezterm() -> i32 {
    let f = cfg(".config/wezterm/wezterm.lua");
    let Some(content) = read(&f) else {
        eprintln!("Error: wezterm.lua not found at {}", f.display());
        eprintln!("Instructions to create it: https://wezterm.org/config/files.html");
        return 1;
    };
    if !lines_of(&content).iter().any(|l| wezterm_is_nosdshell(l)) {
        if lines_of(&content).iter().any(|l| wezterm_scheme_prefix(l).is_some()) {
            let new = lines_of(&content)
                .iter()
                .map(|l| match wezterm_scheme_prefix(l) {
                    Some(n) => format!("{}\"NosDshell\"", &l[..n]),
                    None => l.clone(),
                })
                .collect::<Vec<_>>()
                .join("\n");
            write_in_place(&f, &new);
        } else if lines_of(&content).iter().any(|l| is_return_config(l)) {
            // insert BEFORE the return line
            let mut out = Vec::new();
            for l in content.split('\n') {
                if is_return_config(l) {
                    out.push("config.color_scheme = \"NosDshell\"".to_string());
                }
                out.push(l.to_string());
            }
            write_in_place(&f, &out.join("\n"));
        } else {
            eprintln!("Warning: 'config.color_scheme' not set and 'return config' line not found.");
            eprintln!("         Make sure {} is correct: https://wezterm.org/config/files.html", f.display());
        }
    }
    // touching the config file fools wezterm into reloading it
    if let Ok(meta) = fs::metadata(&f) {
        if let Ok(fh) = fs::OpenOptions::new().write(true).open(&f) {
            let _ = fh.set_len(meta.len());
        }
    }
    0
}

fn is_return_config(line: &str) -> bool {
    // ^\s*return\s*config (no end anchor; \s* also matches zero ws)
    let t = &line[ws_star(line, 0)..];
    t.strip_prefix("return").map(|r| r[ws_star(r, 0)..].starts_with("config")).unwrap_or(false)
}

fn apply_fuzzel() -> i32 {
    const LINE: &str = "include=~/.config/fuzzel/themes/nosdshell";
    let f = cfg(".config/fuzzel/fuzzel.ini");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "include=~/.config/fuzzel/themes/nosdshell\n");
        return 0;
    }
    let content = read(&f).unwrap_or_default();
    let ls = lines_of(&content);
    if ls.iter().any(|l| l == LINE) {
        return 0;
    }
    let new = if ls.iter().any(|l| l.starts_with("include=") && l.contains("themes")) {
        ls.iter().map(|l| if l.starts_with("include=") && l.contains("themes") { LINE.to_string() } else { l.clone() }).collect::<Vec<_>>().join("\n")
    } else {
        // echo >> : plain append, fails on read-only files like bash
        write(&f, &format!("{content}include=~/.config/fuzzel/themes/nosdshell\n"));
        return 0;
    };
    write_in_place(&f, &new);
    0
}

fn apply_walker() -> i32 {
    let f = cfg(".config/walker/config.toml");
    let Some(content) = read(&f) else {
        eprintln!("Error: walker config file not found at {}", f.display());
        return 1;
    };
    let ls = lines_of(&content);
    if ls.iter().any(|l| {
        let t = &l[ws_star(l, 0)..];
        t.strip_prefix("theme").map(|r| {
            let i = ws_star(r, 0);
            r[i..].strip_prefix('=').map(|r2| r2[ws_star(r2, 0)..].starts_with("\"nosdshell\"")).unwrap_or(false)
        }).unwrap_or(false)
    }) {
        return 0;
    }
    let new = if ls.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "theme")) {
        ls.iter().map(|l| if line_assign(&l[ws_star(l, 0)..], "theme") { "theme = \"nosdshell\"".to_string() } else { l.clone() }).collect::<Vec<_>>().join("\n")
    } else {
        // echo >> : plain append, fails on read-only files like bash
        write(&f, &format!("{content}theme = \"nosdshell\"\n"));
        return 0;
    };
    write_in_place(&f, &new);
    0
}

fn apply_kitty() -> i32 {
    let nosdshell_theme = cfg(".config/kitty/themes/nosdshell.conf");
    let current_theme = cfg(".config/kitty/current-theme.conf");
    if nosdshell_theme.is_file() {
        if let Some(parent) = current_theme.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if current_theme.exists() || is_symlink(&current_theme) {
            let _ = fs::remove_file(&current_theme);
        }
        #[cfg(unix)]
        let _ = std::os::unix::fs::symlink("themes/nosdshell.conf", &current_theme);
    }
    let kitty_conf = cfg(".config/kitty/kitty.conf");
    if writable(&kitty_conf) {
        run_quiet("kitty", &["+kitten", "themes", "--reload-in=all", "nosdshell"]);
    } else {
        run_quiet("kitty", &["+runpy", "from kitty.utils import *; reload_conf_in_all_kitties()"]);
    }
    pkill(&["-USR1", "kitty"]);
    0
}

fn apply_vicinae() -> i32 {
    run_quiet("vicinae", &["theme", "set", "nosdshell"]);
    0
}

fn apply_pywalfox(mode: Option<&str>) -> i32 {
    if let Some(m) = mode {
        if m == "dark" || m == "light" {
            run_quiet("pywalfox", &[m]);
        } else {
            eprintln!("Warning: Invalid mode '{m}'. Expected 'dark' or 'light'. Skipping mode switch.");
        }
    }
    run_quiet("pywalfox", &["update"]);
    0
}

fn apply_cava() -> i32 {
    let f = cfg(".config/cava/config");
    let Some(content) = read(&f) else {
        eprintln!("Error: cava config file not found at {}", f.display());
        return 1;
    };
    let ls = lines_of(&content);
    if ls.iter().any(|l| l == "[color]") {
        let in_color = section_lines(&ls, "[color]");
        let is_set = in_color.iter().any(|l| {
            let t = &l[ws_star(l, 0)..];
            t.strip_prefix("theme").map(|r| {
                let i = ws_star(r, 0);
                r[i..].strip_prefix('=').map(|r2| r2[ws_star(r2, 0)..].starts_with("\"nosdshell\"")).unwrap_or(false)
            }).unwrap_or(false)
        });
        let has_theme = in_color.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "theme"));
        if !is_set {
            let edited = edit_section(&content, "[color]", |l| {
                if line_assign(&l[ws_star(l, 0)..], "theme") {
                    Some("theme = \"nosdshell\"".to_string())
                } else {
                    None
                }
            });
            let new = if has_theme {
                edited
            } else {
                insert_after_all(&edited, |l| l == "[color]", "theme = \"nosdshell\"")
            };
            write_in_place(&f, &new);
        }
    } else {
        write(&f, &format!("{content}\n[color]\ntheme = \"nosdshell\"\n"));
    }
    if pgrep_f("cava") {
        let list = run_capture("pgrep", &["-af", "cava"]).unwrap_or_default();
        // grep -q -- "-p.*stdin": -p occurs before stdin on the same line
        let uses_stdin = list.split('\n').any(|l| {
            l.find("-p").map(|i| l[i..].contains("stdin")).unwrap_or(false)
        });
        if !uses_stdin {
            pkill(&["-USR1", "cava"]);
        }
    }
    0
}

fn apply_yazi() -> i32 {
    let f = cfg(".config/yazi/theme.toml");
    if let Some(parent) = f.parent() {
        let _ = fs::create_dir_all(parent);
    }
    let Some(content) = read(&f) else {
        write(&f, "[flavor]\ndark  = \"nosdshell\"\nlight = \"nosdshell\"\n");
        return 0;
    };
    let ls = lines_of(&content);
    if !ls.iter().any(|l| l == "[flavor]") {
        // echo "" + [flavor] + dark + light
        write(&f, &format!("{content}\n[flavor]\ndark  = \"nosdshell\"\nlight = \"nosdshell\"\n"));
        return 0;
    }
    let mut new = content.clone();
    let in_flavor = section_lines(&ls, "[flavor]");
    if in_flavor.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "dark")) {
        new = edit_section(&new, "[flavor]", |l| {
            if line_assign(&l[ws_star(l, 0)..], "dark") {
                Some("dark  = \"nosdshell\"".to_string())
            } else {
                None
            }
        });
    } else {
        new = insert_after_all(&new, |l| l == "[flavor]", "dark  = \"nosdshell\"");
    }
    let ls2 = lines_of(&new);
    let in_flavor2 = section_lines(&ls2, "[flavor]");
    if in_flavor2.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "light")) {
        new = edit_section(&new, "[flavor]", |l| {
            if line_assign(&l[ws_star(l, 0)..], "light") {
                Some("light = \"nosdshell\"".to_string())
            } else {
                None
            }
        });
    } else {
        // sed: /^\[flavor\]/,/^dark/a light = "nosdshell"
        // (append after every line from [flavor] through the first ^dark line)
        let mut out = Vec::new();
        let mut in_range = false;
        for l in new.split('\n') {
            out.push(l.to_string());
            if in_range {
                out.push("light = \"nosdshell\"".to_string());
                if l.starts_with("dark") {
                    in_range = false;
                }
            } else if l == "[flavor]" {
                in_range = true;
                out.push("light = \"nosdshell\"".to_string());
            }
        }
        new = out.join("\n");
    }
    write_in_place(&f, &new);
    0
}

fn apply_niri() -> i32 {
    const LINE: &str = "include \"./nosdshell.kdl\"";
    let f = cfg(".config/niri/config.kdl");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "\ninclude \"./nosdshell.kdl\"\n\n");
        return 0;
    }
    let content = read(&f).unwrap_or_default();
    // include\s+["'](./)?nosdshell\.kdl["']
    let has = content.split('\n').any(|l| {
        let t = &l[ws_star(l, 0)..];
        let Some(r) = t.strip_prefix("include") else { return false };
        if r.is_empty() || !ws(r.as_bytes()[0]) {
            return false;
        }
        let r = &r[ws_star(r, 0)..];
        let Some(body) = r.strip_prefix('\'').or_else(|| r.strip_prefix('"')) else { return false };
        let inner = body.strip_prefix("./").unwrap_or(body);
        inner.strip_prefix("nosdshell.kdl").map(|a| a.starts_with('\'') || a.starts_with('"')).unwrap_or(false)
    });
    if !has {
        write(&f, &format!("{content}\n{LINE}\n\n"));
    }
    0
}

fn apply_hyprland() -> i32 {
    println!("🎨 Applying 'nosdshell' theme to Hyprland...");
    let dir = cfg(".config/hypr");
    let lua_cfg = dir.join("hyprland.lua");
    let conf_cfg = dir.join("hyprland.conf");
    if lua_cfg.is_file() {
        let content = read(&lua_cfg).unwrap_or_default();
        if !content.contains("nosdshell-colors.lua") {
            convert_readonly_symlink(&lua_cfg);
            let theme = dir.join("nosdshell/nosdshell-colors.lua");
            let line = format!("dofile(\"{}\")", theme.display());
            write(&lua_cfg, &format!("{content}\n-- This loads NosDshell-generated Hyprland colors.\n{line}\n"));
            println!("Added NosDshell Lua theme include to config.");
        } else {
            println!("Lua theme already included, skipping modification.");
        }
    } else if !conf_cfg.is_file() {
        if let Some(parent) = conf_cfg.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let theme = dir.join("nosdshell/nosdshell-colors.conf");
        write(&conf_cfg, &format!("\nsource = {}\n", theme.display()));
        println!("Config file not found, creating {}...", conf_cfg.display());
        println!("Created new config file with nosdshell theme.");
    } else {
        let content = read(&conf_cfg).unwrap_or_default();
        let has = content.split('\n').any(|l| {
            let t = &l[ws_star(l, 0)..];
            let Some(r) = t.strip_prefix("source") else { return false };
            let i = ws_star(r, 0);
            let Some(r2) = r[i..].strip_prefix('=') else { return false };
            let rest = &r2[ws_star(r2, 0)..];
            rest.contains("nosdshell") && rest.contains(".conf")
        });
        if has {
            println!("Theme already included, skipping modification.");
        } else {
            convert_readonly_symlink(&conf_cfg);
            let theme = dir.join("nosdshell/nosdshell-colors.conf");
            write(&conf_cfg, &format!("{content}\nsource = {}\n", theme.display()));
            println!("Added nosdshell theme include to config.");
        }
    }
    run_quiet("hyprctl", &["reload"]);
    0
}

fn sway_include_present(line: &str) -> bool {
    let t = &line[ws_star(line, 0)..];
    let Some(r) = t.strip_prefix("include") else { return false };
    if r.is_empty() || !ws(r.as_bytes()[0]) {
        return false;
    }
    r.contains("nosdshell")
}

fn apply_sway() -> i32 {
    println!("🎨 Applying 'nosdshell' theme to Sway...");
    let dir = cfg(".config/sway");
    let f = dir.join("config");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "\ninclude ~/.config/sway/nosdshell\n\n");
        println!("Config file not found, creating {}...", f.display());
        println!("Created new config file with nosdshell theme.");
    } else {
        let content = read(&f).unwrap_or_default();
        if content.split('\n').any(sway_include_present) {
            println!("Theme already included, skipping modification.");
        } else {
            convert_readonly_symlink(&f);
            write(&f, &format!("{content}\ninclude ~/.config/sway/nosdshell\n\n"));
            println!("✅ Added nosdshell theme include to config.");
        }
    }
    run_quiet("swaymsg", &["reload"]);
    0
}

fn apply_scroll() -> i32 {
    println!("Applying 'nosdshell' theme to Scroll...");
    let dir = cfg(".config/scroll");
    let f = dir.join("config");
    if !f.is_file() {
        if let Some(parent) = f.parent() {
            let _ = fs::create_dir_all(parent);
        }
        write(&f, "\ninclude ~/.config/scroll/nosdshell\n\n");
        println!("Config file not found, creating {}...", f.display());
        println!("Created new config file with nosdshell theme.");
    } else {
        let content = read(&f).unwrap_or_default();
        let has = content.split('\n').any(|l| {
            let t = &l[ws_star(l, 0)..];
            let Some(r) = t.strip_prefix("include") else { return false };
            if r.is_empty() || !ws(r.as_bytes()[0]) {
                return false;
            }
            r.contains("nosdshell")
        });
        if has {
            println!("Theme already included, skipping modification.");
        } else {
            convert_readonly_symlink(&f);
            write(&f, &format!("{content}\ninclude ~/.config/scroll/nosdshell\n\n"));
            println!("Added nosdshell theme include to config.");
        }
    }
    run_quiet("scrollmsg", &["reload"]);
    0
}

const MANGO_VARS: &[&str] = &[
    "shadowscolor", "rootcolor", "bordercolor", "focuscolor", "maximizescreencolor", "urgentcolor",
    "scratchpadcolor", "globalcolor", "overlaycolor",
];

fn mango_is_colorvar(line: &str) -> bool {
    MANGO_VARS.iter().any(|v| line_assign(line, v))
}

fn apply_mango() -> i32 {
    let dir = cfg(".config/mango");
    let main = dir.join("config.conf");
    let theme_file = dir.join("nosdshell.conf");
    let backup = dir.join("theme.conf.bak");
    let source_line = format!("source = {}", theme_file.display());
    let _ = fs::create_dir_all(&dir);
    let already = main.is_file() && read(&main).map(|c| c.contains(&source_line)).unwrap_or(false);
    if !already {
        if let Ok(rd) = fs::read_dir(&dir) {
            let mut confs: Vec<PathBuf> = rd
                .filter_map(|e| e.ok().map(|e| e.path()))
                .filter(|p| p.extension().and_then(|e| e.to_str()) == Some("conf"))
                .collect();
            confs.sort();
            for conf in confs {
                if conf == theme_file {
                    continue;
                }
                let Ok(content) = fs::read_to_string(&conf) else { continue };
                if !content.split('\n').any(mango_is_colorvar) {
                    continue;
                }
                let extracted: Vec<&str> =
                    content.split('\n').filter(|l| mango_is_colorvar(l)).collect();
                if let Ok(mut bf) = fs::OpenOptions::new().create(true).append(true).open(&backup) {
                    for l in &extracted {
                        let _ = writeln!(bf, "{l}");
                    }
                }
                let target = fs::canonicalize(&conf).unwrap_or_else(|_| conf.clone());
                if is_symlink(&conf) && !writable(&conf) {
                    convert_readonly_symlink(&conf);
                    if let Ok(c2) = fs::read_to_string(&conf) {
                        let new: Vec<&str> =
                            c2.split('\n').filter(|l| !mango_is_colorvar(l)).collect();
                        write_in_place(&conf, &new.join("\n"));
                    }
                } else if let Ok(c2) = fs::read_to_string(&target) {
                    let new: Vec<&str> =
                        c2.split('\n').filter(|l| !mango_is_colorvar(l)).collect();
                    write_in_place(&target, &new.join("\n"));
                }
            }
        }
        convert_readonly_symlink(&main);
        if main.is_file() {
            let cur = read(&main).unwrap_or_default();
            write(&main, &format!("{cur}\n# This sources the nosdshell theme\n\n{source_line}\n\n"));
        } else {
            write(&main, &format!("# This sources the nosdshell theme\n\n{source_line}\n\n"));
        }
    }
    if have("mmsg") {
        run_quiet("mmsg", &["-s", "-d", "reload_config"]);
    } else {
        eprintln!("Warning: mmsg command not found, manual restart may be needed.");
    }
    0
}

fn apply_btop() -> i32 {
    let f = cfg(".config/btop/btop.conf");
    let Some(content) = read(&f) else {
        eprintln!("Warning: btop config file not found at {}", f.display());
        return 0;
    };
    let ls = lines_of(&content);
    let is_set = ls.iter().any(|l| {
        let t = &l[ws_star(l, 0)..];
        t.strip_prefix("color_theme").map(|r| {
            let i = ws_star(r, 0);
            r[i..].strip_prefix('=').map(|r2| r2[ws_star(r2, 0)..].starts_with("\"nosdshell\"")).unwrap_or(false)
        }).unwrap_or(false)
    });
    if !is_set {
        if ls.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "color_theme")) {
            let new: Vec<String> = ls.iter().map(|l| if line_assign(&l[ws_star(l, 0)..], "color_theme") { "color_theme = \"nosdshell\"".to_string() } else { l.clone() }).collect();
            write_in_place(&f, &new.join("\n"));
        } else {
            // echo >> : plain append, fails on read-only files like bash
            write(&f, &format!("{content}color_theme = \"nosdshell\"\n"));
        }
    }
    if std::process::Command::new("pgrep").args(["-x", "btop"]).status().map(|s| s.success()).unwrap_or(false) {
        pkill(&["-SIGUSR2", "-x", "btop"]);
    }
    0
}

fn apply_zathura() -> i32 {
    let list = run_capture(
        "dbus-send",
        &[
            "--session", "--dest=org.freedesktop.DBus", "--type=method_call", "--print-reply",
            "/org/freedesktop/DBus", "org.freedesktop.DBus.ListNames",
        ],
    )
    .unwrap_or_default();
    for token in list.split_whitespace() {
        let t = token.trim_matches('"');
        if t.starts_with("org.pwmt.zathura.PID-")
            && t["org.pwmt.zathura.PID-".len()..].bytes().all(|b| b.is_ascii_digit())
            && !t["org.pwmt.zathura.PID-".len()..].is_empty()
        {
            run_quiet(
                "dbus-send",
                &[
                    "--session",
                    &format!("--dest={t}"),
                    "--type=method_call",
                    "/org/pwmt/zathura",
                    "org.pwmt.zathura.ExecuteCommand",
                    "string:source",
                ],
            );
        }
    }
    0
}

fn apply_starship() -> i32 {
    let palette = cfg(".cache/nosdshell/starship-palette.toml");
    let config = match env::var("STARSHIP_CONFIG") {
        Ok(s) if !s.is_empty() => PathBuf::from(s),
        _ => {
            let a = cfg(".config/starship.toml");
            let b = cfg(".config/starship/starship.toml");
            if a.is_file() {
                a
            } else if b.is_file() {
                b
            } else {
                a
            }
        }
    };
    // NOTE: bash uses top-level `return` here, which in an executed script
    // only prints an error and FALLS THROUGH. Mirror the fall-through.
    let have_palette = palette.is_file();
    if !have_palette {
        eprintln!("Error: Starship palette file not found at {}", palette.display());
    }
    const BEGIN: &str = "# >>> NOSDSHELL STARSHIP PALETTE >>>";
    const END: &str = "# <<< NOSDSHELL STARSHIP PALETTE <<<";
    if !config.is_file() {
        if let Some(parent) = config.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let pal = read(&palette).unwrap_or_default();
        write(&config, &format!("palette = \"nosdshell\"\n\n{BEGIN}\n{pal}{END}\n"));
        // fall through (bash `return 0` does not exit)
    }
    let mut target = config.clone();
    if is_symlink(&target) {
        target = fs::canonicalize(&target).unwrap_or(target);
    }
    let mut content = read(&target).unwrap_or_default();
    let ls = lines_of(&content);
    if ls.iter().any(|l| line_assign(&l[ws_star(l, 0)..], "palette")) {
        // sed: s/^([[:space:]]*)palette([[:space:]]*)=.*/\1palette\2= "nosdshell"/
        content = ls
            .iter()
            .map(|l| {
                let k = ws_star(l, 0);
                let t = &l[k..];
                if line_assign(t, "palette") {
                    let rest = &t["palette".len()..];
                    let i = ws_star(rest, 0);
                    format!("{}palette{}= \"nosdshell\"", &l[..k], &rest[..i])
                } else {
                    l.clone()
                }
            })
            .collect::<Vec<_>>()
            .join("\n");
    } else if ls.iter().any(|l| l.trim_start().starts_with("\"$schema\"")) {
        let mut out = Vec::new();
        for l in content.split('\n') {
            out.push(l.to_string());
            if l.trim_start().starts_with("\"$schema\"") {
                out.push("palette = \"nosdshell\"".to_string());
            }
        }
        content = out.join("\n");
    } else {
        content = format!("palette = \"nosdshell\"\n{content}");
    }
    // sed -i steps above (mode-preserving); awk strip uses mv (fresh mode)
    write_in_place(&target, &content);
    if content.contains(BEGIN) {
        let mut out = Vec::new();
        let mut skip = false;
        for l in content.split('\n') {
            if l == BEGIN {
                skip = true;
            } else if l == END {
                skip = false;
            } else if !skip {
                out.push(l.to_string());
            }
        }
        content = out.join("\n");
        write_mv(&target, &content);
    }
    let pal = read(&palette).unwrap_or_default();
    let mut block = format!("\n{BEGIN}\n{pal}");
    if !pal.ends_with('\n') {
        block.push('\n');
    }
    block.push_str(&format!("{END}\n"));
    // { ... } >> file: plain append, fails on read-only files like bash
    let cur = read(&target).unwrap_or(content);
    write(&target, &format!("{cur}{block}"));
    0
}

/// `command -v prog`: executable file found on PATH.
fn have(prog: &str) -> bool {
    if prog.contains('/') {
        return Path::new(prog).is_file();
    }
    env::var_os("PATH").map(|p| {
        env::split_paths(&p).any(|d| {
            let c = d.join(prog);
            c.is_file()
        })
    }).unwrap_or(false)
}

fn apply_labwc() -> i32 {
    run_quiet("labwc", &["-r"]);
    0
}

pub fn run(args: &[String]) -> i32 {
    if args.is_empty() {
        eprintln!("Error: No application specified.");
        eprintln!("Usage: nosd-helpers apply {{kitty|ghostty|foot|alacritty|wezterm|starship|fuzzel|walker|pywalfox|cava|yazi|labwc|niri|hyprland|sway|scroll|mango|btop|zathura}} [dark|light]");
        return 1;
    }
    let (app, mode) = (&args[0], args.get(1).map(|s| s.as_str()));
    match app.as_str() {
        "kitty" => apply_kitty(),
        "ghostty" => apply_ghostty(),
        "foot" => apply_foot(),
        "alacritty" => apply_alacritty(),
        "wezterm" => apply_wezterm(),
        "fuzzel" => apply_fuzzel(),
        "walker" => apply_walker(),
        "vicinae" => apply_vicinae(),
        "pywalfox" => apply_pywalfox(mode),
        "cava" => apply_cava(),
        "yazi" => apply_yazi(),
        "labwc" => apply_labwc(),
        "niri" => apply_niri(),
        "hyprland" => apply_hyprland(),
        "sway" => apply_sway(),
        "scroll" => apply_scroll(),
        "mango" => apply_mango(),
        "btop" => apply_btop(),
        "zathura" => apply_zathura(),
        "starship" => apply_starship(),
        _ => {
            eprintln!("Error: Unknown application '{app}'.");
            1
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn assign_matcher() {
        assert!(line_assign("theme = nosdshell", "theme"));
        assert!(line_assign("theme=nosdshell", "theme"));
        assert!(line_assign("theme\t =\tx", "theme"));
        assert!(!line_assign("xtheme = x", "theme"));
        assert!(!line_assign("theme", "theme"));
        assert!(!line_assign("themefoo = x", "theme"));
        assert!(line_assign("palette  = \"old\"", "palette"));
    }

    #[test]
    fn ghostty_matchers() {
        assert!(ghostty_theme_set("theme = nosdshell", "nosdshell"));
        assert!(ghostty_theme_set("  theme\t=\tnosdshell", "nosdshell"));
        assert!(!ghostty_theme_set("theme = catppuccin", "nosdshell"));
        assert!(!ghostty_theme_set("# theme = nosdshell", "nosdshell"));
        assert!(ghostty_has_theme("theme = catppuccin"));
        assert!(!ghostty_has_theme("font-size = 12"));
    }

    #[test]
    fn wezterm_matchers() {
        assert_eq!(wezterm_scheme_prefix("  config.color_scheme = 'NosDshell'"), Some(24));
        assert!(wezterm_scheme_prefix("config.color_scheme='x'").is_some());
        assert!(wezterm_scheme_prefix("-- config.color_scheme = 'x'").is_none());
        assert!(wezterm_is_nosdshell("config.color_scheme = \"NosDshell\""));
        assert!(wezterm_is_nosdshell("config.color_scheme='NosDshell' -- themed"));
        assert!(wezterm_is_nosdshell("config.color_scheme = 'NosDshell\""));
        assert!(!wezterm_is_nosdshell("config.color_scheme = \"NosDshellX\""));
        assert!(!wezterm_is_nosdshell("config.color_scheme = NosDshell"));
        assert!(is_return_config("return config"));
        assert!(is_return_config("  return   config"));
        assert!(is_return_config("return config2"));
        assert!(!is_return_config("-- return config"));
    }

    #[test]
    fn section_edit_is_sed_like() {
        let src = "[a]\nx = 1\n[color]\ntheme = \"old\"\nplain\n[other]\nz = 2\n";
        let out = edit_section(src, "[color]", |l| {
            if line_assign(&l[ws_star(l, 0)..], "theme") {
                Some("theme = \"nosdshell\"".to_string())
            } else {
                None
            }
        });
        assert!(out.contains("theme = \"nosdshell\""));
        assert!(out.contains("x = 1"));
        assert!(out.contains("z = 2"));
        // range is inclusive of the closing header
        let ls: Vec<String> = lines_of(src);
        let sec: Vec<&str> = section_lines(&ls, "[color]");
        assert_eq!(sec, vec!["[color]", "theme = \"old\"", "plain", "[other]"]);
    }

    #[test]
    fn insert_after_every_match() {
        let out = insert_after_all("[main]\na\n[main]\nb", |l| l == "[main]", "INS");
        assert_eq!(out, "[main]\nINS\na\n[main]\nINS\nb");
    }

    #[test]
    fn mango_var_matcher() {
        assert!(mango_is_colorvar("bordercolor = #fff"));
        assert!(mango_is_colorvar("overlaycolor= x"));
        assert!(!mango_is_colorvar("# bordercolor = x"));
        assert!(!mango_is_colorvar("xbordercolor = x"));
        assert!(!mango_is_colorvar("bordercolor2 = x"));
    }

    #[test]
    fn sway_niri_matchers() {
        assert!(sway_include_present("include ~/.config/sway/nosdshell"));
        assert!(sway_include_present("\tinclude other nosdshell"));
        assert!(!sway_include_present("# include nosdshell"));
        assert!(!sway_include_present("includesway"));
    }
}
