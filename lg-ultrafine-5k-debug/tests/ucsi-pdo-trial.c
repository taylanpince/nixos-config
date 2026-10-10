/* Exercise the actual patched predicate and PDO-fetch function without hardware. */
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
typedef uint8_t u8;
typedef uint32_t u32;
enum typec_role { TYPEC_SINK, TYPEC_SOURCE };
#define DMI_SYS_VENDOR 0
#define DMI_PRODUCT_NAME 1
#define UCSI_CAP_PDO_DETAILS 1
#define UCSI_MAX_PDOS 4
#define PDO_MAX_OBJECTS 7
#define dev_warn_once(dev, ...) ((void)(dev))
struct ucsi { struct { int features; } cap; void *dev; };
struct ucsi_connector { struct ucsi *ucsi; int num; };
static bool lab_skip_partner_pdos;
static bool vendor_match, product_match;
static int calls, query_result;
static bool dmi_match(int field, const char *value)
{ (void)value; return field == DMI_SYS_VENDOR ? vendor_match : product_match; }
static int ucsi_read_pdos(struct ucsi_connector *con, enum typec_role role,
                         int partner, u32 *pdos, int offset, int count)
{
    (void)con; (void)role; (void)partner;
    /* Check the ordinary two-read path still requests exactly 4 + 3 PDOs. */
    if (offset != (calls ? 4 : 0) || count != (calls ? 3 : 4)) abort();
    ++calls;
    if (query_result < 0) return query_result;
    for (int i = 0; i < count; ++i) pdos[offset + i] = 100 + offset + i;
    return count * sizeof(u32);
}
#include "ucsi-pdo-under-test.inc"
int main(void)
{
    const struct {
        const char *name;
        bool enabled, vendor, product;
        int connector, partner, features, io_result, expected, expected_calls;
    } cases[] = {
        {"default off", 0, 1, 1, 4, 1, 1, 0, 7, 2},
        {"target partner suppressed", 1, 1, 1, 4, 1, 1, 0, 0, 0},
        {"other connector untouched", 1, 1, 1, 1, 1, 1, 0, 7, 2},
        {"local capabilities untouched", 1, 1, 1, 4, 0, 1, 0, 7, 2},
        {"other vendor untouched", 1, 0, 1, 4, 1, 1, 0, 7, 2},
        {"other product untouched", 1, 1, 0, 4, 1, 1, 0, 7, 2},
        {"stock errors preserved", 0, 1, 1, 4, 1, 1, -95, -95, 1},
        {"missing feature preserved", 0, 1, 1, 4, 1, 0, 0, 0, 0},
    };
    int failures = 0;
    for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        struct ucsi ucsi = { .cap.features = cases[i].features };
        struct ucsi_connector con = { &ucsi, cases[i].connector };
        u32 pdos[PDO_MAX_OBJECTS];
        memset(pdos, 0xa5, sizeof(pdos));
        lab_skip_partner_pdos = cases[i].enabled;
        vendor_match = cases[i].vendor;
        product_match = cases[i].product;
        query_result = cases[i].io_result;
        calls = 0;
        int result = ucsi_get_pdos(&con, TYPEC_SOURCE, cases[i].partner, pdos);
        bool ok = result == cases[i].expected && calls == cases[i].expected_calls;
        if (i == 1)
            for (size_t j = 0; j < PDO_MAX_OBJECTS; ++j) ok &= pdos[j] == 0;
        printf("%s: %s (return=%d, queries=%d)\n", ok ? "PASS" : "FAIL",
               cases[i].name, result, calls);
        failures += !ok;
    }
    return failures != 0;
}
