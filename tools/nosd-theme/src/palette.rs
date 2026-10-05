#![forbid(unsafe_code)]

//! Dominant-color extraction: K-means clustering in Lab plus scoring modes.
//! Mirrors Scripts/python/src/theming/lib/palette.py.
//!
//! Parity notes:
//! - All sorts are stable, like Python's `list.sort`.
//! - Hue-family grouping preserves first-seen insertion order (Python dict).
//! - Short-input path (`len < k`): Python returns `set` order; we return
//!   first-seen order with the same (color, color, count) values. Only the
//!   order of that edge case can differ.

use std::collections::HashSet;

use crate::color::{Color, hue_distance, lab_distance, lab_to_rgb, rgb_to_lab};
use crate::hct::{Cam16, Hct};

pub type Rgb = (u8, u8, u8);

pub fn downsample_pixels(pixels: &[(u8, u8, u8)], factor: usize) -> Vec<(u8, u8, u8)> {
    if factor <= 1 {
        return pixels.to_vec();
    }
    let step = factor * factor;
    pixels.iter().step_by(step).copied().collect()
}

fn sort_by_score_desc<T>(v: &mut [(T, f64)]) {
    // Stable, total order; scores are finite in practice.
    v.sort_by(|a, b| b.1.total_cmp(&a.1));
}

pub fn kmeans_cluster(colors: &[Rgb], k: usize, iterations: usize) -> Vec<(Rgb, Rgb, usize)> {
    if colors.len() < k {
        let mut seen = Vec::new();
        for c in colors {
            if !seen.contains(c) {
                seen.push(*c);
            }
        }
        return seen
            .into_iter()
            .take(k)
            .map(|c| {
                let n = colors.iter().filter(|x| **x == c).count();
                (c, c, n)
            })
            .collect();
    }
    let labs: Vec<(f64, f64, f64)> = colors.iter().map(|c| rgb_to_lab(c.0, c.1, c.2)).collect();
    let mut order: Vec<usize> = (0..labs.len()).collect();
    order.sort_by(|a, b| labs[*a].0.total_cmp(&labs[*b].0));
    let step = order.len() / k;
    let mut centroids: Vec<(f64, f64, f64)> = (0..k).map(|i| labs[order[i * step]]).collect();
    let mut assignments = vec![0usize; labs.len()];
    for _ in 0..iterations {
        for (idx, color) in labs.iter().enumerate() {
            let mut best_d = f64::INFINITY;
            let mut best_i = 0;
            for (i, cent) in centroids.iter().enumerate() {
                let d = lab_distance(*color, *cent);
                if d < best_d {
                    best_d = d;
                    best_i = i;
                }
            }
            assignments[idx] = best_i;
        }
        let mut next = Vec::with_capacity(k);
        for i in 0..k {
            let mut sl = 0.0;
            let mut sa = 0.0;
            let mut sb = 0.0;
            let mut n = 0usize;
            for (j, lab) in labs.iter().enumerate() {
                if assignments[j] == i {
                    sl += lab.0;
                    sa += lab.1;
                    sb += lab.2;
                    n += 1;
                }
            }
            if n > 0 {
                next.push((sl / n as f64, sa / n as f64, sb / n as f64));
            } else {
                next.push(centroids[i]);
            }
        }
        centroids = next;
    }
    let mut counts = vec![0usize; k];
    let mut reps: Vec<(Rgb, f64)> = vec![(colors[0], f64::INFINITY); k];
    for (idx, lab) in labs.iter().enumerate() {
        let ci = assignments[idx];
        counts[ci] += 1;
        let d = lab_distance(*lab, centroids[ci]);
        if d < reps[ci].1 {
            reps[ci] = (colors[idx], d);
        }
    }
    let mut results = Vec::new();
    for i in 0..k {
        if counts[i] > 0 {
            results.push((lab_to_rgb(centroids[i].0, centroids[i].1, centroids[i].2), reps[i].0, counts[i]));
        }
    }
    // Stable sort by count descending.
    results.sort_by(|a, b| b.2.cmp(&a.2));
    results
}

fn score_chroma(pairs: &[(Rgb, usize)]) -> Vec<(Color, f64)> {
    let mut out = Vec::new();
    for (rgb, count) in pairs {
        let color = Color::from_tuple(*rgb);
        let hct = color.to_hct();
        let tone_penalty = if hct.tone < 20.0 {
            (20.0 - hct.tone) * 2.0
        } else if hct.tone > 80.0 {
            (hct.tone - 80.0) * 1.5
        } else if hct.tone < 40.0 {
            (40.0 - hct.tone) * 0.5
        } else if hct.tone > 60.0 {
            (hct.tone - 60.0) * 0.3
        } else {
            0.0
        };
        let hue_penalty = if hct.hue > 80.0 && hct.hue < 110.0 { 5.0 } else { 0.0 };
        let score = (hct.chroma - tone_penalty - hue_penalty) * (*count as f64).powf(0.3);
        out.push((color, score));
    }
    sort_by_score_desc(&mut out);
    out
}

fn hue_to_family(hue: f64) -> usize {
    if hue >= 330.0 || hue < 30.0 {
        0
    } else if hue < 60.0 {
        1
    } else if hue < 105.0 {
        2
    } else if hue < 190.0 {
        3
    } else if hue < 270.0 {
        4
    } else {
        5
    }
}

fn family_center(family: usize) -> f64 {
    [0.0, 45.0, 82.5, 147.5, 230.0, 300.0][family]
}

fn circular_hue_diff(h1: f64, h2: f64) -> f64 {
    let d = (h1 - h2).abs();
    d.min(360.0 - d)
}

type FamEntry = (Color, f64, f64, usize); // color, hue, chroma, count

fn group_families(pairs: &[(Rgb, usize)]) -> Vec<(usize, Vec<FamEntry>)> {
    let mut fams: Vec<(usize, Vec<FamEntry>)> = Vec::new();
    for (rgb, count) in pairs {
        let color = Color::from_tuple(*rgb);
        let hct = color.to_hct();
        if hct.chroma >= 10.0 {
            let fam = hue_to_family(hct.hue);
            match fams.iter_mut().find(|(f, _)| *f == fam) {
                Some((_, v)) => v.push((color, hct.hue, hct.chroma, *count)),
                None => fams.push((fam, vec![(color, hct.hue, hct.chroma, *count)])),
            }
        }
    }
    fams
}

fn score_count(pairs: &[(Rgb, usize)]) -> Vec<(Color, f64)> {
    let fams = group_families(pairs);
    if fams.is_empty() {
        let mut out: Vec<(Color, f64)> =
            pairs.iter().map(|(rgb, c)| (Color::from_tuple(*rgb), *c as f64)).collect();
        sort_by_score_desc(&mut out);
        return out;
    }
    let mut totals: Vec<(usize, usize)> =
        fams.iter().map(|(f, v)| (*f, v.iter().map(|e| e.3).sum())).collect();
    totals.sort_by(|a, b| b.1.cmp(&a.1));
    let mut out = Vec::new();
    for (fam, _) in &totals {
        let mut members = fams.iter().find(|(f, _)| f == fam).unwrap().1.clone();
        members.sort_by(|a, b| b.3.cmp(&a.3).then(b.2.total_cmp(&a.2)));
        for (color, _, chroma, count) in members {
            let rank = totals.iter().position(|(f, _)| f == fam).unwrap();
            let score = (totals.len() - rank) as f64 * 1_000_000.0 + count as f64 * 1000.0 + chroma;
            out.push((color, score));
        }
    }
    sort_by_score_desc(&mut out);
    out
}

fn score_dysfunctional(pairs: &[(Rgb, usize)]) -> Vec<(Color, f64)> {
    let fams = group_families(pairs);
    if fams.is_empty() {
        let mut out: Vec<(Color, f64)> =
            pairs.iter().map(|(rgb, c)| (Color::from_tuple(*rgb), *c as f64)).collect();
        sort_by_score_desc(&mut out);
        return out;
    }
    let mut totals: Vec<(usize, usize)> =
        fams.iter().map(|(f, v)| (*f, v.iter().map(|e| e.3).sum())).collect();
    totals.sort_by(|a, b| b.1.cmp(&a.1));
    let dominant = totals[0].0;
    let dominant_center = family_center(dominant);
    let total_colorful: usize = totals.iter().map(|(_, c)| c).sum();
    let min_count = total_colorful as f64 * 0.02;
    let mut distant: Vec<(usize, usize, f64, f64)> = Vec::new();
    let mut close = vec![dominant];
    for (fam, count) in totals.iter().skip(1) {
        let diff = circular_hue_diff(dominant_center, family_center(*fam));
        if diff >= 45.0 && *count as f64 >= min_count {
            let max_chroma = fams
                .iter()
                .find(|(f, _)| f == fam)
                .unwrap()
                .1
                .iter()
                .map(|e| e.2)
                .fold(0.0f64, f64::max);
            distant.push((*fam, *count, diff, max_chroma));
        } else {
            close.push(*fam);
        }
    }
    let mut out = Vec::new();
    distant.sort_by(|a, b| (b.2 * b.3).total_cmp(&(a.2 * a.3)));
    for (fam, _, _, _) in &distant {
        let mut members = fams.iter().find(|(f, _)| f == fam).unwrap().1.clone();
        members.sort_by(|a, b| b.2.total_cmp(&a.2).then(b.3.cmp(&a.3)));
        for (color, _, chroma, count) in members {
            let rank = distant.iter().position(|(f, _, _, _)| f == fam).unwrap();
            let score = (distant.len() - rank) as f64 * 1_000_000.0 + chroma * 1000.0 + count as f64;
            out.push((color, score));
        }
    }
    for fam in close {
        let mut members = fams.iter().find(|(f, _)| f == &fam).unwrap().1.clone();
        members.sort_by(|a, b| b.3.cmp(&a.3).then(b.2.total_cmp(&a.2)));
        for (color, _, chroma, count) in members {
            out.push((color, count as f64 * 1000.0 + chroma));
        }
    }
    sort_by_score_desc(&mut out);
    out
}

fn score_muted(pairs: &[(Rgb, usize)]) -> Vec<(Color, f64)> {
    let mut out: Vec<(Color, f64)> =
        pairs.iter().map(|(rgb, c)| (Color::from_tuple(*rgb), *c as f64)).collect();
    sort_by_score_desc(&mut out);
    out
}

fn score_population(pairs: &[(Rgb, usize)], total_pixels: usize) -> Vec<(Color, f64)> {
    let mut hue_pop = [0usize; 360];
    let mut pop_sum = 0usize;
    let mut with_hct: Vec<(Color, Hct, usize)> = Vec::new();
    for (rgb, count) in pairs {
        let color = Color::from_tuple(*rgb);
        let hct = color.to_hct();
        let bucket = hct.hue as usize % 360;
        hue_pop[bucket] += count;
        pop_sum += count;
        with_hct.push((color, hct, *count));
    }
    let _ = total_pixels;
    if with_hct.is_empty() || pop_sum == 0 {
        let mut out: Vec<(Color, f64)> =
            pairs.iter().map(|(rgb, c)| (Color::from_tuple(*rgb), *c as f64)).collect();
        sort_by_score_desc(&mut out);
        return out;
    }
    let mut excited = [0.0f64; 360];
    for hue in 0..360 {
        let proportion = hue_pop[hue] as f64 / pop_sum as f64;
        for offset in -14..=15 {
            let n = (hue as i64 + offset).rem_euclid(360) as usize;
            excited[n] += proportion;
        }
    }
    let mut scored: Vec<(Color, Hct, f64)> = Vec::new();
    for (color, hct, _) in &with_hct {
        let bucket = hct.hue as usize % 360;
        let proportion = excited[bucket];
        if hct.chroma < 5.0 || proportion <= 0.01 {
            continue;
        }
        let proportion_score = proportion * 100.0 * 0.7;
        let w = if hct.chroma < 48.0 { 0.1 } else { 0.3 };
        scored.push((*color, *hct, proportion_score + (hct.chroma - 48.0) * w));
    }
    if scored.is_empty() {
        let mut out: Vec<(Color, f64)> =
            pairs.iter().map(|(rgb, c)| (Color::from_tuple(*rgb), *c as f64)).collect();
        sort_by_score_desc(&mut out);
        return out;
    }
    scored.sort_by(|a, b| b.2.total_cmp(&a.2));
    let mut chosen: Vec<(Color, f64)> = Vec::new();
    for min_diff in (15..=90).rev() {
        chosen.clear();
        for (color, hct, score) in &scored {
            let mut far = true;
            for (picked, _) in &chosen {
                if hue_distance(hct.hue, picked.to_hct().hue) < min_diff as f64 {
                    far = false;
                    break;
                }
            }
            if far {
                chosen.push((*color, *score));
            }
            if chosen.len() >= 4 {
                break;
            }
        }
        if chosen.len() >= 4 {
            break;
        }
    }
    if chosen.is_empty() {
        chosen = scored.iter().take(4).map(|(c, _, s)| (*c, *s)).collect();
    }
    chosen
}

pub fn extract_palette(pixels: &[Rgb], k: usize, scoring: &str) -> Vec<Color> {
    let sampled = downsample_pixels(pixels, 4);
    let total_sampled = sampled.len();
    let uniq: HashSet<Rgb> = sampled.iter().copied().collect();
    let (cluster_count, filtered) = match scoring {
        "population" => (128.min((k * 10).max(uniq.len() / 10)), sampled.clone()),
        "count" | "dysfunctional" => (48, sampled.clone()),
        "muted" => (24, sampled.clone()),
        _ => {
            let mut colorful: Vec<Rgb> = sampled
                .iter()
                .copied()
                .filter(|p| Cam16::from_rgb(p.0, p.1, p.2).chroma >= 5.0)
                .collect();
            if colorful.len() < 20 * 2 {
                colorful = sampled.clone();
            }
            (20, colorful)
        }
    };
    let clusters = kmeans_cluster(&filtered, cluster_count, 10);
    let scored = match scoring {
        "chroma" => score_chroma(&clusters.iter().map(|c| (c.0, c.2)).collect::<Vec<_>>()),
        "count" => score_count(&clusters.iter().map(|c| (c.1, c.2)).collect::<Vec<_>>()),
        "dysfunctional" => {
            score_dysfunctional(&clusters.iter().map(|c| (c.1, c.2)).collect::<Vec<_>>())
        }
        "muted" => score_muted(&clusters.iter().map(|c| (c.1, c.2)).collect::<Vec<_>>()),
        _ => score_population(&clusters.iter().map(|c| (c.1, c.2)).collect::<Vec<_>>(), total_sampled),
    };
    let mut colors: Vec<Color> = scored.into_iter().map(|(c, _)| c).collect();
    while colors.len() < k {
        if colors.is_empty() {
            colors.push(Color::from_hex("#6750A4").unwrap());
            continue;
        }
        let hct = colors[0].to_hct();
        let offset = colors.len() as f64 * 60.0;
        colors.push(Color::from_hct(Hct::new((hct.hue + offset) % 360.0, hct.chroma, hct.tone)));
    }
    colors.truncate(k);
    colors
}

pub fn find_error_color(palette: &[Color]) -> Color {
    for color in palette {
        let (h, s, l) = color.to_hsl();
        if (h <= 30.0 || h >= 330.0) && s > 0.4 && l > 0.3 && l < 0.7 {
            return *color;
        }
    }
    Color::from_hex("#FD4663").unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_pixels() -> Vec<Rgb> {
        let mut v = Vec::new();
        for _ in 0..400 {
            v.push((200, 60, 30));
        }
        for _ in 0..300 {
            v.push((30, 120, 200));
        }
        for _ in 0..200 {
            v.push((40, 180, 80));
        }
        for _ in 0..100 {
            v.push((240, 240, 240));
        }
        v
    }

    #[test]
    fn downsample_factor() {
        let px: Vec<Rgb> = (0..64u8).map(|i| (i, i, i)).collect();
        assert_eq!(downsample_pixels(&px, 1), px);
        assert_eq!(downsample_pixels(&px, 2).len(), 16);
    }

    #[test]
    fn kmeans_groups_by_count() {
        // Oracle: python returns 2 non-empty clusters here (one empties out).
        let clusters = kmeans_cluster(&sample_pixels(), 3, 10);
        assert_eq!(clusters.len(), 2);
        assert_eq!(clusters[0].2, 600);
        assert_eq!(clusters[1].2, 400);
        assert_eq!(clusters[0].1, (240, 240, 240));
        assert_eq!(clusters[0].0, (99, 159, 168));
        assert_eq!(clusters[1], ((200, 60, 30), (200, 60, 30), 400));
    }

    #[test]
    fn extract_returns_k_colors() {
        for mode in ["population", "chroma", "count", "dysfunctional", "muted"] {
            let colors = extract_palette(&sample_pixels(), 5, mode);
            assert_eq!(colors.len(), 5, "{mode}");
        }
    }

    #[test]
    fn extract_modes_match_python() {
        // Oracle: lib.palette.extract_palette on sample_pixels(), k=5.
        let px = sample_pixels();
        let hexes = |mode: &str| {
            extract_palette(&px, 5, mode).iter().map(|c| c.to_hex()).collect::<Vec<_>>()
        };
        assert_eq!(hexes("population"), ["#c83c1e", "#1e78c8", "#28b450", "#007a88", "#0063f7"]);
        assert_eq!(hexes("chroma"), ["#c83c1e", "#28b450", "#1e78c8", "#007a88", "#0063f7"]);
        assert_eq!(hexes("count"), ["#c83c1e", "#1e78c8", "#28b450", "#007a88", "#0063f7"]);
        assert_eq!(hexes("dysfunctional"), ["#1e78c8", "#28b450", "#c83c1e", "#9f6b00", "#4e8326"]);
        assert_eq!(hexes("muted"), ["#c83c1e", "#1e78c8", "#28b450", "#f0f0f0", "#0063f7"]);
    }

    #[test]
    fn error_color_prefers_red() {
        let pal = vec![Color::from_tuple((30, 120, 200)), Color::from_tuple((220, 40, 60))];
        assert_eq!(find_error_color(&pal).to_hex(), "#dc283c");
        assert_eq!(find_error_color(&[]).to_hex(), "#fd4663");
    }
}
