#!/usr/bin/env python3
"""Turn a verify.sh motion burst into a filmstrip, a curve plot and metrics.

Usage: motion-report.py <burst-dir> <slowdown> [--keep-frames]

<burst-dir> holds what verify.sh's burst_start/burst_stop wrote:
  fNNNN.png   region captures taken back to back with grim
  times       "<index> <ns>" per frame, plus one "trigger <ns>" line written
              right before the IPC call / input that starts the animation
<slowdown>    the factor the run stretched every duration by (1 /
              general.animationSpeed); reported times are divided by it so
              they read as real-speed milliseconds.

Outputs, next to the frames:
  filmstrip.png  up to 10 frames from the trigger to the settle point,
                 each labelled with its real-speed time
  curve.png      progress (1 - distance to the final frame / initial
                 distance) and the changed-area bounding box size relative
                 to the final one, against real-speed time
  metrics.json   settle_ms (first time progress stays >= 0.98), t50_ms,
                 bbox_overshoot (max bbox size / final - 1; > 0 means the
                 surface grew past its rest size, i.e. an overshoot curve),
                 monotonic (progress never drops by more than 0.05)

Progress is computed from pixels only, so it measures what the user sees,
including shadow and blur, without any probe inside the shell.
"""

import json
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageStat

SETTLE = 0.98


def load(burst):
    frames, trigger = [], None
    with open(os.path.join(burst, "times")) as fh:
        for line in fh:
            a, b = line.split()
            if a == "trigger":
                trigger = int(b)
            else:
                path = os.path.join(burst, "f%04d.png" % int(a))
                if os.path.exists(path):
                    frames.append((int(b), path))
    frames.sort()
    if trigger is None:
        trigger = frames[0][0]
    return frames, trigger


def distance(a, b):
    diff = ImageChops.difference(a, b).convert("L")
    return sum(ImageStat.Stat(diff).mean) / 255.0


def bbox_size(img, ref):
    box = ImageChops.difference(img, ref).convert("L").point(lambda v: 255 if v > 24 else 0).getbbox()
    if not box:
        return 0.0
    return float((box[2] - box[0]) * (box[3] - box[1]))


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    burst, slow = sys.argv[1], float(sys.argv[2])
    keep = "--keep-frames" in sys.argv
    frames, trigger = load(burst)
    if len(frames) < 3:
        print("motion-report: fewer than 3 frames in", burst)
        return 1
    imgs = [Image.open(p).convert("RGB") for _, p in frames]
    times = [(t - trigger) / 1e6 / slow for t, _ in frames]
    first, last = imgs[0], imgs[-1]
    d0 = distance(first, last) or 1e-9
    progress = [1.0 - distance(im, last) / d0 for im in imgs]
    final_box = bbox_size(last, first) or 1.0
    boxes = [bbox_size(im, first) / final_box for im in imgs]

    settle = None
    for i, (t, p) in enumerate(zip(times, progress)):
        if t >= 0 and all(q >= SETTLE for q in progress[i:]):
            settle = t
            break
    t50 = next((t for t, p in zip(times, progress) if t >= 0 and p >= 0.5), None)
    drops = [progress[i] - progress[i + 1] for i in range(len(progress) - 1)]
    after = [b for t, b in zip(times, boxes) if t >= 0]
    metrics = {
        "frames": len(imgs),
        "frame_interval_ms": round((times[-1] - times[0]) / max(1, len(times) - 1), 1),
        "settle_ms": None if settle is None else round(settle, 1),
        "t50_ms": None if t50 is None else round(t50, 1),
        "bbox_overshoot": round(max(after) - 1.0, 4) if after else 0.0,
        "monotonic": max(drops) <= 0.05 if drops else True,
    }

    # filmstrip: trigger .. settle (+ one frame of margin), 10 evenly spaced
    end = settle if settle is not None else times[-1]
    span = [i for i, t in enumerate(times) if -1e-6 <= t <= end * 1.15 + 1]
    if len(span) < 2:
        span = list(range(len(imgs)))
    pick = sorted({span[round(k * (len(span) - 1) / 9)] for k in range(10)})
    w, h = imgs[0].size
    scale = min(1.0, 360.0 / max(w, h))
    tw, th = max(1, int(w * scale)), max(1, int(h * scale))
    strip = Image.new("RGB", (tw * len(pick), th + 22), (24, 24, 24))
    draw = ImageDraw.Draw(strip)
    for k, i in enumerate(pick):
        strip.paste(imgs[i].resize((tw, th)), (k * tw, 22))
        draw.text((k * tw + 6, 5), "%d ms" % round(times[i]), fill=(235, 235, 235))
        draw.line([(k * tw, 0), (k * tw, th + 22)], fill=(70, 70, 70))
    strip.save(os.path.join(burst, "filmstrip.png"))

    # curve plot
    W, H, M = 640, 320, 40
    plot = Image.new("RGB", (W, H), (250, 250, 250))
    pd = ImageDraw.Draw(plot)
    tmax = max(times[-1], 1.0)
    ymin, ymax = min(-0.1, min(progress), min(boxes) - 0.05), max(1.2, max(boxes) + 0.05)

    def xy(t, v):
        return (M + (t - times[0]) / (tmax - times[0]) * (W - 2 * M),
                H - M - (v - ymin) / (ymax - ymin) * (H - 2 * M))

    for v in (0.0, 1.0):
        pd.line([xy(times[0], v), xy(tmax, v)], fill=(200, 200, 200))
    pd.line([xy(0, ymin), xy(0, ymax)], fill=(220, 120, 120))
    pd.line([xy(t, p) for t, p in zip(times, progress)], fill=(44, 167, 248), width=2)
    pd.line([xy(t, b) for t, b in zip(times, boxes)], fill=(217, 119, 87), width=2)
    pd.text((M, 8), "progress (blue)  bbox/final (orange)  t in real-speed ms; red = trigger", fill=(40, 40, 40))
    pd.text((M, H - M + 8), "%d ms" % round(times[0]), fill=(40, 40, 40))
    pd.text((W - M - 40, H - M + 8), "%d ms" % round(tmax), fill=(40, 40, 40))
    plot.save(os.path.join(burst, "curve.png"))

    with open(os.path.join(burst, "metrics.json"), "w") as fh:
        json.dump(metrics, fh, indent=2)
    print("motion %s: %s" % (os.path.basename(burst.rstrip("/")), json.dumps(metrics)))
    if not keep:
        for _, p in frames:
            os.remove(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
