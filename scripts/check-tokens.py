#!/usr/bin/env python3
"""tokens.toml 三方一致性检查（nosd-theme）

检查项：
1. GTK CSS 中 border-radius 字面值必须落在 tokens.toml [radius] 集合内。
2. GTK CSS 中非 defaults 块不得出现硬编码 hex 颜色（defaults 块由
   '@define-color' 行界定：检查仅对不在 '@define-color' 声明里的颜色值生效）。
3. Kvantum nosd.kvconfig 不得包含 [GeneralColors] 节（颜色继承 QPalette）。
4. nosDshell Commons/Style.qml 的 radius 家族与 tokens.toml 一致（若仓库存在）。

用法: scripts/check-tokens.py [nosd-theme 根目录]
退出码: 0 = 全部通过；1 = 存在漂移（打印每一项）。
"""
import re
import sys
import tomllib
from pathlib import Path

THEME_DIRS = ("deepin", "deepin-dark")
GTK_SUBDIRS = ("gtk-3.0", "gtk-4.0")


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    tokens = tomllib.loads((root / "tokens.toml").read_text())
    # [radius] 下除令牌外还有 [radius.exempt] 子表，只取整数项。
    allowed_radii = {v for v in tokens["radius"].values() if isinstance(v, int)}
    exempt = tokens["radius"].get("exempt", {})
    failures = []

    # 1. GTK border-radius 字面值
    radius_re = re.compile(r"border-radius\s*:\s*([^;]+);")
    hex_re = re.compile(r"(?<![\w-])#[0-9a-fA-F]{3,8}\b")
    for theme in THEME_DIRS:
        for sub in GTK_SUBDIRS:
            css_dir = root / theme / sub
            if not css_dir.is_dir():
                continue
            for css in css_dir.rglob("*.css"):
                in_defaults = False
                current_selector = ""
                for lineno, line in enumerate(css.read_text(errors="replace").splitlines(), 1):
                    stripped = line.strip()
                    # 选择器跟踪：块内 radius 行要靠它匹配 [radius.exempt] 白名单。
                    # 只取 "{" 前的选择器文本；多行选择器取最后一行即可。
                    if "{" in stripped:
                        head = stripped.split("{")[0].strip()
                        if head and not head.startswith("@"):
                            current_selector = head
                    # 2. 硬编码颜色：@define-color 行允许字面值（默认值声明），其余行不允许。
                    # 跳过 url(...) 内 / url 文件名 里的 hex 片段（如 titlebutton@2x.png）。
                    if "@define-color" in stripped:
                        continue
                    for m in hex_re.finditer(stripped):
                        span_line = stripped
                        if "url(" in span_line:
                            # 剔除所有 url(...) 参数后再判定
                            cleaned = re.sub(r"url\([^)]*\)", "", span_line)
                            if not hex_re.search(cleaned):
                                continue
                        failures.append(f"{css.relative_to(root)}:{lineno} 硬编码颜色 {m.group(0)}（须走 @define-color）")
                        break
                    for m in radius_re.finditer(stripped):
                        for tok in m.group(1).split():
                            tok = tok.rstrip(",")
                            if not tok or not tok[0].isdigit():
                                continue
                            try:
                                val = float(tok.rstrip("px"))
                            except ValueError:
                                continue
                            if val > 0 and val not in allowed_radii:
                                if any(key in current_selector and tok == rule["radius"] for key, rule in exempt.items()):
                                    continue
                                failures.append(f"{css.relative_to(root)}:{lineno} border-radius {tok} 不在令牌集合 {sorted(allowed_radii)}")
                                break

    # 3. kvconfig 不得声明 [GeneralColors]
    kvcfg = root / "kvantum" / "nosd" / "nosd.kvconfig"
    if kvcfg.exists() and "[GeneralColors]" in kvcfg.read_text():
        failures.append(f"{kvcfg.relative_to(root)} 含 [GeneralColors]（应省略以继承 QPalette）")

    # 4. nosDshell Style.qml 半径
    style_qml = root.parent / "nosDshell" / "Commons" / "Style.qml"
    if style_qml.exists():
        style = style_qml.read_text()
        mapping = {
            "radiusXS": "radiusRow",
            "radiusS": "radiusItem",
            "radiusM": "radiusPopup",
            "radiusL": "radiusWindow",
        }
        for prop, token in mapping.items():
            m = re.search(rf"property int {prop}: Math\.round\((\d+) \*", style)
            if m and int(m.group(1)) != tokens["radius"][token]:
                failures.append(f"Style.qml {prop}={m.group(1)} 与 {token}={tokens['radius'][token]} 不一致")

    if failures:
        print(f"check-tokens: {len(failures)} 处漂移")
        for f in failures:
            print(" -", f)
        return 1
    print("check-tokens: 全部一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
