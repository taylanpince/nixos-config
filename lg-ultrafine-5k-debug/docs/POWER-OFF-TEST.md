# Powered-off interval test

**COMPLETED:** Owner returned at 12:27 on 10 October 2026. New boot verified; original module-connected failure persisted (transient LG USB hubs, UCSI errors, no external TB router or DP output). Snapshot `../evidence/20261010T122735-left-rear-module-after-shutdown-Kstoz1/`. Do not repeat this sequence without a new reason; next step is the Fedora Live comparison.

**REVISED: use the rear-left USB-C expansion module.** Reinstalling it restored Type-C partner detection, a reported 5 V port supply and transient LG USB hubs. The direct connection is not a validated baseline. Do not remove the module for this test.

Prepared 10 October 2026. Corrected pre-shutdown baseline: `../evidence/20261010T115006-left-rear-module-restored-JR6vgW/`, same boot as previous tests, module installed, charger absent. All external DP connectors remain disconnected. EC report from the earlier equivalent module setup: `../evidence/pd-left-rear.txt`.

Purpose: determine whether a normal full shutdown and unpowered-from-USB interval recovers attachment. [Framework PD issue #225](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225) requests a shutdown of three or more minutes with the power adapter disconnected. We keep the separate charger absent on restart to match the current baseline; this is an adaptation of their sequence. The internal battery remains connected, so this is not a guaranteed EC power reset.

Owner steps:

1. Save work. Disconnect the LG cable **at the laptop**. Keep the laptop charger unplugged and LG AC power on. Leave the rear-left USB-C expansion module installed and keyboard unchanged.
2. Shut NixOS down normally, rather than suspend or restart. Leave it fully off for at least three minutes.
3. Power on using the battery and log into the same NixOS/Hyprland session. No firmware/boot settings need changing.
4. Reconnect the same LG cable through the same rear-left USB-C expansion module. Keep the charger unplugged and lid open, with camera facing LG.
5. Return to this conversation and say “back after shutdown.”

Agent resumption:

- Read this file and the latest RESULTS.md entries before starting more physical tests.
- Capture a new labeled snapshot and boot ID. The collector saves the full current kernel boot journal, including insertion before the conversation resumes.
- Check external TB router discovery, UCSI partner state, DRM connectors/EDIDs and internal eDP. Take the authorized camera still.
- If enumeration recovers, inspect external EDIDs/TILE properties before modesetting. Preserve eDP. Do not equate a 4K image with the 5K goal.
- If absent, prioritize Fedora Live comparison or a targeted support report over speculative compositor changes. No firmware flash, EC write, kernel reset or persistent system change is authorized by this test.

Current diagnostics are read-only. The earlier approved Thunderbolt logging flags were restored byte-for-byte. All traces are bounded and will stop at shutdown; no automatic post-boot task is installed.
