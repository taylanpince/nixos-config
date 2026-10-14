Framework 13 AI 300 + LG 27MD5KL investigation, 10 October 2026

This package is a local draft for review, not a submitted support ticket.
REPORT.md states the problem and the model-specific help requested.
COMPARISON.md distinguishes observed results from remaining hypotheses.

Selected evidence:
- nixos-ec-pd.txt: read-only Framework tool report with unrelated NVMe section omitted.
- nixos-hotplug.txt: NixOS post-shutdown journal lines 1384-1402, hostname replaced
  and USB serial number redacted.
- fedora-hotplug.txt: complete 14-line last labeled Fedora hotplug kernel trace.
- {nixos,fedora}-{drm-status,typec,power,thunderbolt-list}.txt: original snapshots.

NixOS source: 20261010T122735-left-rear-module-after-shutdown-Kstoz1
Fedora source: 20261010T111336-fedora-left-rear-connected-WI6uSJ
Fedora trace: 20261010T111242-fedora-left-rear-trace-5GvFca

File paths in the reports refer to the original local investigation tree.
Full boot logs, udev logs and camera images are retained locally, not included.
Early Fedora DRM cleanup warnings are described in the reports; the complete
boot log is available for further review if specifically needed.
Known personal hostname, hardware serials and network addresses were checked
in these selected files. Review before external sharing.

Additional 10 October EC/UCSI engineering evidence:
- nixos-ec-failure-live.txt: source20261010T121518Z-ucsi-probes-N3nlVt,
  ec-console-live.txt lines195-310, omitting POST codes, host-event notifications,
  battery percentages and SOC power-limit chatter. Original event order retained.
- nixos-ucsi-with-ec.txt: request/return and connector-change records from that
  capture's decoded trace, retaining raw command arguments and monotonic times.
- ec-ack-regression.txt: offline actual-function fixture, pinned public EC source,
  original false-success reproduction and RFC guard results. Not a hardware test.
See docs/EC-ACK-INVESTIGATION.md for source pin, limits and capture cleanup checks.

Local PDO-suppression trial:
- ucsi-pdo-trial-tests.txt: eight offline source-function checks.
- pdo-trial-{A1,B,A2}-ucsi.txt: decoded request/write/return and connector events
  from the A/B/A run, filtered without kernel journals or personal identifiers.
  Source directory mapping and interpretation: docs/PDO-TRIAL-RESULTS.md.
  Targeted partner-query writes5/0/7; no display recovered; stock restored.

UCSI backend-off trial:
- ucsi-backend-off-probe-stats.txt: actual request/write/return counts, all zero.
- ucsi-backend-off-ec-port3.txt: only port3 from the unbound EC endpoint query.
- ucsi-backend-off-hotplug.txt: full trial hotplug journal minus USB serial-value
  line, with hostname replaced by HOST.
- ucsi-backend-off-{drm,thunderbolt}.txt: endpoints before stock rebinding.
Source/coverage/limits and restoration: docs/UCSI-BACKEND-OFF-RESULTS.md.
