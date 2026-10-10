# Partner-PDO suppression trial: no display enumeration

10 October 2026, 22:11–22:21 Europe/Madrid. Approved temporary A/B/A replacement
of UCSI modules completed with exit0. The experimental switch demonstrably
suppressed the intended queries, but **none of the three legs detected the LG as
a display or enumerated an external Thunderbolt router**. Do not retain this
patch as a working workaround. Native5120×2880@60 remains unresolved.

Parent evidence: `evidence/20261010T201101Z-pdo-aba-Y2hkZW/`.
Same compiled6.18.44 binary, flag0/1/0; backend reloaded for every leg; stock
modules restored between legs and afterward. Owner performed terminal-prompted
reconnects through the left-rear module. Collection used UCSI/TB probes and
5-second sysfs snapshots, without continuous EC-console reads in any leg.

| Measure | A1: normal queries | B: suppressed | A2: normal queries |
| --- | --- | --- | --- |
| Capture start | 22:11:19 | 22:14:43 | 22:18:05 |
| Capture duration | 180s | 180s | 180s |
| Loaded parameter | N | Y | N |
| Partner GET_PDOS writes, connector4 | 5 | **0** | 7 |
| Request/write/return probes | 30/69/30 | 27/57/27 | 34/78/34 |
| Missed probes / buffer losses | 0 / 0 | 0 / 0 | 0 / 0 |
| Router/DRM snapshots, including before/after | 33 | 36 | 36 |
| External Thunderbolt router in snapshots | None | None | None |
| External DP connected / nonempty EDID | None / none | None / none | None / none |
| Internal eDP | Connected throughout samples | Connected throughout samples | Connected throughout samples |
| Final failure transition | Disconnected → debug | Disconnected → debug | Changed to debug; no separate disconnected sample |

All152 TB TX/RX records in each capture address host route0 only. Snapshot router
lists contain only0-0,1-0,domain0,domain1. All external EDID files are empty.
Battery samples were Discharging and ACAD offline throughout all three legs;
5-second sampling does not exclude brief pulses. Charging is supporting evidence,
not the trial's success criterion.

## What the traces establish

- A1 first reports UFP at kernel6072.239535, then disconnect at6073.319258 and
  debug accessory at6073.459522. Partner PDO reads occur before and after the loss.
- B reports UFP at6266.975747, PD sink at6267.344765, disconnect at6267.815832,
  and debug accessory at6268.031742. No connector4 partner-PDO request reaches
  the ACPI-write probe. Local PDO requests still occur, confirming the narrower
  intended suppression. The driver also logs its lab-switch warning.
- A2 reports UFP at6467.215609 and debug accessory at6468.691598. Its status
  event combines change bits rather than showing a separate disconnected state;
  do not invent an intermediate status sample. Partner queries are restored.

The B leg's later sysfs partner `accessory_mode=none` did not establish recovery:
the trace already retained a debug-accessory transition, and no display/router
appeared. A previously created partner object's label can disagree with a later
status event; this observation should not be promoted to a working connection.

The failure **does not require these partner-PDO reads in this reproduced
scenario**. This is stronger than merely seeing fewer errors. It does not exclude
effects from other UCSI commands, UCSI initialization, USB-role handling, shared
Linux code or firmware state retained between attempts. One A/B/A sequence is not
proof that suppressing queries can never influence timing in other scenarios.

## Cleanup and remaining state

All three capture logs say RESTORED and show zero missed probes/overruns/drops.
The wrapper reports STOCK RESTORED after each leg and A/B/A COMPLETE, with exit0.
Read-only follow-up confirms no test/probe processes remain, the experimental
parameter is absent, stock ucsi_acpi holds typec_ucsi, and only host routers exist.
No module, NixOS config, boot entry or firmware was installed persistently.

Kernel taint is4096, the external-module bit introduced by this test. It persists
after unloading; a normal reboot starts a fresh kernel. No warning/oops/forced-load
bits are set in that value. See [Linux taint documentation](https://docs.kernel.org/admin-guide/tainted-kernels.html).

## Next local avenue

Do not iterate on this PDO-suppression patch without new evidence. A broader,
separately approved trial could temporarily remove the UCSI ACPI backend while
leaving the Thunderbolt driver running, then inspect external-router and display
enumeration. That tests remaining Linux UCSI activity as a trigger. It can also
remove required Type-C handling, so a negative result alone cannot prove firmware
is solely responsible. This broader change has not been made.

The EC acknowledgment defect remains an independent public-source finding, not
validated as the hardware root cause or repaired by this kernel experiment.
Further ticket posts remain prohibited by the owner's instruction.

## Reviewed evidence

Raw capture directories (local/ignored):

- A1: `20261010T201119Z-ucsi-probes-zDoUZh`
- B: `20261010T201443Z-ucsi-probes-DNGTBl`
- A2: `20261010T201805Z-ucsi-probes-dwdcDf`

Versioned command/connector excerpts retain raw arguments plus decoder annotations:
[A1](../evidence/framework-support-packet/pdo-trial-A1-ucsi.txt),
[B](../evidence/framework-support-packet/pdo-trial-B-ucsi.txt),
[A2](../evidence/framework-support-packet/pdo-trial-A2-ucsi.txt).
Full module lifecycle, reconnect confirmations, snapshots, EDIDs and journal remain
in the parent evidence directory. Raw journals contain identifiers and were not
copied into the support packet.
