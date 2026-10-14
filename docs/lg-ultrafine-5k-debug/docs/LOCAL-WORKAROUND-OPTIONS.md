# Local workaround options and prepared Linux fork

## Remaining options after both failed Linux trials

Reviewed again after the backend-off result. Native5K/display enumeration remains
the goal; there is no proven local workaround. No new live change or ticket post
is authorized by this options review.

1. **Borrow a genuine Thunderbolt hub/dock with downstream Thunderbolt.** First
   verify that it enumerates on the Framework, then attach only LG downstream.
   This changes the immediate PD/TB peers and could avoid a direct-connection
   compatibility issue. That is a hypothesis, not a demonstrated fix. Use a path
   capable of this monitor's dual-DP-stream5K operation, not a USB-only hub or
   HDMI adapter. CalDigit's [Element4 specification](https://www.caldigit.com/thunderbolt-4-element-hub/)
   lists USB4-host/Thunderbolt-display and5K60 support; it does not prove this
   Framework/Linux combination works. Borrow/test before buying.
2. **Verified EC restart/reset.** The earlier shutdown did not include a
   before/after proof of EC/PD state clearance. The installed Framework tool has
   `--reboot-ec` and uptime/reset information. Review the exact command path and
   prepare a controlled restart, then verify uptime/reset flags; an EC restart
   may not reset separately powered PD controllers. This could clear retained
   state but cannot fix a persistent compatibility defect. Do not copy generic
   older-board reset instructions onto Lilac without verifying applicability.
3. **A known-working Thunderbolt peripheral on this Framework.** A real TB dock
   or SSD must enumerate as an external router, not merely fall back to USB.
   Success narrows the problem toward LG-specific interoperability; broad failure
   makes host firmware/board diagnosis more valuable. Can be combined with1.
4. **Windows on the same Framework, with its official driver bundle.** This
   changes the USB4/Type-C software stack more substantially than another Linux
   distribution. Use a separately planned spare-disk installation if pursued;
   there is no prepared Windows image and no disk-write authorization here.
   Lower priority: the [earlier firsthand report for HX370 +27MD5KL](https://community.frame.work/t/fw-13-ryzen-ai-9-thunderbolt-dp-display-output-is-broken/69643/4)
   also failed under Windows11, although that report used older BIOS3.03 and is
   not a test of this machine. It cannot substitute for a local comparison.
5. **Firmware engineering.** A concrete offline project remains: identify the
   installed EC image/source, reproduce a stock Lilac build, extend the ACK
   regression to caller failures/event concurrency, then design a complete
   recovery path. A read-only flash dump may help establish build identity; its
   availability is advertised by the local tool but has not been exercised.
   On-device testing still needs verified protection/rollback/recovery. The EC
   and CCG8 policy firmware are distinct targets; no matching CCG8 source has
   been located. Framework's [debugger documentation](https://github.com/FrameworkComputer/FrameworkDebugger)
   describes EC debug connections separately from the JPD connector for PD-chip
   programming, which generally requires fitting a connector and Cypress tools.
   This is not another drop-in kernel-module experiment.
6. **USB-PD/CC protocol analysis.** Capture the failing Framework exchange and
   working Mac exchange with equipment that preserves the relevant Thunderbolt
   path. This can identify the actual packets/reset/CC sequence rather than only
   host-reported state. Framework's [maintainer explicitly describes analyzer
   capture as the next step for persistent compatibility failures](https://github.com/FrameworkComputer/SoftwareFirmwareIssueTracker/issues/225#issuecomment-5490733359).
   This needs suitable hardware or a lab; a voltage/current display alone is not
   an equivalent trace.

**Practical order:** borrow/test a suitable TB hub if available; otherwise prepare
a verified EC restart as the next low-equipment diagnostic. For sustained local
coding work, choose the firmware source/build/recovery investigation. Keep USB4
runtime-power experiments lower priority unless new logs implicate suspend; both
recent traces retained functioning host routers but no external router.

Respect the owner's working Mac/cable control and request to stop cable swapping.
BIOS downgrade is not the proposed next step: failure predates4.02, and rollback
support/PD-version effects have not been established. Framework's existing ticket
is awaiting a response; this review neither adds a post nor opens a new contact.

**Trial now completed:** [Results](PDO-TRIAL-RESULTS.md). Suppression worked as
implemented but did not restore Thunderbolt/display detection in any leg. Stock
modules are restored. The runner/proposal below is retained as a reproducible
record, not a recommendation to repeat or install the unsuccessful patch.

**Activation approved:** Owner agreed to proceed after reviewing the proposal.
Prepared `scripts/ucsi-pdo-trial.sh --run`: one locally authenticated A/B/A
session with exact module hash/kernel/DMI checks, exclusive lock, bounded manual
prompts,180-second captures,5-second Thunderbolt/DRM/EDID snapshots, progress
messages and stock-module restoration between legs and on catchable interruption.
Bash syntax and ShellCheck pass; the live run is pending local authentication.
The owner emphasized that display detection/native5K is the goal; charging is
supporting evidence, not an acceptance requirement.

```bash
sudo bash /home/taylan/config/lg-ultrafine-5k-debug/scripts/ucsi-pdo-trial.sh --run
```

Save work first. Follow terminal prompts: disconnect LG and press Enter, then
reconnect to the same left-rear module only at READY and press Enter immediately.
Each leg retains at least120seconds after that confirmation. Leave other
connections unchanged. Speaker prompts are attempted through the desktop user's
audio server; alert failure is printed. Ctrl-C stops and attempts restoration.
A process crash/SIGKILL cannot run cleanup; reboot restores the unchanged installed
system. An externally built module may taint the running kernel; that taint can
persist after stock restoration until reboot. The script never forces an unload.

Historical proposal and preparation details follow; approval is now recorded.

No working local workaround is established yet. We can test a Linux-side change
without waiting for a ticket response. The strongest source-level defect found so
far is in public EC code, but its relationship to installed firmware and the
disconnect remains unproven. Nothing below has been activated. Do not post the
prepared Framework draft; the owner explicitly asked to wait for a response.

## Options, in proposed order

| Option | What it tests or changes | Practical limit |
| --- | --- | --- |
| Local Linux UCSI fork, prepared and compiled | Suppress partner PDO capability reads on connector4 while preserving status, role, cable and altmode handling. Tests whether these reads trigger or aggravate the firmware failure. | It cannot repair the EC's ACK handling. Earlier loss after40s without requests weakens the hypothesis. Missing power metadata is expected. |
| Stock driver disabled for one controlled session | Remove Linux UCSI traffic entirely, then observe EC charging and USB4 enumeration. This is a broader discriminator if the narrow trial fails. | UCSI also participates in USB-role/mode handling; failure with it disabled does not isolate firmware. Removal/registration can reset the interface. Not a general configuration recommendation. |
| Public EC fork | Develop ACK/event serialization, correct failure propagation and cached FET-state handling, then reproduce them offline. | The current RFC guard is only one part. Exact installed source and verified flash/recovery method are missing; separate CCG8 policy firmware is not fixed by an EC fork. Not ready for on-device testing. |
| USB4 runtime-power experiment | Temporarily keep the relevant host awake if new evidence ties failure to suspend/resume. | No such causal evidence yet; two host routers exist and failure is already visible at the PD layer. Lower priority than the tests above. |

An additional inexpensive discriminator is watching whether LG charging survives
while stopped in firmware setup before Linux starts. A failure there would show
Linux activity is not necessary for that attempt. Stable charging there would not
prove Thunderbolt/video works or identify the faulty component. This needs a
manual reboot and is not being requested yet.

No cable swap, display-driver fork, forced role/voltage, or reinterpretation of
Debug as a normal partner is justified by the evidence. We have not established
that an intervening dock would help or preserve native5K, so buying one is not the
recommended next step.

## Prepared driver experiment

Patch: [0003-lab-ucsi-skip-partner-pdos.patch](../patches/0003-lab-ucsi-skip-partner-pdos.patch).
It is a local experimental fork of `typec_ucsi`, not an upstream hardware quirk.

- Parameter `lab_skip_partner_pdos` is a boolean, false by default, read-only
  after load. Both experimental modes use the same binary.
- Requires DMI vendor `Framework`, product `Laptop 13 (AMD Ryzen AI 300 Series)`,
  and one-based UCSI connector4 (sysfs port3, left-rear on this machine).
- Applies to partner source/sink PDO queries only. Local PDO reads are unchanged.
  Device identity is not available reliably at this stage, so it affects **any
  peripheral on that connector** while enabled, not only this LG.
- Returns no PDOs using the existing missing-capability convention and clears the
  destination array. It does not fabricate a PD contract or send role/voltage
  settings. Partner power capabilities and some UCSI voltage/current values will
  be missing or incomplete; use EC/ACAD/battery evidence to judge power stability.
- Status, notification acknowledgments, cable and alternate-mode requests remain.
  This is deliberately not a test of all possible Linux-triggered failures.

Compile-only command, from the repository root:

```bash
bash lg-ultrafine-5k-debug/scripts/build-ucsi-instrumentation.sh --pd-query-test
bash lg-ultrafine-5k-debug/tests/run-ucsi-pdo-trial.sh
```

The build also includes the earlier command-tracing patch. Verified artifact:
`evidence/ucsi-build-CHVJka/drivers/usb/typec/ucsi/typec_ucsi.ko`.
Build inputs are the exact installed6.18.44 source/development files and
GCC15.3.0/binutils2.46. Link/modpost pass; vermagic matches6.18.44. BTF is skipped
because the packaged build files lack `vmlinux`. This module is not installed or
loaded. The source/build tree and binary are ignored; patches and build recipe
are versioned on `investigation/lg-ultrafine-5k`.

The offline fixture extracts the actual predicate and PDO-fetch function from
hash-verified6.18.44 source after applying the patch. Eight checks pass: default
off, target suppression/cache clearing, other connector, local capabilities,
other vendor, other product, existing transport errors, and missing capability.
It also checks the normal two-request4+3 PDO sequence. This does not test module
lifecycle or actual USB-C behavior. See
[recorded output](../evidence/framework-support-packet/ucsi-pdo-trial-tests.txt).

## Concrete proposed activation and rollback — approval required

**Preferred first trial:** transient module replacement, no persistent install,
boot entry or firmware write. Current kernel permits module unload and has
CONFIG_MODULE_SIG disabled; current `typec_ucsi` holder is `ucsi_acpi`. These
facts must be rechecked immediately before activation. Check sufficient battery,
save work, stop our UCSI probes/console collectors, and ensure no unexpected
module consumers. Do not force an unload if busy.

For each leg, with the LG disconnected initially, unload `ucsi_acpi` then
`typec_ucsi`, insert the prepared module with the selected flag, and load stock
`ucsi_acpi` again. The representative commands below are **review material, not
a request to run them now**. Actual execution must check each result and restore
stock on failure before asking for another reconnect.

```bash
sudo modprobe -r ucsi_acpi
sudo modprobe -r typec_ucsi
sudo insmod /home/taylan/config/lg-ultrafine-5k-debug/evidence/ucsi-build-CHVJka/drivers/usb/typec/ucsi/typec_ucsi.ko lab_skip_partner_pdos=1
sudo modprobe ucsi_acpi
```

Reloading the ACPI backend can reset/reinitialize the UCSI interface and affects
Type-C registration on **all ports**, even though the query suppression is
connector-specific. USB peripherals or charging status may temporarily disappear;
the kernel remains experimental until restored. Internal eDP is not targeted.
Module replacement may fail or hang; retain the normal reboot recovery path.

Rollback after stopping any trial probes, checking each command:

```bash
sudo modprobe -r ucsi_acpi
sudo modprobe -r typec_ucsi
sudo modprobe ucsi_acpi
```

The final modprobe loads the stock dependency from the installed system. Verify
the lab parameter no longer exists and normal Type-C registration returns. If
unload/reload cannot complete, reboot the unchanged normal system; do not use
forced module removal. A reconnect or monitor power cycle may still be needed to
clear peripheral state. No modified binary is copied into the installed module
tree and no persistent modprobe settings are written.

## Comparison and acceptance

1. **A:** patched binary, flag0 (stock query behavior), backend reloaded.
2. **B:** same binary, flag1, identical reload/reconnect and observation window.
3. **A again:** flag0 to check reproducibility; finally restore stock modules.

For each leg, keep cable/module/port/other connections and collection overhead
constant. Record at least120seconds after reconnect, longer if power stays up.
Use command traces to confirm GET_PDOS partner requests are absent only in B;
record ACAD/battery, EC state and external-router enumeration. Changing console
streaming between legs would introduce the timing confound seen previously.

Fewer UCSI error messages are not success: B necessarily removes some requests.
The first useful outcome is a real external Thunderbolt router; PD stability is
supporting evidence, not a requirement for display success.
If that succeeds, investigate DRM/EDID and native5120×2880@60 next. Then repeat
hotplug, boot and resume tests while preserving eDP. A single lucky connection
cannot establish a reliable workaround. If B still fails, restore stock and
consider the broader UCSI-disabled or pre-OS control before adding more quirks.

The working [investigation brief](../../framework-lg-ultrafine-5k-investigation.md)
requires a concrete proposal, rollback and approval before kernel/system changes.
Source preparation, offline tests and compilation are complete; activation remains
pending. The existing EC RFC is **not** included in this kernel trial.

Primary references: exact6.18.44 source saved locally (see
[source/build pins](LOCAL-ENGINEERING.md));
[Linux module parameter documentation](https://docs.kernel.org/admin-guide/kernel-parameters.html);
[public UCSI source](https://github.com/torvalds/linux/blob/v6.18/drivers/usb/typec/ucsi/ucsi.c)
for architecture only; and [EC analysis with pinned sources](EC-ACK-INVESTIGATION.md).
