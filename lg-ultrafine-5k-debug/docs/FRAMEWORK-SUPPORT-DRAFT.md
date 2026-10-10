# Draft: LG 27MD5KL fails before Thunderbolt enumeration on Framework 13 AI 300

Local draft only; not submitted. Investigation ongoing, 10 October 2026.

Framework Laptop 13 Ryzen AI 9 HX 370 with LG UltraFine 5K 27MD5KL fails before external Thunderbolt discovery on **both NixOS 26.05 (kernel6.18.44, Hyprland0.54.3) and Fedora44 Workstation Live (kernel6.19.10-300.fc44.x86_64)**, BIOS04.02. LG remains black, external DP connectors disconnected, external EDIDs empty. Internal eDP remains working. Fedora reproduces the same transient LG USB-hub enumeration and UCSI debug-accessory state; this is not just a desktop display-settings issue.

The monitor and exact original LG cable (approximately one metre) work on the owner's Mac. The owner confirmed that comparison during this investigation.

Firmware read with framework_tool 0.6.2 using the cros-ec driver:

```text
BIOS 04.02
EC lilac-4.0.2-fdbf549
Right PD controller: MainFw 0.0.21
Left PD controller: MainFw 0.0.21
Both controllers: backup and main application versions 0.0.21
```

| Controlled setup | Result |
| --- | --- |
| LG rear-right through USB-C expansion card; charger rear-left | No external TB router or connected DP output after controlled replug |
| Same LG connection, remove only charger | LG USB hubs briefly appear on bus 5 and disconnect; no external TB router or DP output |
| Move same LG cable to rear-left, charger absent | LG USB hubs briefly appear on bus 7 and disconnect; no external TB router or DP output |
| Remove rear-left expansion card; same cable directly into mainboard | No output; UCSI no longer exposes a port3 partner; direct attachment not confirmed electrically |
| Same direct connection, LG AC removed for 60 seconds then restored | No output or port3 partner; no kernel events captured |
| Same direct socket, laptop-end plug reversed | No output; EC port3 reports Nothing, no PD contract, 0 W; UCSI no partner |
| Restore same rear-left USB-C module, same boot | Partner/debug accessory and reported 5 V port supply return; LG hubs appear briefly then drop; no external TB router or DP output |
| Normal shutdown, requested three minutes off with external power disconnected; boot NixOS and reconnect through rear-left module | New boot verified; same transient USB hubs, UCSI errors and debug partner; no external TB router or DP output |
| Fedora44 Workstation Live, labeled left-rear connection through module | Same failure on kernel6.19.10: host routers only, eight DP outputs disconnected, debug-accessory partner, repeated LG USB appearance/disappearance |

While connected through the rear-left card with charger absent, EC query reports port3 as `Debug`, PD contract No, power role Sink, data role Ufp, VCONN Off, negotiated 0 V / 0 mA / 0 W, CC1, active port No. These are firmware-reported values. UCSI also reported a debug accessory in that setup. Physical right-rear maps to UCSI port0; left-rear maps to port3.

Kernel messages include `UCSI_GET_PDOS failed (-95)` or `(-5)`, `unknown error 0`, and `unknown error 256`. The latter is undefined UCSI error, not evidence of a specific electrical fault. A bounded Thunderbolt debug capture found host DP IN resources available but `no suitable DP OUT adapter available, not tunneling`. No external router or DROM-read failure was observed. Debug flags were restored exactly after capture.

Both TB hosts expose security=user and IOMMU protection. There is no detected external device to authorize. Eight DP connectors remain disconnected with no external EDID. Changing compositor modes has not been attempted because discovery fails earlier.

Fedora comparison and powered-off interval are completed, both failing. In the last Fedora trace, port3 partner appears at 677.600s, drops at 678.638s, reappears at 678.780s; LG hub enumerates at 679.010s and disconnects at 679.515s, followed by UCSI error256. Fedora also has DRM cleanup warnings during plymouthd close/release at ~5.36s, before these insertions; their relationship to this failure is unproven. GNOME/Mutter versions and drm_info are unavailable in the supplied capture, but kernel/USB/Bolt/sysfs capture succeeded.

The direct test lost basic attachment, so it must not be treated as ruling out the module or reproducing the original negotiation failure. Start date of original issue and first affected BIOS version remain unconfirmed. BIOS update is confirmed successful but did not restore output. Shared Linux driver behavior remains a possibility; we have not established a particular firmware defect.

Please assess whether this case matches the older-peripheral PD compatibility work in [issue #225](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5490733359). Is there an approved diagnostic or supported fix specifically for **Framework Laptop13 AI300, PD0.0.21 and LG27MD5KL**? If a test BIOS is appropriate, please provide the model-specific package, verification information and rollback instructions. If protocol-level capture or hardware inspection is needed, please identify the next test. No experimental firmware has been applied.

Local evidence index (paths are not public attachments):

- `../evidence/pd-left-rear.txt`: complete firmware and EC/PD report.
- `../evidence/20261010T112507-right-rear-approved-debug-trace-M4uBYP/`: controlled Thunderbolt debug trace.
- `../evidence/20261010T113029-framework-power-port-comparison-trace-DjKgVB/`: controlled charger/port events.
- `../evidence/20261010T114200-left-rear-direct-mainboard-jwESnK/`: direct-connection snapshot.
- `../evidence/20261010T122735-left-rear-module-after-shutdown-Kstoz1/`: NixOS after powered-off interval.
- `../evidence/20261010T111336-fedora-left-rear-connected-WI6uSJ/`: Fedora connected capture (UTC timestamps).
- `../evidence/20261010T111242-fedora-left-rear-trace-5GvFca/`: Fedora labeled port3 hotplug.

Review logs for private identifiers before any submission. Camera images are not needed for support.
