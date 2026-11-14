#![forbid(unsafe_code)]

//! Minimal iCalendar VEVENT parsing plus recurrence expansion.
//! Mirrors the per-object logic of Scripts/python/src/calendar/calendar-events.py.
//!
//! Quirks verified against the live python oracle (same EDS fixture) and kept
//! intentionally, same observable behavior:
//! - SECONDLY recurrences yield zero occurrences (`if freq:` is falsy for 0).
//! - RDATE/EXDATE lists are ignored: the ICalGLib calls the original relies
//!   on (`get_rdate_list`) don't exist, so it always falls back to `[]`.
//!   RDATE-only components therefore take the normal path (one row).
//! - EDS strips RRULEs it can't validate (e.g. unknown FREQ); those arrive
//!   RRULE-less and take the normal path too. A well-formed RRULE with an
//!   unknown frequency would yield one row via python `case _`.
//! - Non-UTC stamps ignore TZID and read as local wall time (ICalGLib finds
//!   no timezone on EDS's bare VEVENT strings, so python stays naive).
//! - Missing DTEND normalizes like libical: all-day runs to the next day,
//!   date-times are zero-duration. Only a present-but-garbage DTEND falls
//!   back to start + 3600 s.
//! - A normal event without DTSTART is still emitted with a null start.
//! - Normal path keeps a missing SUMMARY as null; the recurrent path coerces
//!   it to "(No title)".
//!
//! Intentional divergence: python's final `sort(key=start)` crashes with no
//! output at all when a null start is present; Rust sorts nulls first and
//! still emits every event.

use std::collections::HashMap;
use std::str::FromStr;
use std::sync::OnceLock;

use chrono::{DateTime, Datelike, Months, NaiveDate, NaiveDateTime, TimeZone, Timelike};
use chrono_tz::Tz;

/// One parsed VEVENT (any component block, like the python comp path).
#[derive(Debug, Default, Clone)]
pub struct Component {
    pub summary: Option<String>,
    pub location: Option<String>,
    pub description: Option<String>,
    pub uid: Option<String>,
    pub dtstart: Option<Stamp>,
    pub dtend: Option<Stamp>,
    pub dtend_present: bool,
    pub rrule_text: Option<String>,
}

/// A parsed DATE / DATE-TIME value. A TZID parameter, when present, is
/// ignored (the oracle reads such stamps as naive local wall time).
#[derive(Debug, Clone)]
pub struct Stamp {
    pub all_day: bool,
    pub ymd: (i32, u32, u32),
    pub hms: Option<(u32, u32, u32)>,
    pub utc: bool,
}

/// Recurrence spec. `freq`: 0 SECONDLY .. 6 YEARLY (ICalGLib enum),
/// 7 anything else (yields one occurrence via `case _`).
#[derive(Debug, Clone)]
pub struct Recur {
    pub freq: u8,
    pub interval: i64,
    pub count: i64, // 0 = unbounded, capped by until/end_time
    pub until: Option<Stamp>,
}

/// Unfold RFC 5545 continued lines (CRLF followed by space/tab).
pub fn unfold(text: &str) -> Vec<String> {
    let mut lines: Vec<String> = Vec::new();
    for raw in text.replace("\r\n", "\n").replace('\r', "\n").split('\n') {
        if raw.starts_with(' ') || raw.starts_with('\t') {
            if let Some(last) = lines.last_mut() {
                last.push_str(raw.trim_start_matches([' ', '\t']));
            }
        } else if !raw.is_empty() {
            lines.push(raw.to_string());
        }
    }
    lines
}

fn split_prop(line: &str) -> Option<(&str, &str)> {
    // NAME;PARAM=...:value. Param values here (TZID, VALUE) contain no ':',
    // so the first ':' ends the head. Matches the inputs EDS emits.
    let ci = line.find(':')?;
    Some((&line[..ci], &line[ci + 1..]))
}

fn params_of(head: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    for part in head.split(';').skip(1) {
        if let Some((k, v)) = part.split_once('=') {
            map.insert(k.to_uppercase(), v.to_string());
        }
    }
    map
}

pub fn parse_stamp(head: &str, value: &str) -> Option<Stamp> {
    let params = params_of(head);
    if params.get("VALUE").map(|s| s.as_str()) == Some("DATE") {
        let d = NaiveDate::parse_from_str(value.trim(), "%Y%m%d").ok()?;
        return Some(Stamp { all_day: true, ymd: (d.year(), d.month(), d.day()), hms: None, utc: false });
    }
    let (core, utc) = match value.strip_suffix('Z') {
        Some(c) => (c, true),
        None => (value, false),
    };
    if core.len() == 8 {
        let d = NaiveDate::parse_from_str(core, "%Y%m%d").ok()?;
        return Some(Stamp { all_day: true, ymd: (d.year(), d.month(), d.day()), hms: None, utc: false });
    }
    let dt = NaiveDateTime::parse_from_str(core, "%Y%m%dT%H%M%S").ok()?;
    Some(Stamp {
        all_day: false,
        ymd: (dt.year(), dt.month(), dt.day()),
        hms: Some((dt.hour(), dt.minute(), dt.second())),
        utc,
    })
}

/// Parse an RRULE value. `None` = structurally unusable (python would raise
/// while resolving the recurrence and abort the calendar). Unknown or absent
/// FREQ becomes 7, which python's `case _` turns into one occurrence.
pub fn parse_rrule(value: &str) -> Option<Recur> {
    let mut freq: Option<u8> = None;
    let mut freq_seen = false;
    let mut interval = 1i64;
    let mut count = 0i64;
    let mut until = None;
    let mut any = false;
    for part in value.split(';') {
        let (k, v) = part.split_once('=')?;
        any = true;
        match k.to_uppercase().as_str() {
            "FREQ" => {
                freq_seen = true;
                freq = Some(match v.to_uppercase().as_str() {
                    "SECONDLY" => 0,
                    "MINUTELY" => 1,
                    "HOURLY" => 2,
                    "DAILY" => 3,
                    "WEEKLY" => 4,
                    "MONTHLY" => 5,
                    "YEARLY" => 6,
                    _ => 7,
                });
            }
            "INTERVAL" => interval = v.parse().unwrap_or(1).max(1),
            "COUNT" => count = v.parse().unwrap_or(0),
            "UNTIL" => until = parse_stamp("UNTIL", v),
            _ => {}
        }
    }
    if !any {
        return None;
    }
    let _ = freq_seen;
    Some(Recur { freq: freq.unwrap_or(7), interval, count, until })
}

/// Parse every BEGIN:/END: component block (normally VEVENTs from EDS).
pub fn parse_components(text: &str) -> Vec<Component> {
    let mut out = Vec::new();
    let mut cur: Option<Component> = None;
    for line in unfold(text) {
        if line.starts_with("BEGIN:") {
            cur = Some(Component::default());
            continue;
        }
        if line.starts_with("END:") {
            if let Some(c) = cur.take() {
                out.push(c);
            }
            continue;
        }
        let Some(comp) = cur.as_mut() else { continue };
        let Some((head, value)) = split_prop(&line) else { continue };
        let name = head.split(';').next().unwrap_or("").to_uppercase();
        match name.as_str() {
            "SUMMARY" => comp.summary = Some(value.to_string()),
            "LOCATION" => comp.location = Some(value.to_string()),
            "DESCRIPTION" => comp.description = Some(value.to_string()),
            "UID" => comp.uid = Some(value.to_string()),
            "DTSTART" => comp.dtstart = parse_stamp(head, value),
            "DTEND" => {
                comp.dtend_present = true;
                comp.dtend = parse_stamp(head, value);
            }
            "RRULE" => comp.rrule_text = Some(value.to_string()),
            _ => {}
        }
    }
    out
}

fn zone_from_tz_value(val: &str) -> Option<Tz> {
    let val = val.trim();
    if val.is_empty() || val == "UTC" || val.starts_with(':') {
        return None;
    }
    Tz::from_str(val).ok()
}

fn zone_from_localtime_link(target: &str) -> Option<Tz> {
    // /etc/localtime -> .../zoneinfo/<Area/City>
    let rel = target.split("zoneinfo/").last()?;
    if rel == target {
        return None;
    }
    Tz::from_str(rel.trim()).ok()
}

fn zone_from_timezone_file(content: &str) -> Option<Tz> {
    Tz::from_str(content.trim()).ok()
}

/// System local zone, resolved explicitly: TZ env, then the /etc/localtime
/// symlink target, then /etc/timezone, else UTC. (chrono::Local assumes a
/// zoneinfo layout that Guix systems don't provide, so it collapses to UTC
/// there; this chain reads what glibc/python read.)
fn resolve_local_zone() -> Tz {
    if let Ok(tz) = std::env::var("TZ") {
        if let Some(z) = zone_from_tz_value(&tz) {
            return z;
        }
    }
    if let Ok(target) = std::fs::read_link("/etc/localtime") {
        if let Some(z) = target.to_str().and_then(zone_from_localtime_link) {
            return z;
        }
    }
    if let Ok(content) = std::fs::read_to_string("/etc/timezone") {
        if let Some(z) = zone_from_timezone_file(&content) {
            return z;
        }
    }
    Tz::UTC
}

pub fn local_zone() -> Tz {
    static ZONE: OnceLock<Tz> = OnceLock::new();
    *ZONE.get_or_init(resolve_local_zone)
}

/// Mirrors python `safe_get_time`: ical stamp -> epoch seconds.
/// Naive and all-day stamps are local wall time in `zone`.
pub fn stamp_to_ts(stamp: &Stamp, zone: Tz) -> Option<(i64, bool)> {
    let (y, mo, d) = stamp.ymd;
    if stamp.all_day {
        let naive = NaiveDate::from_ymd_opt(y, mo, d)?.and_hms_opt(0, 0, 0)?;
        return zone.from_local_datetime(&naive).earliest().map(|dt| (dt.timestamp(), true));
    }
    let (h, mi, s) = stamp.hms?;
    let naive = NaiveDate::from_ymd_opt(y, mo, d)?.and_hms_opt(h, mi, s)?;
    if stamp.utc {
        return Some((naive.and_utc().timestamp(), false));
    }
    // TZID is ignored like the oracle does: naive local wall time.
    zone.from_local_datetime(&naive).earliest().map(|dt| (dt.timestamp(), false))
}

fn zone_dt(ts: i64, zone: Tz) -> NaiveDateTime {
    DateTime::from_timestamp(ts, 0)
        .map(|d| d.with_timezone(&zone).naive_local())
        .unwrap_or_else(|| DateTime::from_timestamp(0, 0).unwrap().with_timezone(&zone).naive_local())
}

/// Normal (non-recurrent) event: always exactly one row, even with a null
/// start. Missing DTEND follows libical: next day for all-day, zero
/// duration otherwise; a present-but-garbage DTEND falls back to +3600 s.
pub fn expand_normal(comp: &Component, zone: Tz) -> Vec<(Option<i64>, Option<i64>)> {
    let start_ts = comp.dtstart.as_ref().and_then(|s| stamp_to_ts(s, zone).map(|t| t.0));
    let mut end_ts = comp.dtend.as_ref().and_then(|s| stamp_to_ts(s, zone).map(|t| t.0));
    if end_ts.is_none() {
        end_ts = match (start_ts, comp.dtend_present) {
            (Some(s), false) => {
                let all_day = comp.dtstart.as_ref().map(|t| t.all_day).unwrap_or(false);
                Some(if all_day { s + 86400 } else { s })
            }
            (Some(s), true) => Some(s + 3600),
            _ => None,
        };
    }
    vec![(start_ts, end_ts)]
}

/// Recurrent expansion with the component's own RRULE spec.
/// Err aborts the rest of the calendar.
pub fn expand_recurrent(
    comp: &Component,
    spec: &Recur,
    zone: Tz,
    end_time: i64,
) -> Result<Vec<(Option<i64>, Option<i64>)>, String> {
    // `if freq:` — SECONDLY (0) is falsy and yields zero occurrences.
    if spec.freq == 0 {
        return Ok(Vec::new());
    }
    let start_ts = comp
        .dtstart
        .as_ref()
        .and_then(|s| stamp_to_ts(s, zone).map(|t| t.0))
        .ok_or("recurrent event without DTSTART")?;
    let mut end_ts = comp.dtend.as_ref().and_then(|s| stamp_to_ts(s, zone).map(|t| t.0));
    if end_ts.is_none() {
        let all_day = comp.dtstart.as_ref().map(|t| t.all_day).unwrap_or(false);
        end_ts = Some(if !comp.dtend_present && all_day { start_ts + 86400 } else { start_ts + 3600 });
    }
    let end_ts = end_ts.unwrap();
    let duration = end_ts - start_ts;
    let interval = spec.interval.max(1);
    let count = spec.count;
    let until_ts = spec.until.as_ref().and_then(|s| stamp_to_ts(s, zone).map(|t| t.0)).unwrap_or(end_time);

    let mut occurrences = Vec::new();
    match spec.freq {
        1 | 2 | 3 | 4 => {
            // MINUTELY..WEEKLY via fixed steps, exactly like the timedeltas.
            let step: i64 = match spec.freq {
                1 => 60 * interval,
                2 => 3600 * interval,
                3 => 86400 * interval,
                _ => 7 * 86400 * interval,
            };
            let mut current = start_ts;
            let mut added = 0i64;
            while current <= until_ts && (count == 0 || added < count) {
                occurrences.push((current, current + duration));
                current += step;
                added += 1;
            }
        }
        5 | 6 => {
            // MONTHLY/YEARLY via calendar arithmetic (dateutil.relativedelta:
            // clamping, non-sticky: Jan 31 -> Feb 28 -> Mar 28).
            let mut dt = zone_dt(start_ts, zone);
            let mut current = start_ts;
            let mut added = 0i64;
            while current <= until_ts && (count == 0 || added < count) {
                occurrences.push((current, current + duration));
                let months = if spec.freq == 5 { interval } else { 12 * interval };
                dt = dt.checked_add_months(Months::new(months as u32)).ok_or("month overflow")?;
                current = zone
                    .from_local_datetime(&dt)
                    .earliest()
                    .map(|d| d.timestamp())
                    .ok_or("bad recurrence time")?;
                added += 1;
            }
        }
        _ => {
            // Unknown frequency: python `case _` emits one occurrence.
            occurrences.push((start_ts, end_ts));
        }
    }
    Ok(occurrences.into_iter().map(|(s, e)| (Some(s), Some(e))).collect())
}

#[cfg(test)]
mod tests {
    use super::*;

    const ZONE: Tz = Tz::Asia__Shanghai;

    fn ts(y: i32, mo: u32, d: u32, h: u32, mi: u32) -> i64 {
        // Expected value helper: UTC stamp (env-independent).
        chrono::NaiveDate::from_ymd_opt(y, mo, d)
            .unwrap()
            .and_hms_opt(h, mi, 0)
            .unwrap()
            .and_utc()
            .timestamp()
    }

    fn comp(text: &str) -> Component {
        let cs = parse_components(text);
        assert_eq!(cs.len(), 1);
        cs.into_iter().next().unwrap()
    }

    #[test]
    fn unfold_continuations() {
        let v = unfold("A:1\r\n B\r\nC:2");
        assert_eq!(v, vec!["A:1B", "C:2"]);
    }

    #[test]
    fn utc_and_allday_stamps() {
        let s = parse_stamp("DTSTART", "20261005T090000Z").unwrap();
        assert_eq!(stamp_to_ts(&s, ZONE).unwrap(), (ts(2026, 10, 5, 9, 0), false));
        let a = parse_stamp("DTSTART;VALUE=DATE", "20261006").unwrap();
        assert!(a.all_day);
        // All-day Oct 6 in +08:00 == Oct 5 16:00 UTC.
        assert_eq!(stamp_to_ts(&a, ZONE).unwrap(), (ts(2026, 10, 5, 16, 0), true));
    }

    #[test]
    fn tzid_ignored_like_oracle() {
        // Oracle: python reads TZID stamps as naive local wall time.
        let s = parse_stamp("DTSTART;TZID=America/New_York", "20261005T090000").unwrap();
        assert_eq!(stamp_to_ts(&s, ZONE).unwrap(), (ts(2026, 10, 5, 1, 0), false));
        let e = parse_stamp(
            "DTSTART;TZID=/freeassociation.sourceforge.net/America/New_York",
            "20261005T110000",
        )
        .unwrap();
        assert_eq!(stamp_to_ts(&e, ZONE).unwrap(), (ts(2026, 10, 5, 3, 0), false));
    }

    #[test]
    fn zone_chain_helpers() {
        assert_eq!(zone_from_tz_value("Asia/Shanghai"), Some(Tz::Asia__Shanghai));
        assert_eq!(zone_from_tz_value(""), None);
        assert_eq!(
            zone_from_localtime_link("/gnu/store/x-tzdata/share/zoneinfo/Asia/Shanghai"),
            Some(Tz::Asia__Shanghai)
        );
        assert_eq!(zone_from_localtime_link("not-a-link"), None);
        assert_eq!(zone_from_timezone_file("Asia/Shanghai\n"), Some(Tz::Asia__Shanghai));
    }

    #[test]
    fn normal_event_passthrough() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261005T090000Z\r\nDTEND:20261005T093000Z\r\nSUMMARY:S\r\nEND:VEVENT");
        assert_eq!(
            expand_normal(&c, ZONE),
            vec![(Some(ts(2026, 10, 5, 9, 0)), Some(ts(2026, 10, 5, 9, 30)))]
        );
    }

    #[test]
    fn missing_dtend_normalizes_like_libical() {
        // Date-time without DTEND: zero duration (end == start).
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261005T090000Z\r\nEND:VEVENT");
        assert!(c.dtend.is_none() && !c.dtend_present);
        assert_eq!(
            expand_normal(&c, ZONE),
            vec![(Some(ts(2026, 10, 5, 9, 0)), Some(ts(2026, 10, 5, 9, 0)))]
        );
        // All-day without DTEND: runs to the next day.
        let a = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART;VALUE=DATE:20261006\r\nEND:VEVENT");
        assert_eq!(
            expand_normal(&a, ZONE),
            vec![(Some(ts(2026, 10, 5, 16, 0)), Some(ts(2026, 10, 6, 16, 0)))]
        );
        // Present-but-garbage DTEND: start + 3600.
        let g = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261005T090000Z\r\nDTEND:garbage\r\nEND:VEVENT");
        assert!(g.dtend_present && g.dtend.is_none());
        assert_eq!(expand_normal(&g, ZONE)[0].1, Some(ts(2026, 10, 5, 10, 0)));
    }

    #[test]
    fn weekly_count_expands() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261001T080000Z\r\nDTEND:20261001T090000Z\r\nRRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=4\r\nEND:VEVENT");
        let spec = parse_rrule(c.rrule_text.as_deref().unwrap()).unwrap();
        let occ = expand_recurrent(&c, &spec, ZONE, 9999999999).unwrap();
        assert_eq!(occ.len(), 4);
        assert_eq!(occ[0].0, Some(ts(2026, 10, 1, 8, 0)));
        assert_eq!(occ[1].0, Some(ts(2026, 10, 8, 8, 0)));
        assert_eq!(occ[3].0, Some(ts(2026, 10, 22, 8, 0)));
    }

    #[test]
    fn secondly_yields_nothing_like_python() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261001T080000Z\r\nDTEND:20261001T080100Z\r\nRRULE:FREQ=SECONDLY;COUNT=5\r\nEND:VEVENT");
        let spec = parse_rrule(c.rrule_text.as_deref().unwrap()).unwrap();
        assert!(expand_recurrent(&c, &spec, ZONE, 9999999999).unwrap().is_empty());
    }

    #[test]
    fn unknown_freq_yields_single_occurrence() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261004T080000Z\r\nDTEND:20261004T090000Z\r\nRRULE:FREQ=FOO;COUNT=3\r\nEND:VEVENT");
        let spec = parse_rrule(c.rrule_text.as_deref().unwrap()).unwrap();
        assert_eq!(spec.freq, 7);
        let occ = expand_recurrent(&c, &spec, ZONE, 9999999999).unwrap();
        assert_eq!(occ.len(), 1);
        assert_eq!(occ[0].0, Some(ts(2026, 10, 4, 8, 0)));
    }

    #[test]
    fn garbage_rrule_aborts() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261001T080000Z\r\nRRULE:BLAH\r\nEND:VEVENT");
        assert!(c.rrule_text.is_some());
        assert!(parse_rrule(c.rrule_text.as_deref().unwrap()).is_none());
    }

    #[test]
    fn monthly_clamps_like_relativedelta() {
        // Jan 31 + 1 month: Feb 28; then non-sticky Mar 28 (2026 not leap).
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20260131T120000Z\r\nDTEND:20260131T130000Z\r\nRRULE:FREQ=MONTHLY;COUNT=3\r\nEND:VEVENT");
        let spec = parse_rrule(c.rrule_text.as_deref().unwrap()).unwrap();
        let occ = expand_recurrent(&c, &spec, ZONE, 9999999999).unwrap();
        assert_eq!(occ.len(), 3);
        assert_eq!(occ[1].0, Some(ts(2026, 2, 28, 12, 0)));
        assert_eq!(occ[2].0, Some(ts(2026, 3, 28, 12, 0)));
    }

    #[test]
    fn extra_rrule_props_ignored() {
        let c = comp("BEGIN:VEVENT\r\nUID:x\r\nDTSTART:20261001T080000Z\r\nDTEND:20261001T090000Z\r\nRRULE:FREQ=MINUTELY;BYSECOND=0;COUNT=3\r\nEND:VEVENT");
        let spec = parse_rrule(c.rrule_text.as_deref().unwrap()).unwrap();
        assert_eq!(expand_recurrent(&c, &spec, ZONE, 9999999999).unwrap().len(), 3);
    }
}
