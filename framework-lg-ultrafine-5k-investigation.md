# Framework 13 + LG UltraFine 5K: investigation and engineering plan

**Project:** Restore the LG UltraFine 5K at native **5120 × 2880 @ 60 Hz** on a Framework Laptop 13 (Ryzen AI 9 HX 370) running NixOS and Hyprland.  
**Prepared:** 10 October 2026  
**Intended operators:** Codex + Astra on the Framework; human owner runs firmware changes, reboots, cable experiments, and Fedora Live USB test.  
**Mode:** Evidence-first troubleshooting; write code only after identifying the failing layer.

### Review checkpoint — 10 October 2026, after BIOS upgrade

**Later finding — Fedora comparison complete:** Fedora44 Workstation Live (kernel6.19.10) reproduces the NixOS6.18.44 pre-DRM failure through the rear-left USB-C module: transient LG USB hubs, UCSI debug accessory/errors, no external TB router, all external DP disconnected/EDIDs empty. Mac works with the same LG/cable. Powered-off interval did not help. Direct-mainboard tests lost basic attachment and are not valid equivalents. H1/H2 remain relevant; compositor/tile patches are not justified. Next priority is Framework engineering review of PD compatibility, while retaining shared Linux-driver behavior as an alternative. See [comparison](docs/lg-ultrafine-5k-debug/docs/NIXOS-FEDORA-COMPARISON.md) and [prepared report](docs/lg-ultrafine-5k-debug/docs/FRAMEWORK-SUPPORT-DRAFT.md). Earlier checkpoint bullets below are historical.

- **OBSERVED:** Owner confirms the LG is attached to the **right-rear USB-C port**. Sysfs confirms BIOS **04.02**, BIOS date `06/09/2026`, and kernel `6.18.44`. Local raw evidence: `evidence/lg-ultrafine-review/20261010-right-rear-dDysRn/` (ignored by Git).
- **OBSERVED:** `thunderbolt.txt:2–5` contains only `0-0`, `1-0`, `domain0`, and `domain1`: two host routers, no external router. A successful `boltctl list -a` outside the tool sandbox likewise lists only two authorized Framework hosts. Both domains report security `user`; that is not evidence of an LG authorization failure.
- **OBSERVED:** `drm-status.txt:1–8` reports all eight DP connectors disconnected; line 10 reports eDP connected. `hyprctl monitors all` shows only the internal panel, active at 2880×1920@120, scale 1. Hyprland is **0.54.3**, commit `521ece463c4a9d3d128670688a34756805a4328f`, built against Aquamarine **0.10.0** (runtime library version not independently verified).
- **OBSERVED:** Saved `kernel.txt:1143–1144,1186,1236,1399` has UCSI `unknown error 256` messages; lines 1395–1396 have `UCSI_GET_PDOS failed (-95)` at boot-relative 572.665075 seconds and `unknown error 0` at 573.614042 seconds. No `reading DROM failed` message was found. These logs lack a controlled insertion marker, so do not attribute a particular error to the current connection yet.
- **OBSERVED:** Repository config `hypr/hyprland.conf:10` explicitly requests `DP-4,3840x2160@60,auto,1`. Revisit this rule once the LG enumerates; it does not explain the current absence of an external Thunderbolt router. Effective loaded rules have not been verified.
- **INFERRED:** **H1/H2 are the current investigation priority**. H3 cannot yet be separated from the enumeration failure; H4/H5/H7 lack external connector/EDID evidence; H6 needs repeated controlled runs. This snapshot does not establish a faulty cable, port, monitor, or kernel.
- **NEXT TEST:** Record the exact monitor model, cable identity, and upstream monitor input. Capture one unplug/replug on the **same right-rear port and cable**, including a disconnected snapshot, timestamped insertion marker, and 30–60 seconds of kernel events. Then compare with Fedora GNOME using this same port/cable before changing other variables. No firmware or display configuration changes are needed for this test.
- **REVIEW CORRECTIONS:** Read EDID sysfs files without a file-size gate (the internal EDID reports size 0 but returns 384 bytes here). Keep eDP enabled throughout this plan. Authorization governs PCIe tunneling and must not be treated as proof of DisplayPort tunneling [R12]. Current connected-state evidence is not a disconnected baseline or a clean hotplug trace.

> **Agent instruction:** Treat this file as the working project brief. You may perform read-only diagnostics, write scripts, prepare reproducible experiments, analyze logs, and develop isolated patches. **Do not** change BIOS, boot configuration, disk partitions, kernel parameters, display-manager configuration, NixOS system config, or system firmware automatically. Propose each such change, its rollback, and why it is necessary, and request approval. Do not disable the laptop's internal panel. The owner will do the Fedora Live USB test manually.

---

## 0. Executive brief

We already own a working LG UltraFine 5K. It works correctly with a Mac. On the Framework, several cables and connection combinations have produced **no image**. An HDMI-to-DisplayPort adapter has allowed a lower-resolution picture, **not proof of native 5K working over Thunderbolt**. The main target is native, reliable 5K on NixOS/Hyprland; buying another monitor is not the objective.

The LG UltraFine 5K is not a typical single-stream DisplayPort display. On relevant models, Thunderbolt 3 carries **two DisplayPort video streams** that describe **two horizontal tiles, nominally 2560 × 2880 each**. The kernel/DRM and compositor must correctly discover and coordinate these tiles. Some models / modes also expose a single-stream 3840 × 2160 fallback. **Do not assume that either fallback works on this exact monitor without inspecting the model and EDIDs.**

A particularly relevant prior report covers **the same Framework Ryzen AI 9 HX 370 + LG 27MD5KL combination**, with intermittent USB4/Thunderbolt device enumeration, `reading DROM failed`, and eventual native 5K output on GNOME in some conditions [R1]. A separate September 2026 Omarchy issue shows a **dual-tile mixed-modeset bug** causing black screens when the two connector modes are selected independently [R3]. An older Aquamarine report documents regressions with the UltraFine after a compositor-backend transition [R2]. These are **leads, not diagnoses of this machine**.

### Success criteria

- **Primary:** LG displays a stable, correctly assembled **5120 × 2880 @ 60 Hz** image on **NixOS + Hyprland**, with laptop panel remaining recoverable.
- Hot-plug, cold-boot-connected, and resume-from-suspend tested; no frequent blanking, compositor crashes, or lost input.
- 2× logical scaling (effective 2560 × 1440) works for readable, Retina-like text. Native scanout resolution must remain 5120 × 2880.
- Solution is reproducible from documented config or a small maintainable patch, with rollback steps.
- **Secondary:** Separate fallbacks (3840 × 2160; GNOME on NixOS) may be useful for diagnosis, but are **not** substitutes for the primary goal.

### Things we must not conflate

1. USB-C physical connector vs USB4/Thunderbolt transport vs DP Alt Mode vs USB-C power.
2. An LG USB hub or camera enumerating vs the **Thunderbolt device** enumerating.
3. A Thunderbolt device authorizing vs the **two DisplayPort tunnels** being created.
4. DRM connector detected vs usable video mode and working compositor.
5. The compositor's logical resolution / scaling vs physical native panel signal.
6. Working Fedora GNOME vs proving Hyprland alone is at fault. Fedora also changes kernel, Mesa, udev/bolt, and userspace; compare versions and logs before attributing cause.

---

## 1. Known machine and constraints

| Field | Current evidence |
|---|---|
| Computer | Framework Laptop 13 DIY Edition, **AMD Ryzen AI 300 Series**, mainboard FRANMGCP09 |
| CPU / GPU | **Ryzen AI 9 HX 370**, Radeon **890M** integrated GPU |
| Internal display | Framework 13 **2.8K** panel (2880 × 1920) |
| Operating system | **NixOS 26.05 (Yarara)**, Wayland / **Hyprland** |
| Kernel | **6.18.44** |
| Firmware before upgrade | BIOS **3.05** |
| Current firmware | BIOS **04.02**, verified through `/sys/class/dmi/id/bios_version` on 10 October 2026 |
| Firmware upgrade status | **Completed by owner; running version verified.** |
| Firmware tooling | `fwupd` 2.1.1 functional; previous 3.04 → 3.05 upgrade succeeded |
| Current LG failure | Owner reports right-rear USB-C connection; no external TB router or connected DP output detected in review snapshot |
| Other known connection | HDMI-to-DisplayPort adapter can display an image at lower resolution |
| Exact LG model / revision | **27MD5KL confirmed by owner** on 10 October 2026; controller revision and cable identity still unverified |
| Current Hyprland / Aquamarine / Mesa revisions | Hyprland **0.54.3**, built against Aquamarine **0.10.0**; runtime Aquamarine and Mesa still unverified |

**Port topology:** Framework's Ryzen AI 300 port matrix says ports **1 and 3** are USB4 and DP 2.0 (UHBR20); these are the **two rear/top slots** with the laptop keyboard facing up. The front-right slot supports DP video but is not USB4; front-left is not suitable for the TB3 display. Physical expansion cards must actually expose USB-C rather than HDMI/DP. Use one of the **rear USB4 USB-C expansion-card slots** for the LG, directly, without a hub, KVM, dock, HDMI converter, or ordinary USB-C charging-only cable. Confirm visual orientation against Framework's official port guide [R4].

**Cable:** Try the supplied **Thunderbolt 3 cable** first, then a **known-certified 40 Gb/s Thunderbolt 3/4 cable**, ideally 0.8–1 m. A high-quality Thunderbolt 5 cable is an optional controlled experiment, not a requirement or guaranteed fix. Regular USB-C 10 Gb/s or charge cables are not sufficient evidence for two tunneled DP streams. Confirm the cable terminates at the LG's **Thunderbolt upstream input**, not one of its downstream USB-C hub ports.

**Power:** LG should be powered from its own AC supply. The laptop must have enough battery or an independent charger when possible; avoid assuming the monitor's downstream charging path is operating during testing.

**Owner-confirmed current layout (10 October 2026):** rear-right: LG Thunderbolt; rear-left: charger; front-right: keyboard. The owner performed additional manual checks/disconnections after the initial controlled reconnect, then reconnected the LG. Do not treat all intervening events as an unchanged physical setup. Owner explicitly approved the prepared three-minute Thunderbolt debug experiment; this approval does not authorize unrelated system/firmware changes.

---

## 2. Hypotheses, ordered by layer

| ID | Hypothesis | Evidence / deciding observation | Primary owner |
|---|---|---|---|
| H1 | Wrong physical port/cable / no TB3 link | No external switch in Bolt/sysfs and link errors; changes with rear port/cable | Hardware / USB4 |
| H2 | USB4/TB authorization, negotiation, retimer or firmware bug | External device appears intermittently; DROM/DP tunnel/UCSI errors | Kernel `thunderbolt`, UCSI, firmware |
| H3 | USB4 is connected but one/both DisplayPort tunnels fail | TB device authorized but 0/1 DRM tiles | Kernel USB4 / AMDGPU |
| H4 | Both tiles are correctly exposed but bad mode or insufficient display pipe/CRTC allocation | DRM shows tile group and both connectors; atomic modeset rejects/disables one | AMDGPU / DRM / compositor |
| H5 | Hyprland/Aquamarine incorrectly applies `preferred` to tiles, disables eDP, or can't recombine tile group | GNOME works; Hyprland logs mixed 4K + 2560×2880 modes or lost eDP | Aquamarine / Hyprland |
| H6 | Hotplug, suspend/resume, or mode-commit race | Cold-boot state differs from hotplug; logs change around connector events | Compositor / DRM / USB4 |
| H7 | Monitor-specific EDID/tile quirk | TILE/EDID differs from known working UltraFine examples | DRM quirk or compositor |

### Stop/branch rules

- **Zero USB4 enumeration:** focus H1/H2. Do **not** spend weekend patching tiling code yet.
- **Thunderbolt device exists, zero video outputs:** focus H2/H3 (tunnels, authorization, AMDGPU).
- **One output / 3840×2160 only:** identify expected single-stream fallback vs missing second tile; inspect cable, tunnels, EDIDs.
- **Two `2560×2880` tiles visible in DRM, black in Hyprland:** prioritize H4/H5, run Fedora GNOME before touching a kernel.
- **Fedora GNOME drives native 5K:** capture working evidence. First compare logs/versions/config, then prototype userspace fix on NixOS; don't conclude USB4 is permanently solved if connection is intermittent.
- **Fedora GNOME also fails, but TB enumeration works:** compare full DRM/TILE outputs; test another compositor only after captured baseline.
- **Everything works once then fails on replug:** focus H6 and build repeatable iteration tests.

---

## 3. Weekend sequencing: avoid expensive detours

### Friday / Stage A: baseline and non-destructive tooling

1. Create a new project repository: `~/src/lg-ultrafine-5k-debug` (or existing preferred workspace).
2. Copy this plan to `PLAN.md`.
3. Record machine identity, complete current versions, connector layout, current Hyprland monitor rules, and BIOS version **after the owner's upgrade** (if performed).
4. Take a photo of the LG rear model label and identify Thunderbolt input. Keep serial numbers private.
5. Prepare `scripts/collect.sh` that writes timestamped snapshots under `evidence/`; all collection scripts must be **read-only, idempotent**, and gracefully handle missing tools.
6. Establish a safe baseline **without the LG connected**. The laptop's internal screen must stay usable.
7. Get one failing-connection trace with **one named cable + one named rear USB4 port**. Do not rotate multiple variables simultaneously.

### Saturday morning / Stage B: decisive Fedora GNOME live test

The human owner follows **Section 5** below. Agents prep a one-page worksheet and instructions, not a destructive USB-flashing command.

### Saturday afternoon / Stage C: diagnose by failure layer

- Compare NixOS vs Fedora evidence using the hypothesis matrix.
- If Fedora works, identify GNOME/Mutter's monitor mapping and NixOS/Aquamarine behavior.
- If neither works, inspect USB4/Thunderbolt enumeration and error classes before compositor patches.
- Choose the smallest testable hypothesis, not the most ambitious fix.

### Sunday / Stage D: prototype and regression checks

- Develop one isolated workaround or patch; keep its source, command, and rollback in the repo.
- Test hotplug, cold boot, suspend/resume, internal panel recovery, different rear USB4 ports.
- Produce short `RESULTS.md` with evidence and next actions. An upstream issue/PR is optional and must be reviewed before publication.

---

## 4. NixOS: data collection recipes

**Agent duties:** run non-privileged commands autonomously; seek permission for `sudo` if needed; put original raw logs in local `evidence/` and scrub serial numbers, MACs, host IDs, user paths, and other personal identifiers before sharing publicly.

### 4.1 Versions and topology (before plugging in)

```bash
mkdir -p evidence
uname -a
cat /etc/os-release
sudo dmidecode -s bios-version         # If owner approves sudo
# Prefer the unprivileged read when available:
cat /sys/class/dmi/id/bios_version
hyprctl version
hyprctl monitors all
# Read monitor rules from the actual loaded config and its included files.
lspci -nnk | grep -A4 -Ei 'VGA|Display|USB4|Thunderbolt' || true
ls -l /dev/dri/ || true
ls -la /sys/bus/thunderbolt/devices/ || true
lsusb -t
```

Record Hyprland, Aquamarine, Mesa and kernel package versions with the existing NixOS flake/lockfile or store derivations as appropriate. **Do not edit the system configuration simply to gather version strings.** Capture applicable monitor rules (sanitize other user config as necessary).

Tools to use if already installed: `boltctl`, `drm_info`, `edid-decode`, `lspci`, `lsusb`, `lsblk`, `journalctl`. On NixOS, a temporary `nix shell` for read-only commands is fine, e.g. try `nix shell nixpkgs#drm_info nixpkgs#edid-decode nixpkgs#usbutils nixpkgs#pciutils -c bash` after checking attribute availability. If unavailable, skip and document; do not guess obscure package names.

If there is no Bolt service, its NixOS option is:

```nix
services.hardware.bolt.enable = true;
```

Enabling this requires an approved declarative NixOS rebuild. First inspect kernel/sysfs enumeration without it; **an empty `boltctl list` does not by itself mean USB4 failed**. If a genuinely external Thunderbolt device is found but not authorized, verify its identity, then propose `boltctl authorize` or enrollment for human review [R7].

Authorization controls **PCIe tunnels** [R12]; a missing authorization is not by itself an explanation for missing DP video. Inspect external-router enumeration and video separately. If Bolt or Hyprland queries fail because the diagnostic sandbox blocks local sockets, record the query failure separately from hardware state and retry with permitted read-only host access.

### 4.2 Capture an insertion event

In Terminal A, **before connecting the LG**:

```bash
sudo journalctl -k -b -f -o short-iso | tee evidence/kernel-hotplug-live.txt
```

In Terminal B:

```bash
SINCE="$(date --iso-8601=seconds)"
printf 'Connection marker: %s\n' "$SINCE" | tee evidence/hotplug-marker.txt
```

Now attach the LG to **one rear USB4 port** with a known TB3/TB4 cable; allow 30–60 seconds, without toggling other variables. Stop Terminal A with Ctrl+C. Record the exact LG power state, laptop lid state, USB4 slot, cable, BIOS, whether screen lit, and whether any prompts appeared.

After insertion:

```bash
sudo journalctl -k -b --since "$SINCE" -o short-iso > evidence/kernel-hotplug-since.txt
journalctl --user -b --since "$SINCE" -o short-iso > evidence/user-session-since.txt
hyprctl monitors all > evidence/hyprland-monitors-after.txt
boltctl list -a > evidence/bolt-after.txt 2>&1 || true
lsusb -t > evidence/usb-tree-after.txt
ls -l /sys/bus/thunderbolt/devices/ > evidence/tb-devices-after.txt 2>&1 || true
```

Look for `thunderbolt`, `usb4`, `ucsi`, `amdgpu`, `drm`, `DP`, `DROM`, `tunnel`, `atomic`, `tile`, `link training`, and `page-flip`. Keep **unfiltered logs** in addition to grepped summaries; context and sequence are critical.

### 4.3 Independently inspect DRM (even if Hyprland says no monitors)

```bash
for p in /sys/class/drm/card*-*/status; do
  [ -f "$p" ] || continue
  printf '%s: ' "$p"
  cat "$p"
done | tee evidence/drm-connector-status.txt

# Capture every enumerated connector, and retain EDIDs as BINARY for accurate decoding.
for d in /sys/class/drm/card*-*; do
  [ -e "$d/status" ] || continue
  n="$(basename "$d")"
  mkdir -p "evidence/edid"
  cat "$d/status" > "evidence/edid/${n}.status" || true
  [ -r "$d/modes" ] && cat "$d/modes" > "evidence/edid/${n}.modes"
  # sysfs can report size 0 even when the EDID contains data.
  [ -r "$d/edid" ] && cat "$d/edid" > "evidence/edid/${n}.bin" || true
done

# Optional: use a DRM metadata viewer for properties, including TILE.
drm_info > evidence/drm-info.txt 2>&1 || true
for f in evidence/edid/*.bin; do
  [ -s "$f" ] || continue  # Size check is valid on the saved regular file.
  edid-decode "$f" > "${f%.bin}.decoded.txt" 2>&1 || true
done
```

**Interpretation:** Two connected physical DRM connectors with corresponding tile group positions (`0,0` and `1,0`) and 2560×2880 modes are strong evidence that Thunderbolt DP tunneling + AMDGPU enumeration largely work. DRM's `TILE` property is explicitly intended for connectors comprising one logical display [R5]. An EDID missing for a connector does not by itself determine which layer failed; correlate to TB tunnel messages.

**Avoid `modetest` modesetting against a running compositor**; use it only in a deliberately arranged TTY/test session with approval. `xrandr` is not a trustworthy description of real outputs under GNOME Wayland/Hyprland.

### 4.4 Robustness / safe recovery

- Keep laptop lid open and internal panel active during initial tests.
- Maintain an SSH path from another device **if practical**, set up explicitly and securely, before deliberately testing risky modesets. Do not expose SSH to untrusted networks.
- If both screens go black, first **unplug the LG** and allow the compositor to recover. If necessary, switch to a TTY (`Ctrl+Alt+F3`, function-key modifiers if needed), or use SSH. Reboot only when required.
- Do not auto-run `hyprctl keyword monitor ... disable` on the internal eDP connector.
- Save working Hyprland config and a NixOS rollback generation before any permitted modifications.
- Keep cable- and port-specific evidence in separate run folders rather than overwriting captures.

### 4.5 Escalation instrumentation, only after the initial trace

If USB4 enumerates unreliably, agents may **propose** temporary kernel dynamic-debug instrumentation for the `thunderbolt` subsystem. It is a runtime setting (not a firmware flash) but can generate large logs and has prerequisites (`CONFIG_DYNAMIC_DEBUG`, debugfs mounted); use only with approval and restore it afterward. For example, if supported:

```bash
# Requires human approval; inspect availability before writing.
sudo sh -c "echo 'module thunderbolt +p' > /sys/kernel/debug/dynamic_debug/control"
# Collect a short reproduction, then disable:
sudo sh -c "echo 'module thunderbolt -p' > /sys/kernel/debug/dynamic_debug/control"
```

For modeset failures, compare detailed DRM/KMS information and Aquamarine debug logs before enabling broad DRM debugging or adding kernel boot flags. Do **not** modify kernel command line blindly or disable security features to gain visibility.

---

## 5. **Manual experiment: Fedora Workstation 44 live USB (GNOME)**

This is the highest-value controlled experiment. It changes operating system, userspace, and compositor **without installing Fedora to the internal SSD**. The owner performs it manually; Codex/Astra can analyze the resulting files afterward.

### 5.1 Materials and download

- One disposable **8 GB or larger USB flash drive** (all data on it will be erased); a second drive or network destination for saving logs is useful.
- Stable power for both LG and Framework, and a known Thunderbolt-certified cable.
- Download **Fedora Workstation 44, Intel/AMD x86_64 Live ISO** from the official page:  
  **https://fedoraproject.org/workstation/download/**
- Avoid Fedora KDE, Server, or random third-party ISO; **GNOME/Mutter** is the control compositor being tested. As of this plan, Fedora's official Workstation download page offers **Fedora 44** (release 28 April 2026) [R6]. If the page has advanced by the time of execution, record exact version/ISO and prefer the current stable Workstation GNOME image.
- On the download page, use **Verify your download**. Prefer validating the signed checksum file per Fedora instructions. At minimum, compare the ISO's SHA-256 to the checksum displayed by Fedora's official site. Do not hard-code checksum values from this document: verify against the current official download.

### 5.2 Create bootable USB from NixOS

**Preferred graphical method: Fedora Media Writer.** Fedora's project docs recommend it for making Live USB media [R6, R8].

If Flatpak is already available and configured with Flathub:

```bash
flatpak install flathub org.fedoraproject.MediaWriter
flatpak run org.fedoraproject.MediaWriter
```

If Flathub isn't configured, follow Fedora Media Writer / Flathub instructions and confirm the repository before adding it; alternatively run GNOME Disks (Disk Image Restore) if installed. **There is no need to change the machine's boot configuration.**

In the application:

1. Insert the **disposable USB stick**. Check its identity/capacity carefully with `lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS` beforehand if unsure.
2. In Fedora Media Writer select **Fedora Workstation**, x86_64, **Fedora 44**, or **Custom Image** and select the verified Live ISO.
3. Select the **USB flash drive** as destination. **Never select the Framework's internal NVMe SSD.**
4. Confirm the erase/write operation; wait for completion and verification.
5. Safely eject the USB. Do not use `dd` unless you are fully comfortable identifying whole block devices and accept its destructive risk.

### 5.3 Boot Fedora without installing it

1. Save NixOS work and shut down the Framework.
2. Insert the Fedora USB. Initially **leave the LG disconnected** so the internal display is the guaranteed control.
3. Power on and repeatedly tap **F12** immediately (on a Framework, `Fn+F12` may be needed if function keys are media keys). Framework's official boot selection guidance confirms F12 [R9].
4. In Boot Manager, select **EFI USB Device** or the named Fedora USB; press Enter.
5. Select the Fedora Live startup option (wording may be **Start Fedora Workstation-Live** or similar).
6. When the Fedora GNOME desktop/installer prompt appears, choose **Try Fedora / Try Fedora Workstation / Not Now** as applicable. **Do not click Install Fedora. Do not enter the disk partitioner.**
7. Confirm live session:

   ```bash
   cat /etc/os-release
   uname -r
   echo "$XDG_SESSION_TYPE"
   ```

   Expect Fedora Workstation, a Fedora kernel, and Wayland. Verify the desktop is GNOME / Mutter.
8. Open **Settings → Displays** before attaching LG. Record built-in panel and current layout.

**Secure Boot:** Fedora's official Live media should generally boot with Secure Boot enabled. Your NixOS system previously reported Secure Boot disabled; after a BIOS upgrade the setting might change. Record it. **Do not toggle firmware Secure Boot solely for this experiment unless the USB actually fails and you understand your NixOS bootloader's requirements.**

### 5.4 Experiment matrix (manual)

For each run, take a photo of the physical screen **and record any recognized modes in Settings → Displays**. Capture terminal evidence if possible. Avoid running many variations at once.

| Test | Starting state | Connection / action | What to observe |
|---|---|---|---|
| F0 | Fedora GNOME Live, no LG | Baseline | Internal panel works; record kernel, GNOME, Bolt/DRM |
| F1 | Fedora running, lid open | Plug LG into **rear-right USB4**, same cable as NixOS checkpoint | No image? Single 4K? Two tiled outputs? **One 5120×2880 @ 60 Hz logical monitor?** |
| F2 | Power off | Boot Fedora with LG already attached | Does cold-boot detection differ from F1? |
| F3 | Fedora running, no LG | Plug into **rear-left USB4**, same cable | Are two USB4 ports different? |
| F4 | Fedora running | Repeat best rear USB4 port with second certified TB cable | Is behavior cable-dependent? |
| F5 | Fedora if video already works | Disconnect/reconnect 3 times, then suspend/resume once | Does 5K remain stable? |

Keep the lid open and eDP enabled throughout this plan. Any later external-only experiment requires separately agreed scope and recovery steps. Avoid docking/adapter chains in this phase.

### 5.5 Evidence to save **from the Fedora live session**

Fedora's Live session is normally **ephemeral**. Save the captures to a **second USB stick**, a dedicated shared network destination, or a clearly identified **non-system** temporary destination before shutting down. Do **not** assume the boot USB is writable/persistent, and do not mount or write the internal NixOS drive unless intentionally approved.

In GNOME Terminal (some utilities may not be installed; skip gracefully):

```bash
mkdir -p ~/fedora-lg-evidence
cat /etc/os-release > ~/fedora-lg-evidence/os-release.txt
uname -a > ~/fedora-lg-evidence/uname.txt
echo "$XDG_SESSION_TYPE" > ~/fedora-lg-evidence/session-type.txt
boltctl list -a > ~/fedora-lg-evidence/bolt.txt 2>&1 || true
lsusb -t > ~/fedora-lg-evidence/usb-tree.txt
lspci -nnk > ~/fedora-lg-evidence/pci.txt
sudo journalctl -k -b -o short-iso > ~/fedora-lg-evidence/kernel.txt
for s in /sys/class/drm/card*-*/status; do
  [ -f "$s" ] && printf '%s: %s\n' "$s" "$(cat "$s")"
done > ~/fedora-lg-evidence/drm-status.txt
```

Before plugging LG in, optionally run:

```bash
sudo journalctl -k -b -f -o short-iso | tee ~/fedora-lg-evidence/hotplug.txt
```

If `drm_info` / `edid-decode` are available, capture the DRM TILE properties and EDIDs as in §4.3. Do not install extra packages unless needed. Also take a screenshot of **Settings → Displays** showing the reported monitor **5120×2880, 60 Hz** if achieved. A Fedora success photo is evidence of a working configuration, but capture logs too.

After saving, use **Shut Down**, unplug Fedora boot USB, and boot normal NixOS. The internal SSD and NixOS install should be unchanged.

### 5.6 Result interpretation

- **Fedora GNOME: native 5K works, stable** → strong reason to prioritize a **Hyprland/Aquamarine / configuration / userspace** solution, while comparing Fedora kernel/Mesa and TB topology with NixOS to avoid false attribution.
- **Fedora GNOME: intermittent 5K, DROM errors** → USB4 link/firmware/cable stability is still a blocker; compositor fixes may be second stage.
- **Fedora GNOME: sees both 2560×2880 tiles but no 5K** → focus on tile grouping, mode selection, and resource constraints.
- **Fedora GNOME: zero LG/TB device** → prioritize USB4 negotiation, port, cable, monitor input, and firmware, not compositor.
- **Fedora only works with lid closed** → likely CRTC/pipe/resource or mode-selection complication; document rather than assuming all displays can run together.

---

## 6. Controlled experiments back on NixOS

### A. Build a comparison table

For every run, record:

| Run ID | Date / firmware | OS / kernel | Compositor | USB4 slot | TB cable | Bolt LG found? | DP tiles | 5K? | Stable? | Main error |
|---|---|---|---|---|---|---|---|---|---|---|
| N0 | | NixOS 6.18.44 | Hyprland | rear-left | TB3 | | | | | |
| N1 | | NixOS 6.18.44 | Hyprland | rear-right | TB3 | | | | | |
| F1 | | Fedora Live | GNOME | rear-right | record actual cable | | | | | |
| F3 | | Fedora Live | GNOME | rear-left | same as F1 | | | | | |

Do not combine failures from different runs in a single narrative without identifying the run and cable.

### B. Verify connections vs tile properties

If DRM presents a `TILE` group, read the coordinates/dimensions, preferred modes, CRTC candidates, and atomic commit errors. A known September 2026 case exposed:

- DP tile 0 at `(0,0)` with `2560×2880`.
- DP tile 1 at `(1,0)` with `2560×2880`.
- One connector's `preferred` mode was **3840×2160**, **not** the 2560×2880 tile mode.
- A compositor using `preferred` on each independently tried incompatible modes (4K for one tile, 2560×2880 for the other), causing all screens to go black [R3].

**Do not copy that case's exact connector names or modes into this Framework's config blindly.** Derive them from actual `drm_info`, EDID and `hyprctl` outputs.

### C. Minimal configuration experiment, *only if both DRM tiles exist*

1. Backup current Hyprland monitor configuration and NixOS generation.
2. Identify the two matching LG connectors and the eDP connector; verify tile-group membership from DRM data, not just matching vendor strings.
3. With owner approval, first attempt an explicit compatible 2560×2880@60 mode **on both LG connectors** and distinct adjacent positions, while preserving the internal panel and a recovery route.
4. If two tiles plus eDP exceed resources or fail atomic modesetting, preserve eDP, capture the failure, and stop that modeset experiment. An external-only test is outside this plan's current authorization and requires separately agreed scope and recovery steps.
5. A 3840×2160 single-stream fallback is diagnostic only. Don't turn a fallback into the final fix.

This is **not guaranteed to yield a single logical 5K monitor**: two 2560×2880 desktops side by side are only a useful intermediate. Correct 5K composition, cursor, fullscreen, frame synchronization, and scaling still require proper tiled-monitor treatment.

### D. Stronger compositor A/B, only if needed

If Fedora GNOME succeeds, an optional **GNOME or KWin session on NixOS with the same kernel/Mesa** is the cleaner compositor comparison, but adding a display manager or desktop environment is a system config change and requires explicit owner approval and rollback. Prefer isolated or specialisation-based NixOS configuration; do not replace the daily Hyprland setup.

---

## 7. If code is needed: choose the smallest layer

### Path 1 — Userspace: Aquamarine / Hyprland

**Prerequisites:** reliable USB4 link, both DP streams exist in DRM, at least one other compositor can drive full 5K or solid evidence that modesets fail only in Aquamarine.

Tasks for Codex/Astra:

1. Read issue [R2], the 2026 mixed-mode bug [R3], and **current** Hyprland/Aquamarine source and open issues before choosing implementation points. Do not assume 2024 APIs or patches still apply in 2026.
2. Locate code handling DRM connector `TILE` metadata, connector grouping, preferred-mode ranking, atomic modeset / CRTC allocation, and hotplug recovery. Inspect whether behavior belongs in Aquamarine or Hyprland's higher-level monitor abstraction.
3. Compare with GNOME/Mutter tiled-monitor handling as a **design reference**. Avoid copying code with incompatible licensing or APIs.
4. Prototype: identify and group connectors with the same tile group, match tiles to a compatible physical mode (often 2560×2880@60 for this LG), request coordinated commits, and expose coherent logical geometry; preserve internal display whenever resources allow.
5. Recover if a proposed commit fails: revert both tiles, ensure eDP remains enabled, avoid leaving all outputs disabled. Add logging that reports selected modes and tile-group composition.
6. Create minimal patch, regression test plan and before/after logs. Avoid implementing one-off physical connector names or PCI IDs as a final upstream patch.
7. Test unplug/replug, monitor absent on startup, cold boot with it connected, resume, scale=2, cursor transitions, fullscreen, and failures mid-hotplug.

Possible edge: one pipe may need allocation per tile plus eDP; don't assume the iGPU has enough available resources without inspecting failed atomic transactions.

### Path 2 — Kernel USB4 / Thunderbolt / AMDGPU

**Prerequisites:** failure occurs before both streams reach DRM, or kernel consistently fails enumerating LG / building DP tunnels even on GNOME.

Tasks:

1. Reproduce and categorize `reading DROM failed`, `downstream port is locked`, UCSI errors, DP IN/OUT resource availability, tunnel creation failures, and link resets; compare to [R1].
2. Collect one bounded dynamic-debug trace with human approval (see §4.5); inspect kernel's relevant code in `drivers/thunderbolt/`, Type-C/UCSI, and `drivers/gpu/drm/amd/display/` before patching anything.
3. Compare successful vs unsuccessful same-port/cable runs; look for timing, authorization, PCI runtime PM, suspend, initial enumeration, and tunnel capacity differences.
4. Search for upstream fixes/quirks newer than installed 6.18.44 **before** writing custom C driver code. A temporary kernel test boot is a separate approved action with an easy rollback.
5. If reproducible to a small kernel bug, make a patch on an isolated branch, write test procedure and proposed upstream report. **No automatic firmware flashing, EC writes, or unsafe PCI register pokes.**

### Path 3 — EDID/display quirks

Only consider an EDID override or display quirk if EDID/TILE metadata is demonstrably wrong and the link itself is stable. Archive the original binary EDIDs before any override; monitor overrides can make a display unusable, so require an owner-approved rollback plan. Avoid speculative firmware reverse engineering. A brand-new LG hardware driver is **not the default solution**.

---

## 8. Agent deliverables and collaboration protocol

Create the following **in a local Git repository**:

```text
lg-ultrafine-5k-debug/
  PLAN.md                         # this brief, updated only with annotated findings
  README.md                       # 1-page status: what works, next decisive experiment
  RESULTS.md                      # chronology, hypothesis verdicts, acceptance tests
  docs/
    FEDORA-LIVE-CHECKLIST.md      # compact manual checklist for the owner
    FAILURE-MATRIX.md            # H1-H7 evidence / current status
    UPSTREAM-REFERENCES.md       # references, hashes/versions, links
    SAFETY-AND-ROLLBACK.md        # recovery for each proposed system change
  scripts/
    collect.sh                    # read-only snapshots; explicit run label
    compare.sh                    # NixOS vs Fedora summary; no fragile assumptions
    sanitize.sh                   # prepare reports without private IDs
  evidence/
    .gitignore                    # default exclude large/raw/private captures
    RUN-ID/
      notes.md
      kernel.txt
      user-session.txt
      drm-info.txt
      drm-connector-status.txt
      bolt.txt
      edid/
  patches/                        # only when evidence supports a specific fix
```

**First Codex/Astra task:** implement `scripts/collect.sh` and `docs/FEDORA-LIVE-CHECKLIST.md`, run **read-only baseline**, report current H1–H7 status and the single most valuable next test. Do not start by changing system settings. Let the owner run Fedora and upload evidence before deciding a source-level patch.

**Collaboration:** One agent can handle USB4/DRM evidence, the other Hyprland/Aquamarine research. Maintain a shared `RESULTS.md` with clearly tagged **OBSERVED**, **INFERRED**, **EXTERNAL REPORT**, **UNVERIFIED**, and **NEXT TEST** entries. Agents must cite file paths and exact log lines for claims. Keep experiments in separate Git branches; don't run simultaneous live-display mutations while the owner is using the laptop.

**Quality bar:** Each proposed fix has: root-cause hypothesis; supporting trace; smallest change; exact reproduction and pass/fail check; rollback; and compatibility notes. Don't claim 5K fixed merely because a 4K mode or two adjacent 2560×2880 desktops are available.

### Completion checklist

- [ ] Exact UltraFine model, upstream port, and working Mac/cable configuration documented.
- [x] Firmware updated/verified by owner; current BIOS recorded (04.02).
- [ ] NixOS baseline and at least one clean failing hotplug trace captured.
- [ ] Fedora GNOME Live tested manually, with both video evidence and logs.
- [ ] Working/failing layer isolated to USB4, DRM, compositor, or unresolved with explicit evidence.
- [ ] If fixed: native 5120×2880 @ 60Hz verified, with scale/geometry/cursor correctness.
- [ ] Hotplug ×3, cold boot, sleep/wake, and eDP recovery validated.
- [ ] Minimal reproducible config/patch committed and rollback documented.
- [ ] `RESULTS.md` contains remaining limitations and upstream path.

---

## 9. Sources and prior art (read before coding)

These links are for technical investigation, **not guarantees** that this exact hardware combination behaves identically.

- **[R1] Exact Framework HX 370 + LG 27MD5KL case:** Framework Community, *FW 13 - Ryzen AI 9 - Thunderbolt/DP Display Output is Broken*. Documents DP tunneling errors, `reading DROM failed`, changed cable behavior and intermittent GNOME 5K:  
  https://community.frame.work/t/fw-13-ryzen-ai-9-thunderbolt-dp-display-output-is-broken/69643
- **[R2] Aquamarine issue #59:** *modesetting failing on external monitor*, LG UltraFine 5K tiling, historical wlroots/Aquamarine behavior:  
  https://github.com/hyprwm/aquamarine/issues/59
- **[R3] Omarchy issue #10691 (7 Sep 2026):** dual-DP LG UltraFine, mismatched preferred modes (3840×2160 + 2560×2880), black-screen and lost eDP; reported on **different Intel laptop**, so use as clue, not direct reproduction:  
  https://github.com/omacom/omarchy/issues/10691
- **[R4] Framework official Ryzen AI 300 port matrix:**  
  https://knowledgebase.frame.work/usb-port-definition-matrix-framework-laptop-13-HkHVUHaTge
- **[R5] Linux DRM/KMS specification — TILE connector property:**  
  https://dri.freedesktop.org/docs/drm/gpu/drm-kms.html
- **[R6] Official Fedora Workstation 44 Live download, checksum instructions, Fedora Media Writer:**  
  https://fedoraproject.org/workstation/download/
- **[R7] NixOS official Thunderbolt/Bolt guidance:**  
  https://wiki.nixos.org/wiki/Thunderbolt
- **[R8] Fedora USB media tests and Fedora Media Writer Flatpak:**  
  https://fedoraproject.org/wiki/QA:Testcase_USB_fmw
- **[R9] Framework BIOS/boot key reference (F2 BIOS, F12 boot selection):**  
  https://knowledgebase.frame.work/how-do-i-enter-the-bios-on-the-framework-laptop-HydmWf5Ad
- **[R10] Framework Ryzen AI 300 BIOS 4.02 official release page:**  
  https://resources.frame.work/downloads/laptop-13/amd-ryzen-ai-300-series/4.02/
- **[R11] Related 2026 Aquamarine modesetting/pipe-allocation case:** useful if atomic modeset reports insufficient pipes; different panel/GPU:  
  https://github.com/hyprwm/aquamarine/issues/352
- **[R12] Linux USB4/Thunderbolt administration documentation:** authorization and security levels govern PCIe tunneling; distinguish them from DP transport:  
  https://docs.kernel.org/admin-guide/thunderbolt.html

---

## 10. Copy-paste kickoff prompt for Codex + Astra

> We are investigating native 5120×2880@60 on an LG UltraFine 5K connected to a Framework Laptop 13 Ryzen AI 9 HX 370 on NixOS 26.05, kernel 6.18.44, Hyprland. Read `PLAN.md` completely. First establish the machine's live hardware/software facts and write read-only evidence collection scripts. Do not change system configuration or firmware. Look up the latest state of the linked upstream issues/source before proposing a fix. Pay particular attention to USB4 Thunderbolt enumeration, two tunneled DisplayPort streams, DRM TILE properties, Aquamarine mode selection and the internal eDP display. Prepare `docs/FEDORA-LIVE-CHECKLIST.md` so the owner can manually test Fedora Workstation GNOME Live without installing to disk. After initial evidence, populate `RESULTS.md` with observed facts vs hypotheses, the minimum decisive next experiment, and rollback details for any later proposed change. Prefer a small user-space fix if Fedora works; investigate the kernel only if tunnels/DRM fail. Do not silently settle for 4K.
