# Proposed three-minute Thunderbolt debug capture

Status: **approved, run, and restoration verified** on 10 October 2026. See `../RESULTS.md` for the captured result. The procedure below documents that experiment; additional logging windows require authorization under investigation plan §4.5.

Hypothesis: the USB-C connection is detected, but firmware does not establish the TB3 link, or the kernel cannot enumerate the monitor/router. Existing ordinary logs show UCSI errors and no external router; they do not expose the Thunderbolt connection manager's decisions.

Preflight: the running kernel has `CONFIG_DYNAMIC_DEBUG=y` and the readable `/proc/dynamic_debug/control` lists Thunderbolt callsites. Their printing flags are currently off; saved in `evidence/dynamic-debug-before.txt`. No debugfs mounting or boot-parameter change is needed.

Procedure after approval:

1. Start `bash scripts/trace.sh right-rear-debug 240` as the desktop user.
2. Run `sudo -n bash scripts/debug-window.sh 180`. If sudo needs a password, the owner runs the same command in a local terminal without `-n`; never send a password in chat.
3. Wait for the `ENABLED` message, play `bash scripts/alert.sh`, and ask the owner for one same-port/same-cable unplug/replug. Record the exact physical setup and insertion time. Do not run a different connection experiment concurrently.
4. Let the logging window end and verify the `RESTORED` message plus no enabled Thunderbolt printing callsites. Capture `collect.sh` after the connection settles.
5. Inspect hotplug acknowledgements, switch initialization, DP IN/OUT discovery, tunnel creation, and any DROM/link failures. Absence of an external router still does not establish the physical cause.

The script enables `module thunderbolt +p` only, refuses to run if any Thunderbolt printing is already enabled, and restores `module thunderbolt -p` on normal completion, interruption, or termination. Other flags/modules remain unchanged. It changes logging verbosity only: no modeset, driver reload, authorization, power-management setting, firmware write, or reboot.

Risk: temporary extra kernel logs and timing overhead may affect a timing-sensitive reproduction. Duration is capped at five minutes; proposed run is three. An uncatchable kill can bypass shell cleanup. If restoration does not complete, use this exact rollback:

```bash
printf 'module thunderbolt -p\n' | sudo tee /proc/dynamic_debug/control >/dev/null
```

Then inspect:

```bash
awk '$2 ~ /^\[thunderbolt\]/ && $3 ~ /p/' /proc/dynamic_debug/control
```

Expected: no output. Reboot also clears this runtime setting, but is not needed for ordinary rollback and is not part of this experiment.

Reference: [Linux dynamic-debug documentation](https://docs.kernel.org/admin-guide/dynamic-debug-howto.html).
