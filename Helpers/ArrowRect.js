// ArrowRect — SVG path helpers for a rounded rectangle with a triangular
// arrow on one edge (DArrowRectangle shape, DESIGN §3.2).
// Pure JS, no QML types — reusable from Shape PathSvg and Canvas code.
//
// The w x h box INCLUDES the arrow: the body is inset by arrowH on `edge`.
// `arrowPos` is the tip coordinate along that edge (x for top/bottom,
// y for left/right), clamped so the arrow base never overlaps a corner.
// `ox`/`oy` optionally place the box's top-left at a non-origin position
// (used by the MainScreen Shape, which draws in screen coordinates).
//
// Zero radius emits straight lines, never zero-displacement Q curves —
// the CurveRenderer triangulator crashes on degenerate arcs.

function _clampTip(pos, edgeLen, radius, arrowW) {
  var half = arrowW / 2;
  var lo = radius + half;
  var hi = edgeLen - radius - half;
  if (lo > hi) {
    return edgeLen / 2;
  }
  return Math.min(Math.max(pos, lo), hi);
}

// Returns the content area (body without the arrow) as {x, y, width, height}.
function bodyRect(w, h, edge, arrowH) {
  switch (edge) {
  case "top":
    return {
      "x": 0,
      "y": arrowH,
      "width": w,
      "height": h - arrowH
    };
  case "bottom":
    return {
      "x": 0,
      "y": 0,
      "width": w,
      "height": h - arrowH
    };
  case "left":
    return {
      "x": arrowH,
      "y": 0,
      "width": w - arrowH,
      "height": h
    };
  case "right":
    return {
      "x": 0,
      "y": 0,
      "width": w - arrowH,
      "height": h
    };
  default:
    return {
      "x": 0,
      "y": 0,
      "width": w,
      "height": h
    };
  }
}

// Returns an SVG path string for PathSvg.
// edge: "top" | "bottom" | "left" | "right" | "" (plain rounded rect)
function svgPath(w, h, radius, edge, arrowPos, arrowW, arrowH, ox, oy) {
  ox = ox || 0;
  oy = oy || 0;
  var r = Math.max(0, Math.min(radius, Math.min(w, h) / 2));
  var straight = r <= 0;

  // Format helpers (absolute coordinates, offset by ox/oy)
  function P(x, y) {
    return (x + ox) + " " + (y + oy);
  }
  // Corner segment: quadratic curve when rounded, plain line when r == 0.
  function corner(cx, cy, ex, ey) {
    if (straight)
      return " L " + P(ex, ey);
    return " Q " + P(cx, cy) + " " + P(ex, ey);
  }
  function M(x, y) {
    return "M " + P(x, y);
  }
  function L(x, y) {
    return " L " + P(x, y);
  }
  function H(x) {
    return " H " + (x + ox);
  }
  function V(y) {
    return " V " + (y + oy);
  }

  if (!edge) {
    return M(r, 0) + H(w - r) + corner(w, 0, w, r) + V(h - r) + corner(w, h, w - r, h) + H(r) + corner(0, h, 0, h - r) + V(r) + corner(0, 0, r, 0) + " Z";
  }

  var half = arrowW / 2;
  var a;
  var p;

  if (edge === "bottom") {
    var bh = h - arrowH;
    a = _clampTip(arrowPos, w, r, arrowW);
    p = M(r, 0) + H(w - r) + corner(w, 0, w, r) + V(bh - r) + corner(w, bh, w - r, bh) + H(a + half) + L(a, h) + L(a - half, bh) + H(r) + corner(0, bh, 0, bh - r) + V(r) + corner(0, 0, r, 0) + " Z";
  } else if (edge === "top") {
    a = _clampTip(arrowPos, w, r, arrowW);
    p = M(a - half, arrowH) + L(a, 0) + L(a + half, arrowH) + H(w - r) + corner(w, arrowH, w, arrowH + r) + V(h - r) + corner(w, h, w - r, h) + H(r) + corner(0, h, 0, h - r) + V(arrowH + r) + corner(0, arrowH, r, arrowH) + H(a - half) + " Z";
  } else if (edge === "left") {
    a = _clampTip(arrowPos, h, r, arrowW);
    p = M(arrowH + r, 0) + H(w - r) + corner(w, 0, w, r) + V(h - r) + corner(w, h, w - r, h) + H(arrowH + r) + corner(arrowH, h, arrowH, h - r) + V(a + half) + L(0, a) + L(arrowH, a - half) + V(r) + corner(arrowH, 0, arrowH + r, 0) + " Z";
  } else {
    // "right"
    var bw = w - arrowH;
    a = _clampTip(arrowPos, h, r, arrowW);
    p = M(r, 0) + H(bw - r) + corner(bw, 0, bw, r) + V(a - half) + L(w, a) + L(bw, a + half) + V(h - r) + corner(bw, h, bw - r, h) + H(r) + corner(0, h, 0, h - r) + V(r) + corner(0, 0, r, 0) + " Z";
  }
  return p;
}
