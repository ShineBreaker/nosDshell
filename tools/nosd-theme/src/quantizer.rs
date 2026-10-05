#![forbid(unsafe_code)]

//! Wu + WSMeans quantization (QuantizerCelebi pipeline) and Score ranking.
//! Mirrors Scripts/python/src/theming/lib/quantizer.py.
//!
//! Parity notes:
//! - Wu histogram/moment sums are exact integers (`i64`/`u128`); float
//!   divisions happen at exactly the same points as Python's `/`.
//! - WSMeans inter-cluster matrix is filled, row-sorted, and read
//!   positionally exactly like the Python version (including the diagonal
//!   staying `[0.0, j]` and later iterations mutating already-sorted rows).
//! - The LCG matches Java's `java.util.Random` via the Python `_Random`.

use crate::color::{lab_to_rgb, rgb_to_lab};
use crate::hct::{Cam16, Hct};

const INDEX_BITS: usize = 5;
const SIDE: usize = 33;
const TOTAL: usize = 35937;

const DIR_RED: usize = 0;
const DIR_GREEN: usize = 1;
const DIR_BLUE: usize = 2;

fn get_index(r: usize, g: usize, b: usize) -> usize {
    (r << (INDEX_BITS * 2)) + (r << (INDEX_BITS + 1)) + r + (g << INDEX_BITS) + g + b
}

pub fn argb_from_rgb(r: u8, g: u8, b: u8) -> u32 {
    (255u32 << 24) | ((r as u32) << 16) | ((g as u32) << 8) | b as u32
}

pub fn rgb_from_argb(argb: u32) -> (u8, u8, u8) {
    (((argb >> 16) & 0xFF) as u8, ((argb >> 8) & 0xFF) as u8, (argb & 0xFF) as u8)
}

#[derive(Clone, Copy)]
struct Cube {
    r0: usize, r1: usize,
    g0: usize, g1: usize,
    b0: usize, b1: usize,
    vol: usize,
}

impl Cube {
    fn new() -> Cube {
        Cube { r0: 0, r1: 0, g0: 0, g1: 0, b0: 0, b1: 0, vol: 0 }
    }
}

struct Moments {
    weights: Vec<i64>,
    mr: Vec<i64>,
    mg: Vec<i64>,
    mb: Vec<i64>,
    moments: Vec<f64>,
}

fn volume_i64(c: &Cube, m: &[i64]) -> i64 {
        m[get_index(c.r1, c.g1, c.b1)]
            - m[get_index(c.r1, c.g1, c.b0)]
            - m[get_index(c.r1, c.g0, c.b1)]
            + m[get_index(c.r1, c.g0, c.b0)]
            - m[get_index(c.r0, c.g1, c.b1)]
            + m[get_index(c.r0, c.g1, c.b0)]
            + m[get_index(c.r0, c.g0, c.b1)]
            - m[get_index(c.r0, c.g0, c.b0)]
    }

    fn bottom(c: &Cube, dir: usize, m: &[i64]) -> i64 {
        match dir {
            DIR_RED => {
                -m[get_index(c.r0, c.g1, c.b1)]
                    + m[get_index(c.r0, c.g1, c.b0)]
                    + m[get_index(c.r0, c.g0, c.b1)]
                    - m[get_index(c.r0, c.g0, c.b0)]
            }
            DIR_GREEN => {
                -m[get_index(c.r1, c.g0, c.b1)]
                    + m[get_index(c.r1, c.g0, c.b0)]
                    + m[get_index(c.r0, c.g0, c.b1)]
                    - m[get_index(c.r0, c.g0, c.b0)]
            }
            _ => {
                -m[get_index(c.r1, c.g1, c.b0)]
                    + m[get_index(c.r1, c.g0, c.b0)]
                    + m[get_index(c.r0, c.g1, c.b0)]
                    - m[get_index(c.r0, c.g0, c.b0)]
            }
        }
    }

    fn top(c: &Cube, dir: usize, pos: usize, m: &[i64]) -> i64 {
        match dir {
            DIR_RED => {
                m[get_index(pos, c.g1, c.b1)]
                    - m[get_index(pos, c.g1, c.b0)]
                    - m[get_index(pos, c.g0, c.b1)]
                    + m[get_index(pos, c.g0, c.b0)]
            }
            DIR_GREEN => {
                m[get_index(c.r1, pos, c.b1)]
                    - m[get_index(c.r1, pos, c.b0)]
                    - m[get_index(c.r0, pos, c.b1)]
                    + m[get_index(c.r0, pos, c.b0)]
            }
            _ => {
                m[get_index(c.r1, c.g1, pos)]
                    - m[get_index(c.r1, c.g0, pos)]
                    - m[get_index(c.r0, c.g1, pos)]
                    + m[get_index(c.r0, c.g0, pos)]
            }
        }
    }

fn box_variance(mo: &Moments, c: &Cube) -> f64 {
    let dr = volume_i64(c, &mo.mr);
    let dg = volume_i64(c, &mo.mg);
    let db = volume_i64(c, &mo.mb);
    let xx = mo.moments[get_index(c.r1, c.g1, c.b1)]
        - mo.moments[get_index(c.r1, c.g1, c.b0)]
        - mo.moments[get_index(c.r1, c.g0, c.b1)]
        + mo.moments[get_index(c.r1, c.g0, c.b0)]
        - mo.moments[get_index(c.r0, c.g1, c.b1)]
        + mo.moments[get_index(c.r0, c.g1, c.b0)]
        + mo.moments[get_index(c.r0, c.g0, c.b1)]
        - mo.moments[get_index(c.r0, c.g0, c.b0)];
    // Exact integer hypotenuse first, like Python's unbounded ints.
    let hyp = dr as u128 * dr as u128 + dg as u128 * dg as u128 + db as u128 * db as u128;
    let vol = volume_i64(c, &mo.weights);
        if vol == 0 {
            return 0.0;
        }
        xx - (hyp as f64) / (vol as f64)
    }

fn maximize(
    mo: &Moments, c: &Cube, dir: usize, first: usize, last: usize,
    whole_r: i64, whole_g: i64, whole_b: i64, whole_w: i64,
) -> (i64, f64) {
    let bottom_r = bottom(c, dir, &mo.mr);
    let bottom_g = bottom(c, dir, &mo.mg);
    let bottom_b = bottom(c, dir, &mo.mb);
    let bottom_w = bottom(c, dir, &mo.weights);
    let mut max_val = 0.0;
    let mut cut = -1i64;
    for i in first..last {
        let half_r = bottom_r + top(c, dir, i, &mo.mr);
        let half_g = bottom_g + top(c, dir, i, &mo.mg);
        let half_b = bottom_b + top(c, dir, i, &mo.mb);
        let half_w = bottom_w + top(c, dir, i, &mo.weights);
            if half_w == 0 {
                continue;
            }
            let num = half_r as u128 * half_r as u128
                + half_g as u128 * half_g as u128
                + half_b as u128 * half_b as u128;
            let mut temp = (num as f64) / (half_w as f64);
            let hr = whole_r - half_r;
            let hg = whole_g - half_g;
            let hb = whole_b - half_b;
            let hw = whole_w - half_w;
            if hw == 0 {
                continue;
            }
            let num2 =
                hr as u128 * hr as u128 + hg as u128 * hg as u128 + hb as u128 * hb as u128;
            temp += (num2 as f64) / (hw as f64);
            if temp > max_val {
                max_val = temp;
                cut = i as i64;
            }
        }
        (cut, max_val)
    }

fn cut(mo: &Moments, one: &mut Cube, two: &mut Cube) -> bool {
    let whole_r = volume_i64(one, &mo.mr);
    let whole_g = volume_i64(one, &mo.mg);
    let whole_b = volume_i64(one, &mo.mb);
    let whole_w = volume_i64(one, &mo.weights);
    let (rcut, rv) = maximize(mo, one, DIR_RED, one.r0 + 1, one.r1, whole_r, whole_g, whole_b, whole_w);
    let (gcut, gv) = maximize(mo, one, DIR_GREEN, one.g0 + 1, one.g1, whole_r, whole_g, whole_b, whole_w);
    let (bcut, bv) = maximize(mo, one, DIR_BLUE, one.b0 + 1, one.b1, whole_r, whole_g, whole_b, whole_w);
        let (direction, location) = if rv >= gv && rv >= bv {
            if rcut < 0 {
                return false;
            }
            (DIR_RED, rcut as usize)
        } else if gv >= rv && gv >= bv {
            (DIR_GREEN, gcut as usize)
        } else {
            (DIR_BLUE, bcut as usize)
        };
        two.r1 = one.r1;
        two.g1 = one.g1;
        two.b1 = one.b1;
        match direction {
            DIR_RED => {
                one.r1 = location;
                two.r0 = one.r1;
                two.g0 = one.g0;
                two.b0 = one.b0;
            }
            DIR_GREEN => {
                one.g1 = location;
                two.r0 = one.r0;
                two.g0 = one.g1;
                two.b0 = one.b0;
            }
            _ => {
                one.b1 = location;
                two.r0 = one.r0;
                two.g0 = one.g0;
                two.b0 = one.b1;
            }
        }
        one.vol = (one.r1 - one.r0) * (one.g1 - one.g0) * (one.b1 - one.b0);
        two.vol = (two.r1 - two.r0) * (two.g1 - two.g0) * (two.b1 - two.b0);
        true
}

pub fn quantize_wu(pixels: &[(u8, u8, u8)], max_colors: usize) -> Vec<u32> {
    let mut mo = Moments {
        weights: vec![0; TOTAL],
        mr: vec![0; TOTAL],
        mg: vec![0; TOTAL],
        mb: vec![0; TOTAL],
        moments: vec![0.0; TOTAL],
    };
    let mut cubes = vec![Cube::new(); max_colors.max(1)];
    let mut counts: Vec<(u32, usize)> = Vec::new();
    for (r, g, b) in pixels {
        let argb = argb_from_rgb(*r, *g, *b);
        match counts.iter_mut().find(|(c, _)| *c == argb) {
            Some((_, n)) => *n += 1,
            None => counts.push((argb, 1)),
        }
    }
    for (pixel, count) in &counts {
        let red = ((pixel >> 16) & 0xFF) as i64;
        let green = ((pixel >> 8) & 0xFF) as i64;
        let blue = (pixel & 0xFF) as i64;
        let ir = ((red >> 3) + 1) as usize;
        let ig = ((green >> 3) + 1) as usize;
        let ib = ((blue >> 3) + 1) as usize;
        let index = get_index(ir, ig, ib);
        let n = *count as i64;
        mo.weights[index] += n;
        mo.mr[index] += n * red;
        mo.mg[index] += n * green;
        mo.mb[index] += n * blue;
        mo.moments[index] += n as f64 * (red * red + green * green + blue * blue) as f64;
    }
    for r in 1..SIDE {
        let mut area = [0i64; SIDE];
        let mut area_r = [0i64; SIDE];
        let mut area_g = [0i64; SIDE];
        let mut area_b = [0i64; SIDE];
        let mut area2 = [0.0f64; SIDE];
        for g in 1..SIDE {
            let (mut line, mut line_r, mut line_g, mut line_b, mut line2) = (0i64, 0i64, 0i64, 0i64, 0.0);
            for b in 1..SIDE {
                let index = get_index(r, g, b);
                line += mo.weights[index];
                line_r += mo.mr[index];
                line_g += mo.mg[index];
                line_b += mo.mb[index];
                line2 += mo.moments[index];
                area[b] += line;
                area_r[b] += line_r;
                area_g[b] += line_g;
                area_b[b] += line_b;
                area2[b] += line2;
                let prev = get_index(r - 1, g, b);
                mo.weights[index] = mo.weights[prev] + area[b];
                mo.mr[index] = mo.mr[prev] + area_r[b];
                mo.mg[index] = mo.mg[prev] + area_g[b];
                mo.mb[index] = mo.mb[prev] + area_b[b];
                mo.moments[index] = mo.moments[prev] + area2[b];
            }
        }
    }
    // Create boxes.
    let mut variance = vec![0.0f64; max_colors.max(1)];
    cubes[0].r1 = SIDE - 1;
    cubes[0].g1 = SIDE - 1;
    cubes[0].b1 = SIDE - 1;
    let mut generated = max_colors;
    let mut next_box = 0usize;
    let mut i = 1usize;
    while i < max_colors {
        // Split borrow: operate on indices directly.
        let ok = {
            let (head, tail) = cubes.split_at_mut(i);
            cut(&mo, &mut head[next_box], &mut tail[0])
        };
        if ok {
            variance[next_box] = if cubes[next_box].vol > 1 { box_variance(&mo, &cubes[next_box]) } else { 0.0 };
            variance[i] = if cubes[i].vol > 1 { box_variance(&mo, &cubes[i]) } else { 0.0 };
        } else {
            variance[next_box] = 0.0;
            i -= 1;
        }
        next_box = 0;
        let mut temp = variance[0];
        for j in 1..=i {
            if variance[j] > temp {
                temp = variance[j];
                next_box = j;
            }
        }
        if temp <= 0.0 {
            generated = i + 1;
            break;
        }
        i += 1;
    }
    let mut colors = Vec::new();
    for k in 0..generated.min(cubes.len()) {
        let cube = cubes[k];
        let weight = volume_i64(&cube, &mo.weights);
        if weight > 0 {
            let r = (volume_i64(&cube, &mo.mr) as f64 / weight as f64) as u8;
            let g = (volume_i64(&cube, &mo.mg) as f64 / weight as f64) as u8;
            let b = (volume_i64(&cube, &mo.mb) as f64 / weight as f64) as u8;
            colors.push(argb_from_rgb(r, g, b));
        }
    }
    colors
}

const LCG_MASK: u64 = (1 << 48) - 1;

struct JavaRandom {
    seed: u64,
}

impl JavaRandom {
    fn new(seed: u64) -> JavaRandom {
        JavaRandom { seed: (seed ^ 0x5DEECE66D) & LCG_MASK }
    }
    fn next(&mut self, bits: u32) -> i64 {
        self.seed = (self.seed.wrapping_mul(0x5DEECE66D).wrapping_add(0xB)) & LCG_MASK;
        let mut val = (self.seed >> (48 - bits)) as i64;
        if val >= (1 << 31) {
            val -= 1 << 32;
        }
        val
    }
    fn next_range(&mut self, range: i64) -> i64 {
        // Power of two: (range & -range) == range, wrapping like Java longs.
        if (range & range.wrapping_neg()) == range {
            return ((range * self.next(31)) >> 31) as i64;
        }
        loop {
            let bits = self.next(31);
            let val = bits.rem_euclid(range);
            if bits - val + (range - 1) >= 0 {
                return val;
            }
        }
    }
}

fn lab_dist2(a: (f64, f64, f64), b: (f64, f64, f64)) -> f64 {
    let (dl, da, db) = (a.0 - b.0, a.1 - b.1, a.2 - b.2);
    dl * dl + da * da + db * db
}

pub fn quantize_wsmeans(pixels: &[(u8, u8, u8)], max_colors: usize, starting: &[u32]) -> Vec<(u32, usize)> {
    let mut counts: Vec<(u32, usize)> = Vec::new();
    let mut points: Vec<(f64, f64, f64)> = Vec::new();
    for (r, g, b) in pixels {
        let argb = argb_from_rgb(*r, *g, *b);
        match counts.iter_mut().find(|(c, _)| *c == argb) {
            Some((_, n)) => *n += 1,
            None => {
                counts.push((argb, 1));
                let lab = rgb_to_lab(*r, *g, *b);
                points.push(lab);
            }
        }
    }
    let cluster_count = max_colors.min(points.len());
    if cluster_count == 0 {
        return Vec::new();
    }
    let mut clusters: Vec<(f64, f64, f64)> = starting
        .iter()
        .take(cluster_count)
        .map(|a| {
            let (r, g, b) = rgb_from_argb(*a);
            rgb_to_lab(r, g, b)
        })
        .collect();
    let additional = cluster_count as i64 - clusters.len() as i64;
    if additional > 0 {
        let mut rng = JavaRandom::new(0x42688);
        let mut indices: Vec<i64> = Vec::new();
        for _ in 0..additional {
            let mut index = rng.next_range(points.len() as i64);
            while indices.contains(&index) {
                index = rng.next_range(points.len() as i64);
            }
            indices.push(index);
        }
        for index in indices {
            clusters.push(points[index as usize]);
        }
    }
    let mut cluster_of = vec![0usize; points.len()];
    for (i, slot) in cluster_of.iter_mut().enumerate() {
        *slot = i % cluster_count;
    }
    let mut matrix: Vec<Vec<(f64, usize)>> = (0..cluster_count).map(|_| (0..cluster_count).map(|j| (0.0, j)).collect()).collect();
    let mut sums = vec![0usize; cluster_count];
    for _iteration in 0..10 {
        let mut moved = 0;
        for i in 0..cluster_count {
            for j in (i + 1)..cluster_count {
                let d = lab_dist2(clusters[i], clusters[j]);
                matrix[j][i] = (d, i);
                matrix[i][j] = (d, j);
            }
            matrix[i].sort_by(|a, b| a.0.total_cmp(&b.0));
        }
        for (pi, point) in points.iter().enumerate() {
            let prev = cluster_of[pi];
            let prev_dist = lab_dist2(*point, clusters[prev]);
            let mut new_idx = -1i64;
            for j in 0..cluster_count {
                if matrix[prev][j].0 >= 4.0 * prev_dist {
                    continue;
                }
                if lab_dist2(*point, clusters[j]) < prev_dist {
                    new_idx = j as i64;
                }
            }
            if new_idx != -1 {
                moved += 1;
                cluster_of[pi] = new_idx as usize;
            }
        }
        if moved == 0 && _iteration > 0 {
            break;
        }
        let mut cl = vec![0.0; cluster_count];
        let mut ca = vec![0.0; cluster_count];
        let mut cb = vec![0.0; cluster_count];
        for k in 0..cluster_count {
            sums[k] = 0;
        }
        for (pi, point) in points.iter().enumerate() {
            let cidx = cluster_of[pi];
            let count = counts[pi].1;
            sums[cidx] += count;
            cl[cidx] += point.0 * count as f64;
            ca[cidx] += point.1 * count as f64;
            cb[cidx] += point.2 * count as f64;
        }
        for k in 0..cluster_count {
            if sums[k] == 0 {
                clusters[k] = (0.0, 0.0, 0.0);
            } else {
                clusters[k] = (cl[k] / sums[k] as f64, ca[k] / sums[k] as f64, cb[k] / sums[k] as f64);
            }
        }
    }
    let mut argbs: Vec<u32> = Vec::new();
    let mut pops: Vec<usize> = Vec::new();
    for k in 0..cluster_count {
        if sums[k] == 0 {
            continue;
        }
        let (r, g, b) = lab_to_rgb(clusters[k].0, clusters[k].1, clusters[k].2);
        let argb = argb_from_rgb(r, g, b);
        if argbs.contains(&argb) {
            continue;
        }
        argbs.push(argb);
        pops.push(sums[k]);
    }
    argbs.into_iter().zip(pops).collect()
}

pub const FALLBACK_ARGB: u32 = 0xFF4285F4;

fn sanitize_degrees_int(hue: i64) -> usize {
    hue.rem_euclid(360) as usize
}

pub fn score_colors(map: &[(u32, usize)], desired: usize, fallback: u32, filter: bool) -> Vec<u32> {
    let mut with_hct: Vec<(u32, Hct)> = Vec::new();
    let mut hue_pop = [0usize; 360];
    let mut pop_sum = 0usize;
    for (argb, pop) in map {
        let (r, g, b) = rgb_from_argb(*argb);
        let hct = Hct::from_rgb(r, g, b);
        with_hct.push((*argb, hct));
        hue_pop[sanitize_degrees_int(hct.hue as i64)] += pop;
        pop_sum += pop;
    }
    if with_hct.is_empty() || pop_sum == 0 {
        return vec![fallback];
    }
    let mut excited = [0.0f64; 360];
    for hue in 0..360 {
        let proportion = hue_pop[hue] as f64 / pop_sum as f64;
        for offset in -14..=15i64 {
            excited[sanitize_degrees_int(hue as i64 + offset)] += proportion;
        }
    }
    let mut scored: Vec<(u32, Hct, f64)> = Vec::new();
    for (argb, hct) in &with_hct {
        let hue = sanitize_degrees_int(crate::color::py_round(hct.hue) as i64);
        let proportion = excited[hue];
        if filter {
            if hct.chroma < 5.0 || proportion <= 0.01 {
                continue;
            }
        }
        let proportion_score = proportion * 100.0 * 0.7;
        let w = if hct.chroma < 48.0 { 0.1 } else { 0.3 };
        scored.push((*argb, *hct, proportion_score + (hct.chroma - 48.0) * w));
    }
    if scored.is_empty() {
        return vec![fallback];
    }
    scored.sort_by(|a, b| b.2.total_cmp(&a.2));
    let mut chosen: Vec<(u32, Hct)> = Vec::new();
    for diff in (15..=90).rev() {
        chosen.clear();
        for (argb, hct, _) in &scored {
            let mut dup = false;
            for (_, picked) in &chosen {
                let d = (hct.hue - picked.hue).abs().min(360.0 - (hct.hue - picked.hue).abs());
                if d < diff as f64 {
                    dup = true;
                    break;
                }
            }
            if !dup {
                chosen.push((*argb, *hct));
            }
            if chosen.len() >= desired {
                break;
            }
        }
        if chosen.len() >= desired {
            break;
        }
    }
    if chosen.is_empty() {
        return vec![fallback];
    }
    chosen.into_iter().map(|(a, _)| a).collect()
}

pub fn extract_source_color(pixels: &[(u8, u8, u8)], fallback: u32) -> u32 {
    if pixels.is_empty() {
        return fallback;
    }
    let wu = quantize_wu(pixels, 128);
    let ws = quantize_wsmeans(pixels, 128, &wu);
    let mut filtered: Vec<(u32, usize)> = Vec::new();
    for (argb, count) in &ws {
        let (r, g, b) = rgb_from_argb(*argb);
        if Cam16::from_rgb(r, g, b).chroma >= 5.0 {
            filtered.push((*argb, *count));
        }
    }
    if filtered.is_empty() {
        filtered = ws;
    }
    let ranked = score_colors(&filtered, 4, fallback, true);
    ranked.first().copied().unwrap_or(fallback)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Vec<(u8, u8, u8)> {
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
    fn wu_matches_python() {
        // Oracle: quantize_wu(px, 128) box order.
        assert_eq!(
            quantize_wu(&sample(), 128),
            [0xFFC83C1E, 0xFF1E78C8, 0xFFF0F0F0, 0xFF28B450]
        );
    }

    #[test]
    fn celebrities_pipeline_matches_python() {
        // Oracle: quantize_wsmeans + score_colors on sample().
        let wu = quantize_wu(&sample(), 128);
        assert_eq!(
            quantize_wsmeans(&sample(), 128, &wu),
            [(0xFFC83C1E, 400), (0xFF1E78C8, 300), (0xFFF0F0F0, 100), (0xFF28B450, 200)]
        );
        let ws = quantize_wsmeans(&sample(), 128, &wu);
        assert_eq!(score_colors(&ws, 4, FALLBACK_ARGB, true), [0xFFC83C1E, 0xFF1E78C8, 0xFF28B450]);
    }

    #[test]
    fn source_color_matches_python() {
        assert_eq!(extract_source_color(&sample(), FALLBACK_ARGB), 0xFFC83C1E);
    }

    #[test]
    fn empty_falls_back() {
        assert_eq!(extract_source_color(&[], FALLBACK_ARGB), FALLBACK_ARGB);
    }
}
