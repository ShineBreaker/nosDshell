#!/usr/bin/env python3
"""从 nosd monorepo 构建各组件的发布产物，并校验 tag 与包内版本一致。

组件独立发版（docs/adr/0001）：tag 形如 `<component>-v<version>`，一个提交
可携带多个 tag，每个 tag 只触发自己组件的流水线。把「每个组件怎么打包」
收敛在这一个脚本里，workflow 只负责判定 tag 前缀——新增组件只改
COMPONENTS 一处。

用法::

    python3 tools/release/build.py --component nosdshell --tag nosdshell-v1.7.7
    python3 tools/release/build.py --list

产物统一落在 `dist/<component>/`，workflow 直接 `gh release upload` 即可。
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import re
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DIST = REPO_ROOT / "dist"

# tag 前缀 → (包目录, 打包时排除的前缀)。前缀即组件名。
COMPONENTS: dict[str, dict] = {
    "nosdshell": {
        "dir": "packages/nosdshell",
        # Screenshots 是文档截图，guix 包的 reduce-output-size phase 同样删掉它。
        "exclude": ("Assets/Screenshots",),
    },
    "nosd-gtk-theme": {"dir": "packages/nosd-gtk-theme"},
    "nosd-kvantum-theme": {"dir": "packages/nosd-kvantum-theme"},
    "fcitx5-theme-nosd": {"dir": "packages/fcitx5-theme-nosd"},
}


def die(msg: str) -> None:
    raise SystemExit(f"✗ {msg}")


# ══════════════════════════════════════════════════════════════
# 版本读取：nosdshell 用 Commons/Version.qml，主题组件用 VERSION
# ══════════════════════════════════════════════════════════════


def read_version(pkg: str) -> str:
    d = REPO_ROOT / COMPONENTS[pkg]["dir"]
    if pkg == "nosdshell":
        m = re.search(
            r'baseVersion:\s*"([^"]+)"', (d / "Commons" / "Version.qml").read_text()
        )
        if m:
            return m.group(1)
        die("nosdshell: Commons/Version.qml 里没有 baseVersion")
    vfile = d / "VERSION"
    if vfile.exists():
        return vfile.read_text().strip()
    die(f"{pkg} 找不到版本声明（VERSION / Commons/Version.qml）")


def check_tag(tag: str, pkg: str) -> str:
    """tag 必须形如 `<pkg>-v<version>`，且 version 与包内一致。"""
    prefix = f"{pkg}-v"
    if not tag.startswith(prefix):
        die(f"tag {tag!r} 与组件 {pkg!r} 不符——本仓约定 tag 前缀即组件名（{prefix}*）")
    version = tag[len(prefix) :]
    actual = read_version(pkg)
    if version != actual:
        die(
            f"tag {tag} 指向提交的 {pkg} 版本是 {actual}，不一致。"
            f"核对 tag 是否打在改过版本的 release commit 上"
        )
    if pkg == "nosdshell":
        dev = re.search(
            r"isDevelopment:\s*(\w+)",
            (REPO_ROOT / "packages/nosdshell/Commons/Version.qml").read_text(),
        )
        if dev and dev.group(1) != "false":
            die(f"tag {tag} 打在了 isDevelopment={dev.group(1)} 的提交上——release commit 应置 false")
    return version


# ══════════════════════════════════════════════════════════════
# 发布说明：从组件 CHANGELOG 抽对应版本段落
# ══════════════════════════════════════════════════════════════


def release_notes(pkg: str, version: str) -> str:
    ch = REPO_ROOT / COMPONENTS[pkg]["dir"] / "CHANGELOG.md"
    if not ch.exists():
        return f"{pkg} {version}\n\n（本组件无 CHANGELOG——首次发布或尚未记录）"
    text = ch.read_text(encoding="utf-8")
    m = re.search(
        rf"^##\s*\[{re.escape(version)}\][^\n]*\n.*?(?=^##\s*\[|\Z)", text, re.M | re.S
    )
    if not m or not m.group(0).strip():
        die(
            f"{COMPONENTS[pkg]['dir']}/CHANGELOG.md 中找不到 ## [{version}] 段落"
            f"——发版流程要求先记日志（Keep a Changelog 格式）"
        )
    return m.group(0).strip() + "\n"


# ══════════════════════════════════════════════════════════════
# 产物构建：确定性 tar + SHA256SUMS
# ══════════════════════════════════════════════════════════════


def _clean_dist(pkg: str) -> Path:
    out = DIST / pkg
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    return out


def _write_checksums(out: Path, artifacts: list[Path]) -> None:
    """写 SHA256SUMS：固定 tag 的产物必须不变，校验和是把「拉到的就是
    发出来的那个」变成可验证事实的唯一手段——所以打包必须走
    `_add_to_tar` 规范化元数据。"""
    lines = [f"{hashlib.sha256(a.read_bytes()).hexdigest()}  {a.name}" for a in artifacts]
    (out / "SHA256SUMS").write_text("\n".join(lines) + "\n")


def _git(*args: str) -> str:
    return subprocess.run(
        ["git", *args], cwd=REPO_ROOT, check=True, capture_output=True, text=True
    ).stdout.strip()


def _deterministic_mtime(tag: str | None) -> int:
    """tar 条目与 gzip 头共用的时间戳：取 tag 指向提交的时间，同一 tag
    无论谁在何时构建都得到同一个值。"""
    rev = tag or "HEAD"
    if tag is not None and not tag.startswith("refs/"):
        rev = f"refs/tags/{tag}"
    try:
        return int(_git("log", "-1", "--format=%ct", rev))
    except (subprocess.CalledProcessError, ValueError):
        die(f"取不到 {rev} 的提交时间——发版构建必须在 git 仓库内针对真实 tag")


def _add_to_tar(tf: tarfile.TarFile, f: Path, arcname: str, mtime: int) -> None:
    """规范化元数据：uid/gid、属主名、pax 头、mtime 都随构建环境而变，
    一个都不能进产物。"""
    ti = tf.gettarinfo(str(f), arcname=arcname)
    ti.mtime = mtime
    ti.uid = ti.gid = 0
    ti.uname = ti.gname = ""
    if getattr(ti, "pax_headers", None):
        ti.pax_headers = {}
    with f.open("rb") as fh:
        tf.addfile(ti, fh)


def build_tarball(pkg: str, version: str, out: Path, mtime: int) -> list[Path]:
    """通用 tar.gz：只打 git 跟踪的内容，顶层目录 <pkg>-<version>/。"""
    conf = COMPONENTS[pkg]
    src_dir = conf["dir"]
    src = REPO_ROOT / src_dir
    if not src.is_dir():
        die(f"{src_dir} 不存在")
    tracked = _git("ls-files", src_dir).split()
    excludes = tuple(f"{src_dir}/{e}" for e in conf.get("exclude", ()))
    tracked = [t for t in tracked if not t.startswith(excludes)]
    if not tracked:
        die(f"{src_dir} 下没有 git 跟踪的文件")
    archive = out / f"{pkg}-{version}.tar.gz"
    top = f"{pkg}-{version}"
    # tar 与 gzip 两层都自己写：tarfile "w:gz" 会把当前时间塞进 gzip 头。
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w") as tf:
        for rel in tracked:
            f = REPO_ROOT / rel
            if f.is_dir():
                continue
            rel_inside = rel[len(src_dir) + 1 :]
            _add_to_tar(tf, f, arcname=f"{top}/{rel_inside}", mtime=mtime)
    with archive.open("wb") as fh:
        with gzip.GzipFile(filename="", fileobj=fh, mode="wb", mtime=0) as gz:
            gz.write(raw.getvalue())
    return [archive]


# ══════════════════════════════════════════════════════════════


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--component", choices=sorted(COMPONENTS))
    ap.add_argument("--tag", help="形如 <component>-v<version>；给定时校验与包内版本一致")
    ap.add_argument("--list", action="store_true", help="列出全部组件及其版本")
    ap.add_argument("--notes-only", action="store_true", help="只产出 release_notes.md")
    args = ap.parse_args()

    if args.list:
        for pkg in sorted(COMPONENTS):
            print(f"{pkg:20s} {read_version(pkg)}")
        return 0

    if not args.component:
        ap.error("需要 --component 或 --list")

    pkg = args.component
    version = read_version(pkg)
    if args.tag:
        version = check_tag(args.tag, pkg)

    out = _clean_dist(pkg)
    if args.notes_only:
        (out / "release_notes.md").write_text(release_notes(pkg, version), encoding="utf-8")
        print(f"✓ {pkg} {version} 发布说明已写出")
        return 0

    artifacts = build_tarball(pkg, version, out, _deterministic_mtime(args.tag))
    _write_checksums(out, artifacts)
    (out / "release_notes.md").write_text(release_notes(pkg, version), encoding="utf-8")
    print(f"✓ {pkg} {version} 产物：")
    for a in artifacts:
        print(f"    {a.relative_to(REPO_ROOT)}  ({a.stat().st_size} bytes)")
    print(f"    dist/{pkg}/SHA256SUMS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
