### LG UltraFine 27MD5KL fails before Thunderbolt discovery on Laptop 13 AI 300, BIOS 04.02

Could engineering assess whether this reproduction matches the PD compatibility work discussed in this issue, and whether a model-specific fix or further diagnostic is available?

**Hardware / firmware**

- Framework Laptop 13, AMD Ryzen AI 9 HX 370, mainboard FRANMGCP09.
- BIOS 04.02; EC `lilac-4.0.2-fdbf549`; both left/right PD controllers running MainFw **0.0.21**. Read with framework_tool 0.6.2, `--driver cros-ec --versions`, `--pdports`, `--pd-info`.
- LG UltraFine **27MD5KL**, original LG cable approximately one metre. The exact monitor/cable combination works on a Mac, checked during this investigation.
- Initial layout: LG rear-right through USB-C expansion module, charger rear-left, keyboard front-right. Controlled tests then removed the charger and moved LG to rear-left through its USB-C module.

**Reproduced on two Linux environments**

| Environment | Kernel | Result |
| --- | --- | --- |
| NixOS 26.05, Hyprland 0.54.3 | 6.18.44 | No external Thunderbolt router; eight disconnected DP connectors |
| Fedora 44 Workstation Live | 6.19.10-300.fc44.x86_64 | Same, with all external EDIDs empty |

Both Thunderbolt host routers enumerate. Internal eDP works. LG USB2 hub `043e:9a61` appears briefly, then disconnects; downstream `043e:9a73` sometimes enumerates before dropping. Both environments log UCSI GET_PDOS failures and `unknown error 256`.

The last Fedora left-rear trace records port3 partner add/remove/add at 677.600 / 678.638 / 678.780 seconds after boot, LG hub discovery at 679.010, disconnect at 679.515, and UCSI error256 at 679.960. Settled port3 reports a **debug accessory**, zero alternate modes, no advertised PD support. UCSI reports 5 V / 0 A, explicitly Not charging on Fedora; battery remains discharging.

The EC query on NixOS with LG through the rear-left module reports:

```text
USB-C Port 3:
  Type-C State: Debug
  PD Contract: No
  Power Role: Sink
  Data Role: Ufp
  VCONN: Off
  Negotiated: 0.000 V, 0 mA, 0.0 W
  CC Polarity: CC1
  Active Port: No
```

**Completed controls / limitations**

- Both rear ports fail on NixOS, with and without the separate charger. The labeled Fedora captures are rear-left.
- Normal shutdown with external power disconnected for at least three minutes, followed by boot on battery and module reconnection, reproduced the failure. This differs from the issue's sequence by keeping the separate charger absent on startup.
- Removing the USB-C module lost *all* partner detection, including after LG AC cycling and plug reversal. Reinstalling the module restored detectable but unstable attachment. Direct seating/electrical continuity was not established, so this does **not** rule out the module.
- Bounded NixOS Thunderbolt debug logging showed available host DP IN resources but no suitable DP OUT endpoint. No external router or DROM-read failure observed. Debug flags restored afterward.
- Fedora also logs DRM cleanup warnings during plymouthd close/release around 5.36 seconds, before the LG insertions; causality is unproven. GNOME/Mutter versions and drm_info were not captured. Kernel, USB, Bolt and sysfs evidence was captured successfully.
- A shared Linux-driver defect remains possible; this is not a proven firmware diagnosis. First affected BIOS and original onset date are unconfirmed.

Does the older-peripheral PD fix described in the September update apply to **Laptop 13 AI 300 / PD0.0.21 / LG27MD5KL**? If a test BIOS is appropriate, please provide the exact model-specific package, verification details and rollback procedure. Otherwise, what targeted diagnostic or protocol-analyzer capture would help distinguish firmware compatibility from a shared Linux-driver problem? No experimental firmware has been installed. Full logs are retained locally; selected excerpts can be supplied.
