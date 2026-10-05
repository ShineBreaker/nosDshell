#!/usr/bin/env python3
"""Generate the nosDshell nautilus logo.

Run from the repository root:

  python3 Scripts/assets/gen-logo.py

Outputs:
  1. Assets/nosdshell.svg           - styled: navy-teal disc + white spiral
  2. Assets/nosdshell-glyph.svg     - monochrome outlines for fontforge
                                    (input to patch-font-glyph.py)

Spiral: logarithmic ribbon whose width grows with radius (nautilus groove).
Original artwork - follows the disc-plus-swirl vocabulary of the deepin
launcher mark (deepin-icon-theme places/deepin-launcher.svg) without
copying its brush-stroke artwork.
"""
import math

def spiral_ribbon(cx, cy, r0, k, theta_end, wfrac, n=260):
    """Filled polygon for a logarithmic spiral ribbon.

    Centerline r = r0*e^(k*theta). Ribbon half-width = wfrac*r/2 at each
    point, offset along the local normal. Round caps at both ends.
    Returns SVG path 'd' (y-down coords, caller supplies cx/cy).
    """
    # orientation: start the spiral tail at bottom-right, winding
    # counter-clockwise inward like a nautilus. theta sweeps the angle.
    pts_center = []
    for i in range(n + 1):
        t = theta_end * i / n
        r = r0 * math.exp(k * t)
        # rotate so the outer tail points down-right (~65 deg below +x)
        a = t + math.radians(115) - theta_end
        pts_center.append((cx + r * math.cos(a), cy + r * math.sin(a), r))

    outer, inner = [], []
    for i, (x, y, r) in enumerate(pts_center):
        if i == 0:
            dx = pts_center[1][0] - x
            dy = pts_center[1][1] - y
        elif i == len(pts_center) - 1:
            dx = x - pts_center[i - 1][0]
            dy = y - pts_center[i - 1][1]
        else:
            dx = pts_center[i + 1][0] - pts_center[i - 1][0]
            dy = pts_center[i + 1][1] - pts_center[i - 1][1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        hw = wfrac * r / 2.0
        outer.append((x + nx * hw, y + ny * hw))
        inner.append((x - nx * hw, y - ny * hw))

    # round cap at outer end: semicircle fan from outer[-1] to inner[-1]
    cap_pts = []
    ex, ey, er = pts_center[-1]
    ehw = wfrac * er / 2.0
    # tangent direction at end
    dx = ex - pts_center[-2][0]
    dy = ey - pts_center[-2][1]
    L = math.hypot(dx, dy) or 1.0
    tx, ty = dx / L, dy / L
    for i in range(1, 10):
        a = math.pi * i / 10.0
        # rotate from +normal to -normal around the end point
        ox = outer[-1][0] - ex
        oy = outer[-1][1] - ey
        rx = ox * math.cos(a) - oy * math.sin(a)
        ry = ox * math.sin(a) + oy * math.cos(a)
        cap_pts.append((ex + rx, ey + ry))

    # cap at start: small arc closing the nucleus (start point ~ tiny r)
    d = "M %.3f %.3f " % outer[0]
    d += "L " + " L ".join("%.3f %.3f" % p for p in outer[1:])
    d += " L " + " L ".join("%.3f %.3f" % p for p in cap_pts)
    d += " L " + " L ".join("%.3f %.3f" % p for p in reversed(inner))
    # round the nucleus: arc back to outer[0]
    sx, sy, sr = pts_center[0]
    shw = wfrac * sr / 2.0
    d += " A %.3f %.3f 0 0 1 %.3f %.3f Z" % (shw, shw, outer[0][0], outer[0][1])
    return d


# --- styled logo (256x256) -------------------------------------------------
CX, CY, DISC = 128.0, 128.0, 104.0
spiral_d = spiral_ribbon(CX, CY, r0=10.0, k=0.176, theta_end=math.radians(675),
                         wfrac=0.34)
svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <radialGradient id="disc" cx="35%" cy="30%" r="85%">
      <stop offset="0%" stop-color="#1e5c7a"/>
      <stop offset="100%" stop-color="#0d2b3d"/>
    </radialGradient>
  </defs>
  <circle cx="{CX}" cy="{CY}" r="{DISC}" fill="url(#disc)"/>
  <path d="{spiral_d}" fill="#f2f6f8"/>
</svg>
'''
with open('Assets/nosdshell.svg', 'w') as f:
    f.write(svg)

# --- fontforge glyph (1000-unit canvas matching the font em) ---------------
# font coords are y-up; fontforge's SVG import ignores transforms, so bake
# an affine map svg(128,128)->font(510,400), y flipped, into the path data.
GX, GY, GDISC = 510.0, 500.0, 400.0
SC = GDISC / DISC
raw_d = spiral_ribbon(CX, CY, r0=10.0, k=0.176,
                      theta_end=math.radians(675), wfrac=0.34)


def affine(d):
    # remap every x,y pair; only M/L (x y) and A (rx ry rot laf sf x y) occur
    toks = d.replace(",", " ").split()
    out, pend, i = [], 0, 0
    while i < len(toks):
        t = toks[i]
        out.append(t)
        i += 1
        n = 7 if t == "A" else (2 if t in ("M", "L") else pend)
        if t in ("M", "L", "A"):
            pend = n
            for j in range(n):
                v = float(toks[i + j])
                if t == "A" and j in (0, 1):
                    out.append("%.2f" % (v * SC))       # rx, ry scale only
                elif t == "A" and j == 4:
                    out.append("%.0f" % (1 - v))         # sweep flips with y
                elif t == "A" and j in (2, 3):
                    out.append("%.0f" % v)               # rot, laf pass
                else:
                    k = (j - 5) if t == "A" else j       # x,y pair index
                    out.append("%.2f" % (GX + (v - CX) * SC if k % 2 == 0 else GY + (v - CY) * SC))
            i += n
    return " ".join(out)


gspiral_d = affine(raw_d)
gsvg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000">
  <path d="M {GX} {GY} m {-GDISC} 0 a {GDISC} {GDISC} 0 1 1 {2*GDISC} 0 a {GDISC} {GDISC} 0 1 1 {-2*GDISC} 0 Z" fill="#000"/>
  <path d="{gspiral_d}" fill="#000"/>
</svg>
'''
with open('Assets/nosdshell-glyph.svg', 'w') as f:
    f.write(gsvg)
print("wrote Assets/nosdshell.svg and Assets/nosdshell-glyph.svg")
