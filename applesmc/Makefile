# SPDX-License-Identifier: GPL-2.0-or-later

obj-m      += applesmc.o
KVER       ?= `uname -r`
KBASE      ?= /lib/modules/$(KVER)
KBUILD_DIR ?= $(KBASE)/build
EXTRA_CFLAGS := -I$(M)/sbs

all:
	make -C $(KBUILD_DIR) M=`pwd`

clean:
	rm -f *.ko *.o .*.cmd applesmc.mod* modules.order Module.symvers

srcinstall:
	install -Dm644 Makefile $(TARGET)/Makefile
	install -Dm644 applesmc.c $(TARGET)/applesmc.c
