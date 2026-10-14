/* Offline fixture for the actual, extracted public EC acknowledgment helper.
 * Constants match the pinned cypress_pd_common.h and include/common.h.
 * No device access: successful I2C reads and one asserted completion interrupt
 * are simulated. This tests classification, not real concurrency or transport.
 */
#include <stdio.h>
#include <stdlib.h>

#define EC_SUCCESS 0
#define EC_ERROR_INVAL 5
#define EC_ERROR_BUSY 6
#define CCG_DEV_INTR 1
#define CCG_PORT0_INTR 2
#define CCG_PORT1_INTR 4
#define CCG_RESPONSE_REG 0x007e
#define CCG_PORT_PD_RESPONSE_REG(x) (0x1400 + (x) * 0x1000)
#define CCG_RESPONSE_SUCCESS 2
#define CPRINTS(...) ((void)0)

struct gpio_dt_spec { int unused; };
static const struct gpio_dt_spec gpio;
static const struct { int gpio; } pd_chip_config[2] = {{0}, {1}};
static int flags, dev_response, p0_response, p1_response, cleared;

static const struct gpio_dt_spec *gpio_get_dt_spec(int id)
{ (void)id; return &gpio; }
static int gpio_pin_get_dt(const struct gpio_dt_spec *pin)
{ (void)pin; return 1; } /* No interrupt pending before the write. */
static int cypd_get_int(int controller, int *value)
{ (void)controller; *value = flags; return EC_SUCCESS; }
static int cypd_read_reg16(int controller, int reg, int *value)
{
    (void)controller;
    switch (reg) {
    case CCG_RESPONSE_REG: *value = dev_response; break;
    case CCG_PORT_PD_RESPONSE_REG(0): *value = p0_response; break;
    case CCG_PORT_PD_RESPONSE_REG(1): *value = p1_response; break;
    default: abort();
    }
    return EC_SUCCESS;
}
static int cypd_clear_int(int controller, int mask)
{ (void)controller; cleared |= mask; return EC_SUCCESS; }
static int cypd_write_reg8(int controller, int reg, int data)
{ (void)controller; (void)reg; (void)data; return EC_SUCCESS; }
static int cypd_wait_for_ack(int controller, int timeout)
{ (void)controller; (void)timeout; return EC_SUCCESS; }
static void crec_usleep(int delay) { (void)delay; }

#include "cypd-ack-under-test.inc"

int main(void)
{
    const struct {
        const char *name;
        int reg, irq, dev, p0, p1, expected, expected_clear;
    } cases[] = {
        {"device ACK", 0x10, 1, 2, 0, 0, EC_SUCCESS, 1},
        {"port0 ACK", 0x1032, 2, 0, 2, 0, EC_SUCCESS, 2},
        {"port1 ACK", 0x2032, 4, 0, 0, 2, EC_SUCCESS, 4},
        {"captured IRQ=0, P1=0x0886", 0x2032, 0, 0, 0, 0x886, EC_ERROR_BUSY, 0},
        {"matching IRQ, async contract event", 0x2032, 4, 0, 0, 0x886, EC_ERROR_BUSY, 0},
        {"wrong-port ACK", 0x1032, 4, 0, 0, 2, EC_ERROR_BUSY, 0},
        {"empty response", 0x2032, 4, 0, 0, 0, EC_ERROR_INVAL, 4},
        {"invalid-state response", 0x2032, 4, 0, 0, 6, EC_ERROR_INVAL, 4},
    };
    int failures = 0;
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        flags = cases[i].irq;
        dev_response = cases[i].dev;
        p0_response = cases[i].p0;
        p1_response = cases[i].p1;
        cleared = 0;
        int result = cypd_write_reg8_wait_ack(1, cases[i].reg, 1);
        int ok = result == cases[i].expected && cleared == cases[i].expected_clear;
        printf("%s: %s: result=%d expected=%d clear=%x expected=%x\n",
               ok ? "PASS" : "FAIL", cases[i].name, result,
               cases[i].expected, cleared, cases[i].expected_clear);
        failures += !ok;
    }
    return failures;
}
