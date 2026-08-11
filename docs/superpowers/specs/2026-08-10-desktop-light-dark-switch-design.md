# Desktop-wide Light/Dark Theme Switch — Design

**Date:** 2026-08-10
**Repo:** bloomware NixOS dotfiles (`~/config`)
**Status:** Approved design, ready for implementation planning

## Problem

The Waybar theme toggle (`waybar/scripts/theme.sh`) only re-themes Waybar itself.
When the user switches to "light mode," every other app stays dark:

- **GUI/web apps** (Brave, Slack, Superhuman) never receive a "go light" signal.
- **Terminal + launchers + OSD + notifications** (kitty, wofi, rofi, wob, swaync)
  are hardcoded to the Solarized Dark palette.

The desktop is effectively a **Solarized** theme (Waybar already ships a Solarized
*Light* variant); only Waybar honors it.

## Root cause (GUI/web apps)

`theme.sh`'s "light" branch sets `gsettings ... color-scheme 'default'`. Verified
mapping through the running `xdg-desktop-portal-gtk` backend:

| gsettings value | `org.freedesktop.appearance color-scheme` | meaning |
|---|---|---|
| `prefer-light` | `2` | true light |
| `prefer-dark` | `1` | dark |
| `default` (current "light") | `0` | **no preference** |

So "light mode" tells apps *"no preference,"* and Brave/Slack/Superhuman fall back
to their own default (dark). The fix is to emit `prefer-light` for light mode.

## Deployment constraint (the pivotal finding)

Configs are deployed via **two regimes**:

- **Waybar** → `~/.config/waybar` is a symlink to the live git checkout
  (`~/config/waybar`) → **mutable**. This is the only reason `theme.sh`'s runtime
  `ln -sf` works, and why Waybar is deliberately excluded from home-manager
  (`nixos/home/taylan.nix:55`).
- **kitty, wofi, rofi, wob, swaync** → symlinked into the **read-only Nix store**
  (`root`-owned). Runtime symlink-swap / `cp` **cannot** work on these as deployed.
  (This also means `scripts/switch-swaync-config.sh`, which `cp`s over
  `~/.config/swaync/style.css`, is already silently broken under Nix.)

**Decision:** extend the Waybar pattern — make the themed apps mutable by symlinking
`~/.config/<app>` → `~/config/<app>` and dropping them from home-manager
`xdg.configFile`. Established precedent in this repo; requires one rebuild to apply,
then no rebuilds for toggling. Un-breaks the swaync display switcher as a side effect.

## Design

### Component 1 — Deployment regime change (one-time, needs rebuild)

In `nixos/home/taylan.nix`, remove these from `xdg.configFile`:
`kitty/kitty.conf`, `wofi`, `rofi`, `wob`, `swaync`. (`hypr`, `wlogout`, `mpv`,
`nvim`, `starship`, `scripts`, `pnpm` stay in home-manager — they are not
theme-switched.) Then manually symlink each to the checkout, mirroring Waybar:

```
ln -sfn ~/config/kitty  ~/.config/kitty
ln -sfn ~/config/wofi   ~/.config/wofi
ln -sfn ~/config/rofi   ~/.config/rofi
ln -sfn ~/config/wob    ~/.config/wob
ln -sfn ~/config/swaync ~/.config/swaync
```

Apply with `home-manager switch` (via the flake). Document the manual symlink step
next to the existing Waybar note in `taylan.nix`.

### Component 2 — `theme.sh` as the single orchestrator

Rewrite `waybar/scripts/theme.sh`:

- Subcommands: `--status`, `--toggle`, **`--light`**, **`--dark`** (new explicit
  setters so a keybind/command lands in a known state).
- Mode persisted in `~/.config/theme-mode` (unchanged).
- **Portal fix:** light → `gsettings set ... color-scheme 'prefer-light'`;
  dark → `'prefer-dark'`. Keep the GTK theme hints (`Adwaita`/`Adwaita-dark`).
- Apply per-app changes (below), each guarded so a missing app/daemon never aborts
  the switch (`|| true`), matching the current script's tolerant style.

Per-app switch + reload:

| App | Files | Switch action | Reload |
|-----|-------|---------------|--------|
| Waybar | `style.css` → `style-{dark,light}.css` (exists) | swap symlink | `pkill -USR2 waybar` |
| kitty | move current color block out of `kitty.conf` into `theme-dark.conf`; add full Solarized Light `theme-light.conf`; `kitty.conf` gains `include theme.conf` | swap `theme.conf` symlink | `pkill -USR1 kitty` (live config reload) |
| wofi | split `style.css` → `style-{dark,light}.css` | swap `style.css` symlink | none (reads on launch) |
| rofi | add `themes/solarized-light.rasi`; `config.rasi` → `@theme ".../themes/current.rasi"` | swap `current.rasi` symlink | none (reads on launch) |
| wob | split `wob.ini` → `wob-{dark,light}.ini` | swap `wob.ini` symlink | restart daemon via `scripts/start-wob.sh` |
| swaync | extract palette → `palette-{dark,light}.css`; layout files `@import "palette.css"` | swap `palette.css` symlink | `swaync-client --reload-css` |

Palette source of truth: **Solarized Dark** = existing values; **Solarized Light** =
the values already in `waybar/style-light.css`
(`base03 #fdf6e3; base02 #eee8d5; base01 #93a1a1; base0 #657b83; base1 #586e75;`
accents `yellow #b58900; red #dc322f; blue #268bd2; cyan #2aa198`). kitty is the
exception: it needs a **full 16-color ANSI** Solarized Light mapping (color0–color15
plus foreground/background/cursor), not just the shared base colors — use the
standard Solarized Light terminal palette.

### Component 3 — wob launch refactor

Extract the wob launch pipeline currently inline in `hypr/hyprland.conf:22`
into `scripts/start-wob.sh`:

```sh
#!/usr/bin/env bash
# Recreate the FIFO and (re)start the wob daemon reading from it.
pkill -x wob 2>/dev/null || true
rm -f /tmp/wobpipe
mkfifo -m 600 /tmp/wobpipe
tail -f /tmp/wobpipe | wob &
```

`hyprland.conf` `exec-once` calls `~/.config/scripts/start-wob.sh`; `theme.sh` calls
the same script to restart wob after swapping `wob.ini`. Single source of launch
truth. (`osd-volume.sh` / `osd-brightness.sh` writing to `/tmp/wobpipe` are
unaffected.)

### Component 4 — swaync palette / layout split

All three layout files (`style.css`, `style.laptop.css`, `style.external.css`) use
the identical `@define-color` set (`base01 base02 base03 base1 base2 blue cyan red`
— verified). Extract that block into `palette-dark.css` / `palette-light.css`;
replace it in each layout file with `@import "palette.css";`. `palette.css` is the
swapped symlink. The laptop/external display axis (`switch-swaync-config.sh`) and the
dark/light theme axis are then orthogonal and independent.

### Component 5 — Keybind (optional, in scope)

Add a Hyprland binding for `theme.sh --toggle` (e.g. `SUPER SHIFT, T`), pending a
free keybind check in `hyprland.conf`.

## Out of scope

- **Hyprland window borders** — keep Catppuccin Mocha accents
  (`col.active_border = $mauve $flamingo`); they read fine on light and dark.
- **Per-app "follow system" GUI settings** — one-time manual steps the user performs;
  the implementation provides exact click-paths in docs/handoff, not code:
  - Brave → Settings → Appearance → **Same as device**
  - Slack → Preferences → Themes → **Sync with OS setting**
  - Superhuman → appearance settings → **System**
- Re-architecting the swaync display-switcher beyond what the mutable regime fixes for
  free.

## Testing / verification

1. **Portal:** after `theme.sh --light`, assert
   `gdbus call ... Settings.Read org.freedesktop.appearance color-scheme` → `uint32 2`;
   after `--dark` → `1`.
2. **Symlinks:** each app's swapped symlink points at the correct `-light`/`-dark`
   target for the active mode.
3. **Live reload:** Waybar restyles; kitty recolors in place; swaync popups restyle;
   wob bar shows new colors on next volume/brightness event; wofi/rofi show new colors
   on next launch.
4. **GUI apps:** with each set to "follow system," Brave/Slack/Superhuman flip on
   `--light` / `--dark`.
5. **Idempotence:** repeated `--light` / `--dark` are safe; `--toggle` alternates.
6. **Rebuild safety:** `home-manager switch` succeeds with the apps removed from
   `xdg.configFile` and manual symlinks in place.

## Risks

- **Rebuild collision:** removing an app from `xdg.configFile` while a stale
  `~/.config/<app>` store symlink remains → resolve by replacing with the checkout
  symlink before/after switch. Mitigation: `ln -sfn` and verify per app.
- **kitty SIGUSR1** applies most settings live incl. colors; a few require restart —
  acceptable for palette-only changes.
- **style.css as a runtime-written file** in swaync (pre-existing): the display
  switcher `cp`s onto it, so it appears git-dirty at runtime. Pre-existing behavior,
  not introduced here; noted.
