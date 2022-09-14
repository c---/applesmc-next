/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __ACPI_SBS_H
#define __ACPI_SBS_H

#include <acpi/battery.h>

void sbs_hook_register(struct acpi_battery_hook *hook);
void sbs_hook_unregister(struct acpi_battery_hook *hook);

#endif
