'''Replace the U+EC33 glyph outline with the nosDshell mark.

Usage (from repo root):
  fontforge -lang=py -script Scripts/assets/patch-font-glyph.py \
    Assets/Fonts/tabler/nosdshell-tabler-icons.ttf \
    Assets/nosdshell-glyph.svg \
    Assets/Fonts/tabler/nosdshell-tabler-icons.ttf
'''
import fontforge, sys

src, svg, dst = sys.argv[1], sys.argv[2], sys.argv[3]
f = fontforge.open(src)
g = f[0xec33]
g.clear()
g.importOutlines(svg)
g.correctDirection()
g.round()
f.generate(dst)
print("patched glyph:", g.glyphname, "bbox:", g.boundingBox())
