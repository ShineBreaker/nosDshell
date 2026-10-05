#!/usr/bin/env python3
"""nosDshell default wallpaper - DDE 15 style night sky.

Deep navy sky fading to a teal horizon glow, sparse stars, faint
aurora wisps. Original artwork generated procedurally; palette
follows the DDE 15 default wallpaper mood (references:
gxde-session-ui/dde-lock/theme/background/default_background.jpg).
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

W, H = 2560, 1440
rng = np.random.default_rng(20261005)

# --- sky gradient: navy -> deep blue -> teal horizon -----------------------
y = np.linspace(0.0, 1.0, H)[:, None]
x = np.linspace(0.0, 1.0, W)[None, :]

# stops: (pos, rgb)
sp = np.array([0.00, 0.45, 0.72, 0.88, 1.00])
srgb = np.array([(10, 21, 41), (16, 40, 74), (22, 60, 100),
                 (30, 95, 130), (52, 140, 165)], dtype=float)

sky = np.zeros((H, W, 3), dtype=float)
for c in range(3):
    col = np.interp(y[:, 0], sp, srgb[:, c])
    sky[:, :, c] = col[:, None]

# horizon glow: wide radial centered slightly right of middle, near bottom
gx, gy = 0.58, 1.10
r = np.sqrt((x - gx) ** 2 + ((y - gy) * 1.35) ** 2)
glow = np.clip(1.0 - r / 0.55, 0, 1) ** 2.4
for c, gc in enumerate((70, 185, 205)):
    sky[:, :, c] += glow * gc * 0.42

# --- aurora wisps: 3 sine bands, blurred ------------------------------------
aur = np.zeros((H, W, 3), dtype=float)
for i, (cx, amp, wlen, hue) in enumerate([
        (0.30, 60, 900, (80, 220, 190)),
        (0.36, 90, 1200, (100, 170, 235)),
        (0.24, 45, 700, (150, 130, 230)),
]):
    xs = np.arange(W)
    center = H * cx + amp * np.sin(2 * np.pi * xs / wlen + i * 1.7)
    band = np.exp(-((np.arange(H)[:, None] - center[None, :]) ** 2) / (2 * 42.0 ** 2))
    band *= (0.55 + 0.45 * np.sin(2 * np.pi * xs / (wlen * 0.63) + i * 3.1))[None, :]
    for c in range(3):
        aur[:, :, c] += band * hue[c] * 0.16

sky += aur
img = Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8))
img = img.filter(ImageFilter.GaussianBlur(2.2))

# --- stars ------------------------------------------------------------------
star_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(star_img)
n = 340
sx = rng.uniform(0, W, n)
sy = (rng.uniform(0, 1, n) ** 1.6) * H * 0.8           # denser toward top
sr = rng.uniform(0.4, 1.6, n)
sa = rng.uniform(90, 235, n)
for xi, yi, ri, ai in zip(sx, sy, sr, sa):
    d.ellipse([xi - ri, yi - ri, xi + ri, yi + ri],
              fill=(230, 240, 255, int(ai)))
# a few brighter stars with cross sparkle
for i in range(14):
    xi, yi, ri = rng.uniform(0, W), rng.uniform(0, H * 0.55), rng.uniform(1.4, 2.4)
    a = int(rng.uniform(180, 255))
    d.ellipse([xi - ri, yi - ri, xi + ri, yi + ri], fill=(255, 255, 255, a))
    d.line([xi - ri * 3.5, yi, xi + ri * 3.5, yi], fill=(255, 255, 255, a // 3), width=1)
    d.line([xi, yi - ri * 3.5, xi, yi + ri * 3.5], fill=(255, 255, 255, a // 3), width=1)
star_img = star_img.filter(ImageFilter.GaussianBlur(0.4))
img = Image.alpha_composite(img.convert("RGBA"), star_img).convert("RGB")

# --- gentle vignette --------------------------------------------------------
vx = np.linspace(-1, 1, W)[None, :]
vy = np.linspace(-1, 1, H)[:, None]
vig = 1.0 - 0.16 * np.clip(np.sqrt(vx ** 2 + vy ** 2) - 0.55, 0, 1) ** 1.5
arr = np.asarray(img).astype(float) * vig[:, :, None]
Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(
    "Assets/Wallpaper/nosdshell.png", optimize=True)
print("wrote Assets/Wallpaper/nosdshell.png")
