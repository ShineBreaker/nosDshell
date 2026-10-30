#!/usr/bin/env python3
"""Generate and check the motion curve tokens in Commons/Style.qml.

The motion language follows open-claude-ui's CDS tokens (DESIGN §1.7). QML
has no CSS cubic-bezier() or spring() easing that a duration token can
drive, so every curve becomes an `easing.bezierCurve` list for
`Easing.BezierSpline`:

- a CSS cubic-bezier(x1, y1, x2, y2) is one segment, copied verbatim;
- a CSS linear() keypoint list and a damped-spring step response become a
  smooth multi-segment spline through samples of the reference
  (Catmull-Rom tangents, x evenly spaced, so each segment is monotonic in x).

Usage:
  test-motion-curves.py           check Style.qml against the references
  test-motion-curves.py --emit    print the QML token lines to paste

The check fails when a token drifts from its generated value, when a spline
strays more than MAX_ERR from its reference, when a spline is malformed for
QEasingCurve (non-monotonic x, not ending at (1, 1)), or when a duration tier
in Style.qml stops matching the CDS value. Lint runs it (Scripts/dev/lint.sh).
"""

import math
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STYLE = os.path.join(REPO, "Commons", "Style.qml")
MAX_ERR = 0.02
OCU = "open-claude-ui/code-examples/"

# name -> (kind, data, source). Sources are paths in
# https://github.com/Caho1/open-claude-ui (main).
CURVES = {
    "Swift": ("bezier", (0.16, 1, 0.3, 1), OCU + "cds-theme.css:204"),
    "Expand": ("bezier", (0.19, 1, 0.22, 1), OCU + "cds-theme.css:205"),
    "Enter": ("bezier", (0.22, 1, 0.36, 1), OCU + "cds-theme.css:206"),
    "Out": ("bezier", (0.165, 0.84, 0.44, 1), OCU + "cds-theme.css:207"),
    "Snap": ("bezier", (0.32, 0.72, 0, 1), OCU + "cds-theme.css:208"),
    "Overshoot": ("bezier", (0.34, 1.3, 0.64, 1), OCU + "cds-theme.css:209"),
    "Pop": ("bezier", (0.34, 1.56, 0.64, 1), OCU + "cds-theme.css:210"),
    "Pulse": ("bezier", (0.4, 0, 0.2, 1), OCU + "cds-theme.css:211"),
    "Rise": ("bezier", (0.3, 0.7, 0.4, 1), OCU + "cds-theme.css:212"),
    "Fall": ("bezier", (0, 0, 0.2, 1), OCU + "cds-theme.css:213"),
    # CSS keyword `ease-out`: the press-in of .cds-btn-squish and the exit of
    # motionPopover.
    "CssEaseOut": ("bezier", (0, 0, 0.58, 1), OCU + "cds-theme.css:490; ClaudeMotionPresets.ts:184"),
    # --cds-btn-spring, the 450 ms button release (+9.15 % overshoot).
    "Release": ("linear", (0, .2459, .6526, .9468, 1.0764, 1.0915, 1.0585, 1.0219,
                           .9993, .9914, .9921, .9957, .9988, 1.0004, 1),
                OCU + "cds-theme.css:223,486"),
    # SPRING_SNAPPY {stiffness 320, damping 28, mass 1}: motionPopover enter.
    "Snappy": ("spring", (320, 28, 1), OCU + "ClaudeMotionPresets.ts:79-82,173-178"),
}

# Duration tiers, ms (cds-theme.css:218-222).
TIERS = {"durFast": 60, "durSnap": 120, "durBase": 200, "durSheet": 300, "durSlow": 450}

SPRING_SAMPLES = 16
SPRING_SETTLE = 0.01  # the spline spans the response until it stays within 1 %


def spring_response(k, c, m):
    w = math.sqrt(k / m)
    z = c / (2 * math.sqrt(k * m))
    wd = w * math.sqrt(1 - z * z)

    def x(t):
        return 1 - math.exp(-z * w * t) * (math.cos(wd * t) + z * w / wd * math.sin(wd * t))

    ts = [i / 2000 for i in range(0, 4000)]
    settle = next(t for t in reversed(ts) if abs(x(t) - 1) > SPRING_SETTLE)
    return x, settle


def catmull_rom(points):
    """Points (x, y) with x from 0 to 1 -> flat bezierCurve list."""
    out = []
    n = len(points)
    for i in range(n - 1):
        p0 = points[max(0, i - 1)]
        p1, p2 = points[i], points[i + 1]
        p3 = points[min(n - 1, i + 2)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out += [c1[0], c1[1], c2[0], c2[1], p2[0], p2[1]]
    return out


def generate(name):
    kind, data, _ = CURVES[name]
    if kind == "bezier":
        return list(data) + [1, 1]
    if kind == "linear":
        n = len(data)
        return catmull_rom([(i / (n - 1), v) for i, v in enumerate(data)])
    k, c, m = data
    x, settle = spring_response(k, c, m)
    pts = [(i / (SPRING_SAMPLES - 1), x(settle * i / (SPRING_SAMPLES - 1))) for i in range(SPRING_SAMPLES)]
    pts[-1] = (1.0, 1.0)
    return catmull_rom(pts)


def reference(name):
    """y(x) of the reference the spline must follow."""
    kind, data, _ = CURVES[name]
    if kind == "bezier":
        return lambda u: eval_spline(list(data) + [1, 1], u)
    if kind == "linear":
        n = len(data)

        def lin(u):  # CSS linear(): straight lines between evenly spaced stops
            f = u * (n - 1)
            i = min(n - 2, int(f))
            return data[i] + (data[i + 1] - data[i]) * (f - i)
        return lin
    k, c, m = data
    x, settle = spring_response(k, c, m)
    return lambda u: 1.0 if u >= 1 else x(settle * u)


def eval_spline(flat, u):
    """QEasingCurve BezierSpline semantics: start at (0, 0), segments of
    (c1, c2, end); find the segment containing x = u, solve its x(s) = u."""
    start = (0.0, 0.0)
    for i in range(0, len(flat), 6):
        c1, c2, end = (flat[i], flat[i + 1]), (flat[i + 2], flat[i + 3]), (flat[i + 4], flat[i + 5])
        if u <= end[0] + 1e-12:
            lo, hi = 0.0, 1.0
            for _ in range(60):
                s = (lo + hi) / 2
                xs = (1 - s) ** 3 * start[0] + 3 * (1 - s) ** 2 * s * c1[0] + 3 * (1 - s) * s * s * c2[0] + s ** 3 * end[0]
                if xs < u:
                    lo = s
                else:
                    hi = s
            s = (lo + hi) / 2
            return (1 - s) ** 3 * start[1] + 3 * (1 - s) ** 2 * s * c1[1] + 3 * (1 - s) * s * s * c2[1] + s ** 3 * end[1]
        start = end
    return 1.0


def fmt(v):
    s = ("%.4f" % v).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def emit():
    for name, (_, _, src) in CURVES.items():
        vals = ", ".join(fmt(v) for v in generate(name))
        print("  // %s" % src)
        print("  readonly property var curve%s: [%s]" % (name, vals))


def check():
    errors = []
    style = open(STYLE).read()
    for name in CURVES:
        gen = [float(fmt(v)) for v in generate(name)]
        # structural checks on the generated spline
        if len(gen) % 6 or gen[-2:] != [1.0, 1.0]:
            errors.append("curve%s: spline must be whole segments ending at (1, 1)" % name)
        xs = [0.0] + [gen[i] for i in range(4, len(gen), 6)]
        if any(b <= a for a, b in zip(xs, xs[1:])):
            errors.append("curve%s: segment end x must increase" % name)
        ref = reference(name)
        err = max(abs(eval_spline(gen, u / 400) - ref(u / 400)) for u in range(401))
        if err > MAX_ERR:
            errors.append("curve%s: spline strays %.4f from its reference (max %.2f)" % (name, err, MAX_ERR))
        # the token in Style.qml must be the generated list
        m = re.search(r"readonly property var curve%s:\s*\[([^\]]*)\]" % name, style, re.S)
        if not m:
            errors.append("Style.qml: missing token curve%s (run with --emit)" % name)
            continue
        have = [float(v) for v in m.group(1).replace("\n", " ").split(",") if v.strip()]
        if len(have) != len(gen) or any(abs(a - b) > 1e-4 for a, b in zip(have, gen)):
            errors.append("Style.qml: curve%s differs from the generated value (run with --emit)" % name)
    for tok, ms in TIERS.items():
        m = re.search(r"readonly property int %s:\s*_motion\((\d+)\)" % tok, style)
        if not m:
            errors.append("Style.qml: missing duration tier %s: _motion(%d)" % (tok, ms))
        elif int(m.group(1)) != ms:
            errors.append("Style.qml: %s is %s ms, CDS tier is %d ms" % (tok, m.group(1), ms))
    # the curve map NAnim resolves names through must list every curve
    m = re.search(r"readonly property var curves:\s*\(\{(.*?)\}\)", style, re.S)
    if not m:
        errors.append("Style.qml: missing `curves` name map")
    else:
        for name in CURVES:
            key = name[0].lower() + name[1:]
            if not re.search(r"\"?\b%s\"?:\s*curve%s\b" % (key, name), m.group(1)):
                errors.append("Style.qml: curves map lacks %s: curve%s" % (key, name))
    if errors:
        print("motion curves FAIL:")
        for e in errors:
            print("  " + e)
        return 1
    print("motion curves ok: %d curve tokens match their CDS references, %d duration tiers" % (len(CURVES), len(TIERS)))
    return 0


if __name__ == "__main__":
    if "--emit" in sys.argv:
        emit()
        sys.exit(0)
    sys.exit(check())
