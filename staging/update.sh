#!/bin/sh
# NOTE: the "newer" check doesn't work on the kernel.org web server
wget --no-if-modified-since -N -O sbs.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/acpi/sbs.c?h=linux-rolling-stable"
wget --no-if-modified-since -N -O sbshc.h "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/acpi/sbshc.h?h=linux-rolling-stable"
wget --no-if-modified-since -N -O applesmc.c "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hwmon/applesmc.c?h=linux-rolling-stable"
