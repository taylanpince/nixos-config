# UCSI capture: charging followed by spontaneous loss

Capture: `evidence/20261010T115207Z-ucsi-probes-DxUUhQ/`, 10 October2026,
13:52:07–13:54:07 Europe/Madrid. Linux6.18.44, BIOS4.02. Owner confirms LG on
the left-rear port and **no further touching/reconnection after the requested
unplug/wait/replug**. Separate-charger presence is awaiting explicit confirmation.

## What changed

The owner observed charging through the LG. The agent's initial direct sysfs read
confirmed battery `Charging`, ACAD online, and connector4 (`port3`) power supply
`[PD]`, 20V, current limit4.7A. This is a negotiated/reported limit, not a measured
94W draw. That initial read is in the conversation tool output; the later saved
collector ran across/after the drop and already reports discharging.

The trace shows a normal UFP partner and PD power mode for roughly42seconds,
then a reported detach/reattach as a debug accessory, without human intervention.
A later60-sample, one-minute poll found the battery **Discharging throughout**,
with connector4 reporting5V/1.5A Type-C power. Charging was real but not sustained.

## Trace integrity and timeline

All27 request probes and27 return probes were recorded, plus60 ACPI-write probes.
Miss counters and all per-CPU buffer overruns/drops are zero.523 trace records were
retained. The script reports successful removal of its instance/probes and returned
file ownership to the desktop user. The initial root-only directory was a still
running capture, not an ownership/cleanup failure.

The [reviewed command timeline](../evidence/framework-support-packet/nixos-ucsi-command-timeline.txt)
preserves raw command values, decoded recipients and return values. Times below
are boot-relative monotonic seconds.

| Time | Observation |
| --- | --- |
| 2160.239581 | Connector4 reported disconnected during requested unplug. |
| 2169.907589 | Reconnect: partner type2 (UFP), initially sourcing, Type-C1.5A. |
| 2170.013837 | PD mode reported, still sourcing. |
| 2170.013885–2170.164727 | Partner source-PDO query: first4 PDOs returns16bytes; offset4 request returns-95. |
| 2170.203707–2170.295903 | Power role becomes sink, then PD mode with a nonzero RDO. |
| 2170.295936–2170.752805 | Source-PDO queries succeed, returning16bytes then4bytes. Updated RDO `428759d6`. |
| 2171.008009–2171.098628 | Cable SOP-prime alternate-mode request returns-5; journal says undefined/unknown error0. |
| 2171.150777–2171.306588 | Further partner source and sink PDO queries succeed. |
| 2171.306637–2171.595507 | Four partner SOP alternate-mode requests return0bytes (no modes). |
| 2171.570554 | Last ACPI UCSI write before the long quiet interval: command-completion ACK. |
| 2212.086509 | Next UCSI request: connector-status read from connector-change handling, after~40.5s without UCSI commands. |
| 2212.126470 | Status reports disconnected. |
| 2212.442170 | Status reports connected, partner type5 (debug), Type-C1.5A, no PD RDO. |
| 2212.428041–2213.041018 | LG USB2 hubs043e:9a61/9a73 appear and disconnect. |
| 2213.464031 onward | Cable details / cable alternate-mode queries occur after the bad partner state and hub loss; latter query fails-5 with error256. |

There is **no GET_PD_MESSAGE request in this window**. The one GET_PDOS failure
did not immediately prevent a PD sink contract: subsequent source/sink queries
succeeded and charging was observed. This weakens an immediate query-triggered
failure explanation. It does not exclude delayed effects of earlier commands,
kernel behavior outside UCSI, or a timing-sensitive interaction.

Thunderbolt traffic addresses host route0 only; no external-router transaction
appears. Host-port events are acknowledged with `TB_CFG_PKG_ERROR error=0x7`:
in this kernel's `drivers/thunderbolt/tb_msgs.h`, value7 is
`TB_CFG_ERROR_ACK_PLUG_EVENT`, the normal plug-event acknowledgment, not evidence
of a fatal link error. Some later host traffic occurs in the collector's `lspci`
task and must not be mistaken for the LG appearing.

## Current state and implications

Saved snapshot `evidence/20261010T135308-charging-after-ucsi-trace-Xxyl7U/` contains
two host routers only, all external DP disconnected, internal eDP connected,
debug accessory on port3 and discharging battery. Its `power-follow.txt` confirms
discharging from13:54:01 to13:55:01. No successful video mode was observed.

The camera currently faces the room rather than the LG. The saved image cannot
verify the monitor's visual state; do not describe it as a photograph of a black LG.

**Next:** read the EC's existing console buffer, uptime and PD status while leaving
the connections unchanged. This can reveal controller events around the autonomous
loss without introducing another replug or negotiation change. The source-reviewed
`scripts/ec-console-snapshot.sh` uses Framework tool0.6.2 ConsoleSnapshot/ConsoleRead
and status queries through `cros-ec`, with20s timeouts. It advances the console read
cursor but sends no console instructions, resets, PD-control writes or firmware
updates. Root authentication is needed. Owner has been asked to run it.

A PDO-suppression patch is **not yet justified as a fix**. First establish whether
the EC reports a reset, contract loss, role/mux change or controller error. If the
console lacks the relevant events, the next useful experiment needs a synchronized
EC/kernel recording, or Framework's model-specific PD diagnostic firmware. The
already compiled patch is instrumentation only and remains uninstalled.
