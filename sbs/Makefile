# SPDX-License-Identifier: GPL-2.0-or-later

obj-m      += sbs.o
KVER       ?= `uname -r`
KBASE      ?= /lib/modules/$(KVER)
KBUILD_DIR ?= $(KBASE)/build

all:
	make -C $(KBUILD_DIR) M=`pwd`

clean:
	rm -f *.ko *.o .*.cmd sbs.mod* modules.order Module.symvers

srcinstall:
	install -Dm644 Makefile $(TARGET)/Makefile
	install -Dm644 acpi/sbs.h $(TARGET)/acpi/sbs.h
	install -Dm644 sbs.c $(TARGET)/sbs.c
	install -Dm644 sbshc.h $(TARGET)/sbshc.h
