#!/bin/sh
# NOTE: the "newer" check doesn't work on the kernel.org web server
wget --no-if-modified-since -N https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/acpi/sbs.c
wget --no-if-modified-since -N https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/acpi/sbshc.h
wget --no-if-modified-since -N https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hwmon/applesmc.c
