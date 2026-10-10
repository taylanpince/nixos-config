# Investigation results

## 10 October 2026 — initial connected state

**OBSERVED:** Owner reports LG connected to right-rear USB-C, black, with laptop camera facing it. Authorized camera still `evidence/camera-initial.jpg` shows a black external panel with a reflection of the laptop. It does not establish native resolution or signal presence.

**OBSERVED:** Baseline `evidence/20261010T110758-nixos-right-rear-initial-CUanUS/` and complete-tool snapshot `evidence/20261010T110922-nixos-right-rear-with-tools-pM0fl8/` are separate runs. All commands in the latter's `exit-status.tsv` succeeded. Firmware is 04.02; kernel 6.18.44; Hyprland 0.54.3 built against Aquamarine 0.10.0. Internal eDP is active at 2880×1920@120.

**OBSERVED:** Complete-tool snapshot `drm-status.txt:1–8` has eight disconnected DP connectors; line 10 has connected eDP. `drm-info.txt:68–259` has no external modes/EDID/TILE blobs; `drm-info.txt:348–405` exposes four CRTCs, only the internal panel's CRTC active. This is not a failed atomic modeset or proof of future resource sufficiency.

**OBSERVED:** `thunderbolt-list.txt:2–5` contains only hosts `0-0`, `1-0` and domains. `bolt.txt` agrees. `usb-tree.txt` contains internal devices and a Keychron keyboard, no LG device. The original `lspci` query did not cause external enumeration.

**OBSERVED:** Type-C sysfs has partner objects and power-role information, but no readable partner/cable identity VDOs were exposed by the attempted paths. Their presence alone is not Thunderbolt enumeration. Physical-to-sysfs port mapping is still unverified.

**OBSERVED:** `scripts/alert.sh` successfully played a short tone through `alsa_output.pci-0000_c1_00.6.HiFi__Speaker__sink`, with per-stream volume, without changing global volume or default routing. Successful playback does not independently prove the owner heard it.

**INFERRED:** H1/H2 are the deciding branch. H3 is downstream and untested; H4/H5/H7 cannot be assessed without external DRM/EDID evidence; H6 requires repeated controlled connection states. No root cause established yet.

**EXTERNAL REPORT:** The original HX 370 + UltraFine reporter still had failures after BIOS 3.04 and reported differing cable behavior. This is a useful control experiment, not a diagnosis here: [Framework thread, posts 11–15](https://community.frame.work/t/fw-13-ryzen-ai-9-thunderbolt-dp-display-output-is-broken/69643/11).

**EXTERNAL SOURCE:** Linux v6.18 defines UCSI error 256 as `UCSI_ERROR_UNDEFINED` and prints it through the unknown-error path. It does not identify an overcurrent condition or particular faulty component. Exact installed stable-patch source has not yet been retrieved. [ucsi.h](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/typec/ucsi/ucsi.h), [ucsi.c](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/typec/ucsi/ucsi.c).

**NEXT TEST:** Started bounded trace `evidence/20261010T110801-right-rear-replug-trace-Exxf1G/` at 11:08:01 Europe/Madrid. Asked owner to unplug at the laptop, wait 10 seconds, reconnect to the same port, and identify cable/model. Completion not yet confirmed. Empty event logs before a confirmed reconnect are not evidence of a failed hotplug.

**UNVERIFIED:** Exact LG model, cable certification/length/active status, correct upstream input, working Mac with the exact same cable, and other current physical port attachments. No display/firmware/system changes, device authorization, driver reset or reboot performed.

## Same-port reconnect, approximately 11:12 Europe/Madrid

**OBSERVED:** Owner confirms performing the requested reconnect. Trace `20261010T110801-right-rear-replug-trace-Exxf1G/udev-live.txt:27,79` records `port0-partner` removal at boot-relative 2343.954130 seconds and addition at 2350.001952 seconds (about six seconds apart). Given the requested physical action, this maps the right-rear connection to UCSI `port0`. It does not yet map it to a particular Thunderbolt domain.

**OBSERVED:** The same trace's `kernel-live.txt:1–2` records `UCSI_GET_PDOS failed (-95)` and `unknown error 0` just after insertion. No external Thunderbolt-router or DRM events appeared in that interval. No DROM failure was logged.

**OBSERVED:** Settled post-reconnect snapshot `evidence/20261010T111314-nixos-right-rear-after-replug-2b8ij9/` still has no external router or connected DP connector. `typec.txt` reports `port0` as host/source with an active Type-C cable and zero partner alternate modes. It also reports PD operation but `supports_usb_power_delivery: no`; given the UCSI errors, do not assume every reported capability accurately describes the cable/monitor. Laptop battery is 100%, AC is online. Camera still `evidence/camera-after-replug.jpg` remains black with reflections.

**INFERRED:** This is now a reproduced pre-DRM failure, not just a static snapshot. Prefer physical connection/cable controls and USB4 instrumentation over changing Hyprland monitor rules.

**OBSERVED:** Owner did not hear the first alert despite successful playback. Longer three-second tone played through the laptop speaker; PipeWire reports sink and playback stream unmuted. **Owner confirmed hearing the longer tone.** Use `scripts/alert.sh` for subsequent manual requests.

**NEXT TEST:** Owner asked to identify LG model, cable markings/length, upstream input, and other laptop connections before selecting the next single-variable physical test.

## Additional observations while awaiting physical details

**OBSERVED:** `evidence/fwupd-history.txt:385–400` reports System Firmware update **Success**, previous version `0.0.3.5`, new version `0.0.4.2`, consistent with running DMI BIOS 04.02. This is update-status evidence, not a separate audit of every embedded controller version.

**OBSERVED:** At boot-relative 2552.849–2554.090 seconds, `20261010T110801-right-rear-replug-trace-Exxf1G/kernel-live.txt:3–19` records an LG USB2.1 Hub (`043e:9a61`) and downstream hub (`043e:9a73`) appearing on USB bus 5, disconnecting in under a second, and another UCSI error 256. Physical action at this time is unconfirmed, so this is **not** assigned to the earlier controlled reconnect or any particular cable/port variation. No external TB router or connected DP output observed.

**EXTERNAL REPORT:** Framework's open [PD issue #225](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225) explicitly includes Ryzen AI 300 laptops and asks for cable/port controls plus `framework_tool --versions`, `--pdports`, and `--pd-info`. Later comments describe compatibility work involving older peripherals. This supports collecting PD-level evidence if cable controls fail; it does not confirm this LG's root cause or authorize firmware/reset commands.

**NEXT TEST:** Once physical details are known, compare the same cable on the other rear port, a different certified cable if available, or a direct mainboard connection bypassing the USB-C expansion card—one variable per labeled capture. A deeper dynamic-debug/PD query experiment needs explicit approval for the privileged operations under the original brief. Fedora Live remains the OS comparison; no kernel/compositor patch is justified yet.

## Debug preflight after initial capture

**OBSERVED:** The ten-minute `right-rear-replug` trace ended normally. A subsequent read still shows only the two TB hosts and disconnected DP connectors. The previous goal turn made progress by reproducing the failure, collecting DRM/USB data, and verifying an audible notification; it was not a successful-display result.

**OBSERVED:** `/proc/dynamic_debug/control` is readable without sudo. It contains **272 Thunderbolt callsites, zero with printing enabled**. Saved preflight at `evidence/dynamic-debug-before.txt`. Kernel configuration supports dynamic debug. This permits preparing logging and rollback without changing the system.

**NEXT TEST / APPROVAL PENDING:** Prepared `scripts/debug-window.sh` and `docs/THUNDERBOLT-DEBUG-EXPERIMENT.md` for an explicitly approved three-minute logging window. The script refuses to overwrite pre-existing enabled Thunderbolt logging, enables only that module's printing, and restores it on completion or catchable termination. Syntax checked; privileged writes **not executed**. Speaker alert played and approval requested according to plan §4.5. Physical cable/model/input details remain pending separately.

## 11:25 — owner confirms setup and approves logging test

**OWNER CONFIRMED:** LG is **27MD5KL**. Rear-left has charger, rear-right LG Thunderbolt, front-right keyboard. Owner did manual checks including disconnection and then reconnected immediately before replying. The transient USB-hub event during the earlier long trace therefore remains associated with unspecified manual checks, not a clean same-setup repetition.

**AUTHORIZED:** Owner explicitly approved the prepared debug experiment. Read-only trace started at 11:25:07 in `evidence/20261010T112507-right-rear-approved-debug-trace-M4uBYP/`, session 84434, with a five-minute bound.

**OBSERVED:** The agent's `sudo -n` attempt failed with “a password is required”; see `evidence/debug-window-20261010T1125.txt`. No debug setting was changed by that attempt. Played the confirmed audible alert and asked the owner to run the approved script in a local terminal, then perform a same-port reconnect only after `ENABLED` appears. Password entry stays in the local terminal.

**OBSERVED:** Owner replied “done.” At 11:26:38 the live dynamic-debug control showed all **272 Thunderbolt callsites printing**, confirming the approved setting was active. The trace's `udev-live.txt:263,315` records right-rear `port0-partner` removal at boot-relative 3211.665363 and addition at 3222.548981 (10.9 seconds disconnected).

**OBSERVED:** `kernel-live.txt:34–36` reports UCSI `unknown error 0`, `UCSI_GET_PDOS failed (-5)`, then `unknown error 0` around insertion. Lines 58–67 report host `0000:c3:00.5` DP IN resources 0:6 and 0:7 available, but no suitable DP OUT adapter and no tunnel. No external router, DROM-read failure, or external DRM connector was observed. Similar DP IN availability messages also occur before the unplug and during host runtime resume; they are not proof that the monitor was detected.

**OBSERVED:** Full snapshot `evidence/20261010T112702-nixos-right-rear-debug-after-7kZ2XK/` still lists only hosts and disconnected DP outputs. `evidence/camera-debug-after.jpg` shows the LG black with a laptop-screen reflection. Internal eDP remains active.

**INFERRED:** The failing run does not reach an external Thunderbolt router/DP OUT discovery and DP tunnel creation. This supports H1/H2 and excludes a Hyprland modeset as the immediate cause of this run. Cable compatibility, PD/firmware negotiation, expansion card/port path, and kernel enumeration remain alternatives. Host sleep/resume messages alone do not prove a runtime-PM bug.

**NEXT TEST:** Let the approved window finish and verify printing returns to zero. Asked for current cable origin/length and availability of another certified cable to choose a controlled comparison. Keep cable changes separate from this completed insertion.

**OWNER CONFIRMED:** Current cable is the original LG cable, approximately one metre long. Owner is checking for another Thunderbolt cable. Do not infer its certification revision or active/passive circuitry solely from appearance or estimated length.

**ROLLBACK VERIFIED:** At 11:29:23, Thunderbolt printing returned to **0 of 272** callsites. Saved `evidence/dynamic-debug-after.txt` matches `dynamic-debug-before.txt` byte-for-byte. The approved logging change has been fully restored; no privileged cleanup remains pending.

## Framework power and port comparison

**OWNER CONFIRMED:** The exact same original cable and 27MD5KL work without problems on the owner's Mac. Owner requests moving on from cable testing. This controls basic cable/monitor operation; Framework-specific interoperability remains among the possibilities, without justifying more cable swapping now.

**NEXT TEST:** Read-only trace `evidence/20261010T113029-framework-power-port-comparison-trace-DjKgVB/` started at 11:30:29, ten-minute bound. Asked owner to unplug only the laptop charger from rear-left, retaining LG on rear-right, keyboard front-right, and LG AC power. Observe that state first, then compare rear-left with charger still absent. This separates power configuration from physical port changes. No further debug logging enabled.

**OBSERVED — charger removal:** Owner confirmed removing only the charger. Trace `udev-live.txt:19` records rear-left/UCSI `port3-partner` removal at 3501.022193 seconds. At 3501.354558 seconds, the unchanged LG's `port0-partner` also disappeared, then reappeared at 3501.562113 (lines 75,119). `kernel-live.txt:1–17` records LG USB hubs on bus 5 appearing then dropping, ending with UCSI error 256. This time the transient is tied to a known power-only change.

**OBSERVED — settled right-rear without charger:** Snapshot `evidence/20261010T113232-right-rear-charger-absent-FnKP88/` still has zero external TB routers and eight disconnected DP outputs. Battery reports discharging. UCSI now reports the same cable as passive/type-A and partner as a debug accessory, versus active/type-C previously; treat these inconsistent reports as potentially erroneous negotiation/status data, not a change in physical cable.

**OBSERVED — left-rear comparison:** Owner confirmed moving only LG to rear-left with charger still unplugged. Trace `udev-live.txt:823,873` records `port0` partner removal then `port3` partner addition. LG USB hubs briefly appear on bus 7 and drop, with UCSI error 256. Settled snapshot `evidence/20261010T113415-left-rear-charger-absent-JenPAE/` still has zero external routers and eight disconnected DP outputs. Camera `evidence/camera-left-rear.jpg` is black with reflections; eDP remains active.

**INFERRED:** Neither removing the separate charger nor changing rear USB4 port restores enumeration. This weakens a fault isolated to the right-rear path or a failure requiring two power sources. Negotiation/status instability exists in both configurations. Monitor and exact cable have the independent working Mac control supplied by owner.

**NEXT TEST:** Prepared read-only `scripts/pd-status.sh` using Framework tool 0.6.2 from pinned nixpkgs, selecting the existing `cros-ec` driver explicitly. Queries only `--versions`, `--pdports`, `--pd-info`. `/dev/cros_ec` exists but is root-only. Non-root version query could not read SMBIOS/EC and panicked; that is a tool privilege failure, not evidence of an unknown laptop. Agent `sudo -n` again requires local authentication. Asked owner to run the read-only script locally and save `evidence/pd-left-rear.txt` with current physical setup unchanged.

## 11:36 — EC/PD status with LG rear-left, charger absent

**OBSERVED:** Owner completed the read-only query; all three commands in `evidence/pd-left-rear.txt` exited zero. BIOS 04.02, EC `lilac-4.0.2-fdbf549`, both PD controllers running MainFw 0.0.21; main and backup images both report application 0.0.21. This agrees with the [BIOS 4.02 component versions](https://resources.frame.work/downloads/laptop-13/amd-ryzen-ai-300-series/4.02/).

**OBSERVED:** LG rear-left/port3 reports Type-C state `Debug`, no PD contract, sink/UFP, VCONN off, 0 V/0 mA/0 W negotiated, CC1, active port No. This is EC-reported status, not a voltage measurement. It corroborates the UCSI debug-accessory report through a separate EC query. [Tool v0.6.2 power decoder](https://github.com/FrameworkComputer/framework-system/blob/v0.6.2/framework_lib/src/power.rs) maps returned `c_state=3` to `Debug` and `pd_state=0` to no contract. It does not prove which component caused the failure.

**SOURCE CHECK:** The final `Back: Failed to read Silicon ID/Family` is not evidence of a third failed controller on this laptop. The [tool's controller mapping](https://github.com/FrameworkComputer/framework-system/blob/v0.6.2/framework_lib/src/ccgx/device.rs) explicitly treats Back as unsupported on Framework 13 AI 300; the two supported controllers were read successfully.

**NEXT TEST:** Speaker alert played; asked owner to bypass only the rear-left USB-C expansion card and connect the same LG cable directly to that mainboard socket, charger still absent. This is a connector-path control also requested by [Framework PD issue #225](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225). Await owner confirmation before assigning subsequent events to this setup.

**CAPTURE:** Previous power/port trace completed normally at its ten-minute bound. New read-only trace `evidence/20261010T114045-left-rear-direct-mainboard-trace-oqjvsV/` started 11:40:45 with a ten-minute bound, session 88122. Initial state still has only TB hosts and disconnected DP outputs. There was a brief capture gap between the bounded traces; kernel journal can recover kernel events if needed, but not lost udev properties.

**EXTERNAL UPDATE, NOT A DIAGNOSIS:** Framework's issue author reports a PD compatibility fix for some older peripherals in [25 August update](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5406051643), and a support-distributed test BIOS in [1 September update](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5490733359). The latter explicitly leaves device-specific applicability unconfirmed. No test firmware downloaded or installed here. This is a possible support escalation after physical/OS controls, not proof that this LG has the same defect.

## 11:42 — direct rear-left mainboard connection

**OWNER CONFIRMED:** Removed only the rear-left USB-C expansion card and connected the same LG cable directly to the mainboard socket; charger remains absent.

**OBSERVED:** Snapshot `evidence/20261010T114200-left-rear-direct-mainboard-jwESnK/` completed with all recorded command statuses zero. No external TB router, all eight DP connectors disconnected, eDP active. Camera `evidence/camera-left-rear-direct.jpg` shows black LG with reflections. Battery 91%, discharging. UCSI port3 now has **no partner or cable object** and reports 0 V, rather than the previous debug-accessory partner. This change prevents treating the direct test as an identical negotiation failure.

**OBSERVED:** The earlier power/port trace captured port3-partner removal at boot-relative 4061.141237 seconds. The new direct-mainboard trace has no kernel events so far. There is no evidence of successful direct attachment; physical seating, connector orientation, stopped peripheral/controller state, and reporting failures remain alternatives. Bypassing the card did not restore output, but does not independently prove the card innocent.

**NEXT TEST:** Keep direct connection and charger-absent setup fixed; ask owner to remove only LG AC power for 60 seconds, then reconnect AC. This tests recovery from retained monitor-side state without a laptop reboot or firmware/configuration change.

**OBSERVED — LG AC cycle:** Owner confirmed completing the 60-second AC disconnection with direct LG cable unchanged. Snapshot `evidence/20261010T114405-left-rear-direct-after-lg-ac-cycle-CbL6y8/` still has no port3 partner, external TB router or connected DP output. Camera `evidence/camera-after-lg-ac-cycle.jpg` remains black. No kernel events appeared in the direct-mainboard trace. Removing LG AC alone did not restore detection; this does not rule out host controller state or incomplete physical attachment.

**NEXT TEST:** Verify direct connector seating in the opposite orientation and collect a fresh EC/PD report. Same cable, same socket, charger absent. This is a contact/orientation control, not a replacement-cable experiment.

## 11:46 — direct connector reversed and EC queried

**OWNER CONFIRMED:** Completed the requested plug reversal/seating check and read-only PD query; no housing obstruction reported.

**OBSERVED:** `evidence/pd-left-direct-flipped.txt` (11:45:46) has all three query exit statuses zero. Port3 now reports `Nothing`, no PD contract, sink/UFP, VCONN off, 0 V/0 mA/0 W, active port No. Firmware versions are unchanged. This agrees with the absence of a UCSI partner, unlike the earlier `Debug` connection through the expansion card. Neither reading alone proves electrical continuity or a firmware defect.

**OBSERVED:** Full snapshot `evidence/20261010T114602-left-rear-direct-flipped-aoGpkZ/` still has no external TB router and all DP connectors disconnected. Direct-mainboard trace recorded only two unrelated internal fingerprint-reader USB reset messages around local authentication; these are not LG enumeration.

**INFERRED:** Reversing the directly connected plug and cycling LG AC have not recovered attachment. Failure precedes DRM/Hyprland. Remaining useful controls are a powered-off laptop interval and an independent OS; further compositor changes or repetitive same-state replugging are not justified by current evidence.

**NEXT TEST — MANUAL SHUTDOWN:** Save work, disconnect LG from laptop, keep charger disconnected, shut down normally and leave off for at least three minutes. Power on using battery, log into the same NixOS session, reconnect LG directly to the same left-rear mainboard socket, and report back. LG AC remains on; keyboard unchanged; rear-left expansion card remains removed. Battery was 91% before the latest tests. This adapts Framework issue #225's powered-off interval to preserve the charger-absent comparison. It is not claimed to fully depower/reset the EC, which still has the internal battery. No boot settings or firmware changes are involved. On return capture fresh snapshot, boot ID/kernel journal, and camera before requesting further changes.

## Correction after owner challenges direct-connection baseline

**OWNER OBSERVED:** Laptop showed power-supply detection with the rear-left USB-C expansion module, but not with the direct mainboard connection. Owner questions proceeding with the latter setup.

**VERIFIED:** `20261010T113415-left-rear-charger-absent-JenPAE/power.txt` has ACAD online=1 and port3 UCSI supply online=1, 5 V; direct snapshot `20261010T114602-left-rear-direct-flipped-aoGpkZ/power.txt` has both online=0 and port3 0 V. The earlier battery status remained Discharging and the later EC report said no PD contract, so reported AC presence is evidence of attachment/power detection, not proof of successful negotiated charging.

**CORRECTION:** The direct test changed the failure from detected-but-abnormal attachment to no detected attachment. Although recorded earlier, this difference was not given enough weight when selecting the shutdown comparison. Direct seating/electrical continuity was never established; do not use direct failure to rule out the expansion module or to diagnose the original failure. A powered-off test using that unverified connection is lower value than restoring the demonstrated attachment path first.

**CURRENT NEXT TEST:** Supersedes previous shutdown request. Audible alert played; asked owner to reinstall the same rear-left USB-C module, reconnect LG through it, keep separate charger absent, and report “module restored.” Capture partner, power, TB and DRM state before choosing a reboot or OS comparison. If owner already shut down, record that confound explicitly. `docs/POWER-OFF-TEST.md` marked on hold.

## 11:50 — module restored; original failure reproduced

**OWNER CONFIRMED:** Module restored, LG connected through it; separate charger absent. Boot ID remains `a31925ec-eda6-4de4-9cbc-362ed29fbcdb`, confirming no intervening reboot.

**OBSERVED:** Snapshot `evidence/20261010T115006-left-rear-module-restored-JR6vgW/` has port3 cable/partner objects again, accessory `debug`, zero alternate modes, and UCSI port3 supply online=1 at 5 V/0 A. ACAD online=0 and battery Discharging, unlike ACAD=1 in the earlier module snapshot. Thus attachment/port supply reporting returned, but charging or a valid PD contract is not established.

**OBSERVED:** Snapshot kernel journal at boot-relative 4602–4604 seconds shows `UCSI_GET_PDOS failed (-95)` and `(-70)`, LG hubs `043e:9a61` and `043e:9a73` briefly appearing on USB bus7 and disconnecting, then UCSI error256. All DP outputs remain disconnected and TB sysfs still contains hosts only. The module-restoration trace `evidence/20261010T114937-left-rear-module-restored-trace-FnuZLk/` began after the insertion started; use the snapshot's full boot journal for these events.

**INFERRED:** Reversible module/direct/module comparison establishes that the module restores detectable attachment. Direct-only results are not a valid reproduction of the original failure. Original detected-but-unstable connection now reproduced through the module, so a powered-off comparison can use that setup consistently.

**REVISED NEXT TEST:** Normal shutdown, disconnect LG at laptop and leave charger absent for at least three minutes; boot on battery and reconnect through the same installed rear-left USB-C module. No direct-mainboard connection. Instructions in `docs/POWER-OFF-TEST.md` corrected. If failure persists, prioritize independent Fedora Live evidence rather than further repeated cable manipulations.

## 12:27 — returned after powered-off interval

**OWNER CONFIRMED:** Returned after the corrected shutdown test. New boot ID `65f37186-f6d2-4ec1-a8ab-fa089e74310f` differs from the saved pre-shutdown ID; saved as `evidence/boot-id-after-shutdown.txt`. Off-duration and physical sequence are owner-reported, not independently timed.

**OBSERVED:** Snapshot `evidence/20261010T122735-left-rear-module-after-shutdown-Kstoz1/` completed with all recorded command statuses zero, same kernel 6.18.44. Only TB hosts and eight disconnected DP connectors; internal eDP remains connected. UCSI port3 partner again reports debug accessory, no supported PD, zero alternate modes. Port3 power supply reports online=1, 5 V/0 A; ACAD online=0, battery Discharging at 81%. This is the same detected-but-abnormal module state, not the direct-connection no-partner state. No fresh EC query was performed after boot.

**OBSERVED:** Snapshot `kernel.txt:1384–1402` records port insertion at about 77 seconds after boot: UCSI GET_PDOS errors -70/-95, undefined error256, LG hubs 043e:9a61 and 043e:9a73 on bus7, then both disconnect by 78.29 seconds. Additional error256 messages at ~15 seconds precede this insertion and must not be attributed to it. Camera `evidence/camera-after-shutdown.jpg` shows the LG black with reflections.

**INFERRED:** The powered-off interval and fresh NixOS boot did not recover enumeration. This weakens a condition confined to the previous running OS session, but does not distinguish firmware, host/peripheral compatibility, hardware path or kernel behavior. Compositor modes remain downstream of the observed failure.

**NEXT TEST:** Speaker alert played; asked whether Fedora Workstation Live media is ready or a spare erasable USB is available. Compare the same rear-left module/cable, charger absent, preserve eDP, and capture logs without installing to SSD. Do not repeat direct-mainboard or cable handling tests without new evidence.

## Fedora Live media preparation

**OWNER CONFIRMED:** Spare 64 GB Kingston connected; Mac available to transfer scripts and save live-session logs.

**OBSERVED:** Read-only identification finds Kingston DataTraveler 3.0, serial E0D55E6CBD05196139C100F4, 61,991,813,120 bytes, USB/removable, currently `/dev/sda`. Existing Ubuntu Server 26.04 image plus unmounted ext4 `writable` partition. No device writes performed by agent.

**PREPARED / VERIFIED:** Official Fedora Workstation 44 Live x86_64 build1.7 downloaded to `evidence/fedora-media/`, 2,851,612,672 bytes. Signed checksum validates against Fedora44 fingerprint 36F612DCF27F7D1A48A835E4DBFCF71C6D9F90A6, checked on Fedora's security page. Image SHA256 1620295f6a00c27c3208f0c00b8ece4eab1ec69b9002152d97488bf26a426ddf matches. Verification records saved alongside image.

**PREPARED / NOT EXECUTED:** `scripts/write-fedora-usb.sh` defaults to read-only checks; actual writing requires `--write`, root, interactive `ERASE KINGSTON`, exact by-id identity/capacity/USB checks, and unmounted/inactive device. Rechecks target before writing, flushes data, compares device contents afterward. Shell syntax and actual read-only preflight passed. Owner must authenticate locally and confirm erase; no agent device write or automatic reboot.

**PREPARED:** `evidence/fedora-investigation-kit.tar.gz` contains only collector, trace and revised left-rear Fedora checklist. Owner to copy to Mac before boot, then into live session, and save logs back to Mac before shutdown. Full procedure: `docs/FEDORA-USB-PREPARATION.md`. Await owner write/transfer completion before boot instructions.

## Fedora evidence returned — 10 October 2026

**OWNER CONFIRMED:** Fedora also failed to detect/display the LG. Located supplied captures under this project's `evidence/` (not repository-root `docs/evidence`). Fedora timestamps are UTC: `20261010T111336-fedora-left-rear-connected-WI6uSJ/captured-at.txt` is 13:13:36 Europe/Madrid; do not order it before the NixOS tests by directory name alone.

**OBSERVED:** Fedora44 Workstation Live, kernel **6.19.10-300.fc44.x86_64**, BIOS04.02. Capture `20261010T111336-fedora-left-rear-connected-WI6uSJ/` shows two host routers only, all eight DP connectors disconnected, all eight external EDID files empty, eDP connected with 384-byte EDID. Port3 partner is again a debug accessory, zero alternate modes, advertised PD support No; UCSI supply online at5V/0A, Not charging, battery Discharging. Kernel/Bolt/USB/sysfs queries succeeded. `drm_info` and Hyprland tools were unavailable; no GNOME/Mutter version capture or disconnected snapshot supplied.

**OBSERVED:** Trace `20261010T111242-fedora-left-rear-trace-5GvFca/udev-live.txt:21,82,115` records port3 partner add/remove/add at677.600/678.638/678.780seconds. Its `kernel-live.txt:1–14` records GET_PDOS failures, LG043e:9a61 at679.010seconds, USB disconnect at679.515, downstream descriptor error-71, and undefined UCSI error256 at679.960. Earlier trace `20261010T111047-fedora-left-rear-trace-IW1k43/` repeats the pattern. Full journal has additional earlier attempts, including bus5 activity, whose exact physical sequence is not assigned here.

**OBSERVED / LIMIT:** Fedora kernel journal has four DRM cleanup warnings during plymouthd close/release at~5.36seconds (lines1179–1391), before recorded LG insertion attempts. They do not establish the cause of repeated Type-C/USB loss. Captured despite being outside the leading hypothesis. No external-router DROM failure observed.

**INFERRED:** Independent Fedora environment on a different kernel reproduces the pre-DRM failure. Hyprland configuration and a NixOS-specific userspace problem are strongly deprioritized. Hardware/PD-firmware/peripheral interoperability and shared Linux driver behavior remain candidates. This does not prove a firmware bug or exclude all Linux bugs. H3–H5 and H7 cannot be tested until discovery succeeds; H6 currently describes repeated failed attachment, not successful display resume behavior.

**EXTERNAL CHECK:** Official BIOS4.02 page still marks it latest stable, PD0.0.21. Re-read Framework issue225 engineering updates: older-peripheral compatibility fix discussed25August; support test BIOS mentioned1September with device-specific uncertainty and possible protocol-analyzer follow-up. No new applicable public firmware identified, downloaded or installed.

**NEXT ACTION:** Framework engineering/support review is now more valuable than further compositor configuration or repeated physical controls. Updated `docs/FRAMEWORK-SUPPORT-DRAFT.md` with both OS results and exact requested model-specific PD fix/diagnostic guidance; `docs/NIXOS-FEDORA-COMPARISON.md` records sources and limits. Prepare selected evidence excerpts for review, without full private boot logs/camera images. No message posted externally. Native5K goal remains unresolved.

**PREPARED:** `evidence/framework-lg27md5kl-support.tar.gz` contains the report, comparison, EC/PD query and selected NixOS/Fedora hotplug/sysfs excerpts. USB serial redacted from the NixOS excerpt, hostname replaced, unrelated NVMe section omitted, and known personal identifiers checked. Full raw boot logs and camera images excluded. Archive contents verified; SHA256 `5bcc086bc5b6e268707cbe1400187647eda414d2f2c79963232061554e4ac189`. Ready for owner review; not submitted externally.

## Approved public escalation posted

**AUTHORIZED / COMPLETED:** Owner explicitly approved posting the prepared `docs/FRAMEWORK-ISSUE-COMMENT.md`. Published under `taylanpince` at 2026-10-10T11:31:38Z (13:31:38 Europe/Madrid): [Framework issue225 comment6097047597](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-6097047597). Retrieved comment through GitHub API and verified its body matches the approved file byte-for-byte. Receipt saved locally at `evidence/framework-posted-comment.json`. No raw attachments or support archive uploaded.

**NEXT:** Await Framework's model-specific PD compatibility assessment or diagnostic guidance. No response yet captured. Native5K remains unresolved; no experimental firmware or system changes authorized by posting approval.

## Local engineering assessment and prepared UCSI capture

**SOURCE VERIFIED:** Retrieved exact Linux6.18.44 archive from the installed kernel's Nix derivation. UCSI code sends host requests through ACPI; source includes an unused command trace event (no emitting call), while connector-status tracing is active. Both proposed probe function symbols exist in the running kernel. Public Framework EC branch `fwk-lilac-27116` at `01e6abe45e47b7ce858574b6f49f7547eaf5e33a` forwards host commands to CCG8 controllers and caches controller-reported PD/Type-C state. Installed EC hash `fdbf549` could not be resolved publicly, so source equivalence to BIOS4.02 is not established.

**HYPOTHESIS, NOT FINDING:** Optional host PDO/identity queries might trigger or aggravate the PD compatibility failure. Their journal errors could equally be consequences. A command/state timeline and then a controlled query A/B test are needed. Existing partner-PDO and LG-gram quirks do not directly implement a justified workaround for this monitor.

**PREPARED:** `scripts/ucsi-probe-window.sh` records request/write/result probes plus connector/TB tracepoints in a private instance for120seconds and removes its probes on completion or catchable interruption. Root/local authentication needed; no negotiation commands, driver reloads or firmware writes. `scripts/decode-ucsi-commands.sh` annotates raw arguments. `patches/0001-ucsi-restore-command-completion-tracing.patch` adds the missing trace call and raw command text; it is instrumentation, not a fix. Full source references, experiment interpretation, caveats and rollback: `docs/LOCAL-ENGINEERING.md`.

**VALIDATED / LIMITS:** Bash syntax and ShellCheck pass; six decoder vectors match expected command fields; invalid duration rejected. Patch application dry run passes against6.18.44. No compile or kernel load performed. Live tracefs registration/cleanup has not yet been exercised. Owner asked to run the bounded capture; waiting for results. Keep the6.18 kernel series for the repo's documented CrowdStrike constraint.

### Follow-up: diagnostic module compile verified

**PROGRESS:** Retrieved the matching6.18.44 development closure and compiled the instrumentation patch with GCC15.3.0/binutils2.46. Module link and modpost succeeded; `modinfo` vermagic is `6.18.44 SMP preempt mod_unload`. BTF debug metadata skipped because packaged build files lack `vmlinux`. No installation, loading, boot change or system rebuild. Added `scripts/build-ucsi-instrumentation.sh` and verified its full compile-only run plus ShellCheck. Reproducible run artifacts: ignored `evidence/ucsi-build-7H3b0k/` (build.log, modinfo.txt, module.sha256).

**CURRENT LIMIT:** No UCSI capture process or evidence directory exists yet. Read-only sysfs still lists two host routers, all eight external DP connectors disconnected, eDP connected. The first two-minute probe capture still needs the owner's local authentication and controlled reconnect. Compile success does not demonstrate a display fix or justify changing negotiation behavior.

## UCSI capture completed: transient charging and spontaneous failure

**OWNER CONFIRMED:** Completed capture without errors; LG initially continued charging. After the agent identified a later loss, owner confirmed no additional touching/reconnection and LG on left-rear. Separate-charger presence not yet explicitly reconfirmed.

**OBSERVED:** `20261010T115207Z-ucsi-probes-DxUUhQ/` records27 requests,27 returns,60 writes, zero missed probes or buffer losses, successful cleanup. Initial direct sysfs read confirmed battery Charging and port3 supply PD20V/4.7A limit. Trace reports PD and UFP partner, successful PDO queries after one initial-95 failure, and no partner altmodes. About42seconds later it reports detach/reattach as debug accessory, transient LG hubs and loss of PD. No UCSI commands for~40.5seconds before the status query reporting loss. Owner confirms spontaneous event. Follow-up60 samples all Discharging,5V/1.5A reported. No GET_PD_MESSAGE requests occurred. Host-only TB transactions; packet error7 is plug-event ACK, not a fatal error.

**LIMIT:** Initial20V read is in conversation tool output; the saved collector already spans/follows the drop. Camera no longer faces LG, so that snapshot cannot establish its visual state. Sysfs still shows no external router and all external DP disconnected. Timeline and inference limits: `docs/UCSI-TRACE-20261010.md`; reviewed excerpt versioned under `evidence/framework-support-packet/nixos-ucsi-command-timeline.txt`.

**NEXT:** Prepared/source-reviewed `scripts/ec-console-snapshot.sh` to read existing EC console, uptime and PD state without changing connections or firmware. Bash/ShellCheck pass. Owner asked to run it with local authentication. Query suppression is not yet justified; inspect EC-side events before choosing a behavioral intervention.

### EC snapshot returned; failure event already outside retained buffer

**OBSERVED:** Owner ran `ec-console-snapshot.sh`; all four queries returned0. `20261010T120050Z-ec-console-UbE18K/` confirms port3 Debug/no PD contract/0V, ports0/1 Nothing, port2 sourcing5V/1.5A, both PD controllers0.0.21. Console is4096bytes, starts mid-line and retains only~188seconds, later than the failure~7m46s before collection. No inference about errors at the failure can be drawn from their absence in this truncated window.

**PREPARED:** Added optional `--capture-with-ec` mode to the tested UCSI window. It streams the read-only console, records EC/kernel clock anchors and one-second power samples while retaining the same UCSI probes and automatic cleanup. No firmware or negotiation changes. Bash/ShellCheck and harmless timeout termination test pass; combined live run pending. One controlled left-rear reconnect will now retain the EC events that the delayed snapshot lost. See `docs/UCSI-TRACE-20261010.md` for exact effects and procedure.

### Combined EC/UCSI capture: acknowledgment mismatch and offline candidate

**OBSERVED:** `20261010T121518Z-ucsi-probes-N3nlVt/` ran14:15:18–14:17:19 and restored normally. The owner's report that it had not reached RESTORED arrived before the deadline; host processes subsequently exited and cleanup.txt confirms removal. 20 request/20 return/46 write probes, zero misses/overruns. EC reader terminated by cleanup (143). Owner saw one blip then cutoff. EC logs a PD contract,20V limits, AC on for~0.67s, then disconnect/reconnect and AC off. UCSI returns to debug accessory. One-second battery polling misses the brief pulse; all117 samples Discharging.

**OBSERVED / ORDERING:** EC6608.803 logs unexpected IRQ0 for controller1/register0x2032, with device0, port0=0, port1=0x0886. Disconnect follows at6609.2386. VBUS FET-control error5 messages are after disconnect. Do not mistake those later errors for a demonstrated trigger. Cable alternate-mode UCSI failure also follows the bad state. Full ordering, clock/timing caveats and reviewed excerpts: `docs/EC-ACK-INVESTIGATION.md`.

**OFFLINE REPRODUCED:** Extracted actual `cypd_write_reg8_wait_ack` from pinned public EC commit01e6abe. Hardware mocks demonstrate false success for the captured tuple, a matching IRQ with an asynchronous event, and a wrong-port ACK. RFC guard returns BUSY without clearing pending events. All8 regression cases pass with guard; baseline reproduces exactly3 false successes. Bash syntax/ShellCheck and warning-as-error compile pass. Test output and reviewed trace excerpts are versioned.

**LIMIT / NEXT:** Installed `lilac-4.0.2-fdbf549` is not verified as this public source. Installed extended-PD logging differs from its handler. Charge-port callers ignore helper errors/update cached state, so the guard alone is not a fix ready for firmware. No firmware/kernel/system changes. Next: Framework review of exact source/build, ACK/event serialization and recovery, with model-specific diagnostic firmware if applicable. Follow-up text prepared locally; not posted. Native5K remains unresolved.

### Local Linux fork prepared at owner's request

**OWNER DIRECTION:** No more ticket posts while awaiting the existing response. Investigate local workarounds/forks. No external action taken.

**PREPARED / COMPILED:** Patch0003 adds default-off `lab_skip_partner_pdos`, limited to Framework Ryzen AI300 DMI and connector4. It suppresses partner PDO reads and clears their destination; no other queries or reported connector state are changed. Eight actual-function offline checks pass. Build `ucsi-build-CHVJka` links/modposts successfully against exact6.18.44; parameter and vermagic verified. BTF skipped for absent vmlinux. Build also includes diagnostic patch0001. Nothing installed or loaded.

**PROPOSED / LIMIT:** A/B/A transient module replacement, flag0/1/0 with equal backend reloads, trace verification and stock-module/reboot rollback. Reload may affect all Type-C ports; missing power metadata is expected in B. This tests a lower-confidence query-triggered hypothesis; the EC defect is not fixed by it. Activation needs approval under the working brief. Full comparison, alternatives and rollback: `docs/LOCAL-WORKAROUND-OPTIONS.md`.
