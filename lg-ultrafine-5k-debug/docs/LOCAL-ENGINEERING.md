# Local engineering assessment — 10 October 2026

**Latest:** [Combined EC/UCSI evidence and offline acknowledgment regression](EC-ACK-INVESTIGATION.md)
identify a public EC false-success path matching a captured response pattern.
An RFC guard passes the offline fixture, but installed-source correspondence and
caller recovery remain unresolved; it is not a deployable display fix.

Useful local work remains at the **Linux UCSI ↔ EC ↔ PD-controller boundary**.
Fedora strongly deprioritizes Hyprland as the current cause; it does not eliminate
shared Linux code. No external Thunderbolt router exists yet, so modesetting and
tiling patches cannot address the first observed failure.

## Source findings

Retrieved the installed kernel's **6.18.44** source through its Nix derivation.
Archive SHA256: `0f72d938f06828e82c90405174fe572287db7bfe089e2fc46572a99a7f240d43`.
The three Nix patches concern bridge/request-key helpers and randstruct, not UCSI.
Extracted source is ignored under `evidence/engineering-source/`.

| Exact-source location | Finding |
| --- | --- |
| `drivers/usb/typec/ucsi/ucsi_acpi.c`, `ucsi_acpi_async_control()` | Writes the command into shared memory, then invokes the ACPI write method. |
| `ucsi.c`, `ucsi_send_command_common()` | Serializes requests and translates firmware errors through `GET_ERROR_STATUS`. |
| `ucsi.c`, `ucsi_read_pdos()` | Commands distinguish partner/local, source/sink, offset and count; existing journal errors omit these arguments. |
| `ucsi.c`, `ucsi_pwr_opmode_change()` | Reported PD mode schedules an immediate partner source-PDO query with retries. Other discovery work is delayed. |
| `ucsi.c`, `ucsi_handle_connector_change()` | Traces reported connector status before processing it and scheduling further discovery. |
| `trace.h` and `ucsi.c` | The command trace event is declared but never emitted. Connector trace calls are present. Enabling existing tracepoints alone will miss commands. |

Framework's public EC branch `fwk-lilac-27116`, pinned to
[`01e6abe45e47b7ce858574b6f49f7547eaf5e33a`](https://github.com/FrameworkComputer/EmbeddedController/tree/01e6abe45e47b7ce858574b6f49f7547eaf5e33a),
defines Lilac as an Azalea variant; inherited configuration selects CCG8 controllers.
Its [`ucsi_write_tunnel()`](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/src/ucsi.c)
remaps connectors and forwards host commands to a controller's UCSI control
register. That write starts processing in the controller. Thus a Linux request
could influence controller behavior; seeing an error does not prove it caused it.

The EC's [`cypress_pd_common.c`](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/src/cypress_pd_common.c)
reads PD-contract and Type-C state from controller registers into cached port state.
The `Debug` report is meaningful firmware evidence, not an electrical measurement
or an explanation of how the state arose. This source also has console diagnostics
for PD status and UCSI verbosity; availability on our build is unverified.

**Limitation:** GitHub did not resolve installed EC revision `fdbf549`. This public
branch establishes architecture, not exact correspondence to BIOS 4.02. We have not
located the exact CCG8 0.0.21 implementation. Patching the open EC does not by itself
patch the separate controller's PD policy engine.

## Experiments and potential fixes

| Priority | Engineering work | Deciding evidence |
| --- | --- | --- |
| 1 | Trace UCSI commands/results, connector state and Thunderbolt events on a controlled reconnect. | Does bad reported state precede host queries, or follow a particular query? Timing narrows hypotheses; it does not prove causation. |
| 2 | If a query is implicated, prepare a default-off diagnostic switch in the same 6.18 kernel to suppress/delay only that query on the verified machine and connector. | Repeated stock → modified → stock tests must change PD stability/router enumeration, not just silence errors. |
| 3 | If the failure is earlier, read existing EC console output and obtain Framework's model-specific PD compatibility test firmware. | Compare contracts, partner state and enumeration before/after. A fix below Linux may be needed. |
| 4 | If PD becomes stable but no router appears, inspect USB4 link events, adapter state and runtime power timing. | Then consider a narrow Thunderbolt/AMD USB4 change. Host runtime-resume messages alone do not establish a PM bug. |

Further discriminators, if necessary: pre-OS charging or Windows behavior, and a
known-good Thunderbolt peripheral on this host. A PD protocol analyzer is needed
to observe actual CC-wire packets; UCSI traces do not contain those packets. Keep
the already-working Mac/LG/cable control; do not repeat cable swaps. The earlier
direct-mainboard test remains invalid because attachment itself disappeared.

A query experiment could target `ucsi_get_pdos()` or `ucsi_get_pd_message()`, once
the implicated request is identified. Skipping queries can remove power/identity
information, so do not casually suppress source PDO reads, invent a contract,
force power settings, or reinterpret `Debug` as a normal partner. Existing
`UCSI_NO_PARTNER_PDOS` is not a blanket skip: it still permits partner source-PDO
reads while the laptop is a sink. The `ucsi_gram_ops` quirk matches an **LG gram
laptop**, not an LG display, and is not justified here.

The repo pins Linux 6.18 for CrowdStrike compatibility (`nixos/modules/boot.nix`,
`nixos/flake.nix`). A behavior-changing trial should use an isolated patched 6.18
generation and retain the existing generation for rollback. No system config or
kernel activation has been performed.

## Prepared capture

[`ucsi-probe-window.sh`](../scripts/ucsi-probe-window.sh) creates a private tracefs
instance and three uniquely named probes:

1. `ucsi_send_command_common` entry: requested command, before acquiring the PPM lock.
2. `ucsi_acpi_async_control` entry: command about to be sent, including ACK/error
   queries. Entry alone does not prove the ACPI write succeeded.
3. `ucsi_send_command_common` return: final result after firmware error translation.

Both symbols were verified in the running kernel. The script also enables existing
UCSI connector and Thunderbolt events in its private instance. Captures include
monotonic timestamps, readable and field-format traces, buffer overrun statistics,
probe hit/miss counters and the corresponding kernel journal. Pair request/results
by PID, not adjacency across CPUs. Verify no loss before drawing absence conclusions.

**Effect:** temporary logging overhead and 1 MiB of buffer per CPU. It issues no
negotiation commands, resets, role swaps or firmware writes and unloads no drivers.
Probe registration is additive; other probes and trace instances are preserved.
Root is required to register the probes and access tracefs.

**Rollback:** normal completion, Ctrl-C, TERM or HUP saves the capture, disables its
events, removes its instance and deletes its three probes. No reboot required.
SIGKILL/crash cannot run cleanup. In that case use the recorded `probe-group.txt`
to remove only this instance and its `${group}_request`, `${group}_write`,
`${group}_result` probes (definitions saved in `probes.txt`), or reboot.
Never clear the global `kprobe_events` file. A cleanup error is printed explicitly.

After agreeing to this temporary instrumentation, authenticate in a local terminal:

```bash
sudo bash /home/taylan/config/lg-ultrafine-5k-debug/scripts/ucsi-probe-window.sh --capture 120
```

Wait for **ENABLED**, unplug the LG at the laptop, wait 10 seconds, reconnect through
the **same rear USB-C expansion module**, and keep other connections unchanged.
Report which rear port was used. Leave the terminal open until **RESTORED**.
Omitting `--capture` performs a read-only root preflight; probe registration still
needs runtime validation. Do not use the earlier direct-mainboard arrangement.

Decode afterward (no root or hardware access):

```bash
bash lg-ultrafine-5k-debug/scripts/decode-ucsi-commands.sh PATH/trace.txt > PATH/trace-decoded.txt
```

The decoder shows one-based UCSI connector versus zero-based sysfs port, PDO
direction/recipient/offset/count, and PD-message fields. If the failure precedes a
suspect request, suppressing that request does not explain that attempt. A later
failure is grounds for a controlled query trial, not proof. A reconnect can also
preserve peripheral state from prior attempts; account for that in negative tests.

## Prepared instrumentation patch and validation

[`0001-ucsi-restore-command-completion-tracing.patch`](../patches/0001-ucsi-restore-command-completion-tracing.patch)
adds the missing completion trace call after error translation and exposes the raw
command in normal trace text. This is an observation improvement, **not a display
fix**, and a fallback if dynamic probes are unavailable. It records completion,
whereas the probes additionally record command-entry timing.

The patch passes an application dry run and **compiles successfully** against the
installed kernel's exact 6.18.44 build files using GCC15.3.0 and binutils2.46.
`modinfo` reports `6.18.44 SMP preempt mod_unload`; the resulting module contains
the command tracepoint. BTF generation was skipped because the packaged build files
lack `vmlinux`. This is a compile check, not proof of runtime correctness.
**The module has not been installed or loaded.** Shell syntax, ShellCheck and
decoder vectors pass. **Live capture now passed:** 27 requests/27 returns/60 writes,
zero reported misses/overruns and successful cleanup. The [capture analysis](UCSI-TRACE-20261010.md)
finds temporary PD charging followed by spontaneous loss after a long UCSI-quiet
interval; suppressing a query is not yet justified as a fix.
Future kernel activation requires a concrete proposal/rollback and owner approval
under the working investigation brief.

Reproduce the compile-only check with
[`build-ucsi-instrumentation.sh`](../scripts/build-ucsi-instrumentation.sh). It verifies
the source hash, creates a fresh ignored build directory, applies the patch and
builds only `typec_ucsi.ko`; it never installs or loads a module. Local validated
run: `evidence/ucsi-build-7H3b0k/`, with build log, module metadata and checksum.
The script's full run and ShellCheck passed. If the pinned inputs have been garbage
collected, restore them first (the development closure fetched about825MiB here):

```bash
nix-store --realise /nix/store/0mniicxkibs3lq5nz7g34f78fg3m6qmd-linux-6.18.44.tar.xz.drv
nix build '/nix/store/y7rn8r4ywff7y88n7k25fxk58qymgmkf-linux-6.18.44.drv^dev' --no-link
bash lg-ultrafine-5k-debug/scripts/build-ucsi-instrumentation.sh
```

These store paths identify this machine's investigated build; the recipe assumes
their derivations remain available locally. Nix store downloads do not activate
a new kernel or modify the system configuration.

Primary references:

- [Linux UCSI](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/typec/ucsi/ucsi.c)
  and [ACPI backend](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/typec/ucsi/ucsi_acpi.c).
  These public v6.18 links provide context; local analysis uses exact 6.18.44.
- [Kernel probe documentation](https://docs.kernel.org/trace/kprobetrace.html) and
  [ftrace instances/options](https://docs.kernel.org/trace/ftrace.html).
- Framework's [older-peripheral compatibility finding](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5406051643)
  and [test firmware / analyzer guidance](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5490733359).
  Relevant possible relationship; not confirmation for this LG.
