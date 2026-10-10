#!/usr/bin/env python3
"""Vendor the archived Noctalia v4 docs into docs/legacy/ for GitHub Pages.

Source: github.com/noctalia-dev/noctalia-docs @ ed33c13
        src/content/docs/noctalia-shell-legacy/**/*.mdx

The upstream docs are Astro/Starlight MDX. This script flattens the
Starlight-specific constructs to plain kramdown markdown that Jekyll
(default GitHub Pages engine, just-the-docs theme) can render:

  import ...                          -> dropped (image imports tracked)
  :::tip|note|caution|info|important|danger[title]  -> blockquote callout
  <Tabs><TabItem label="x">           -> #### x section headings
  <LinkCard title href description>   -> bullet link
  <ImageLightbox src={var} alt>       -> ![](assets/<file>) + copies asset
  <IpcCommand prefix cmd>             -> inline `prefix cmd`
  <FaqItem question>...</FaqItem>     -> <details markdown="1">
  <Aside type>...</Aside>             -> blockquote callout
  <CardGrid>, <Steps>                 -> unwrapped
  <SettingsReference />               -> nix code block generated from our
                                       own Assets/settings-default.json
                                       (the live descendant of v4's schema)
  /noctalia-shell-legacy/<slug>/      -> relative <slug>.md links
                                       (jekyll-relative-links maps .md -> URL)
  /noctalia/...                       -> https://docs.noctalia.dev/noctalia/...

Section landing pages that upstream renders as sidebar labels get a small
generated index.md (just-the-docs needs a real parent page per nav level).

Usage:
  Scripts/docs/vendor-legacy-docs.py /path/to/noctalia-docs-clone

Idempotent: docs/legacy/ is fully regenerated on every run.
"""

import json
import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "docs" / "legacy"
ASSET_OUT = OUT / "assets"

# Section labels -> nav titles. Directories without a source landing page get
# a generated index.md; directories whose landing file exists keep its title
# unless overridden (upstream reuses "Overview" for several landings, and
# just-the-docs `parent:` lookup requires unique titles).
TITLE_OVERRIDES = {
    "index": "Noctalia v4 Wiki",
    "getting-started/keybinds/keybinds": "Keybinds",
    "development/plugins/overview": "Plugins",
}
SECTION_TITLES = {
    "getting-started": "Getting Started",
    "configuration": "Configuration",
    "theming": "Theming",
    "development": "Development",
    "deprecated": "Deprecated",
    "getting-started/compositor-settings": "Compositor Settings",
    "getting-started/keybinds": "Keybinds",
    "theming/program-specific": "Program Specific",
    "development/plugins": "Plugins",
}
SECTION_ORDER = {
    "getting-started": 1,
    "configuration": 2,
    "theming": 3,
    "development": 4,
    "deprecated": 5,
}
# Slugs that become index.md of their directory (dir landing pages).
LANDING_SLUGS = {
    "index",
    "getting-started/compositor-settings/compositor-settings",
    "getting-started/keybinds/keybinds",
    "development/plugins/overview",
}

ADMON_TITLES = {
    "note": "Note",
    "tip": "Tip",
    "caution": "Warning",
    "info": "Info",
    "important": "Important",
    "danger": "Danger",
}


def parse_frontmatter(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return {}, text
    fm, title, desc, order = {}, None, None, None
    for line in m.group(1).splitlines():
        t = re.match(r"^title:\s*(.+)$", line)
        d = re.match(r"^description:\s*(.+)$", line)
        o = re.match(r"^\s+order:\s*(\d+)", line)
        if t:
            title = t.group(1).strip().strip('"').strip("'")
        if d:
            desc = d.group(1).strip().strip('"').strip("'")
        if o:
            order = int(o.group(1))
    return {"title": title, "description": desc, "order": order}, text[m.end():]


def json_to_nix(obj, indent=0):
    sp = "  " * indent
    if obj is None:
        return "null"
    if isinstance(obj, bool):
        return "true" if obj else "false"
    if isinstance(obj, (int, float)):
        return repr(obj)
    if isinstance(obj, str):
        return '"' + obj.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(obj, list):
        if not obj:
            return "[ ]"
        items = " ".join(json_to_nix(v, indent + 1) for v in obj)
        return f"[ {items} ]"
    if isinstance(obj, dict):
        if not obj:
            return "{ }"
        lines = ["{"]
        for k, v in obj.items():
            lines.append(f"{sp}  {k} = {json_to_nix(v, indent + 1)};")
        lines.append(f"{sp}}}")
        return "\n".join(lines)
    return "null"


def slug_to_relpath(slug):
    slug = slug.strip("/")
    if slug in LANDING_SLUGS:
        if slug == "index":
            return "index.md"
        return slug.rsplit("/", 1)[0] + "/index.md"
    return slug + ".md"


class Converter:
    def __init__(self, src_root):
        self.src_root = Path(src_root)
        self.assets = {}  # var name -> source path
        self.copied = set()

    def convert_file(self, path):
        rel = path.relative_to(self.src_root).with_suffix("").as_posix()
        out_rel = slug_to_relpath(rel)
        fm, body = parse_frontmatter(path.read_text())
        body = self.convert_body(body, path, out_rel)

        title = TITLE_OVERRIDES.get(rel, fm.get("title") or rel.rsplit("/", 1)[-1])
        parent_dir = out_rel.rsplit("/", 1)[0] if "/" in out_rel else ""
        if out_rel.endswith("/index.md"):
            # A directory landing page's nav parent is the dir ABOVE it.
            parent_dir = parent_dir.rsplit("/", 1)[0] if "/" in parent_dir else ""
        lines = ["---", f"title: {title}"]
        if parent_dir:
            lines.append(f"parent: {SECTION_TITLES[parent_dir]}")
        elif out_rel != "index.md":
            pass
        if fm.get("order") is not None:
            lines.append(f"nav_order: {fm['order']}")
        if rel in LANDING_SLUGS and rel != "index":
            lines.append("has_children: true")
        if fm.get("description"):
            lines.append(f"description: {fm['description']}")
        lines.append("---\n")
        lines.append("<!-- generated by Scripts/docs/vendor-legacy-docs.py; do not hand-edit -->\n")
        return out_rel, "\n".join(lines) + body

    def convert_body(self, text, src_path, out_rel):
        # 1. imports: track image vars, drop all import lines.
        def keep_image_import(m):
            var, p = m.group(1), m.group(2)
            if re.search(r"\.(png|jpe?g|svg|webp|gif)$", p):
                resolved = (src_path.parent / p).resolve()
                self.assets[var] = resolved
            return ""

        text = re.sub(r"^import\s+(\w+)\s+from\s+'([^']+)';?\s*$",
                      keep_image_import, text, flags=re.M)
        text = re.sub(r"^import\s+.*?;?\s*$", "", text, flags=re.M)

        # 2. :::admonition[title] / ::::admonition blocks -> blockquote.
        # Line scanner: admonitions may be indented (inside list items or
        # FaqItem details) and siblings may follow at the same indent.
        text = self.conv_admonitions(text)

        # 3. Tabs -> heading per item. TabItem content is indented in the
        # source; dedent it so closing code fences land at column 0.
        def tabitem(m):
            inner = m.group(2).strip("\n")
            indents = [len(l) - len(l.lstrip(" \t"))
                       for l in inner.splitlines() if l.strip()]
            cut = min(indents) if indents else 0
            inner = "\n".join(l[cut:] if l.strip() else ""
                            for l in inner.splitlines())
            return f"#### {m.group(1)}\n\n{inner}\n\n"

        text = re.sub(r'<TabItem label="([^"]*)">(.*?)</TabItem>',
                      tabitem, text, flags=re.S)
        text = re.sub(r"</?Tabs>\s*", "", text)

        # 4. FaqItem -> <details> (kramdown markdown attr keeps md inside live).
        text = re.sub(r'<FaqItem question="([^"]*)">\s*',
                      r'<details markdown="1">\n<summary><strong>\1</strong></summary>\n\n',
                      text)
        text = re.sub(r"</FaqItem>\s*", "</details>\n", text)

        # 5. LinkCard -> bullet link.
        def linkcard(m):
            attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
            href = self.rewrite_href(attrs.get("href", ""), out_rel)
            desc = f" — {attrs['description']}" if attrs.get("description") else ""
            return f"- **[{attrs.get('title','link')}]({href})**{desc}\n"

        text = re.sub(r"<LinkCard\s+([^>]*?)/?>", linkcard, text)
        text = re.sub(r"</?CardGrid[^>]*>\s*", "", text)
        text = re.sub(r"</?Steps[^>]*>\s*", "", text)

        # 6. ImageLightbox -> standard image; copy the asset.
        def lightbox(m):
            attrs = m.group(1)
            var = re.search(r"src=\{(\w+)\}", attrs)
            alt = re.search(r'alt="([^"]*)"', attrs)
            if var and var.group(1) in self.assets:
                src = self.assets[var.group(1)]
                name = src.name
                if name not in self.copied:
                    ASSET_OUT.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, ASSET_OUT / name)
                    self.copied.add(name)
                base = out_rel.rsplit("/", 1)[0] if "/" in out_rel else ""
                path = (os.path.relpath(f"assets/{name}", base)
                        if base else f"assets/{name}")
                return f"![{alt.group(1) if alt else ''}]({path})\n"
            return m.group(0)

        text = re.sub(r"<ImageLightbox\s+([^>]*?)/>", lightbox, text)

        # 7. IpcCommand -> inline code. Attr values may contain '<'/'>'.
        def ipc(m):
            attrs = dict(re.findall(r'(\w+)="([^"]*)"', m.group(1)))
            cmd = f"{attrs.get('prefix','')} {attrs.get('command','')}".strip()
            return f"`{cmd}`"

        text = re.sub(r"<IpcCommand\s+((?:[^>\"']|\"[^\"]*\"|'[^']*')+?)/>",
                      ipc, text)

        # 8. Aside -> blockquote.
        def aside(m):
            inner = m.group(2).rstrip("\n")
            inner = "\n".join("> " + l if l else ">" for l in inner.splitlines())
            label = ADMON_TITLES.get(m.group(1), m.group(1).title())
            return f"> **{label}**\n{inner}\n"

        text = re.sub(r'<Aside type="(\w+)"[^>]*>\s*(.*?)\s*</Aside>',
                      aside, text, flags=re.S)

        # 9. SettingsReference -> nix code block from our live schema.
        def settings_ref(_m):
            data = json.loads((REPO / "Assets" / "settings-default.json").read_text())
            nix = json_to_nix(data)
            return ("The complete settings reference, generated from "
                    "nosDshell's `Assets/settings-default.json` (the live "
                    "descendant of Noctalia v4's schema):\n\n"
                    f"```nix\n{nix}\n```\n")

        text = re.sub(r"<SettingsReference\s*/>", settings_ref, text)

        # 10. Internal links -> relative .md (jekyll-relative-links resolves).
        text = re.sub(r"\]\(/noctalia-shell-legacy/([^)\s]*)",
                      lambda m: f"]({self.rel_link(m.group(1), out_rel)}", text)
        text = re.sub(r"\]\(/noctalia/([^)\s]*)",
                      r"](https://docs.noctalia.dev/noctalia/\1", text)
        return text

    def conv_admonitions(self, text):
        """Convert :::kind[title] / ::::kind blocks to blockquote callouts.

        Scans line-wise so indented admonitions (inside lists / details) are
        found; inner content is dedented and converted recursively, so sibling
        or nested admonitions both work.
        """
        out, lines, i = [], text.split("\n"), 0
        open_re = re.compile(r"^(\s*):{3,}(\w+)(?:\[([^\]]*)\])?\s*$")
        close_re = re.compile(r"^\s*:{3,}\s*$")
        while i < len(lines):
            m = open_re.match(lines[i])
            if not m:
                out.append(lines[i])
                i += 1
                continue
            inner, i = [], i + 1
            while i < len(lines) and not close_re.match(lines[i]):
                inner.append(lines[i])
                i += 1
            i += 1  # skip the closing :::/:::: line
            indents = [len(l) - len(l.lstrip(" \t"))
                       for l in inner if l.strip()]
            cut = min(indents) if indents else 0
            body = "\n".join(l[cut:] if l.strip() else "" for l in inner)
            body = self.conv_admonitions(body)
            label = m.group(3) or ADMON_TITLES.get(m.group(2), m.group(2).title())
            out.append(f"> **{label}**")
            out.extend("> " + l if l.strip() else ">" for l in body.split("\n"))
            out.append("")
        return "\n".join(out)

    def rel_link(self, slug_anchor, out_rel):
        slug, _, anchor = slug_anchor.partition("#")
        slug = slug.rstrip("/")
        target = slug_to_relpath(slug or "index")
        base = out_rel.rsplit("/", 1)[0] if "/" in out_rel else ""
        rel = os.path.relpath(target, base) if base else target
        return rel + ("#" + anchor if anchor else "")

    def rewrite_href(self, href, out_rel):
        m = re.match(r"/noctalia-shell-legacy/(.+)$", href)
        if m:
            return self.rel_link(m.group(1), out_rel)
        if href.startswith("/"):
            return "https://docs.noctalia.dev" + href
        return href


def section_index_body(title, children):
    items = "\n".join(f"- **[{t}]({p})**" for p, t in children)
    return (
        f"Upstream section landing page, generated for navigation.\n\n"
        f"## {title}\n\n{items}\n")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]) / "src/content/docs/noctalia-shell-legacy"
    if not src.is_dir():
        sys.exit(f"legacy docs not found under {src}")

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    conv = Converter(src)
    pages = {}  # out_rel -> title
    order_of = {}  # out_rel -> sidebar order

    for mdx in sorted(src.rglob("*.mdx")):
        out_rel, content = conv.convert_file(mdx)
        dest = OUT / out_rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(content)
        rel = mdx.relative_to(src).with_suffix("").as_posix()
        title = TITLE_OVERRIDES.get(rel) or re.search(r"^title: (.+)$", content, re.M).group(1)
        pages[out_rel] = title
        o = re.search(r"^nav_order: (\d+)$", content, re.M)
        order_of[out_rel] = int(o.group(1)) if o else 99

    # Pre-register generated section index pages so their PARENT section's
    # child list includes them (upstream sidebar labels have no source file).
    for d, title in SECTION_TITLES.items():
        if not (OUT / d / "index.md").exists():
            pages[d + "/index.md"] = title
            order_of.setdefault(d + "/index.md", 50)

    def children_of(d):
        """Immediate children of section dir d: direct pages + subdir landings."""
        kids = []
        for out_rel, title in pages.items():
            if not out_rel.startswith(d + "/") or out_rel == d + "/index.md":
                continue
            rest = out_rel[len(d) + 1:]
            if "/" not in rest or rest.endswith("/index.md"):
                kids.append((rest, title, order_of.get(out_rel, 99)))
        kids.sort(key=lambda k: (k[2], k[1]))
        return [(r, t) for r, t, _ in kids]

    # Generated section index pages (upstream sidebar labels have no page).
    notice = (
        "> **Archived mirror.** These pages are a vendored copy of the "
        "[Noctalia v4 documentation](https://docs.noctalia.dev/noctalia-shell-legacy/) "
        "(noctalia-dev/noctalia-docs @ `ed33c13`), flattened from Starlight "
        "MDX to plain markdown by `Scripts/docs/vendor-legacy-docs.py`. "
        "Noctalia v4 is unmaintained upstream; nosDshell inherits its v4 "
        "feature set on a DDE 15 presentation layer. Where nosDshell and "
        "upstream differ, this mirror may not apply.\n\n")

    for d, title in SECTION_TITLES.items():
        idx = OUT / d / "index.md"
        if idx.exists():  # landing file already provides the page
            continue
        kids = children_of(d)
        depth = d.count("/")
        parent = ("Noctalia v4 Wiki" if depth == 0
                  else SECTION_TITLES[d.rsplit("/", 1)[0]])
        fm = (f"---\ntitle: {title}\nparent: {parent}\n"
              f"nav_order: {SECTION_ORDER.get(d, 99)}\nhas_children: true\n---\n\n")
        idx.write_text(fm + notice + section_index_body(title, kids))

    # Root index gets the same notice prepended.
    root = OUT / "index.md"
    root.write_text(root.read_text().replace(
        "---\n\n", f"---\n\n{notice}", 1))

    # Root index needs has_children for the nav tree.
    head, sep, tail = root.read_text().partition("---\n\n")
    root.write_text(head.replace("---\n", "---\nhas_children: true\nnav_order: 2\n", 1) + sep + tail)

    print(f"vendored {len(pages)} pages + generated section indexes -> {OUT}")
    print(f"copied {len(conv.copied)} image assets -> {ASSET_OUT}")


if __name__ == "__main__":
    main()
