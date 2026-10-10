# UCSI detached: LG still fails before display enumeration

10 October 2026, 22:29–22:33 Europe/Madrid. The approved backend-off trial
completed with exit0 and restored the stock binding. **No external Thunderbolt
router or display appeared while UCSI was detached, or during the30-second
observation after restoration.** Native5120×2880@60 remains unresolved.

Parent evidence: `evidence/20261010T202923Z-ucsi-backend-off-6Ljz0D/`.
Trace: `evidence/20261010T202947Z-ucsi-probes-aW8stL/`.

## Measurements

| Check | Result |
| --- | --- |
| Trace window | 22:29:47–22:32:47,180seconds |
| Owner reconnect confirmation | 22:29:55.448, leaving about172seconds recorded |
| Backend during35 periodic observation snapshots | Unbound in every snapshot |
| UCSI request / ACPI-write / return probes | **0 / 0 / 0**, zero misses |
| Trace records | 157 retained, no buffer overruns/drops |
| Thunderbolt TX/RX records | 152, all host route0 |
| Router/DRM snapshots including before/after and restoration | 45 |
| External Thunderbolt router | None in any snapshot |
| External DP connected / nonempty external EDID | None / none |
| Internal eDP | Connected in all snapshots |
| Stock backend after test | Bound; all four Type-C ports registered |

The USB4 hosts0-0 and1-0 remained present. Kernel events show the LG043e:9a61
and9a73 USB2 hubs briefly enumerating and disconnecting even without active
UCSI handling. This repeats the pre-display failure, not merely an absence of
Type-C sysfs metadata caused by removing its driver.

After the timed observation, while still unbound, the read-only EC endpoint query
reported physical port3 as **Debug, PD Contract No, sink/UFP, VCONN off,0V/0A**.
This status comes through the cros-ec interface, independently of the detached
UCSI sysfs interface. Both CCG8 controllers remain at0.0.21. Ports0 and2 report
sink devices, port1 Nothing; identities of those other devices were not collected
in this test, so do not infer their cabling from older session descriptions.

## What this rules out, and what it does not

The failure reproduced while there were **no ongoing Linux UCSI requests** in
the recorded reconnect window. Together with the failed partner-PDO suppression
A/B/A, this argues against fixing this reproduced failure by hiding or delaying
those Linux discovery queries. Neither experiment is a useful local workaround.

It does not establish that all Linux effects are irrelevant. Unbinding sends
notification-disable before the recorded window and removes Type-C role/mode
handling that may itself be required. Earlier firmware state can persist; the
Thunderbolt and USB host drivers remain active. Therefore the negative result
does not prove a firmware-only cause. It does independently confirm that the EC
reports the same bad partner state without ongoing UCSI discovery requests.

The public EC ACK/event defect remains a source-level candidate, not a proven
cause on the installed firmware. More speculative UCSI query-suppression patches
are not justified by these results. A firmware-level local fork still requires
matching source, correct caller/error recovery and a verified flash/recovery
method before on-device testing. The earlier RFC guard is not ready to flash.

## Restoration and limits

The trace runner removed its private instance/probes. The wrapper restored
USBC000:00 to the stock ucsi_acpi driver, waited for port0–port3, observed another
30seconds with LG connected, and exited0. Follow-up read-only checks confirm the
binding, ports, connected eDP and absence of test/capture processes. The LG remains
undetected. No persistent system, module or firmware changes were made.

The external-module taint4096 from the earlier PDO experiment remains until a
normal reboot; no additional taint bits appeared. The backend-off test did not
load a custom module. Full raw journals stay local. No external ticket update was
posted, in accordance with the owner's instruction.

Reviewed excerpts:
[probe counts](../evidence/framework-support-packet/ucsi-backend-off-probe-stats.txt),
[EC port3](../evidence/framework-support-packet/ucsi-backend-off-ec-port3.txt),
[USB hotplug](../evidence/framework-support-packet/ucsi-backend-off-hotplug.txt),
[DRM endpoint](../evidence/framework-support-packet/ucsi-backend-off-drm.txt),
[Thunderbolt endpoint](../evidence/framework-support-packet/ucsi-backend-off-thunderbolt.txt).
The hotplug excerpt replaces the hostname and omits the USB serial-value line.
