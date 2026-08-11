# Desktop-wide Light/Dark Theme Switch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One command/keybind flips the entire desktop between Solarized Light and Dark — Waybar, kitty, wofi, rofi, wob, swaync — and signals Brave/Slack/Superhuman to follow.

**Architecture:** `theme.sh` becomes a single orchestrator: it sets the freedesktop appearance color-scheme via gsettings (`prefer-light`/`prefer-dark` — the portal-signal fix that drives GUI/web apps) and swaps a per-app symlink + reloads each daemon. The themed apps are moved from home-manager's read-only Nix-store deployment to the mutable checkout-symlink regime (like Waybar) so runtime symlink swaps work.

**Tech Stack:** Bash, NixOS + home-manager (as a NixOS module), Hyprland, gsettings/xdg-desktop-portal-gtk, GTK CSS, kitty/rofi/wob config formats.

## Global Constraints

- Palette: **Solarized**. Light = canonical inversion of the base tones, accents unchanged. Base-tone inversion (verbatim, matches existing `waybar/style-light.css`):
  `base03 #002b36→#fdf6e3` · `base02 #073642→#eee8d5` · `base01 #586e75→#93a1a1` · `base00 #657b83→#839496` · `base0 #839496→#657b83` · `base1 #93a1a1→#586e75` · `base2 #eee8d5→#073642` · `base3 #fdf6e3→#002b36`.
  Accents unchanged: `yellow #b58900` · `orange #cb4b16` · `red #dc322f` · `magenta #d33682` · `violet #6c71c4` · `blue #268bd2` · `cyan #2aa198` · `green #859900`.
- Default committed state of every swappable symlink = **dark**.
- Reload guards: every per-app action in `theme.sh` ends in `|| true` so a missing app never aborts the switch (matches the current script's tolerant style).
- Repo is checked out at `~/config`; the flake lives at `~/config/nixos`. Rebuild command: `sudo nixos-rebuild switch --flake ~/config/nixos#bloomware`.
- Runtime symlink flips make the working tree show non-default symlink targets (git-dirty during use). This is the pre-existing Waybar pattern; do not try to "fix" it.
- Branch: `feature/desktop-theme-switch` (already created).

---

### Task 1: kitty light/dark theme files + include

**Files:**
- Create: `kitty/theme-dark.conf`, `kitty/theme-light.conf`
- Create: `kitty/theme.conf` (symlink → `theme-dark.conf`)
- Modify: `kitty/kitty.conf` (replace inline color block, lines 7–30, with an `include`)

**Interfaces:**
- Produces: `kitty/theme.conf` symlink that `theme.sh` will repoint. kitty reloads via `pkill -USR1 kitty`.

- [ ] **Step 1: Create `kitty/theme-dark.conf`** (the current color block, verbatim)

```conf
# Solarized Dark
background            #002b36
foreground            #839496
selection_background   #073642
selection_foreground   #93a1a1
cursor                #93a1a1
cursor_text_color     #002b36

color0   #073642
color1   #dc322f
color2   #859900
color3   #b58900
color4   #268bd2
color5   #d33682
color6   #2aa198
color7   #eee8d5
color8   #002b36
color9   #cb4b16
color10  #586e75
color11  #657b83
color12  #839496
color13  #6c71c4
color14  #93a1a1
color15  #fdf6e3
```

- [ ] **Step 2: Create `kitty/theme-light.conf`**

Only the 6 bg/fg/selection/cursor lines change; `color0`–`color15` are **intentionally identical** to dark (canonical Solarized shares the 16-color palette between light and dark).

```conf
# Solarized Light
background            #fdf6e3
foreground            #657b83
selection_background   #eee8d5
selection_foreground   #586e75
cursor                #586e75
cursor_text_color     #fdf6e3

color0   #073642
color1   #dc322f
color2   #859900
color3   #b58900
color4   #268bd2
color5   #d33682
color6   #2aa198
color7   #eee8d5
color8   #002b36
color9   #cb4b16
color10  #586e75
color11  #657b83
color12  #839496
color13  #6c71c4
color14  #93a1a1
color15  #fdf6e3
```

- [ ] **Step 3: Create the default-dark symlink**

```bash
cd ~/config/kitty && ln -sfn theme-dark.conf theme.conf
```

- [ ] **Step 4: Replace the inline color block in `kitty/kitty.conf`**

Delete lines 7–30 (from `# Solarized Dark` through `color15  #fdf6e3`) and put in their place:

```conf
# Theme (swapped by ~/.config/waybar/scripts/theme.sh; symlink -> theme-{dark,light}.conf)
include theme.conf
```

Leave the rest of `kitty.conf` (font, maps, mouse_map, etc.) untouched.

- [ ] **Step 5: Verify structure**

Run:
```bash
cd ~/config/kitty && readlink theme.conf && grep -n 'include theme.conf' kitty.conf && ! grep -q '^color0' kitty.conf && echo OK
```
Expected: prints `theme-dark.conf`, the matching `include` line, then `OK` (no stray `color0` left in kitty.conf).

- [ ] **Step 6: Commit**

```bash
cd ~/config && git add kitty/ && git commit -m "feat(kitty): split Solarized theme into swappable dark/light includes"
```

---

### Task 2: wofi light/dark split

**Files:**
- Create: `wofi/style-dark.css` (current content), `wofi/style-light.css`
- Replace: `wofi/style.css` (real file → symlink to `style-dark.css`)

**Interfaces:**
- Produces: `wofi/style.css` symlink that `theme.sh` repoints. wofi reads it fresh on each launch (Hyprland `CTRL, SPACE` → `wofi --show drun --style ~/.config/wofi/style.css`); no reload needed.

- [ ] **Step 1: Move current style to the dark variant**

```bash
cd ~/config/wofi && git mv style.css style-dark.css
```

- [ ] **Step 2: Create `wofi/style-light.css`**

Copy `style-dark.css` and change ONLY the base-tone `@define-color` lines (accents unchanged). The header block becomes:

```css
/* ~/.config/wofi/style.css */
/* Solarized Light palette */
@define-color base03  #fdf6e3;
@define-color base02  #eee8d5;
@define-color base01  #93a1a1;
@define-color base00  #839496;
@define-color base0   #657b83;
@define-color base1   #586e75;

@define-color yellow  #b58900;
@define-color orange  #cb4b16;
@define-color red     #dc322f;
@define-color magenta #d33682;
@define-color violet  #6c71c4;
@define-color blue    #268bd2;
@define-color cyan    #2aa198;
@define-color green   #859900;
```

Everything below the palette block (from `* {` to EOF) is copied **verbatim** from `style-dark.css` — the rules reference the color names, so inverting the definitions flips the theme automatically.

- [ ] **Step 3: Create the default-dark symlink**

```bash
cd ~/config/wofi && ln -sfn style-dark.css style.css
```

- [ ] **Step 4: Verify**

Run:
```bash
cd ~/config/wofi && readlink style.css && grep -c '@define-color' style-light.css && grep -q '#fdf6e3' style-light.css && echo OK
```
Expected: `style-dark.css`, `14`, `OK`.

- [ ] **Step 5: Commit**

```bash
cd ~/config && git add wofi/ && git commit -m "feat(wofi): add Solarized Light variant + swappable style symlink"
```

---

### Task 3: rofi light theme + current symlink

**Files:**
- Create: `rofi/themes/solarized-light.rasi`
- Create: `rofi/themes/current.rasi` (symlink → `solarized-dark.rasi`)
- Modify: `rofi/config.rasi` (last line `@theme` → `current.rasi`)

**Interfaces:**
- Produces: `rofi/themes/current.rasi` symlink that `theme.sh` repoints. rofi reads it fresh on each launch; no reload needed.

- [ ] **Step 1: Create `rofi/themes/solarized-light.rasi`**

Copy `solarized-dark.rasi` and change ONLY the base-tone values in the `* { ... }` palette block (accents and all layout rules unchanged):

```rasi
/* Solarized Light for rofi (Wayland) */
* {
  /* Solarized palette */
  base03: #fdf6e3;
  base02: #eee8d5;
  base01: #93a1a1;
  base00: #839496;
  base0:  #657b83;
  base1:  #586e75;
  yellow: #b58900;
  orange: #cb4b16;
  red:    #dc322f;
  magenta:#d33682;
  violet: #6c71c4;
  blue:   #268bd2;
  cyan:   #2aa198;
  green:  #859900;

  background: @base03;
  background-alt: @base02;
  foreground: @base0;
  selected: @blue;
  selected-foreground: @base03;
  urgent: @red;
  border: @base02;

  font: "Inter 12";
}
```

Then append the **entire remainder** of `solarized-dark.rasi` verbatim (from `window {` to EOF).

- [ ] **Step 2: Create the default-dark symlink**

```bash
cd ~/config/rofi/themes && ln -sfn solarized-dark.rasi current.rasi
```

- [ ] **Step 3: Point `config.rasi` at the swappable theme**

Change the last line of `rofi/config.rasi` from:
```rasi
@theme "~/config/rofi/themes/solarized-dark.rasi"
```
to:
```rasi
@theme "~/config/rofi/themes/current.rasi"
```

- [ ] **Step 4: Verify**

Run:
```bash
cd ~/config/rofi && readlink themes/current.rasi && grep -n 'current.rasi' config.rasi && grep -q '#fdf6e3' themes/solarized-light.rasi && echo OK
```
Expected: `solarized-dark.rasi`, the `@theme` line, `OK`.

- [ ] **Step 5: Commit**

```bash
cd ~/config && git add rofi/ && git commit -m "feat(rofi): add Solarized Light theme + swappable current.rasi symlink"
```

---

### Task 4: wob light/dark split + shared launch script

**Files:**
- Create: `wob/wob-dark.ini` (current content), `wob/wob-light.ini`
- Replace: `wob/wob.ini` (real file → symlink to `wob-dark.ini`)
- Create: `scripts/start-wob.sh`
- Modify: `hypr/hyprland.conf:22` (inline pipeline → call the script)

**Interfaces:**
- Produces: `wob/wob.ini` symlink (repointed by `theme.sh`) and `scripts/start-wob.sh` (called by both Hyprland `exec-once` and `theme.sh` to restart the daemon). `start-wob.sh` recreates `/tmp/wobpipe` and relaunches `tail -f /tmp/wobpipe | wob`.

- [ ] **Step 1: Move current ini to the dark variant**

```bash
cd ~/config/wob && git mv wob.ini wob-dark.ini
```

- [ ] **Step 2: Create `wob/wob-light.ini`**

Identical to `wob-dark.ini` except the color block (base tones inverted, accents unchanged; wob uses `RRGGBB[AA]` with no `#`):

```ini
timeout = 1200
max = 100

anchor = top center
margin = 28

width = 420
height = 28
border_size = 2
border_offset = 0
bar_padding = 6

# Solarized Light
background_color = fdf6e3cc
border_color     = 93a1a1ff
bar_color        = 2aa198ff

# When value > max (rare, but nice to theme)
overflow_background_color = fdf6e3cc
overflow_border_color     = cb4b16ff
overflow_bar_color        = dc322fff
```

- [ ] **Step 3: Create the default-dark symlink**

```bash
cd ~/config/wob && ln -sfn wob-dark.ini wob.ini
```

- [ ] **Step 4: Create `scripts/start-wob.sh`**

```bash
#!/usr/bin/env bash
# Single source of truth for launching the wob OSD daemon.
# Called by Hyprland exec-once and by theme.sh (to restart after a palette swap).
set -euo pipefail

PIPE="${WOB_PIPE:-/tmp/wobpipe}"

pkill -x wob 2>/dev/null || true
rm -f "$PIPE"
mkfifo -m 600 "$PIPE"
tail -f "$PIPE" | wob &
```

Make it executable:
```bash
chmod +x ~/config/scripts/start-wob.sh
```

- [ ] **Step 5: Update Hyprland `exec-once` for wob**

In `hypr/hyprland.conf`, replace line 22:
```conf
exec-once = sh -lc 'rm -f /tmp/wobpipe; mkfifo -m 600 /tmp/wobpipe; tail -f /tmp/wobpipe | wob'
```
with:
```conf
exec-once = ~/.config/scripts/start-wob.sh
```

- [ ] **Step 6: Verify**

Run:
```bash
cd ~/config && readlink wob/wob.ini && test -x scripts/start-wob.sh && grep -n 'start-wob.sh' hypr/hyprland.conf && grep -q 'fdf6e3' wob/wob-light.ini && echo OK
```
Expected: `wob-dark.ini`, the `exec-once` line, `OK`.

- [ ] **Step 7: Commit**

```bash
cd ~/config && git add wob/ scripts/start-wob.sh hypr/hyprland.conf && git commit -m "feat(wob): swappable dark/light ini + shared start-wob.sh launcher"
```

---

### Task 5: swaync palette / layout split

**Files:**
- Create: `swaync/palette-dark.css`, `swaync/palette-light.css`
- Create: `swaync/palette.css` (symlink → `palette-dark.css`)
- Modify: `swaync/style.css`, `swaync/style.laptop.css`, `swaync/style.external.css` (replace the `@define-color` block with `@import "palette.css";`)

**Interfaces:**
- Produces: `swaync/palette.css` symlink (repointed by `theme.sh`). Reload via `swaync-client --reload-css`. Layout files (`style*.css`) now consume the palette by name; the laptop/external display axis stays independent.

- [ ] **Step 1: Create `swaync/palette-dark.css`** (the current shared `@define-color` block)

```css
/* Solarized Dark (GTK-safe) — swaync palette */
@define-color base03 #002b36;
@define-color base02 #073642;
@define-color base01 #586e75;
@define-color base1  #93a1a1;
@define-color base2  #eee8d5;

@define-color cyan   #2aa198;
@define-color blue   #268bd2;
@define-color red    #dc322f;
```

- [ ] **Step 2: Create `swaync/palette-light.css`** (base tones inverted; `base2` heading tone → dark; accents unchanged)

```css
/* Solarized Light (GTK-safe) — swaync palette */
@define-color base03 #fdf6e3;
@define-color base02 #eee8d5;
@define-color base01 #93a1a1;
@define-color base1  #586e75;
@define-color base2  #073642;

@define-color cyan   #2aa198;
@define-color blue   #268bd2;
@define-color red    #dc322f;
```

- [ ] **Step 3: Create the default-dark symlink**

```bash
cd ~/config/swaync && ln -sfn palette-dark.css palette.css
```

- [ ] **Step 4: Replace the palette block in each layout file**

In each of `swaync/style.css`, `swaync/style.laptop.css`, `swaync/style.external.css`: delete the leading `@define-color …` block (the palette lines at the top, through the last `@define-color` line) and replace it with a single line at the very top:

```css
@import "palette.css";
```

Leave every rule below (from `* {` onward) untouched.

- [ ] **Step 5: Verify**

Run:
```bash
cd ~/config/swaync && readlink palette.css && for f in style.css style.laptop.css style.external.css; do head -1 "$f"; grep -c '@define-color' "$f"; done
```
Expected: `palette-dark.css`, then for each file: `@import "palette.css";` and `0` (no `@define-color` left in the layout files).

- [ ] **Step 6: Commit**

```bash
cd ~/config && git add swaync/ && git commit -m "feat(swaync): extract swappable palette from layout via @import"
```

---

### Task 6: Deployment regime change (taylan.nix) + rebuild + mutable symlinks

> This task changes system deployment and requires a `sudo nixos-rebuild`. The operator may need to run the rebuild and provide the sudo password.

**Files:**
- Modify: `nixos/home/taylan.nix:52,58–62` (remove themed apps from `xdg.configFile`; update the note)

**Interfaces:**
- Produces: `~/.config/{kitty,wofi,rofi,wob,swaync}` as symlinks to `~/config/<app>` (mutable checkout), matching the existing Waybar arrangement. After this, `theme.sh`'s runtime swaps operate on live configs.

- [ ] **Step 1: Edit `nixos/home/taylan.nix`**

Remove the kitty single-file line (52):
```nix
xdg.configFile."kitty/kitty.conf".source = ../../kitty/kitty.conf;
```
Remove these four (58–62):
```nix
xdg.configFile."swaync".source = ../../swaync;
xdg.configFile."rofi".source = ../../rofi;
xdg.configFile."wofi".source = ../../wofi;
xdg.configFile."wob".source = ../../wob;
```
Keep `xdg.configFile."hypr"`, `"wlogout"`, `"mpv"`, `"nvim"`, `"scripts"`, `"starship/starship.toml"`, `"pnpm/config.yaml"`. Update the NOTE comment (around line 54) to read:

```nix
  # Desktop config. hypr/wlogout stay declarative. kitty/wofi/rofi/wob/swaync are
  # EXCLUDED here and symlinked from the checkout (like waybar) so theme.sh can swap
  # theme files at runtime:
  #   for a in kitty wofi rofi wob swaync; do ln -sfn ~/config/$a ~/.config/$a; done
```

- [ ] **Step 2: Rebuild**

```bash
sudo nixos-rebuild switch --flake ~/config/nixos#bloomware
```
Expected: completes without error. Home-manager will remove the old `~/.config/{kitty/kitty.conf,wofi,rofi,wob,swaync}` store symlinks (or back them up with `.hm-backup`).

- [ ] **Step 3: Create the mutable checkout symlinks**

```bash
rm -rf ~/.config/kitty
for a in kitty wofi rofi wob swaync; do rm -rf ~/.config/"$a"; ln -sfn ~/config/"$a" ~/.config/"$a"; done
```

- [ ] **Step 4: Verify the regime**

Run:
```bash
for a in kitty wofi rofi wob swaync; do printf '%-8s -> %s\n' "$a" "$(readlink ~/.config/$a)"; done
readlink ~/.config/kitty/theme.conf; readlink ~/.config/wob/wob.ini
```
Expected: each app resolves to `/home/taylan/config/<app>`; `theme.conf` → `theme-dark.conf`; `wob.ini` → `wob-dark.ini`.

- [ ] **Step 5: Sanity-check the live apps still work**

Run (launch each briefly / trigger an event):
```bash
~/.config/scripts/start-wob.sh; sleep 1; printf '50\n' > /tmp/wobpipe   # wob bar shows
swaync-client --reload-css && echo swaync-ok
kitty --version >/dev/null && echo kitty-conf-parses
```
Expected: wob bar appears, `swaync-ok`, `kitty-conf-parses`. (kitty picks up the new `include` on next launch.)

- [ ] **Step 6: Commit**

```bash
cd ~/config && git add nixos/home/taylan.nix && git commit -m "refactor(home): move themed apps to mutable checkout symlinks for theme switching"
```

---

### Task 7: Rewrite theme.sh as the orchestrator

**Files:**
- Modify: `waybar/scripts/theme.sh` (full rewrite; lives under the live Waybar checkout symlink, so edits are immediately live)

**Interfaces:**
- Consumes: all symlinks from Tasks 1–5 and the live regime from Task 6; `scripts/start-wob.sh`.
- Produces: `theme.sh --status|--toggle|--light|--dark`. `--status` emits the same Waybar JSON as before.

- [ ] **Step 1: Write the new `waybar/scripts/theme.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE_FILE="$HOME/.config/theme-mode"
CFG="$HOME/.config"
WAYBAR_DIR="$CFG/waybar"

get_mode() { [[ -f "$MODE_FILE" ]] && cat "$MODE_FILE" || echo "dark"; }

apply_mode() {
  local mode="$1"
  echo "$mode" > "$MODE_FILE"

  # --- Desktop appearance signal for GUI/web apps (Brave/Slack/Superhuman) ---
  # 'prefer-light' -> portal color-scheme 2 (true light); 'default' would be 0 (no pref).
  if [[ "$mode" == "dark" ]]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'  >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'    >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme true  >/dev/null 2>&1 || true
  else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'         >/dev/null 2>&1 || true
    gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme false >/dev/null 2>&1 || true
  fi

  # --- Per-app symlink swaps (suffix = mode) ---
  ln -sfn "style-$mode.css"      "$WAYBAR_DIR/style.css"          || true
  ln -sfn "theme-$mode.conf"     "$CFG/kitty/theme.conf"          || true
  ln -sfn "style-$mode.css"      "$CFG/wofi/style.css"            || true
  ln -sfn "solarized-$mode.rasi" "$CFG/rofi/themes/current.rasi"  || true
  ln -sfn "wob-$mode.ini"        "$CFG/wob/wob.ini"               || true
  ln -sfn "palette-$mode.css"    "$CFG/swaync/palette.css"        || true

  # --- Reloads (launcher apps read fresh on next launch; nothing to do) ---
  pkill -USR2 waybar 2>/dev/null || true          # waybar CSS reload
  pkill -USR1 kitty  2>/dev/null || true          # kitty live config reload
  swaync-client --reload-css 2>/dev/null || true  # swaync CSS reload
  "$CFG/scripts/start-wob.sh" 2>/dev/null || true # restart wob daemon w/ new ini
}

status_json() {
  local mode icon tip cls
  mode="$(get_mode)"
  if [[ "$mode" == "dark" ]]; then icon="󰖔"; tip="Theme: Dark (click to toggle)"; cls="dark"
  else icon="󰖨"; tip="Theme: Light (click to toggle)"; cls="light"; fi
  printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$icon" "$tip" "$cls"
}

toggle() { [[ "$(get_mode)" == "dark" ]] && apply_mode "light" || apply_mode "dark"; }

case "${1:-}" in
  --status) status_json ;;
  --toggle) toggle ;;
  --light)  apply_mode "light" ;;
  --dark)   apply_mode "dark" ;;
  *) echo "usage: $0 --status|--toggle|--light|--dark" >&2; exit 2 ;;
esac
```

- [ ] **Step 2: Verify `--dark` sets everything dark**

Run:
```bash
~/.config/waybar/scripts/theme.sh --dark
cat ~/.config/theme-mode
for l in waybar/style.css kitty/theme.conf wofi/style.css rofi/themes/current.rasi wob/wob.ini swaync/palette.css; do printf '%-28s -> %s\n' "$l" "$(readlink ~/.config/$l)"; done
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
```
Expected: mode `dark`; every symlink ends in `-dark.*`/`dark.rasi`; portal reports `uint32 1`.

- [ ] **Step 3: Verify `--light` sets everything light + the portal fix**

Run:
```bash
~/.config/waybar/scripts/theme.sh --light
cat ~/.config/theme-mode
for l in waybar/style.css kitty/theme.conf wofi/style.css rofi/themes/current.rasi wob/wob.ini swaync/palette.css; do printf '%-28s -> %s\n' "$l" "$(readlink ~/.config/$l)"; done
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
```
Expected: mode `light`; every symlink ends in `-light.*`/`light.rasi`; **portal reports `uint32 2`** (the core fix). Waybar visibly restyles; kitty windows recolor; a volume/brightness tap shows a light wob bar; a test notification (`notify-send hi`) is light.

- [ ] **Step 4: Verify `--toggle` and `--status` alternate**

Run:
```bash
~/.config/waybar/scripts/theme.sh --toggle; cat ~/.config/theme-mode
~/.config/waybar/scripts/theme.sh --status
~/.config/waybar/scripts/theme.sh --toggle; cat ~/.config/theme-mode
```
Expected: mode flips `dark`↔`light`; `--status` emits valid JSON matching the current mode.

- [ ] **Step 5: Reset to dark default and commit**

```bash
~/.config/waybar/scripts/theme.sh --dark
cd ~/config && git add waybar/scripts/theme.sh && git commit -m "feat(theme): orchestrate desktop-wide light/dark switch (portal + per-app)"
```

---

### Task 8: Hyprland keybind + end-to-end verification

**Files:**
- Modify: `hypr/hyprland.conf` (add a toggle keybind near the other binds)

**Interfaces:**
- Consumes: `theme.sh --toggle`. `$mod SHIFT, T` is free (verified: `$mod CTRL, T` is todoist; no `$mod SHIFT, T`).

- [ ] **Step 1: Add the keybind**

After `hypr/hyprland.conf:194` (`bind = $mod SHIFT, Q, ...`), add:
```conf
bind = $mod SHIFT, T, exec, ~/.config/waybar/scripts/theme.sh --toggle
```

- [ ] **Step 2: Reload Hyprland**

```bash
hyprctl reload
```
Expected: `ok`.

- [ ] **Step 3: End-to-end check**

Press `SUPER+SHIFT+T` (or run the toggle). Confirm in one flip: Waybar, kitty, a new wofi launch (`CTRL+SPACE`), a new rofi launch, a wob bar (volume key), and a test notification all switch together, and the portal value tracks (`1`↔`2`). Toggle back.

- [ ] **Step 4: Commit**

```bash
cd ~/config && git add hypr/hyprland.conf && git commit -m "feat(hypr): bind SUPER+SHIFT+T to toggle desktop theme"
```

---

## Post-implementation: one-time GUI app settings (operator, manual)

These are not code. After the above, set each app to follow the system once:
- **Brave** → Settings → Appearance → **Same as device**
- **Slack** → Preferences → Themes → **Sync with OS setting**
- **Superhuman** → Settings → Appearance → **System**

Then `theme.sh --light`/`--dark` drives them automatically via the portal signal.

## Self-Review notes

- **Spec coverage:** portal fix (Task 7), regime change (Task 6), kitty (1), wofi (2), rofi (3), wob + start-wob.sh (4), swaync palette split (4→5), theme.sh --light/--dark/--toggle (7), keybind (8), borders untouched (no task — intentional), GUI-app steps (post-impl section). All covered.
- **Placeholders:** none — every step has concrete content/commands.
- **Consistency:** symlink naming is uniform `<name>-<mode>.<ext>` and the `theme.sh` swaps in Task 7 match the exact filenames created in Tasks 1–5 (`style-{dark,light}.css`, `theme-{dark,light}.conf`, `solarized-{dark,light}.rasi`, `wob-{dark,light}.ini`, `palette-{dark,light}.css`).
