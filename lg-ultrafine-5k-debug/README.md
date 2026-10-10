# LG UltraFine 5K investigation

Goal: stable native 5120×2880@60 on Framework 13 Ryzen AI HX 370, NixOS and Hyprland, with eDP preserved. The working brief is [the investigation plan](../framework-lg-ultrafine-5k-investigation.md).

**Latest finding:** Fedora44 Live on kernel6.19.10 reproduces NixOS6.18.44's failure: transient LG USB hubs, UCSI debug-accessory state, no external Thunderbolt router, disconnected DP connectors and empty external EDIDs. [Comparison and limitations](docs/NIXOS-FEDORA-COMPARISON.md). Firmware/interoperability and shared Linux-driver behavior remain possible; root cause is not proven. **Next: Framework engineering review using the prepared [support report](docs/FRAMEWORK-SUPPORT-DRAFT.md).** Native5K remains unresolved.

**Escalation posted with owner approval:** [Framework issue225 comment](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-6097047597), 10 October 2026, under `taylanpince`. Published text verified against `docs/FRAMEWORK-ISSUE-COMMENT.md`. Await model-specific guidance; raw evidence package remains local.

Current status: BIOS 04.02 and both PD controllers at 0.0.21 verified; LG model **27MD5KL**, original approximately one-metre cable. Last confirmed setup: LG rear-left, charger disconnected, keyboard front-right. Both rear ports fail to enumerate the LG, including with the charger absent. Camera shows LG black. Both USB4 hosts exist, but no external Thunderbolt router, external EDID or connected external DRM connector is present. LG USB hubs appear briefly and disconnect during controlled tests. The EC PD query reports rear-left as `Debug`, no PD contract, VCONN off and 0 W negotiated. This is reported firmware status, not an electrical measurement or a proven firmware defect. The approved Thunderbolt debug trace found no suitable DP OUT endpoint; logging was restored with identical before/after flags. Focus on link/negotiation before compositor configuration.

Owner confirmed the same cable and display work on a Mac and requested moving on from cable testing. **Direct attachment is unverified:** removing the module lost basic attachment; reinstalling it restored the partner, reported 5 V port supply and transient LG USB hubs. Treat the direct-only tests separately from the original failure. Powered-off interval and Fedora comparison are complete, both unsuccessful through the module. Physical setup after return from Fedora has not been rechecked; do not assume unchanged connections. A speaker tone signals that an action request is ready in the conversation. Camera snapshots are local and ignored by Git.

Fedora preparation and live test are complete. Media instructions remain as a record; no repeat boot requested.

Version control includes the plan, scripts, findings, posted issue text and [reviewed support evidence](evidence/framework-support-packet/README.txt). Full raw captures, camera images, audio alerts, archives and Fedora media remain local and ignored. References to timestamped raw evidence directories require those local files.

Run the collector as the logged-in desktop user:

```bash
bash scripts/collect.sh descriptive-run-label
bash scripts/trace.sh descriptive-run-label 600
```

Each collector or trace invocation writes a new private directory under `evidence/`. These two scripts query the system; they do not authorize devices, change modes, reload drivers, or invoke sudo. Missing tools and command failures are recorded. Host access is needed for desktop sockets, device nodes and udev events; a sandbox denial is not a hardware failure. Other scripts include the explicitly invoked temporary logging experiment and destructive USB-media writer; consult their instructions before use.

For the full tool set with this system's pinned nixpkgs:

```bash
nix shell github:NixOS/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57#usbutils github:NixOS/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57#drm_info github:NixOS/nixpkgs/0726a0ecb6d4e08f6adced58726b95db924cef57#edid-decode -c bash scripts/collect.sh descriptive-run-label
```

See [results](RESULTS.md) and the [Fedora checklist](docs/FEDORA-LIVE-CHECKLIST.md). No persistent system configuration changes have been made; the approved temporary logging change is restored.
