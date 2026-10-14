# Approved UCSI backend-off display test

**Completed:** [Results](UCSI-BACKEND-OFF-RESULTS.md). The trace verifies zero
ongoing UCSI requests during the reconnect window, yet no external router/display
appeared and the EC still reported Debug/no contract. Stock binding and all ports
restored; exit0. The following procedure is retained as the experiment record,
not a recommendation to leave UCSI disabled or repeat the failed test.

The owner approved this broader test after the PDO-suppression A/B/A failed.
Goal: determine whether the LG enumerates as an external Thunderbolt device and
display while the Linux UCSI ACPI backend is detached. Charging is supporting
evidence only. This is not a firmware fix and no further ticket post is authorized.

Run from a local terminal after saving work:

```bash
sudo bash /home/taylan/config/lg-ultrafine-5k-debug/scripts/ucsi-backend-off-trial.sh --run
```

Follow the speaker/terminal prompts: disconnect only LG, press Enter, then
reconnect to the same left-rear module at READY and press Enter immediately.
Leave other connections unchanged. Allow about4–5minutes after reconnect and
wait for COMPLETE. Ctrl-C attempts restoration and saves evidence.

## Exact change and interpretation

The script writes `USBC000:00` to the stock driver's
`/sys/bus/platform/drivers/ucsi_acpi/unbind`, leaving the stock modules loaded
and the Thunderbolt driver and both USB4 hosts in place. Keeping the modules
loaded allows the existing UCSI request/write probes to verify inactivity during
the capture. The script refuses an already loaded experimental PDO module,
unexpected DMI/kernel/binding, missing hosts, low battery, existing UCSI probes or
a concurrent trial.

Reviewed installed6.18.44 source: `ucsi_acpi_remove()` invokes
`ucsi_unregister()` and removes its ACPI notification handler. Unregistration
sends SET_NOTIFICATION_ENABLE with a zero mask and removes the Type-C ports.
Thus **the transition itself sends a UCSI command**; the subsequent unbound
observation is the period intended to have no UCSI requests. This test also
changes firmware notification state and removes Type-C role handling; it is not
equivalent to passively suppressing all reads while preserving all other behavior.

Type-C sysfs entries and UCSI power metadata disappearing are expected, not a
measurement of electrical detachment. The script checks Thunderbolt device names,
DRM connector status, EDIDs and modes every5seconds, plus ACAD/battery status.
The internal panel is checked before and immediately after unbinding; no display
configuration is written. Other USB-C peripherals may temporarily be affected.

It records180seconds of UCSI/Thunderbolt probes, with at least120seconds after
the owner's reconnect confirmation. Binding absence and the Thunderbolt module
are checked throughout. After the main observation it reads EC `pdports` and
`pd-info`, each bounded by20seconds, to inspect endpoint firmware status without
depending on the detached UCSI sysfs interface. These EC host-command reads are
separated from the main observation; no PD-control/reset/firmware operation is used.

If no display appears, the failure does not establish firmware as the sole cause:
the removed role/mode handling might itself be required for enumeration, prior
firmware state can persist, and other Linux subsystems remain active. If display
enumeration succeeds, capture its modes/EDID and refine which UCSI interaction
causes the problem rather than permanently disabling the whole backend.

## Restoration

After capture and endpoint reads, the script writes the same device name to
`ucsi_acpi/bind`, verifies its driver link and all four Type-C ports, then records
30seconds with the LG still connected. Rebinding reinitializes UCSI and can change
any connection obtained during the unbound period. The post-restore samples are
kept separate from the test samples.

The EXIT/INT/TERM/HUP handler stops its probe process and restores the binding on
errors or catchable interruption. Bind/unbind writes have25-second timeouts and
the script never forces driver removal. Kernel calls stuck uninterruptibly may
outlast a userspace timeout. SIGKILL/power loss cannot execute the cleanup handler.
If restoration fails, reboot the unchanged normal system. No persistent binding
override, blacklist, installed module, NixOS/boot configuration or firmware changes
are made. The previous external-module taint marker remains until reboot; this
test introduces no custom module.

Manual recovery, if the script cannot complete but the kernel remains responsive:

```bash
printf '%s' 'USBC000:00' | sudo tee /sys/bus/platform/drivers/ucsi_acpi/bind
```

Only do that when the device is still unbound. If it is already bound, inspect
the script's error instead of blindly rebinding. Reboot is the fallback.

## Validation and evidence

`scripts/ucsi-backend-off-trial.sh` passes Bash syntax and ShellCheck; the only
ShellCheck suppression documents intentional argument expansion inside a child
shell. The existing probe runner and speaker helper have already been exercised
by the previous A/B/A. Read-only host checks show kernel6.18.44, stock UCSI,
deviceUSBC000:00 bound, two USB4 hosts and battery79%. Full root preflight and
unbind/rebind remain pending local authentication; the new live runner has not
yet been exercised.

Evidence is private under `evidence/TIMESTAMP-ucsi-backend-off-*/` and returned to
the desktop user's ownership at exit. It contains session/result logs,
before/unbound/restored snapshots, EC endpoint reads and kernel journal. Its
capture.txt identifies the separate trace directory. Raw evidence stays ignored;
reviewed findings will be committed on the investigation branch.
