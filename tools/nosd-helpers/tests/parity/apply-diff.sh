#!/usr/bin/env bash
# Differential parity: Scripts/bash/template-apply.sh vs `nosd-helpers apply`.
# Builds two identical HOME fixtures, runs every app branch on both sides,
# then diffs resulting trees, stdout, exit codes and stub-call logs.
# Known accepted divergence: bash's own top-level-`return` error line on
# stderr in the starship fall-through paths (locale-specific, filtered).
set -u
ROOT="$(cd "$(dirname "$(readlink -f "$0")")/../../../.." && pwd)"
RS="$ROOT/tools/nosd-helpers/target/debug/nosd-helpers"
SH="$ROOT/Scripts/bash/template-apply.sh"
T="$(mktemp -d)"
FB="$T/fakebin"
mkdir -p "$FB"

# ---- stubs: log argv, succeed ----
for b in kitty vicinae pywalfox hyprctl swaymsg scrollmsg mmsg labwc pkill; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "$CALL_LOG"\nexit 0\n' "$b" > "$FB/$b"
  chmod +x "$FB/$b"
done
cat > "$FB/pgrep" <<'EOF'
#!/usr/bin/env bash
echo "pgrep $*" >> "$CALL_LOG"
if [[ "$*" == *"-af"* ]]; then echo "123 cava -p /dev/null"; fi
exit 0
EOF
chmod +x "$FB/pgrep"
cat > "$FB/dbus-send" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"ListNames"* ]]; then
  echo 'string "org.pwmt.zathura.PID-4242"'
else
  echo "dbus-send $*" >> "$CALL_LOG"
fi
exit 0
EOF
chmod +x "$FB/dbus-send"

populate() { # $1 = HOME root, $2 = variant
  local H="$1" V="$2"
  mkdir -p "$H"
  case "$V" in
  replace)
    mkdir -p "$H/.config/ghostty" && printf 'font-size = 12\ntheme = catppuccin\n' > "$H/.config/ghostty/config"
    printf 'theme = noctalia\n' > "$H/.config/ghostty/config.ghostty"
    mkdir -p "$H/.config/foot" && printf '[main]\ninclude=other themes/x\nfont = mono\n' > "$H/.config/foot/foot.ini"
    mkdir -p "$H/.config/alacritty" && printf '[general]\nimport = ["a"]\n' > "$H/.config/alacritty/alacritty.toml"
    mkdir -p "$H/.config/wezterm" && printf 'local wezterm = require "wezterm"\nconfig.color_scheme = "Old"\nreturn config\n' > "$H/.config/wezterm/wezterm.lua"
    mkdir -p "$H/.config/fuzzel" && printf 'include=old themes/y\n[main]\n' > "$H/.config/fuzzel/fuzzel.ini"
    mkdir -p "$H/.config/walker" && printf 'theme = "old"\n' > "$H/.config/walker/config.toml"
    mkdir -p "$H/.config/kitty/themes" && : > "$H/.config/kitty/themes/noctalia.conf"
    printf 'font_size 12\n' > "$H/.config/kitty/kitty.conf"
    mkdir -p "$H/.config/cava" && printf '[general]\n[color]\ntheme = "old"\nforeground = "#fff"\n[other]\n' > "$H/.config/cava/config"
    mkdir -p "$H/.config/yazi" && printf '[flavor]\ndark = "old"\n[mgr]\n' > "$H/.config/yazi/theme.toml"
    mkdir -p "$H/.config/niri" && printf '// comment\n' > "$H/.config/niri/config.kdl"
    mkdir -p "$H/.config/hypr" && printf '# hypr\n' > "$H/.config/hypr/hyprland.conf"
    mkdir -p "$H/.config/sway" && printf 'set $x 1\n' > "$H/.config/sway/config"
    mkdir -p "$H/.config/scroll" && printf 'include other\n' > "$H/.config/scroll/config"
    mkdir -p "$H/.config/mango" && printf 'bordercolor = #111\nplain = 1\n' > "$H/.config/mango/00.conf"
    printf 'shadowscolor=#222\n' > "$H/.config/mango/01.conf"
    printf 'nothing here\n' > "$H/.config/mango/02.conf"
    mkdir -p "$H/.config/btop" && printf 'color_theme = "old"\nvim_keys = true\n' > "$H/.config/btop/btop.conf"
    mkdir -p "$H/.cache/noctalia" && printf 'fg = "#eee"\n' > "$H/.cache/noctalia/starship-palette.toml"
    mkdir -p "$H/.config" && printf 'palette = "old"\nformat = "x"\n' > "$H/.config/starship.toml"
    ;;
  create)
    : # everything missing -> create paths
    ;;
  special)
    mkdir -p "$H/.config/wezterm" && printf 'local c = {}\nreturn config\n' > "$H/.config/wezterm/wezterm.lua"
    mkdir -p "$H/.config/foot" && printf 'font = mono\n' > "$H/.config/foot/foot.ini"
    mkdir -p "$H/.config/alacritty" && printf '[window]\n' > "$H/.config/alacritty/alacritty.toml"
    mkdir -p "$H/.config/yazi" && printf 'x = 1\n' > "$H/.config/yazi/theme.toml"
    mkdir -p "$H/.config/cava" && printf '[general]\nframerate = 60\n' > "$H/.config/cava/config"
    mkdir -p "$H/.config/mango"
    printf 'rootcolor = #000\n' > "$H/.config/mango/a.conf"
    printf 'focuscolor #111\nplain\n' > "$H/.config/mango/b.conf"
    ln -s a.conf "$H/.config/mango/c.conf" && chmod a-w "$H/.config/mango/c.conf" 2>/dev/null || true
    mkdir -p "$H/.cache/noctalia" # palette missing on purpose
    mkdir -p "$H/.config" && printf '"$schema" = "x"\n' > "$H/.config/starship.toml"
    mkdir -p "$H/.config/niri" && printf 'include "./noctalia.kdl"\n' > "$H/.config/niri/config.kdl"
    mkdir -p "$H/.config/hypr" && printf 'dofile("/x/noctalia-colors.lua")\n' > "$H/.config/hypr/hyprland.lua"
    ;;
  esac
}

run_side() { # $1 = sh|rs, $2 = variant
  local side="$1" V="$2"
  local H="$T/home-$V-$side"
  export HOME="$H" CALL_LOG="$T/calls-$V-$side.log" STARSHIP_CONFIG=""
  : > "$CALL_LOG"
  local out="$T/out-$V-$side.txt" rc=0
  : > "$out"
  local apps=(kitty ghostty foot alacritty wezterm fuzzel walker vicinae cava yazi labwc niri hyprland sway scroll mango btop zathura starship)
  for a in "${apps[@]}"; do
    if [[ "$side" == sh ]]; then
      HOME="$H" PATH="$FB:$PATH" CALL_LOG="$CALL_LOG" bash "$SH" "$a" >>"$out" 2>>"$T/err-$V-$side.txt"; echo "$a rc=$?" >>"$out"
    else
      HOME="$H" PATH="$FB:$PATH" CALL_LOG="$CALL_LOG" "$RS" apply "$a" >>"$out" 2>>"$T/err-$V-$side.txt"; echo "$a rc=$?" >>"$out"
    fi
  done
  # pywalfox modes
  for m in dark bogus; do
    if [[ "$side" == sh ]]; then
      HOME="$H" PATH="$FB:$PATH" CALL_LOG="$CALL_LOG" bash "$SH" pywalfox "$m" >>"$out" 2>>"$T/err-$V-$side.txt"; echo "pywalfox/$m rc=$?" >>"$out"
    else
      HOME="$H" PATH="$FB:$PATH" CALL_LOG="$CALL_LOG" "$RS" apply pywalfox "$m" >>"$out" 2>>"$T/err-$V-$side.txt"; echo "pywalfox/$m rc=$?" >>"$out"
    fi
  done
  # error cases
  if [[ "$side" == sh ]]; then
    HOME="$H" bash "$SH" >>"$out" 2>>"$T/err-$V-$side.txt"; echo "nousage rc=$?" >>"$out"
    HOME="$H" bash "$SH" bogusapp >>"$out" 2>>"$T/err-$V-$side.txt"; echo "unknown rc=$?" >>"$out"
    HOME="$H" PATH="$FB:$PATH" bash "$SH" wezterm >>"$out" 2>>"$T/err-$V-create-$side.txt" || true
  else
    HOME="$H" "$RS" apply >>"$out" 2>>"$T/err-$V-$side.txt"; echo "nousage rc=$?" >>"$out"
    HOME="$H" "$RS" apply bogusapp >>"$out" 2>>"$T/err-$V-$side.txt"; echo "unknown rc=$?" >>"$out"
  fi
}

fail=0
for V in replace create special; do
  populate "$T/fixture-$V" "$V"
  for side in sh rs; do
    rm -rf "$T/home-$V-$side"
    cp -a "$T/fixture-$V" "$T/home-$V-$side"
    # drop the pre-existing noctalia ghostty file for rs? no - identical start
    run_side "$side" "$V"
  done
  # normalize sandbox HOME paths (hypr/mango embed absolute theme paths)
  for side in sh rs; do
    grep -rl "$T/home-$V-$side" "$T/home-$V-$side" 2>/dev/null | while read -r f; do
      sed -i "s|$T/home-$V-$side|@HOME@|g" "$f"
    done
  done
  if ! diff -r "$T/home-$V-sh" "$T/home-$V-rs" > "$T/tree-$V.diff"; then echo "TREE DIFF [$V]:"; head -n 20 "$T/tree-$V.diff"; fail=1; else echo "TREE IDENTICAL [$V]"; fi
  # normalize sandbox HOME + program name in stdout/stderr before comparing
  for side in sh rs; do
    sed -i "s|$T/home-$V-$side|@HOME@|g; s|Usage: .*template-apply.sh|Usage: PROG|; s|Usage: nosd-helpers apply|Usage: PROG|" "$T/out-$V-$side.txt" "$T/err-$V-$side.txt"
  done
  if ! diff "$T/out-$V-sh.txt" "$T/out-$V-rs.txt" > "$T/out-$V.diff"; then echo "STDOUT DIFF [$V]:"; head -n 20 "$T/out-$V.diff"; fail=1; else echo "STDOUT IDENTICAL [$V]"; fi
  # accepted divergences: bash's top-level-`return` error line, cat/tail
  # errors when the palette is missing (both continue with empty content)
  grep -v "return" "$T/err-$V-sh.txt" | grep -vE "^(cat|tail):" | grep -v "^$" > "$T/e1"; grep -v "^$" "$T/err-$V-rs.txt" > "$T/e2"
  # normalize HOME paths out before comparing stderr
  sed -i "s|$T/home-$V-sh|HOME|g" "$T/e1"; sed -i "s|$T/home-$V-rs|HOME|g" "$T/e2"
  if ! diff "$T/e1" "$T/e2" > "$T/err-$V.diff"; then echo "STDERR DIFF [$V]:"; head -n 20 "$T/err-$V.diff"; fail=1; else echo "STDERR IDENTICAL [$V] (modulo bash return-line)"; fi
  if ! diff "$T/calls-$V-sh.log" "$T/calls-$V-rs.log" > "$T/calls-$V.diff"; then echo "CALLS DIFF [$V]:"; head -n 20 "$T/calls-$V.diff"; fail=1; else echo "CALLS IDENTICAL [$V]"; fi
done
echo "T=$T"
exit $fail
