# EC acknowledgment candidate: offline reproduction

The combined capture retained an unexpected PD-controller acknowledgment before
the connection failed. The corresponding public EC helper has a reproducible
false-success path. This is a concrete engineering lead, **not a proven cause of
the LG failure or a firmware fix ready to install**.

## Capture and ordering

Source: local `evidence/20261010T121518Z-ucsi-probes-N3nlVt/`,
10 October 2026, 14:15:18–14:17:19 Europe/Madrid. Owner reports a single blip
followed by immediate cutoff on reconnect. Same left-rear module and LG cable.

The capture completed at its two-minute deadline. `cleanup.txt` records
`RESTORED: removed temporary instance and probes.` All capture processes exited.
20 request probes, 46 writes and 20 returns were retained, with zero missed
probes or buffer overruns/drops. EC-reader exit status 143 is the cleanup SIGTERM.

[Reviewed EC excerpt](../evidence/framework-support-packet/nixos-ec-failure-live.txt)
retains these events; timestamps below are EC seconds, not kernel time:

| EC time | Observation |
| --- | --- |
| 6608.367800 | Port3 connects. |
| 6608.435300 | PD contract negotiation complete. |
| 6608.795500 | Charge manager reports 20V/3A limit. |
| 6608.803000 | Controller1: unexpected interrupt status0 for write to register0x2032. |
| 6608.809300–6608.829000 | Diagnostic reads: device0, port0=0, port1=0x0886. |
| 6608.866200 | AC on. |
| 6608.971800 | Charge manager reports 20V/4.7A limit. |
| 6609.238600 | PORT_DISCONNECT. |
| 6609.262900–6609.327200 | Zero command responses and VBUS FET-control failures, error5, across ports. |
| 6609.379100 | Port3 connects again. |
| 6609.535400 | AC off. |

AC was reported on for about0.67seconds. All117 one-second battery samples say
Discharging; one port-voltage sample reports20V. The sample interval can miss this
short AC pulse. Limits/status are not measurements of delivered current.

The first acknowledgment mismatch precedes disconnect by about0.44seconds.
The logged FET-control failures occur **after** disconnect; they cannot simply be
called its cause. No explicit hard-reset/error-recovery event appears in this
retained window; logging coverage is not established well enough to exclude one.
Some console lines interleave out of timestamp order; the table uses timestamps.

[UCSI excerpt](../evidence/framework-support-packet/nixos-ucsi-with-ec.txt):
kernel3559.230555 reports UFP, 3559.567930 PD sink, 3559.945608 disconnected,
3560.264588 debug accessory. An early source-PDO offset4 query returns-95, but
the subsequent source-PDO reads succeed (16 then4bytes). The cable alternate-mode
query fails **after** the debug state, at3560.597537. No GET_PD_MESSAGE occurs.
EC uptime in the clock anchor has only second resolution: do not infer precise
cross-clock causality between individual EC events and Linux requests.

Continuous console reads introduce EC host-command traffic and may change timing.
The earlier UCSI-only capture sustained PD for~42seconds before an untouched loss;
this capture cannot establish why the duration changed. Neither produced video.

## Reproduced public-source defect

Pinned public source: FrameworkComputer/EmbeddedController,
`fwk-lilac-27116`, commit `01e6abe45e47b7ce858574b6f49f7547eaf5e33a`.

- [cypd_ccg8.c](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/src/cypd_ccg8.c): `cypd_write_reg8_wait_ack`, lines34–127.
- [cypress_pd_common.h](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/include/cypress_pd_common.h): response registers, interrupt masks and event codes.
- [cypress_pd_common.c](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/src/cypress_pd_common.c): charge-port callers and extended-PD handling.

Register0x2032 is the local port1 VBUS FET control register; controller1/local
port1 maps to physical port3. Event code0x86 denotes PD contract completion.

The helper waits for an interrupt, then looks for a response on the requested
port. If the interrupt does not match, it logs the unexpected response and reads
device, port0 and port1 response registers into the same `event` variable. When
the final value is>=0x80, it skips response validation and returns the successful
register-read result. Thus the captured tuple (IRQ0, device0, port0=0, port1=0x0886)
returns **EC_SUCCESS without a command acknowledgment** in the public source.
A matching interrupt carrying an asynchronous event, or an ACK on the wrong port,
can also produce false success.

The fixture extracts the actual function from the hash-verified source and mocks
only hardware primitives. It reproduces all three false-success cases. Valid
device/port ACKs and negative responses provide controls. The RFC guard rejects
missing/mismatched ACKs and asynchronous events with EC_ERROR_BUSY, preserving
them for the event dispatcher. All eight cases then pass.

```bash
bash lg-ultrafine-5k-debug/tests/run-ec-ack.sh
```

The source defaults to ignored `evidence/engineering-source/ec/cypd_ccg8.c`;
an alternate downloaded file can be supplied as the first argument. Fetch that
file from the pinned source link above. SHA256:
`c3f336b336df4422ff5efeaea7e3e535fec3d4269099ef8dab6d14ffc759698b`.
Requires GCC, awk, patch, sha256sum and standard shell utilities. No hardware,
root access, network or firmware build is involved in the test.

Artifacts: [fixture](../tests/ec-ack-regression.c),
[RFC guard](../patches/0002-rfc-ccg8-reject-unacknowledged-completion.patch),
[recorded results](../evidence/framework-support-packet/ec-ack-regression.txt).
Bash syntax and ShellCheck pass; compilation uses warnings as errors except the
original helper's unused-but-set variable. Patch applies without fuzz.

## Why this is not yet a deployable fix

1. Installed EC is `lilac-4.0.2-fdbf549`; the public revision is not verified as
   its source. The log also labels extended PD types3 and4 unknown, whereas this
   public handler supports both. Type6 is also logged unknown. This supports a
   source/build mismatch, not a conclusion that the monitor sent invalid traffic.
2. `cypd_cfet_vbus_control` updates cached FET state even on failure, and
   `board_set_active_charge_port` ignores these return values and reports success.
   Returning BUSY alone therefore does not complete a recovery path.
3. A production solution needs serialized command/event access, bounded retry or
   deferred completion, error propagation and cache updates only after confirmed
   writes. Failed I2C reads/writes also need review. Simply retrying in a loop could
   starve the event task or repeat a command that already took effect.
4. The fixture does not test actual timing, task races, interrupt clearing,
   electrical behavior, or whether this defect causes disconnect. It assumes
   successful register transport and no interrupt pending before the write.

**Next engineering step:** ask Framework to map this trace to the exact installed
EC and CCG8 sources, review the ACK/event race and charge-port error handling, and
provide a model-specific diagnostic/fixed build if applicable. A useful diagnostic
build would record caller/task, expected/actual interrupt mask, response code,
I2C status, returned status and cached FET state for each transaction. Firmware
deployment requires a concrete recovery/rollback procedure and owner approval.

No firmware, kernel, boot or display configuration was changed. The kernel patch
prepared earlier remains instrumentation only and uninstalled. This finding does
not justify suppressing Linux PDO requests or patching display tiling.
