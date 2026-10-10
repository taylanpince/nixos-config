# NixOS / Fedora comparison — 10 October 2026

The supplied Fedora evidence reproduces the failure before external Thunderbolt discovery. Changing Hyprland monitor rules or tile modes cannot address the observed missing device. The comparison does not exclude a shared Linux driver defect or prove a firmware/hardware root cause.

| Observation | NixOS after shutdown | Fedora Workstation Live |
| --- | --- | --- |
| Kernel | 6.18.44 | 6.19.10-300.fc44.x86_64 |
| BIOS | 04.02 | 04.02 |
| External TB router | None; two hosts only | None; two hosts only |
| External DP connectors | Eight disconnected | Eight disconnected |
| External EDIDs | Empty | All eight empty; internal eDP EDID 384 bytes |
| Rear-left UCSI partner | Debug accessory, no advertised PD support, zero alternate modes | Same |
| Port supply report | Online, 5 V, 0 A | Online, 5 V, 0 A; explicitly Not charging |
| Battery | Discharging | Discharging |
| LG USB hub | Brief appearance, then disconnect | Repeated brief appearances, then disconnect |
| UCSI errors | GET_PDOS failures, undefined error256 | Same class of failures, including -95/-70/-5 and error256 |

## Sources and timing

NixOS baseline: `../evidence/20261010T122735-left-rear-module-after-shutdown-Kstoz1/`. Fedora connected capture: `../evidence/20261010T111336-fedora-left-rear-connected-WI6uSJ/`. Both include successful kernel-journal, USB, Bolt and sysfs queries. Fedora filenames use UTC: its 11:13:36+00:00 capture is **13:13:36 Europe/Madrid**, later than the 12:27 NixOS capture.

Fedora trace `../evidence/20261010T111242-fedora-left-rear-trace-5GvFca/udev-live.txt:21` records port3 partner addition at 677.600 seconds. The partner drops at 678.638 and returns at 678.780 seconds. Its `kernel-live.txt:1–14` shows UCSI failures, LG 043e:9a61 discovery at 679.010, USB disconnect at 679.515, downstream descriptor error -71, and UCSI error256 at 679.960. No TB router or DRM connection appears in the trace's state snapshots. An earlier trace at `20261010T111047-fedora-left-rear-trace-IW1k43/` repeats the same pattern.

Fedora connected `kernel.txt:1631–1711` contains several attempts, including LG USB activity on bus5 before the labeled left-rear traces. Do not assign every earlier attempt a physical setup without owner confirmation. Current port3 partner, labels and bus7 trace agree with the intended left-rear test; raw logs cannot independently certify cable identity or module seating.

## Limits and other findings

- No separate disconnected Fedora snapshot or GNOME/Mutter version output was supplied. These do not prevent assessing the supplied hotplug trace and sysfs state.
- `drm_info` and Hyprland commands were unavailable in Fedora (exit127). Missing `drm_info` is not evidence of absent hardware; the independent sysfs statuses and empty EDIDs establish the disconnected result. Hyprland's absence is expected.
- Fedora has four early DRM cleanup warnings during `plymouthd` close/release at ~5.36 seconds (`kernel.txt:1179–1391`). They precede the recorded LG insertions; no causal link to repeated partner/USB loss is established. Do not hide them or diagnose them as the LG cause without more evidence.
- Direct-mainboard tests are **not** equivalent controls: they lost all partner detection. Reinstalling the module restored detectable but unstable attachment. Preserve that distinction.
- This narrows the immediate failure to USB-C/PD/USB4 attachment and discovery. Firmware/peripheral interoperability and a shared Linux stack defect remain plausible; a specific defective component is not identified.

## Next action

Request Framework engineering review with both kernel traces and the existing EC/PD report. Ask whether the [PD compatibility fix described in issue #225](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5490733359) applies specifically to Laptop 13 AI 300 / LG 27MD5KL / PD0.0.21, and for an approved diagnostic or model-specific firmware/rollback procedure. Their report mentions a support-provided test BIOS and possible protocol-analyzer capture, but does not establish that this LG has the same defect.

BIOS4.02 remains marked latest stable on the [official release page](https://resources.frame.work/downloads/laptop-13/amd-ryzen-ai-300-series/4.02/) when checked. Do not flash a build intended for a different Framework model. A Windows comparison, if already available, would help distinguish Linux-specific behavior; installing another OS is not required before sending this evidence to support.
