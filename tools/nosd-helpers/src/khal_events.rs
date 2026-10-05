#![forbid(unsafe_code)]

//! khal calendar event listing.
//! Mirrors Scripts/python/src/calendar/khal-events.py: read khal's
//! longdatetimeformat, ask `khal list --json ...` for a date range, and
//! rewrite the start/end-long-full fields to ISO-8601, one JSON array per
//! output line.
//!
//! Note: `%c` (locale's default format) renders through the platform locale
//! in both implementations; byte-identical output across python/chrono for
//! exotic locale formats is not guaranteed, field semantics are.

use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

use chrono::NaiveDate;

const KHAL_ARGS: [&str; 15] = [
    "khal",
    "list",
    "--json",
    "uid",
    "--json",
    "title",
    "--json",
    "start-long-full",
    "--json",
    "end-long-full",
    "--json",
    "calendar",
    "--json",
    "description",
    "--json",
];

const KHAL_TAIL_ARGS: [&str; 3] = ["location", "--json", "repeat-pattern"];

fn khal_config_path() -> PathBuf {
    let base = env::var("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home().join(".config"));
    base.join("khal/config")
}

fn home() -> PathBuf {
    env::var("HOME").map(PathBuf::from).unwrap_or_else(|_| PathBuf::from("/root"))
}

/// Extract `longdatetimeformat` from the khal config, defaulting to `%c`.
pub fn khal_date_format() -> String {
    khal_date_format_in(&khal_config_path())
}

fn khal_date_format_in(path: &std::path::Path) -> String {
    let Ok(text) = fs::read_to_string(path) else {
        return "%c".to_string();
    };
    for line in text.lines() {
        let t = line.trim_end();
        if let Some(rest) = t.strip_prefix("longdatetimeformat") {
            let rest = rest.trim_start();
            let rest = rest.strip_prefix('=').unwrap_or(rest).trim();
            if !rest.is_empty() {
                return rest.to_string();
            }
        }
    }
    "%c".to_string()
}

/// `YYYY-MM-DD` -> khal display format. Mirrors `to_khal`.
pub fn to_khal(date: &str, fmt: &str) -> Result<String, String> {
    use std::fmt::Write as _;
    let d = NaiveDate::parse_from_str(date.trim(), "%Y-%m-%d")
        .map_err(|e| format!("bad start date {date:?}: {e}"))?;
    let dt = d.and_hms_opt(0, 0, 0).ok_or("bad start date")?;
    let mut s = String::new();
    write!(s, "{}", dt.format(fmt)).map_err(|_| format!("bad khal format {fmt:?}"))?;
    Ok(s)
}

/// khal display format -> ISO-8601 (`YYYY-MM-DDTHH:MM:SS`). Mirrors `from_khal`.
pub fn from_khal(date: &str, fmt: &str) -> Result<String, String> {
    if date.is_empty() {
        return Ok(String::new());
    }
    let dt = chrono::NaiveDateTime::parse_from_str(date, fmt)
        .map_err(|e| format!("bad khal date {date:?}: {e}"))?;
    Ok(dt.format("%Y-%m-%dT%H:%M:%S").to_string())
}

pub fn run(args: &[String]) -> i32 {
    if args.len() != 2 {
        eprintln!("Usage: nosd-helpers khal-events <YYYY-MM-DD> <duration>");
        return 2;
    }
    let fmt = khal_date_format();
    let khal_start = match to_khal(&args[0], &fmt) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("khal-events: {e}");
            return 1;
        }
    };
    let out = match Command::new(KHAL_ARGS[0])
        .args(&KHAL_ARGS[1..])
        .args(KHAL_TAIL_ARGS)
        .arg(&khal_start)
        .arg(&args[1])
        .output()
    {
        Ok(o) => o,
        Err(e) => {
            eprintln!("khal-events: cannot run khal: {e}");
            return 1;
        }
    };
    if !out.status.success() {
        eprintln!(
            "khal-events: khal failed: {}",
            String::from_utf8_lossy(&out.stderr).trim()
        );
        return 1;
    }
    let stdout = String::from_utf8_lossy(&out.stdout);
    for line in stdout.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let mut day_events: Vec<serde_json::Value> = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(e) => {
                eprintln!("khal-events: bad khal output line: {e}");
                return 1;
            }
        };
        for ev in &mut day_events {
            for key in ["start-long-full", "end-long-full"] {
                let raw = ev.get(key).and_then(|v| v.as_str()).unwrap_or("").to_string();
                match from_khal(&raw, &fmt) {
                    Ok(conv) => ev[key] = serde_json::Value::String(conv),
                    Err(e) => {
                        eprintln!("khal-events: {e}");
                        return 1;
                    }
                }
            }
        }
        println!("{}", serde_json::to_string(&day_events).unwrap_or_default());
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn roundtrip_fixed_format() {
        let fmt = "%d.%m.%Y %H:%M";
        let khal = to_khal("2026-10-05", fmt).unwrap();
        assert_eq!(khal, "05.10.2026 00:00");
        assert_eq!(from_khal(&khal, fmt).unwrap(), "2026-10-05T00:00:00");
    }

    #[test]
    fn empty_stays_empty() {
        assert_eq!(from_khal("", "%d.%m.%Y %H:%M").unwrap(), "");
    }

    #[test]
    fn bad_date_is_error() {
        assert!(to_khal("not-a-date", "%d.%m.%Y").is_err());
    }

    #[test]
    fn config_format_parsing() {
        let d = env::temp_dir().join("nosd-khal-config-test");
        let _ = fs::remove_dir_all(&d);
        fs::create_dir_all(&d).unwrap();
        let cfg = d.join("config");
        fs::write(&cfg, "[locale]\nlongdatetimeformat = %Y/%m/%d %H:%M\n").unwrap();
        assert_eq!(khal_date_format_in(&cfg), "%Y/%m/%d %H:%M");
        fs::write(&cfg, "[locale]\n# no format here\n").unwrap();
        assert_eq!(khal_date_format_in(&cfg), "%c");
        let _ = fs::remove_dir_all(&d);
    }

    #[test]
    fn missing_config_defaults() {
        assert_eq!(
            khal_date_format_in(std::path::Path::new("/nonexistent-nosd-khal-config")),
            "%c"
        );
    }
}
