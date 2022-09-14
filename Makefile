# SPDX-License-Identifier: GPL-2.0-or-later

obj-y      := applesmc/ sbs/
KVER       ?= `uname -r`
KBASE      ?= /lib/modules/$(KVER)
KBUILD_DIR ?= $(KBASE)/build

all:
	make -C $(KBUILD_DIR) M=`pwd`

clean:
	cd applesmc && make clean
	cd sbs && make clean
	rm -f modules.order Module.symvers .modules.order.cmd .Module.symvers.cmd
