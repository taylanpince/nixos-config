# Draft follow-up to Framework issue225 — not posted

Further evidence from the same Ryzen AI9 HX370 / LG27MD5KL, BIOS4.02,
EC `lilac-4.0.2-fdbf549`, both PD controllers0.0.21. Same original LG cable
works on Mac. LG remains on the left-rear USB-C expansion module.

One UCSI-only capture sustained PD charging for about42seconds, then detached
and reattached as a debug accessory without anyone touching the cable. No UCSI
commands were issued for about40.5seconds before the status query reporting loss.
No GET_PD_MESSAGE was issued in either of the two captures.

A subsequent simultaneous EC-console/UCSI capture reproduced the short blip:

```text
[6608.795500 CL: p3 s0 i3000 v20000]
[6608.803000 cypd_write_reg8_wait_ack C:1 Unexpected response 0x0 to reg 0x2032]
[6608.809300 Dev 0x0]
[6608.824500 P0 0x0]
[6608.829000 P1 0x886]
[6608.866200 AC on]
[6608.971800 CL: p3 s0 i4700 v20000]
[6609.238600 PORT_DISCONNECT]
[6609.262900 cypd_write_reg8_wait_ack C:1 0x2032 response 0x0]
[6609.268100 cypd_cfet_vbus_control:3 fail:5]
[6609.379100 CYPD_RESPONSE_PORT_CONNECT 3]
[6609.535400 AC off]
```

The ACK mismatch precedes disconnect; subsequent FET failures may be consequences.
Linux reports PD sink, then disconnect, then debug accessory. Its cable alternate-
mode query fails after the debug state. Early source-PDO offset4 failure is followed
by successful source-PDO reads. Console streaming may perturb timing; the faster
failure is not a controlled comparison. Both captures cleaned up with zero missed
probes or trace-buffer losses.

We reproduced a false-success path in the public
[`cypd_write_reg8_wait_ack`](https://github.com/FrameworkComputer/EmbeddedController/blob/01e6abe45e47b7ce858574b6f49f7547eaf5e33a/zephyr/program/framework/src/cypd_ccg8.c)
using the actual extracted function with mocked I2C/interrupts. For the tuple
above, the diagnostic reads overwrite `event` with0x0886; `event>=0x80` skips
ACK validation and returns the successful register-read status. Matching IRQ with
an asynchronous event and wrong-port ACK also falsely succeed in the fixture.

An offline RFC guard rejects these cases, but is not a complete firmware fix:
the public charge-port callers ignore return values and update cached FET state
even on failure. We have not built or flashed modified firmware and do not claim
this is the cause on the installed EC. Installed-source correspondence is unknown:
the console labels extended PD types3/4/6 unknown, while the public handler
already supports3/4.

Could Framework identify the source revision for the installed EC and review
command ACK/event serialization and charge-port error propagation against this
trace? Is there a model-specific diagnostic or fixed BIOS/PD build suitable for
this laptop and monitor? We can provide the small regression fixture, RFC guard
and reviewed EC/UCSI excerpts. A diagnostic build recording transaction task,
expected/actual IRQ, response, I2C/return status and cached FET state would help
distinguish a cause from fallout. Display remains undetected on both NixOS and
Fedora; no external Thunderbolt router enumerates.
