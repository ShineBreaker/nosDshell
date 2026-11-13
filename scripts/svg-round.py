#!/usr/bin/env python3
"""nosd.svg 九切片 frame 角部圆角化（Kvantum 部件图集）。

Kvantum 按 id 取切片：<family>-<state>-{left,right,top,bottom,
topleft,topright,bottomleft,bottomright}。部件可见角由角切片自身
几何决定，frame.expansion 不产生弧度；本脚本把角部「轴边-连接-轴边」
特征（直角拐点或缺口曲线）替换为 SVG 椭圆弧 A，半径按 id 前缀映射。

映射（id 前缀 -> 目标半径）:
  button-*         5px  （kvconfig PanelButtonCommand frame.element=button，
                         panelbuttoncommand 无独立 id，由 button-* 覆盖）
  menu-normal-*    6px
  tooltip-normal-* 6px
  itemview-*       4px
  menuitem-*       4px
  menubaritem-*    4px  （表外补充：与 menuitem 同为选中高亮，对齐处理）
  tab-normal/toggled-{topleft,topright}  10px（仅顶边两角）
  common-focused-* 4px  （焦点环，切片内角实体仅 2.5px -> 半径收敛）

跳过（报告列出原因）:
  lineedit-* / combo-*：frame 切片为 opacity:0 的 2px 占位矩形，可见轮廓
    由 interior + 底边高亮条构成，无可改的 frame 角几何。
  progress-* / slider-* / scrollbarslider-* / checkbox-* / radio-* /
  arrow-* / tarrow / flat-arrow / indicator / dial / resize-grip：
  指示器或 pill，按要求保留。
  dock-* / header-* / tabframe-* / tabBarFrame-* / menubar-normal-* /
  tbutton-* / focus-* / common-normal-* / menu-shadow-* / tooltip-shadow-* /
  tab-close-* / tab-tear / interior 元素：不在任务清单或非 frame。
  各 <use> 镜像：跟随源切片，无需改。

幂等：换入 A 命令的角特征不再满足候选条件，重跑零改动。
用法: svg-round.py [文件 ...]  缺省处理 nosd.svg 与 nosd.svg.tpl。
"""
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "kvantum" / "nosd"
DEFAULT_FILES = [ROOT / "nosd.svg", ROOT / "nosd.svg.tpl"]

EPS = 1e-4          # 端点重合判定
AXIS_EPS = 0.05     # 近轴平行吸附（数据里有 ±0.001 的刻意漂移）
MIN_R = 0.5         # 小于此不生成弧

CORNER_DIR = {"topleft": (-1, -1), "topright": (1, -1),
              "bottomleft": (-1, 1), "bottomright": (1, 1)}
TARGET = {"button": 5.0, "menu": 6.0, "tooltip": 6.0, "itemview": 4.0,
          "menuitem": 4.0, "menubaritem": 4.0, "tab": 10.0,
          "common-focused": 4.0}
# 命名陷阱：这些 id 前缀会被上面的宽松匹配误伤，显式排除
SKIP_PREFIX = ("tabframe", "tabBarFrame", "menu-shadow", "tooltip-shadow",
               "menuitem-tearoff", "menuitem-left", "menuitem-right",
               "button-default", "tab-close", "tab-tear")

NUM = r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?"
TOKEN_RE = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|" + NUM)


def classify(eid):
    """id -> (radius, (sx,sy))；非目标角切片返回 None。"""
    for p in SKIP_PREFIX:
        if eid.startswith(p):
            return None
    for key in sorted(TARGET, key=len, reverse=True):
        if eid == key or eid.startswith(key + "-"):
            rest = eid[len(key):].lstrip("-")
            for sl, d in CORNER_DIR.items():
                if rest == sl or rest.endswith("-" + sl):
                    if key == "tab" and d[1] != -1:
                        return None
                    return TARGET[key], d
            return None
    return None


class Seg:
    __slots__ = ("cmd", "start", "end", "params")

    def __init__(self, cmd, start, end, params=()):
        self.cmd, self.start, self.end, self.params = cmd, start, end, params

    def axis(self):
        """轴平行线段返回单位方向，否则 None（M/Z/曲线/斜线/近零长）。"""
        if self.cmd in ("M", "Z"):
            return None
        dx, dy = self.end[0] - self.start[0], self.end[1] - self.start[1]
        if abs(dx) < AXIS_EPS and abs(dy) < AXIS_EPS:
            return None
        if abs(dy) < AXIS_EPS:
            return (1.0 if dx > 0 else -1.0, 0.0)
        if abs(dx) < AXIS_EPS:
            return (0.0, 1.0 if dy > 0 else -1.0)
        return None


def parse_path(d):
    """d -> [subpath]，每 subpath 为 [M, seg..., Z]；坐标与参数绝对化。"""
    toks = TOKEN_RE.findall(d)
    subs, cur, i = [], [], 0
    pos, start = (0.0, 0.0), None
    NP = {"L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7}

    def val():
        nonlocal i
        v = float(toks[i]); i += 1; return v

    cmd = None
    while i < len(toks):
        if toks[i].isalpha():
            cmd = toks[i]; i += 1
        rel = cmd.islower(); c = cmd.upper()
        if c == "Z":
            cur.append(Seg("Z", pos, pos))
            if cur:
                subs.append(cur)
            cur, start, cmd = [], None, None
            continue
        if c == "M":
            x, y = val(), val()
            e = (pos[0] + x, pos[1] + y) if rel else (x, y)
            if cur:
                subs.append(cur)
            cur = [Seg("M", pos, e)]
            pos = start = e
            cmd = "l" if rel else "L"   # 隐式 lineto
            continue
        p = tuple(val() for _ in range(NP[c]))
        if rel:
            if c == "H":
                p = (p[0],)
                e = (pos[0] + p[0], pos[1])
            elif c == "V":
                e = (pos[0], pos[1] + p[0])
            elif c == "A":
                e = (pos[0] + p[5], pos[1] + p[6])
            else:
                e = (pos[0] + p[-2], pos[1] + p[-1])
            # 控制点也绝对化
            if c in ("C", "S", "Q", "L", "T"):
                p = tuple(v + (pos[0] if k % 2 == 0 else pos[1])
                          for k, v in enumerate(p))
            elif c == "A":
                p = p[:5] + (pos[0] + p[5], pos[1] + p[6])
            elif c == "H":
                p = (pos[0] + p[0],)
            elif c == "V":
                p = (pos[1] + p[0],)
        else:
            if c == "H":
                e = (p[0], pos[1])
            elif c == "V":
                e = (pos[0], p[0])
            elif c == "A":
                e = (p[5], p[6])
            else:
                e = (p[-2], p[-1])
        cur.append(Seg(c, pos, e, p))
        pos = e
    if cur:
        subs.append(cur)
    return subs


def fmt(v):
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def emit(seg, out, end=None):
    """把 seg 以绝对命令输出到 out；end 可截短终点。"""
    e = seg.end if end is None else end
    c = seg.cmd
    if not out and c != "M":  # 首命令必须是 M
        out.append(f"M {fmt(seg.start[0])},{fmt(seg.start[1])}")
    if c == "M":
        out.append(f"M {fmt(e[0])},{fmt(e[1])}")
    elif c == "Z":
        out.append("Z")
    elif c == "C":
        p = seg.params
        out.append(f"C {fmt(p[0])},{fmt(p[1])} {fmt(p[2])},{fmt(p[3])} "
                   f"{fmt(e[0])},{fmt(e[1])}")
    elif c == "S":
        p = seg.params
        out.append(f"S {fmt(p[0])},{fmt(p[1])} {fmt(e[0])},{fmt(e[1])}")
    elif c == "Q":
        p = seg.params
        out.append(f"Q {fmt(p[0])},{fmt(p[1])} {fmt(e[0])},{fmt(e[1])}")
    elif c == "T":
        out.append(f"T {fmt(e[0])},{fmt(e[1])}")
    elif c == "A":
        p = seg.params
        out.append(f"A {fmt(p[0])},{fmt(p[1])} {fmt(p[2])} {int(p[3])} "
                   f"{int(p[4])} {fmt(e[0])},{fmt(e[1])}")
    elif c == "H":
        out.append(f"H {fmt(e[0])}")
    elif c == "V":
        out.append(f"V {fmt(e[1])}")
    else:  # L 及其他
        out.append(f"L {fmt(e[0])},{fmt(e[1])}")


def lineparam(s, V):
    """seg 两端相对 V 沿 seg 方向的带符号距离区间。"""
    ux, uy = s.axis()
    da = ux * (s.start[0] - V[0]) + uy * (s.start[1] - V[1])
    db = ux * (s.end[0] - V[0]) + uy * (s.end[1] - V[1])
    return (ux, uy), min(da, db), max(da, db)


def find_feats(ring, radius, corner):
    """在闭合 seg 环上找与 corner 方向一致的角特征。

    特征 = 轴边 s1 -> (0..n 条 C/S/Q/T 链) -> 轴边 s2（一横一竖），
    且两条支撑边都伸向目标角内侧。候选须满足其一：
      a) 凸顶点且 V 位于路径在 corner 方向上的极值（外角）；
      b) 凹缺口（notch，内角 >180°），半径收敛到链端距离。
    返回 {i1: (i1,i2,T1,T2,sweep,r,capped)}。
    """
    sx, sy = corner
    n = len(ring)
    # 多边形朝向（鞋带面积符号）：y 向下，负 = CW
    area = 0.0
    pts = [s.end for s in ring]
    for a, b in zip(pts, pts[1:] + pts[:1]):
        area += a[0] * b[1] - b[0] * a[1]
    orient = 1 if area > 0 else -1
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    ex = min(xs) if sx < 0 else max(xs)
    ey = min(ys) if sy < 0 else max(ys)
    feats = {}
    for i1 in range(n):
        s1 = ring[i1]
        u1 = s1.axis()
        if u1 is None:
            continue
        j = i1 + 1
        steps = 0
        while steps < n:
            jj = j % n
            if jj == i1:
                break
            nx = ring[jj]
            if nx.cmd in ("C", "S", "Q", "T") and nx.axis() is None:
                j += 1; steps += 1; continue
            break
        i2 = j % n
        if i2 == i1:
            continue
        s2 = ring[i2]
        u2 = s2.axis()
        if u2 is None or u2 == u1 or u2 == (-u1[0], -u1[1]):
            continue
        # 必须一横一竖
        h = s1 if u1[1] == 0 else s2
        v = s1 if u1[0] == 0 else s2
        V = (v.start[0], h.start[1])
        hx0, hx1 = sorted((h.start[0], h.end[0]))
        vy0, vy1 = sorted((v.start[1], v.end[1]))
        # 两边都必须从 V 伸向角内侧（允许 AXIS_EPS 级的端点漂移越界）
        if sx < 0 and hx0 < V[0] - AXIS_EPS:
            continue
        if sx > 0 and hx1 > V[0] + AXIS_EPS:
            continue
        if sy < 0 and vy0 < V[1] - AXIS_EPS:
            continue
        if sy > 0 and vy1 > V[1] + AXIS_EPS:
            continue
        (u1x, u1y), lo1, hi1 = lineparam(s1, V)
        (u2x, u2y), lo2, hi2 = lineparam(s2, V)
        # 顶点转角的凹凸：内角>180° 为凹缺口（notch）
        turn = u1[0] * u2[1] - u1[1] * u2[0]
        concave = (turn * orient) > 0
        if not concave:
            # 凸角必须是目标方向上的极值点，否则是 tile 内部顶点
            if abs(V[0] - ex) > EPS or abs(V[1] - ey) > EPS:
                continue
        # 切点 T1 在 s1 上距 V 为 r（沿 -u1）；T2 在 s2 上（沿 +u2）。
        # 可行域：-r∈[lo1,hi1] 且 r∈[lo2,hi2]，即
        # r ∈ [max(-hi1, lo2), min(-lo1, hi2)]
        r_lo = max(-hi1, lo2)
        r_hi = min(-lo1, hi2)
        if concave:
            # 缺口切点只在链端一侧的安全范围，防弧咬进相邻结构
            if hi1 >= 0 and lo2 <= 0:
                continue
            r_hi = min(r_hi,
                       -hi1 if hi1 < 0 else r_hi,
                       lo2 if lo2 > 0 else r_hi)
        r = min(radius, r_hi)
        if r < max(MIN_R, r_lo - EPS):
            continue
        T1 = (V[0] - u1x * r, V[1] - u1y * r)
        T2 = (V[0] + u2x * r, V[1] + u2y * r)
        cx = V[0] - u1x * r + u2x * r
        cy = V[1] - u1y * r + u2y * r
        a1 = math.degrees(math.atan2(T1[1] - cy, T1[0] - cx))
        a2 = math.degrees(math.atan2(T2[1] - cy, T2[0] - cx))
        sweep = 1 if 0 < (a2 - a1) % 360 <= 180 else 0
        feats[i1] = (i1, i2, T1, T2, sweep, r, r < radius - EPS)
    return feats


def render_ring(ring, feats):
    """按 feats 替换生成新命令串（不含 M/Z，由调用者包）。"""
    n = len(ring)
    skip = set()
    for (i1, i2, *_f) in feats.values():
        k = i1 + 1
        while k % n != i2:
            skip.add(k % n); k += 1
    out, capped, changed = [], False, 0
    i = 0
    while i < n:
        if i in feats:
            i1, i2, T1, T2, sweep, r, cap = feats[i]
            s1, s2 = ring[i1], ring[i2]
            # 到达边：T1==s1.start 时整条被弧吃掉
            consumed = (abs(T1[0] - s1.start[0]) < EPS
                        and abs(T1[1] - s1.start[1]) < EPS)
            if not consumed:
                emit(s1, out, end=T1)
            if not out:
                out.append(f"M {fmt(T1[0])},{fmt(T1[1])}")
            out.append(f"A {fmt(r)},{fmt(r)} 0 0 {sweep} "
                       f"{fmt(T2[0])},{fmt(T2[1])}")
            # 离开边剩余部分
            if not (abs(T2[0] - s2.end[0]) < EPS
                    and abs(T2[1] - s2.end[1]) < EPS):
                out.append(f"L {fmt(s2.end[0])},{fmt(s2.end[1])}")
            capped |= cap; changed += 1
            i = i2 + 1
            continue
        if i in skip:
            i += 1; continue
        emit(ring[i], out)
        i += 1
    return out, changed, capped


def round_sub(sub, radius, corner):
    """sub = [M, seg..., Z]。返回 (d_fragment, changed, capped) 或 None。"""
    if len(sub) < 3 or sub[-1].cmd != "Z":
        return None
    body = sub[1:-1]
    start = sub[0].end
    ring = list(body)
    if body and (abs(body[-1].end[0] - start[0]) > EPS
                 or abs(body[-1].end[1] - start[1]) > EPS):
        ring.append(Seg("L", body[-1].end, start))
    n = len(ring)
    if n < 2:
        return None
    feats = find_feats(ring, radius, corner)
    if not feats:
        return None
    # 跨收尾的特征：旋转环，让该特征位于开头
    wrap = [f for f in feats.values() if f[1] < f[0]]
    if wrap:
        i1 = wrap[0][0]
        ring = ring[i1:] + ring[:i1]
        feats = find_feats(ring, radius, corner)
    out, changed, capped = render_ring(ring, feats)
    if not changed:
        return None
    out.append("Z")
    return " ".join(out), changed, capped


def round_d(d, radius, corner):
    subs = parse_path(d)
    if not subs:
        return d, 0, False
    parts, changed, capped = [], 0, False
    for sub in subs:
        r = round_sub(sub, radius, corner)
        if r:
            parts.append(r[0]); changed += r[1]; capped |= r[2]
        else:
            buf = []
            for s in sub:
                emit(s, buf)
            parts.append(" ".join(buf))
    if not changed:
        return d, 0, False
    return " ".join(parts), changed, capped


def process(text):
    """返回 (new_text, stats: {id: (处数, 半径是否被收敛)})。"""
    stats = {}
    lines = text.split("\n")
    id_re = re.compile(r'id="([^"]+)"')
    i = 0
    while i < len(lines):
        line = lines[i]
        m = id_re.search(line)
        tm = re.match(r"\s*<(\w+)", line)
        if not m or not tm:
            i += 1; continue
        eid, tag = m.group(1), tm.group(1)
        c = classify(eid)
        if c is None:
            i += 1; continue
        radius, corner = c
        if tag == "g":
            depth, j = 0, i
            while j < len(lines):
                depth += len(re.findall(r"<g\b", lines[j]))
                depth -= len(re.findall(r"</g>", lines[j]))
                if depth <= 0:
                    break
                j += 1
            block = lines[i:j + 1]
            cnt, cap = 0, False
            for k, bl in enumerate(block):
                dm = re.search(r'(?<![\w-])d="([^"]+)"', bl)
                if not dm:
                    continue
                nd, ch, cp = round_d(dm.group(1), radius, corner)
                if ch:
                    block[k] = bl.replace(dm.group(0), f'd="{nd}"', 1)
                    cnt += ch; cap |= cp
            if cnt:
                stats[eid] = (cnt, cap)
                lines[i:j + 1] = block
            i = j + 1; continue
        if tag == "path":
            dm = re.search(r'(?<![\w-])d="([^"]+)"', line)
            if dm:
                nd, cnt, cap = round_d(dm.group(1), radius, corner)
                if cnt:
                    lines[i] = line.replace(dm.group(0), f'd="{nd}"', 1)
                    stats[eid] = (cnt, cap)
        i += 1   # rect/use/其他元素不动
    return "\n".join(lines), stats


def main():
    files = [Path(p) for p in sys.argv[1:]] or DEFAULT_FILES
    total = 0
    for f in files:
        text = f.read_text()
        new, stats = process(text)
        n = sum(c for c, _ in stats.values())
        total += n
        if new != text:
            f.write_text(new)
        print(f"{f.name}: {len(stats)} 个 id 改动 / {n} 处角")
        for eid, (c, cap) in sorted(stats.items()):
            print(f"  {eid}: {c} 处" + (" [半径收敛]" if cap else ""))
    print(f"合计 {total} 处")
    return 0


if __name__ == "__main__":
    sys.exit(main())
