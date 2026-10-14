# Charge-port override trial

Prepared 11 October 2026 after the EC probe showed that the Lilac EC implements
`PD_CHARGE_PORT_OVERRIDE` (host command 0x0114) and none of the Chromium Type-C
discovery or control commands. See the RESULTS.md entry for that probe.

## Question

On both rear USB4 ports the LG's PD session collapses within about a second of the
contract. The EC console showed the collapse following `board_set_active_charge_port
port 3`, the CFET register writes with the unexpected acknowledgment, and a
renegotiation to 4.7 A. On the front-right port, which the EC does select as the
charge port but which cannot enter Thunderbolt mode, the session is stable.

If the EC is told never to select the LG's port as charge input, the charge-manager
sequence is skipped while the CCG8 still negotiates PD on its own. Then:

- **Session survives and an external Thunderbolt router appears:** the charge path
  is the trigger and `chargeoverride dontcharge` is an immediate userspace
  workaround, at the cost of not charging from the monitor.
- **Session still collapses to a debug accessory:** the trigger is in alternate-mode
  or cable handling, which matches the external report that the bundled LG cable's
  older e-marker fails on this laptop. The arriving Thunderbolt 5 cable is then the
  next test.

## What the runner does

`scripts/charge-override-trial.sh --run [seconds]` (default 240, root required):

1. Preflight: tools present, `ucsi-probe-window.sh --check` passes, EC reports
   0x0114 support, battery at least 40 %. `--check` stops here with no change.
2. Records EC charge state, `--pdports`, battery, UCSI supplies, Type-C partners,
   Thunderbolt and DRM state with the LG still on the front-right port.
3. Sets `chargeoverride dontcharge`, waits 6 s and records the same state again so
   the effect of the override is visible on the known-good connection first.
4. Prompts to unplug the LG from the front-right port.
5. Starts the proven `ucsi-probe-window.sh --capture-with-ec` (UCSI command probes,
   connector and Thunderbolt tracepoints, EC console stream, 1 s power samples).
6. After `ENABLED`, prompts to plug the LG into the rear-left module, then records
   a one-line snapshot every 5 s: battery, AC, rear-left supply, port3 partner
   state, any external Thunderbolt router, any connected external DP connector.
7. After the window, records state again and runs the read-only `collect.sh`.
8. Cleanup trap, on any exit: `chargeoverride off`, verification sample, chown.

## Effects and rollback

- While active, the laptop does not charge from any port and runs on battery. The
  override is cleared by the trap; manual rollback if a crash prevents it:

  ```bash
  sudo /nix/store/3bqchzi9v7jr8ragwrvd6a3wnaicxbdj-fw-ectool-0-unstable-2024-04-23/bin/ectool --interface=dev chargeoverride off
  ```

  A reboot also clears it. Check with `framework_tool --driver cros-ec --pdports`
  (an `Active Port: Yes` entry returns once a charger is accepted again) and
  `ectool chargestate show`.
- Trace probes and the EC console stream are removed by `ucsi-probe-window.sh`
  exactly as in the earlier captures; its documented rollback applies.
- No kernel module, firmware, PD role, mode or persistent setting is changed.

## Reading the result

`snapshots.txt` is the acceptance record. The success criterion is an external
Thunderbolt router (anything other than `0-0`, `1-0`, `domain0`, `domain1`) or a
connected external DP connector; a stable PD contract alone is supporting evidence.
`capture-stdout.txt` names the UCSI/EC capture directory; compare its
`ec-console-live.txt` with `evidence/framework-support-packet/nixos-ec-failure-live.txt`
to see whether the `board_set_active_charge_port port 3` and `0x2032` lines are absent
and whether `PORT_DISCONNECT` still follows the contract.
