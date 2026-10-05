#![forbid(unsafe_code)]

//! HCT (Hue, Chroma, Tone) color space: CAM16, Hct solver, tonal palettes.
//! Mirrors Scripts/python/src/theming/lib/hct.py (itself a Material Color
//! Utilities port).
//!
//! Parity notes: banker's rounding via `py_round`, CPython float `%` via
//! `py_mod`, `int()` truncation via `as` casts, stable sort like Python's.

use std::collections::HashMap;

use crate::color::{py_mod, py_round};

pub type Rgb = (u8, u8, u8);

const SRGB_TO_XYZ: [[f64; 3]; 3] = [
    [0.41233895, 0.35762064, 0.18051042],
    [0.2126, 0.7152, 0.0722],
    [0.01932141, 0.11916382, 0.95034478],
];

const XYZ_TO_SRGB: [[f64; 3]; 3] = [
    [3.2413774792388685, -1.5376652402851851, -0.49885366846268053],
    [-0.9691452513005321, 1.8758853451067872, 0.04156585616912061],
    [0.05562093689691305, -0.20395524564742123, 1.0571799111220335],
];

struct Vc;
impl Vc {
    const N: f64 = 0.18418651851244416;
    const AW: f64 = 29.980997194447333;
    const NBB: f64 = 1.0169191804458755;
    const NCB: f64 = 1.0169191804458755;
    const C: f64 = 0.69;
    const NC: f64 = 1.0;
    const FL: f64 = 0.3884814537800353;
    const FL_ROOT: f64 = 0.7894826179304937;
    const Z: f64 = 1.909169568483652;
    const RGB_D: [f64; 3] = [1.0211931250282205, 0.9862992588498498, 0.9338046048498166];
}

fn linearize(channel: u8) -> f64 {
    let n = channel as f64 / 255.0;
    if n <= 0.040449936 {
        return n / 12.92;
    }
    ((n + 0.055) / 1.055).powf(2.4)
}

fn delinearize(linear: f64) -> u8 {
    let n = if linear <= 0.0031308 { linear * 12.92 } else { 1.055 * linear.powf(1.0 / 2.4) - 0.055 };
    (py_round(n * 255.0) as i64).clamp(0, 255) as u8
}

fn mat_mul(m: [[f64; 3]; 3], v: [f64; 3]) -> [f64; 3] {
    [
        m[0][0] * v[0] + m[0][1] * v[1] + m[0][2] * v[2],
        m[1][0] * v[0] + m[1][1] * v[1] + m[1][2] * v[2],
        m[2][0] * v[0] + m[2][1] * v[1] + m[2][2] * v[2],
    ]
}

fn signum(x: f64) -> f64 {
    if x < 0.0 {
        -1.0
    } else if x > 0.0 {
        1.0
    } else {
        0.0
    }
}

fn sanitize_degrees(degrees: f64) -> f64 {
    let d = py_mod(degrees, 360.0);
    if d < 0.0 { d + 360.0 } else { d }
}

const SCALED_DISCOUNT_FROM_LINRGB: [[f64; 3]; 3] = [
    [0.001200833568784504, 0.002389694492170889, 0.0002795742885861124],
    [0.0005891086651375999, 0.0029785502573438758, 0.0003270666104008398],
    [0.00010146692491640572, 0.0005364214359186694, 0.0032979401770712076],
];

const LINRGB_FROM_SCALED_DISCOUNT: [[f64; 3]; 3] = [
    [1373.2198709594231, -1100.4251190754821, -7.278681089101213],
    [-271.815969077903, 559.6580465940733, -32.46047482791194],
    [1.9622899599665666, -57.173814538844006, 308.7233197812385],
];

const Y_FROM_LINRGB: [f64; 3] = [0.2126, 0.7152, 0.0722];

const CRITICAL_PLANES: [f64; 255] = [
    0.015176349177441876, 0.045529047532325624, 0.07588174588720938,
    0.10623444424209313, 0.13658714259697685, 0.16693984095186062,
    0.19729253930674434, 0.2276452376616281, 0.2579979360165119,
    0.28835063437139563, 0.3188300904430532, 0.350925934958123,
    0.3848314933096426, 0.42057480301049466, 0.458183274052838,
    0.4976837250274023, 0.5391024159806381, 0.5824650784040898,
    0.6277969426914107, 0.6751227633498623, 0.7244668422128921,
    0.775853049866786, 0.829304845476233, 0.8848452951698498,
    0.942497089126609, 1.0022825574869039, 1.0642236851973577,
    1.1283421258858297, 1.1946592148522128, 1.2631959812511864,
    1.3339731595349034, 1.407011200216447, 1.4823302800086415,
    1.5599503113873272, 1.6398909516233677, 1.7221716113234105,
    1.8068114625156377, 1.8938294463134073, 1.9832442801866852,
    2.075074464868551, 2.1693382909216234, 2.2660538449872063,
    2.36523901573795, 2.4669114995532007, 2.5710888059345764,
    2.6777882626779785, 2.7870270208169257, 2.898822059350997,
    3.0131901897720907, 3.1301480604002863, 3.2497121605402226,
    3.3718988244681087, 3.4967242352587946, 3.624204428461639,
    3.754355295633311, 3.887192587735158, 4.022731918402185,
    4.160988767090289, 4.301978482107941, 4.445716283538092,
    4.592217266055746, 4.741496401646282, 4.893568542229298,
    5.048448422192488, 5.20615066083972, 5.3666897647573375,
    5.5300801301023865, 5.696336044816294, 5.865471690767354,
    6.037501145825082, 6.212438385869475, 6.390297286737924,
    6.571091626112461, 6.7548350853498045, 6.941541251256611,
    7.131223617812143, 7.323895587840543, 7.5195704746346665,
    7.7182615035334345, 7.919981813454504, 8.124744458384042,
    8.332562408825165, 8.543448553206703, 8.757415699253682,
    8.974476575321063, 9.194643831691977, 9.417930041841839,
    9.644347703669503, 9.873909240696694, 10.106627003236781,
    10.342513269534024, 10.58158024687427, 10.8238400726681,
    11.069304815507364, 11.317986476196008, 11.569896988756009,
    11.825048221409341, 12.083451977536606, 12.345119996613247,
    12.610063955123938, 12.878295467455942, 13.149826086772048,
    13.42466730586372, 13.702830557985108, 13.984327217668513,
    14.269168601521828, 14.55736596900856, 14.848930523210871,
    15.143873411576273, 15.44220572664832, 15.743938506781891,
    16.04908273684337, 16.35764934889634, 16.66964922287304,
    16.985093187232053, 17.30399201960269, 17.62635644741625,
    17.95219714852476, 18.281524751807332, 18.614349837764564,
    18.95068293910138, 19.290534541298456, 19.633915083172692,
    19.98083495742689, 20.331304511189067, 20.685334046541502,
    21.042933821039977, 21.404114048223256, 21.76888489811322,
    22.137256497705877, 22.50923893145328, 22.884842241736916,
    23.264076429332462, 23.6469514538663, 24.033477234264016,
    24.42366364919083, 24.817520537484558, 25.21505769858089,
    25.61628489293138, 26.021211842414342, 26.429848230738664,
    26.842203703840827, 27.258287870275353, 27.678110301598522,
    28.10168053274597, 28.529008062403893, 28.96010235337422,
    29.39497283293396, 29.83362889318845, 30.276079891419332,
    30.722335150426627, 31.172403958865512, 31.62629557157785,
    32.08401920991837, 32.54558406207592, 33.010999283389665,
    33.4802739966603, 33.953417292456834, 34.430438229418264,
    34.911345834551085, 35.39614910352207, 35.88485700094671,
    36.37747846067349, 36.87402238606382, 37.37449765026789,
    37.87891309649659, 38.38727753828926, 38.89959975977785,
    39.41588851594697, 39.93615253289054, 40.460400508064545,
    40.98864111053629, 41.520882981230194, 42.05713473317016,
    42.597404951718396, 43.141702194811224, 43.6900349931913,
    44.24241185063697, 44.798841244188324, 45.35933162437017,
    45.92389141541209, 46.49252901546552, 47.065252796817916,
    47.64207110610409, 48.22299226451468, 48.808024568002054,
    49.3971762874833, 49.9904556690408, 50.587870934119984,
    51.189430279724725, 51.79514187861014, 52.40501387947288,
    53.0190544071392, 53.637271562750364, 54.259673423945976,
    54.88626804504493, 55.517063457223934, 56.15206766869424,
    56.79128866487574, 57.43473440856916, 58.08241284012621,
    58.734331877617365, 59.39049941699807, 60.05092333227251,
    60.715611475655585, 61.38457167773311, 62.057811747619894,
    62.7353394731159, 63.417162620860914, 64.10328893648692,
    64.79372614476921, 65.48848194977529, 66.18756403501224,
    66.89098006357258, 67.59873767827808, 68.31084450182222,
    69.02730813691093, 69.74813616640164, 70.47333615344107,
    71.20291564160104, 71.93688215501312, 72.67524319850172,
    73.41800625771542, 74.16517879925733, 74.9167682708136,
    75.67278210128072, 76.43322770089146, 77.1981124613393,
    77.96744375590167, 78.74122893956174, 79.51947534912904,
    80.30219030335869, 81.08938110306934, 81.88105503125999,
    82.67721935322541, 83.4778813166706, 84.28304815182372,
    85.09272707154808, 85.90692527145302, 86.72564993000343,
    87.54890820862819, 88.3767072518277, 89.2090541872801,
    90.04595612594655, 90.88742016217518, 91.73345337380438,
    92.58406282226491, 93.43925555268066, 94.29903859396902,
    95.16341895893969, 96.03240364439274, 96.9059996312159,
    97.78421388448044, 98.6670533535366, 99.55452497210776,
];

fn sanitize_radians(angle: f64) -> f64 {
    py_mod(angle + std::f64::consts::PI * 8.0, std::f64::consts::PI * 2.0)
}

fn true_delinearized(rgb_component: f64) -> f64 {
    let n = rgb_component / 100.0;
    let d = if n <= 0.0031308 { n * 12.92 } else { 1.055 * (n.powf(1.0 / 2.4)) - 0.055 };
    d * 255.0
}

fn chromatic_adaptation(component: f64) -> f64 {
    let af = component.abs().powf(0.42);
    signum(component) * 400.0 * af / (af + 27.13)
}

fn hue_of(linrgb: [f64; 3]) -> f64 {
    let sd = mat_mul(SCALED_DISCOUNT_FROM_LINRGB, linrgb);
    let ra = chromatic_adaptation(sd[0]);
    let ga = chromatic_adaptation(sd[1]);
    let ba = chromatic_adaptation(sd[2]);
    let a = (11.0 * ra - 12.0 * ga + ba) / 11.0;
    let b = (ra + ga - 2.0 * ba) / 9.0;
    b.atan2(a)
}

fn are_in_cyclic_order(a: f64, b: f64, c: f64) -> bool {
    sanitize_radians(b - a) < sanitize_radians(c - a)
}

fn intercept(source: f64, mid: f64, target: f64) -> f64 {
    (mid - source) / (target - source)
}

fn lerp_point(source: [f64; 3], t: f64, target: [f64; 3]) -> [f64; 3] {
    [
        source[0] + (target[0] - source[0]) * t,
        source[1] + (target[1] - source[1]) * t,
        source[2] + (target[2] - source[2]) * t,
    ]
}

fn set_coordinate(source: [f64; 3], coordinate: f64, target: [f64; 3], axis: usize) -> [f64; 3] {
    lerp_point(source, intercept(source[axis], coordinate, target[axis]), target)
}

fn is_bounded(x: f64) -> bool {
    (0.0..=100.0).contains(&x)
}

fn nth_vertex(y: f64, n: i64) -> [f64; 3] {
    let [k_r, k_g, k_b] = Y_FROM_LINRGB;
    let coord_a = if n % 4 <= 1 { 0.0 } else { 100.0 };
    let coord_b = if n % 2 == 0 { 0.0 } else { 100.0 };
    if n < 4 {
        let (g, b) = (coord_a, coord_b);
        let r = (y - k_g * g - k_b * b) / k_r;
        if is_bounded(r) {
            return [r, g, b];
        }
        return [-1.0, -1.0, -1.0];
    } else if n < 8 {
        let (b, r) = (coord_a, coord_b);
        let g = (y - k_r * r - k_b * b) / k_g;
        if is_bounded(g) {
            return [r, g, b];
        }
        return [-1.0, -1.0, -1.0];
    }
    let (r, g) = (coord_a, coord_b);
    let b = (y - k_r * r - k_g * g) / k_b;
    if is_bounded(b) {
        return [r, g, b];
    }
    [-1.0, -1.0, -1.0]
}

fn bisect_to_segment(y: f64, target_hue: f64) -> [[f64; 3]; 2] {
    let mut left = [-1.0, -1.0, -1.0];
    let mut right = [-1.0, -1.0, -1.0];
    let mut left_hue = 0.0;
    let mut right_hue = 0.0;
    let mut initialized = false;
    let mut uncut = true;
    for n in 0..12 {
        let mid = nth_vertex(y, n);
        if mid[0] < 0.0 {
            continue;
        }
        let mid_hue = hue_of(mid);
        if !initialized {
            left = mid;
            right = mid;
            left_hue = mid_hue;
            right_hue = mid_hue;
            initialized = true;
            continue;
        }
        if uncut || are_in_cyclic_order(left_hue, mid_hue, right_hue) {
            uncut = false;
            if are_in_cyclic_order(left_hue, target_hue, mid_hue) {
                right = mid;
                right_hue = mid_hue;
            } else {
                left = mid;
                left_hue = mid_hue;
            }
        }
    }
    [left, right]
}

fn mid_point(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, (a[2] + b[2]) / 2.0]
}

fn critical_plane_below(x: f64) -> i64 {
    (x - 0.5).floor() as i64
}

fn critical_plane_above(x: f64) -> i64 {
    (x - 0.5).ceil() as i64
}

fn bisect_to_limit(y: f64, target_hue: f64) -> [f64; 3] {
    let seg = bisect_to_segment(y, target_hue);
    let mut left = seg[0];
    let mut left_hue = hue_of(left);
    let mut right = seg[1];
    for axis in 0..3 {
        if (left[axis] - right[axis]).abs() > 1e-10 {
            let (mut l_plane, mut r_plane);
            if left[axis] < right[axis] {
                l_plane = critical_plane_below(true_delinearized(left[axis]));
                r_plane = critical_plane_above(true_delinearized(right[axis]));
            } else {
                l_plane = critical_plane_above(true_delinearized(left[axis]));
                r_plane = critical_plane_below(true_delinearized(right[axis]));
            }
            for _ in 0..8 {
                if (r_plane - l_plane).abs() <= 1 {
                    break;
                }
                // `int()` truncates toward zero, like `as` casts.
                let mut m_plane = ((l_plane + r_plane) / 2) as i64;
                m_plane = m_plane.clamp(0, CRITICAL_PLANES.len() as i64 - 1);
                let mid = set_coordinate(left, CRITICAL_PLANES[m_plane as usize], right, axis);
                let mid_hue = hue_of(mid);
                if are_in_cyclic_order(left_hue, target_hue, mid_hue) {
                    right = mid;
                    r_plane = m_plane;
                } else {
                    left = mid;
                    left_hue = mid_hue;
                    l_plane = m_plane;
                }
            }
        }
    }
    mid_point(left, right)
}

fn inverse_chromatic_adaptation(adapted: f64) -> f64 {
    let aa = adapted.abs();
    let base = (0.0f64).max(27.13 * aa / (400.0 - aa));
    signum(adapted) * base.powf(1.0 / 0.42)
}

fn find_result_by_j(hue_radians: f64, chroma: f64, y: f64) -> Option<Rgb> {
    let mut j = y.sqrt() * 11.0;
    let t_inner_coeff = 1.0 / (1.64 - 0.29f64.powf(Vc::N)).powf(0.73);
    let e_hue = 0.25 * ((hue_radians + 2.0).cos() + 3.8);
    let p1 = e_hue * (50000.0 / 13.0) * Vc::NC * Vc::NCB;
    let h_sin = hue_radians.sin();
    let h_cos = hue_radians.cos();
    for iteration in 0..5 {
        let j_normalized = j / 100.0;
        let alpha = if chroma == 0.0 || j == 0.0 { 0.0 } else { chroma / j_normalized.sqrt() };
        let t = (alpha * t_inner_coeff).powf(1.0 / 0.9);
        let ac = Vc::AW * (j_normalized.powf(1.0 / Vc::C / Vc::Z));
        let p2 = ac / Vc::NBB;
        let gamma = 23.0 * (p2 + 0.305) * t / (23.0 * p1 + 11.0 * t * h_cos + 108.0 * t * h_sin);
        let a = gamma * h_cos;
        let b = gamma * h_sin;
        let r_a = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
        let g_a = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
        let b_a = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
        let linrgb = mat_mul(
            LINRGB_FROM_SCALED_DISCOUNT,
            [
                inverse_chromatic_adaptation(r_a),
                inverse_chromatic_adaptation(g_a),
                inverse_chromatic_adaptation(b_a),
            ],
        );
        if linrgb[0] < 0.0 || linrgb[1] < 0.0 || linrgb[2] < 0.0 {
            return None;
        }
        let fnj = Y_FROM_LINRGB[0] * linrgb[0] + Y_FROM_LINRGB[1] * linrgb[1] + Y_FROM_LINRGB[2] * linrgb[2];
        if fnj <= 0.0 {
            return None;
        }
        if iteration == 4 || (fnj - y).abs() < 0.002 {
            if linrgb[0] > 100.01 || linrgb[1] > 100.01 || linrgb[2] > 100.01 {
                return None;
            }
            return Some((
                delinearize(linrgb[0] / 100.0),
                delinearize(linrgb[1] / 100.0),
                delinearize(linrgb[2] / 100.0),
            ));
        }
        j -= (fnj - y) * j / (2.0 * fnj);
    }
    None
}

pub fn solve_to_rgb(hue_degrees: f64, chroma: f64, tone: f64) -> Rgb {
    if chroma < 0.0001 || tone < 0.0001 || tone > 99.9999 {
        let y = lstar_to_y(tone);
        let gray = delinearize(y / 100.0);
        return (gray, gray, gray);
    }
    let hue_degrees = sanitize_degrees(hue_degrees);
    let hue_radians = hue_degrees.to_radians();
    let y = lstar_to_y(tone);
    if let Some(exact) = find_result_by_j(hue_radians, chroma, y) {
        return exact;
    }
    let linrgb = bisect_to_limit(y, hue_radians);
    (
        delinearize(linrgb[0] / 100.0),
        delinearize(linrgb[1] / 100.0),
        delinearize(linrgb[2] / 100.0),
    )
}

pub fn rgb_to_xyz(r: u8, g: u8, b: u8) -> (f64, f64, f64) {
    let v = mat_mul(SRGB_TO_XYZ, [linearize(r), linearize(g), linearize(b)]);
    (v[0] * 100.0, v[1] * 100.0, v[2] * 100.0)
}

pub fn xyz_to_rgb(x: f64, y: f64, z: f64) -> Rgb {
    let v = mat_mul(XYZ_TO_SRGB, [x / 100.0, y / 100.0, z / 100.0]);
    (delinearize(v[0]), delinearize(v[1]), delinearize(v[2]))
}

pub fn y_to_lstar(y: f64) -> f64 {
    if y <= 0.0 {
        return 0.0;
    }
    let yn = y / 100.0;
    if yn <= 0.008856 {
        return 903.2962962962963 * yn;
    }
    116.0 * yn.powf(1.0 / 3.0) - 16.0
}

pub fn lstar_to_y(lstar: f64) -> f64 {
    if lstar <= 0.0 {
        return 0.0;
    }
    let lstar = if lstar > 100.0 { 100.0 } else { lstar };
    if lstar <= 8.0 {
        return lstar / 903.2962962962963 * 100.0;
    }
    let fy = (lstar + 16.0) / 116.0;
    fy * fy * fy * 100.0
}

pub fn argb_to_int(r: u8, g: u8, b: u8) -> u32 {
    (255u32 << 24) | ((r as u32) << 16) | ((g as u32) << 8) | b as u32
}

pub fn int_to_rgb(argb: u32) -> Rgb {
    (((argb >> 16) & 0xFF) as u8, ((argb >> 8) & 0xFF) as u8, (argb & 0xFF) as u8)
}

#[derive(Debug, Clone)]
pub struct Cam16 {
    pub hue: f64,
    pub chroma: f64,
    pub j: f64,
    pub q: f64,
    pub m: f64,
    pub s: f64,
    pub jstar: f64,
    pub astar: f64,
    pub bstar: f64,
}

impl Cam16 {
    pub fn from_rgb(r: u8, g: u8, b: u8) -> Cam16 {
        let (x, y, z) = rgb_to_xyz(r, g, b);
        let r_c = 0.401288 * x + 0.650173 * y - 0.051461 * z;
        let g_c = -0.250268 * x + 1.204414 * y + 0.045854 * z;
        let b_c = -0.002079 * x + 0.048952 * y + 0.953127 * z;
        let r_d = Vc::RGB_D[0] * r_c;
        let g_d = Vc::RGB_D[1] * g_c;
        let b_d = Vc::RGB_D[2] * b_c;
        let r_af = (Vc::FL * r_d.abs() / 100.0).powf(0.42);
        let g_af = (Vc::FL * g_d.abs() / 100.0).powf(0.42);
        let b_af = (Vc::FL * b_d.abs() / 100.0).powf(0.42);
        let r_a = signum(r_d) * 400.0 * r_af / (r_af + 27.13);
        let g_a = signum(g_d) * 400.0 * g_af / (g_af + 27.13);
        let b_a = signum(b_d) * 400.0 * b_af / (b_af + 27.13);
        let a = (11.0 * r_a + -12.0 * g_a + b_a) / 11.0;
        let b = (r_a + g_a - 2.0 * b_a) / 9.0;
        let hue_radians = b.atan2(a);
        let mut hue = hue_radians.to_degrees();
        if hue < 0.0 {
            hue += 360.0;
        }
        let u = (20.0 * r_a + 20.0 * g_a + 21.0 * b_a) / 20.0;
        let p2 = (40.0 * r_a + 20.0 * g_a + b_a) / 20.0;
        let ac = p2 * Vc::NBB;
        let j = 100.0 * (ac / Vc::AW).powf(Vc::C * Vc::Z);
        let q = (4.0 / Vc::C) * (j / 100.0).sqrt() * (Vc::AW + 4.0) * Vc::FL_ROOT;
        let hue_prime = if hue < 20.14 { hue + 360.0 } else { hue };
        let e_hue = 0.25 * ((hue_prime.to_radians() + 2.0).cos() + 3.8);
        let t = 50000.0 / 13.0 * Vc::NC * Vc::NCB * e_hue * (a * a + b * b).sqrt() / (u + 0.305);
        let alpha = t.powf(0.9) * (1.64 - 0.29f64.powf(Vc::N)).powf(0.73);
        let chroma = alpha * (j / 100.0).sqrt();
        let m = chroma * Vc::FL_ROOT;
        let s = 50.0 * ((Vc::C * alpha) / (Vc::AW + 4.0)).sqrt();
        let jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j);
        let mstar = if m > 0.0 { 1.0 / 0.0228 * (1.0 + 0.0228 * m).ln() } else { 0.0 };
        let astar = mstar * hue_radians.cos();
        let bstar = mstar * hue_radians.sin();
        Cam16 { hue, chroma, j, q, m, s, jstar, astar, bstar }
    }

    pub fn from_jch(j: f64, chroma: f64, hue: f64) -> Cam16 {
        let q = (4.0 / Vc::C) * (j / 100.0).sqrt() * (Vc::AW + 4.0) * Vc::FL_ROOT;
        let m = chroma * Vc::FL_ROOT;
        let alpha = if j > 0.0 { chroma / (j / 100.0).sqrt() } else { 0.0 };
        let s = 50.0 * ((Vc::C * alpha) / (Vc::AW + 4.0)).sqrt();
        let hue_radians = hue.to_radians();
        let jstar = (1.0 + 100.0 * 0.007) * j / (1.0 + 0.007 * j);
        let mstar = if m > 0.0 { 1.0 / 0.0228 * (1.0 + 0.0228 * m).ln() } else { 0.0 };
        let astar = mstar * hue_radians.cos();
        let bstar = mstar * hue_radians.sin();
        Cam16 { hue, chroma, j, q, m, s, jstar, astar, bstar }
    }

    pub fn to_rgb(&self) -> Rgb {
        if self.chroma == 0.0 || self.j == 0.0 {
            let y = lstar_to_y(self.j);
            return xyz_to_rgb(y, y, y);
        }
        let hue_radians = self.hue.to_radians();
        let alpha = if self.j > 0.0 { self.chroma / (self.j / 100.0).sqrt() } else { 0.0 };
        let t = (alpha / (1.64 - 0.29f64.powf(Vc::N)).powf(0.73)).powf(1.0 / 0.9);
        let hue_prime = if self.hue < 20.14 { self.hue + 360.0 } else { self.hue };
        let e_hue = 0.25 * ((hue_prime.to_radians() + 2.0).cos() + 3.8);
        let ac = Vc::AW * (self.j / 100.0).powf(1.0 / (Vc::C * Vc::Z));
        let p1 = 50000.0 / 13.0 * Vc::NC * Vc::NCB * e_hue;
        let p2 = ac / Vc::NBB;
        let gamma = 23.0 * (p2 + 0.305) * t
            / (23.0 * p1 + 11.0 * t * hue_radians.cos() + 108.0 * t * hue_radians.sin());
        let a = gamma * hue_radians.cos();
        let b = gamma * hue_radians.sin();
        let r_a = (460.0 * p2 + 451.0 * a + 288.0 * b) / 1403.0;
        let g_a = (460.0 * p2 - 891.0 * a - 261.0 * b) / 1403.0;
        let b_a = (460.0 * p2 - 220.0 * a - 6300.0 * b) / 1403.0;
        fn reverse_adapt(adapted: f64) -> f64 {
            let aa = adapted.abs();
            let base = (0.0f64).max(27.13 * aa / (400.0 - aa));
            signum(adapted) * 100.0 / Vc::FL * base.powf(1.0 / 0.42)
        }
        let r_c = reverse_adapt(r_a) / Vc::RGB_D[0];
        let g_c = reverse_adapt(g_a) / Vc::RGB_D[1];
        let b_c = reverse_adapt(b_a) / Vc::RGB_D[2];
        let x = 1.8620678 * r_c - 1.0112547 * g_c + 0.1491867 * b_c;
        let y = 0.3875265 * r_c + 0.6214474 * g_c - 0.0089739 * b_c;
        let z = -0.0158415 * r_c - 0.0344156 * g_c + 1.0502571 * b_c;
        xyz_to_rgb(x, y, z)
    }
}

#[derive(Debug, Clone, Copy)]
pub struct Hct {
    pub hue: f64,
    pub chroma: f64,
    pub tone: f64,
}

impl Hct {
    pub fn new(hue: f64, chroma: f64, tone: f64) -> Hct {
        Hct { hue: py_mod(hue, 360.0), chroma: chroma.max(0.0), tone: tone.clamp(0.0, 100.0) }
    }

    pub fn from_rgb(r: u8, g: u8, b: u8) -> Hct {
        let cam = Cam16::from_rgb(r, g, b);
        let (_, y, _) = rgb_to_xyz(r, g, b);
        Hct::new(cam.hue, cam.chroma, y_to_lstar(y))
    }

    pub fn from_argb(argb: u32) -> Hct {
        let (r, g, b) = int_to_rgb(argb);
        Hct::from_rgb(r, g, b)
    }

    pub fn to_rgb(self) -> Rgb {
        solve_to_rgb(self.hue, self.chroma, self.tone)
    }

    pub fn to_argb(self) -> u32 {
        let (r, g, b) = self.to_rgb();
        argb_to_int(r, g, b)
    }

    pub fn to_hex(self) -> String {
        let (r, g, b) = self.to_rgb();
        format!("#{r:02x}{g:02x}{b:02x}")
    }

    pub fn set_hue(self, hue: f64) -> Hct {
        Hct::new(hue, self.chroma, self.tone)
    }

    pub fn set_chroma(self, chroma: f64) -> Hct {
        Hct::new(self.hue, chroma, self.tone)
    }

    pub fn set_tone(self, tone: f64) -> Hct {
        Hct::new(self.hue, self.chroma, tone)
    }
}

pub struct TemperatureCache {
    input: Hct,
    hcts_by_temp: Option<Vec<Hct>>,
    hcts_by_hue: Option<Vec<Hct>>,
    temps_by_hct: Option<HashMap<(u64, u64, u64), f64>>,
    input_relative_temp: Option<f64>,
    complement: Option<Hct>,
}

fn hct_key(h: Hct) -> (u64, u64, u64) {
    (h.hue.to_bits(), h.chroma.to_bits(), h.tone.to_bits())
}

impl TemperatureCache {
    pub fn new(input: Hct) -> TemperatureCache {
        TemperatureCache {
            input,
            hcts_by_temp: None,
            hcts_by_hue: None,
            temps_by_hct: None,
            input_relative_temp: None,
            complement: None,
        }
    }

    pub fn raw_temperature(hct: Hct) -> f64 {
        let (r, g, b) = hct.to_rgb();
        let (x, y, z) = rgb_to_xyz(r, g, b);
        fn f(t: f64) -> f64 {
            let delta: f64 = 6.0 / 29.0;
            if t > delta.powi(3) {
                return t.powf(1.0 / 3.0);
            }
            t / (3.0 * delta * delta) + 4.0 / 29.0
        }
        let (xn, yn, zn) = (95.047, 100.0, 108.883);
        let lab_a = 500.0 * (f(x / xn) - f(y / yn));
        let lab_b = 200.0 * (f(y / yn) - f(z / zn));
        let mut lab_hue = lab_b.atan2(lab_a).to_degrees();
        if lab_hue < 0.0 {
            lab_hue += 360.0;
        }
        let lab_chroma = lab_a.hypot(lab_b);
        let hue_rad = py_mod(lab_hue - 50.0, 360.0).to_radians();
        -0.5 + 0.02 * lab_chroma.powf(1.07) * hue_rad.cos()
    }

    fn hcts_by_hue(&mut self) -> &[Hct] {
        if self.hcts_by_hue.is_none() {
            let hcts: Vec<Hct> = (0..360).map(|h| Hct::new(h as f64, self.input.chroma, self.input.tone)).collect();
            self.hcts_by_hue = Some(hcts);
        }
        self.hcts_by_hue.as_ref().unwrap()
    }

    fn temps_by_hct(&mut self) -> &HashMap<(u64, u64, u64), f64> {
        if self.temps_by_hct.is_none() {
            let hcts = self.hcts_by_hue().to_vec();
            let mut temps = HashMap::new();
            for h in &hcts {
                temps.insert(hct_key(*h), TemperatureCache::raw_temperature(*h));
            }
            self.temps_by_hct = Some(temps);
        }
        self.temps_by_hct.as_ref().unwrap()
    }

    fn hcts_by_temp(&mut self) -> &[Hct] {
        if self.hcts_by_temp.is_none() {
            let mut hcts = self.hcts_by_hue().to_vec();
            let temps = self.temps_by_hct().clone();
            // Stable sort like Python's list.sort.
            hcts.sort_by(|a, b| {
                temps[&hct_key(*a)].partial_cmp(&temps[&hct_key(*b)]).unwrap()
            });
            self.hcts_by_temp = Some(hcts);
        }
        self.hcts_by_temp.as_ref().unwrap()
    }

    fn relative_temperature(&mut self, hct: Hct) -> f64 {
        let key = hct_key(hct);
        let raw = self.temps_by_hct().get(&key).copied().unwrap_or_else(|| TemperatureCache::raw_temperature(hct));
        let by_temp = self.hcts_by_temp().to_vec();
        let coldest = TemperatureCache::raw_temperature(by_temp[0]);
        let warmest = TemperatureCache::raw_temperature(by_temp[by_temp.len() - 1]);
        if warmest == coldest {
            return 0.5;
        }
        (raw - coldest) / (warmest - coldest)
    }

    fn input_relative_temperature_value(&mut self) -> f64 {
        if self.input_relative_temp.is_none() {
            let t = self.relative_temperature(self.input);
            self.input_relative_temp = Some(t);
        }
        self.input_relative_temp.unwrap()
    }

    pub fn complement(&mut self) -> Hct {
        if let Some(c) = self.complement {
            return c;
        }
        let input_temp = self.input_relative_temperature_value();
        let by_temp = self.hcts_by_temp().to_vec();
        let temps = self.temps_by_hct().clone();
        let target = 1.0 - input_temp;
        let mut best = by_temp[0];
        let mut best_diff = f64::INFINITY;
        for h in &by_temp {
            let raw = temps.get(&hct_key(*h)).copied().unwrap_or_else(|| TemperatureCache::raw_temperature(*h));
            let rel = {
                let coldest = TemperatureCache::raw_temperature(by_temp[0]);
                let warmest = TemperatureCache::raw_temperature(by_temp[by_temp.len() - 1]);
                if warmest == coldest { 0.5 } else { (raw - coldest) / (warmest - coldest) }
            };
            let diff = (rel - target).abs();
            if diff < best_diff {
                best_diff = diff;
                best = *h;
            }
        }
        self.complement = Some(best);
        best
    }

    pub fn analogous(&mut self, count: Option<usize>, divisions: Option<usize>) -> Vec<Hct> {
        let count = count.unwrap_or(5);
        let divisions = divisions.unwrap_or(12);
        let by_hue = self.hcts_by_hue().to_vec();
        let start_hue = py_round(self.input.hue) as i64 % 360;
        let start_hct = by_hue[start_hue as usize];
        let mut last_temp = self.relative_temperature(start_hct);
        let mut absolute_total = 0.0;
        for i in 0..360 {
            let hue = (start_hue + i) % 360;
            let temp = self.relative_temperature(by_hue[hue as usize]);
            absolute_total += (temp - last_temp).abs();
            last_temp = temp;
        }
        let temp_step = absolute_total / divisions as f64;
        let mut all_colors: Vec<Hct> = vec![start_hct];
        let mut total = 0.0;
        let mut last = self.relative_temperature(start_hct);
        let mut hue_addend: i64 = 1;
        while all_colors.len() < divisions && hue_addend <= 360 {
            let hue = (start_hue + hue_addend) % 360;
            let hct = by_hue[hue as usize];
            let temp = self.relative_temperature(hct);
            total += (temp - last).abs();
            let mut desired = all_colors.len() as f64 * temp_step;
            while total >= desired && all_colors.len() < divisions {
                all_colors.push(hct);
                desired = (all_colors.len() + 1) as f64 * temp_step;
            }
            last = temp;
            hue_addend += 1;
        }
        while all_colors.len() < divisions {
            let last_c = all_colors.last().copied().unwrap_or(start_hct);
            all_colors.push(last_c);
        }
        let mut answers = vec![self.input];
        let increase = (count as i64 - 1).div_euclid(2).max(0);
        for i in 1..=increase {
            let index = (-i).rem_euclid(all_colors.len() as i64) as usize;
            answers.insert(0, all_colors[index]);
        }
        let decrease = count as i64 - increase - 1;
        for i in 1..=decrease.max(0) {
            answers.push(all_colors[i as usize % all_colors.len()]);
        }
        answers
    }
}

pub fn fix_if_disliked(hct: Hct) -> Hct {
    if hct.hue >= 80.0 && hct.hue <= 110.0 && hct.chroma > 16.0 {
        let new_hue = if hct.hue < 95.0 { 75.0 } else { 115.0 };
        return Hct::new(new_hue, hct.chroma, hct.tone);
    }
    hct
}

pub struct TonalPalette {
    pub hue: f64,
    pub chroma: f64,
    cache: HashMap<i64, u32>,
}

impl TonalPalette {
    pub fn new(hue: f64, chroma: f64) -> TonalPalette {
        TonalPalette { hue, chroma, cache: HashMap::new() }
    }

    pub fn from_hct(hct: Hct) -> TonalPalette {
        TonalPalette::new(hct.hue, hct.chroma)
    }

    pub fn from_rgb(r: u8, g: u8, b: u8) -> TonalPalette {
        TonalPalette::from_hct(Hct::from_rgb(r, g, b))
    }

    pub fn tone(&mut self, t: i64) -> u32 {
        if let Some(v) = self.cache.get(&t) {
            return *v;
        }
        let v = Hct::new(self.hue, self.chroma, t as f64).to_argb();
        self.cache.insert(t, v);
        v
    }

    pub fn get_rgb(&mut self, t: i64) -> Rgb {
        int_to_rgb(self.tone(t))
    }

    pub fn get_hex(&mut self, t: i64) -> String {
        let (r, g, b) = self.get_rgb(t);
        format!("#{r:02x}{g:02x}{b:02x}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sanitize_helpers() {
        assert_eq!(sanitize_degrees(370.0), 10.0);
        assert_eq!(sanitize_degrees(-10.0), 350.0);
        assert_eq!(signum(-2.0), -1.0);
        assert_eq!(signum(0.0), 0.0);
    }

    #[test]
    fn lstar_roundtrip() {
        for t in [0.0, 8.0, 50.0, 100.0] {
            let y = lstar_to_y(t);
            assert!((y_to_lstar(y) - t).abs() < 1e-9, "{t}");
        }
    }

    #[test]
    fn argb_roundtrip() {
        assert_eq!(int_to_rgb(argb_to_int(255, 85, 0)), (255, 85, 0));
    }

    #[test]
    fn hct_gray_clamps() {
        let h = Hct::new(999.0, -5.0, 150.0);
        assert_eq!(h.hue, 999.0 % 360.0);
        assert_eq!(h.chroma, 0.0);
        assert_eq!(h.tone, 100.0);
        assert_eq!(h.to_rgb(), (255, 255, 255));
    }

    #[test]
    fn matches_python_oracle() {
        // Values produced by Scripts/python/src/theming/lib/hct.py.
        let h = Hct::from_rgb(255, 85, 0);
        assert_eq!((h.hue, h.chroma, h.tone), (37.43790175552999, 87.29401886420544, 59.668564211751516));
        assert_eq!(h.to_hex(), "#ff5500");
        let c = Cam16::from_rgb(255, 85, 0);
        assert_eq!(
            (c.hue, c.chroma, c.j, c.q, c.m, c.s),
            (37.43790175552999, 87.29401886420544, 52.55858360228834, 112.74866777403004, 68.91711054258681, 78.18218808019498)
        );
        let h2 = Hct::from_rgb(18, 52, 86);
        assert_eq!((h2.hue, h2.chroma, h2.tone), (255.34463942138404, 29.904068873716756, 21.04306195157679));
        assert_eq!(h2.to_hex(), "#123456");
        let gray = Hct::from_rgb(128, 128, 128);
        assert_eq!(gray.to_hex(), "#808080");
        assert_eq!(Hct::from_rgb(0, 0, 0).to_hex(), "#000000");
        assert_eq!(Hct::from_rgb(255, 255, 255).to_hex(), "#ffffff");
        let mut tp = TonalPalette::from_rgb(255, 85, 0);
        let tones: Vec<String> = [0, 10, 40, 50, 80, 90, 95, 100].iter().map(|t| tp.get_hex(*t)).collect();
        assert_eq!(tones, ["#000000", "#390c00", "#aa3600", "#d54600", "#ffb59c", "#ffdbcf", "#ffede8", "#ffffff"]);
        assert_eq!(TemperatureCache::raw_temperature(Hct::from_rgb(255, 85, 0)), 2.068398980561512);
        let mut tc = TemperatureCache::new(Hct::from_rgb(255, 85, 0));
        assert_eq!(tc.complement().to_hex(), "#0092fe");
        let analog: Vec<String> = tc.analogous(None, None).iter().map(|h| h.to_hex()).collect();
        assert_eq!(analog, ["#ff4692", "#ff5154", "#ff5500", "#d87700", "#ac8d00"]);
        assert_eq!(Hct::new(25.0, 48.0, 60.0).to_hex(), "#db7267");
        assert_eq!(Hct::new(200.0, 100.0, 90.0).to_hex(), "#47f9ff");
        assert_eq!(Hct::new(95.0, 60.0, 30.0).to_hex(), "#554500");
    }

    #[test]
    fn fix_disliked_range() {
        assert_eq!(fix_if_disliked(Hct::new(90.0, 30.0, 60.0)).hue, 75.0);
        assert_eq!(fix_if_disliked(Hct::new(100.0, 30.0, 60.0)).hue, 115.0);
        assert_eq!(fix_if_disliked(Hct::new(90.0, 10.0, 60.0)).hue, 90.0);
        assert_eq!(fix_if_disliked(Hct::new(200.0, 30.0, 60.0)).hue, 200.0);
    }
}
