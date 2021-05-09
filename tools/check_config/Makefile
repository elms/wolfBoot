# Configuration values: see tools/config.mk
CONFIG_FILE?=../../.config
-include $(CONFIG_FILE)
include ../config.mk
include ../../options.mk

CFLAGS+=-I. -I../../ -I../../include

.PHONY: run clean

run:
	$(Q)$(RM) check_config.o
	$(Q)$(MAKE) check_config

check_config: check_config.o
	$(Q)gcc -o $@ $^ $(CFLAGS)
	$(Q)./$@

%.o:%.c
	$(Q)gcc -c -o $@ $^ $(CFLAGS)

clean:
	$(Q)rm -f check_config *.o
