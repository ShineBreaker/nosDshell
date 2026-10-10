#!/usr/bin/env bash
# release.sh — cut a nosDshell release end to end (automates docs/RELEASE.md).
#
# Usage:
#   Scripts/dev/release.sh 1.1.2                 # scaffold or finish, then push
#   Scripts/dev/release.sh v1.1.2 --no-push      # everything local (commit+tag only)
#   Scripts/dev/release.sh 1.1.2 --skip-verify   # skip lint + settings-about shot
#
# Two-phase flow:
#   1. If [Unreleased] is empty the script scaffolds a changelog entry — a TODO
#      intro paragraph plus a commit-linked bullet list grouped by type — then
#      STOPS. Write the marketing intro, re-run the same command.
#   2. With a filled [Unreleased] it lands the entry as `## [X.Y.Z] - <date>`,
#      bumps the four version spots, lints, shoots the About page, commits
#      `chore(release):`, tags -a, pushes main+tag, then reopens development
#      (isDevelopment=true) with a second commit.
#
# The GitHub Release itself is published by .github/workflows/release.yml once
# the tag lands — this script never talks to the API.

set -euo pipefail
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO"

# ---------- args -------------------------------------------------------------
VER="" PUSH=1 VERIFY=1
for arg in "$@"; do
  case "$arg" in
    --no-push)     PUSH=0 ;;
    --skip-verify) VERIFY=0 ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    v[0-9]*|[0-9]*) VER="${arg#v}" ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done
[[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "usage: release.sh <X.Y.Z> [--no-push] [--skip-verify]" >&2; exit 2; }

PREV=$(grep -oP 'baseVersion:\s*"\K[^"]+' Commons/Version.qml)
[[ "$PREV" != "$VER" ]] || { echo "$VER is already the baseVersion" >&2; exit 1; }
if git rev-parse -q --verify "refs/tags/v$VER" >/dev/null; then
  echo "tag v$VER already exists" >&2; exit 1
fi
[[ "$(git branch --show-current)" == "main" ]] || echo "warning: not on main"

TODAY=$(date +%F)

# ---------- phase 1: scaffold an empty [Unreleased] --------------------------
set +e
python3 - "$VER" "$PREV" "$TODAY" <<'PYEOF'
import re, subprocess, sys
ver, prev, today = sys.argv[1:4]
src = open("CHANGELOG.md", encoding="utf-8").read()

if f"## [{ver}]" in src:
    print(f"CHANGELOG already has a [{ver}] entry — refusing to double-land it", file=sys.stderr)
    sys.exit(1)

m = re.search(r"^## \[Unreleased\]\n(.*?)(?=^## \[)", src, re.M | re.S)
body = m.group(1).strip()
if body:
    sys.exit(0)  # entry already written — proceed to phase 2

# Scaffold: intro TODO + commit links grouped by conventional type.
log = subprocess.run(
    ["git", "log", f"v{prev}..HEAD", "--pretty=format:%H|%s"],
    capture_output=True, text=True, check=True).stdout.strip().splitlines()
groups = {}
order = ["feat", "fix", "style", "refactor", "perf", "docs", "test", "ci", "chore"]
titles = {"feat": "新功能", "fix": "修复", "style": "观感", "refactor": "重构",
          "perf": "性能", "docs": "文档", "test": "验证", "ci": "CI", "chore": "工程", "other": "其他"}
for line in log:
    sha, subject = line.split("|", 1)
    if "reopen development" in subject:
        continue
    mm = re.match(r"(\w+)(?:\(.+?\))?!?:\s*(.*)", subject)
    typ, text = (mm.group(1), mm.group(2)) if mm else ("other", subject)
    groups.setdefault(typ if typ in order else "other", []).append(
        f"- {text}：[`{sha[:9]}`](https://github.com/ShineBreaker/nosDshell/commit/{sha})")

parts = ["", "TODO: 一段偏营销的简介，一两句话覆盖本次全部改动。", "", "---", ""]
for typ in order + ["other"]:
    if typ in groups:
        parts.append(f"### {titles[typ]}")
        parts.append("")
        parts += groups[typ]
        parts.append("")
new = src.replace("## [Unreleased]\n", "## [Unreleased]\n" + "\n".join(parts), 1)
open("CHANGELOG.md", "w", encoding="utf-8").write(new)
print(f"scaffolded [Unreleased] from v{prev}..HEAD ({len(log)} commits) —")
print("fill the intro paragraph in CHANGELOG.md, then re-run release.sh")
sys.exit(3)
PYEOF
RC=$?
set -e
if [ $RC -eq 3 ]; then exit 0; fi
[ $RC -eq 0 ] || exit $RC

# ---------- phase 2: land the entry ------------------------------------------
python3 - "$VER" "$PREV" "$TODAY" <<'PYEOF'
import re, sys
ver, prev, today = sys.argv[1:4]
src = open("CHANGELOG.md", encoding="utf-8").read()

# Retitle [Unreleased] -> [X.Y.Z] - date, keep an empty [Unreleased] on top.
src = src.replace("## [Unreleased]\n",
                  f"## [Unreleased]\n\n## [{ver}] - {today}\n", 1)

# Footer links: point Unreleased at the new tag, insert the new compare line.
unrel = re.search(r"^\[Unreleased\]: (\S+)/compare/v\S+\.\.\.HEAD$", src, re.M)
base = unrel.group(1)
src = src.replace(unrel.group(0), f"[Unreleased]: {base}/compare/v{ver}...HEAD")
src = src.replace(f"[Unreleased]: {base}/compare/v{ver}...HEAD\n",
                  f"[Unreleased]: {base}/compare/v{ver}...HEAD\n"
                  f"[{ver}]: {base}/compare/v{prev}...v{ver}\n", 1)
open("CHANGELOG.md", "w", encoding="utf-8").write(src)
PYEOF

# ---------- version bumps ----------------------------------------------------
sed -i "s/baseVersion: \"$PREV\"/baseVersion: \"$VER\"/; s/isDevelopment: true/isDevelopment: false/" Commons/Version.qml
sed -i "s/(version \"$PREV\")/(version \"$VER\")/" nosdshell.scm
sed -i "s/version = \"${PREV}_\" + (self.shortRev or \"dirty\");/version = \"${VER}_\" + (self.shortRev or \"dirty\");/" flake.nix
sed -i "s/version ? \"$PREV\",/version ? \"$VER\",/" nix/package.nix

# ---------- verify ------------------------------------------------------------
if [ $VERIFY -eq 1 ]; then
  Scripts/dev/lint.sh --changed
  Scripts/test/verify.sh "release-$VER" --scenes settings-about
fi

# ---------- commit + tag + push + reopen --------------------------------------
git add CHANGELOG.md Commons/Version.qml nosdshell.scm flake.nix nix/package.nix
git commit -m "chore(release): v$VER"
git tag -a "v$VER" -m "v$VER"
echo "tagged v$VER"

if [ $PUSH -eq 1 ]; then
  git push origin main
  git push origin "v$VER"
  echo "pushed main + v$VER — CI (.github/workflows/release.yml) publishes the release"
fi

sed -i "s/isDevelopment: false/isDevelopment: true/" Commons/Version.qml
git add Commons/Version.qml
git commit -m "chore(release): reopen development after v$VER"
[ $PUSH -eq 1 ] && git push origin main

cat <<EOF

done. reminders:
  - gh release view v$VER   (CI refresh: gh workflow run release.yml -f tag=v$VER)
  - jeans channel pin: bump %nosdshell-commit/%nosdshell-version, guix home reconfigure
EOF
